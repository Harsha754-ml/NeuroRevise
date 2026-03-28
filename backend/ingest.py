import os
import json
import re
import time
import io
from uuid import uuid4

from dotenv import load_dotenv
from google import genai
from youtube_transcript_api import YouTubeTranscriptApi
import PyPDF2
from gtts import gTTS

import database

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

MODEL_NAME = "gemini-2.5-flash"
FALLBACK_MODEL = "gemini-1.5-flash"


def create_chronos_plan(topic_name: str, flashcards: list):
    """
    Creates a multi-stage 'Chronos Plan' for a newly ingested topic.
    """
    now = time.time()
    topic_id = "topic_" + str(uuid4())[:8]

    plan = {
        "topic_id": topic_id,
        "topic_name": topic_name,
        "created_at": now,
        "status": "active",
        "current_stage": 0,
        "steps": [
            {
                "stage": 0,
                "type": "audio_summary",
                "title": "Immediate Synthesis",
                "content": f"Audio summary for {topic_name} is ready for review.",
                "due_at": now,
                "status": "pending",
            },
            {
                "stage": 1,
                "type": "text_recap",
                "title": "Synaptic Calibration",
                "content": f"Recapping {topic_name}: {flashcards[0]['question'] if flashcards else ''}",
                "due_at": now + 259200,
                "status": "pending",
            },
            {
                "stage": 2,
                "type": "quiz",
                "title": "The Knowledge Litmus",
                "content": f"Final challenge for {topic_name}.",
                "due_at": now + 864000,
                "status": "pending",
            },
        ],
    }

    database.add_learning_plan(plan)

    if flashcards:
        generate_audio(flashcards[0]["id"], flashcards[0]["question"], flashcards[0]["answer"])


def _persist_flashcards(topic_name: str, flashcards_data: list, source_type: str, target_completion_at=None) -> list:
    created = []
    now = time.time()

    for item in flashcards_data:
        answer = (item.get("answer") or "").strip()
        question = (item.get("question") or "").strip()
        if not answer or not question:
            continue

        options = item.get("options") or [answer, "Distractor A", "Distractor B", "Distractor C"]
        if len(options) < 4:
            options = options + ["Distractor A", "Distractor B", "Distractor C"]
            options = options[:4]

        fc = {
            "id": "fc_" + str(uuid4())[:8],
            "topic_name": topic_name,
            "question": question,
            "answer": answer,
            "options": options,
            "subject": (item.get("subject") or topic_name)[:40],
            "source_type": source_type,
            "created_at": now,
            "last_reviewed": 0,
            "stability": 24.0,
            "review_count": 0,
            "ignore_count": 0,
            "status": "active",
            "summary": "",
            "audio_ready": False,
            "notified_once": False,
            "target_completion_at": target_completion_at,
        }
        database.add_flashcard(fc)
        created.append(fc)

    if created:
        create_chronos_plan(topic_name, created)

    return created


def _build_local_flashcards(text: str, topic_name: str, max_cards: int = 6) -> list:
    cleaned = re.sub(r"\s+", " ", (text or "")).strip()
    if not cleaned:
        cleaned = f"Uploaded material for {topic_name}."

    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", cleaned) if s.strip()]
    if not sentences:
        sentences = [line.strip() for line in cleaned.splitlines() if line.strip()]
    if not sentences:
        sentences = [cleaned]

    selected = []
    for s in sentences:
        if len(s) < 15:
            continue
        selected.append(s)
        if len(selected) >= max_cards:
            break

    if not selected:
        selected = sentences[:1]

    cards = []
    for i, sentence in enumerate(selected, start=1):
        distractors = [f"Not this: {topic_name}", "Needs more review", "Unrelated concept"]
        cards.append(
            {
                "question": f"What is key point {i} from {topic_name}?",
                "answer": sentence[:240],
                "options": [sentence[:240], distractors[0], distractors[1], distractors[2]],
                "subject": topic_name[:20] if topic_name else "General",
            }
        )

    return cards


def ingest_text(text: str, topic_name: str, target_completion_at=None, source_type: str = "text_upload") -> list:
    cleaned_text = (text or "").strip()
    if not cleaned_text:
        return []

    # Persist uploaded/raw context for grounded AI chat
    database.add_uploaded_context(topic_name, cleaned_text, source_type=source_type)

    if client:
        prompt = f"""You are a master neuro-pedagogy expert for the MemoryForge system.
Analyze the input text and generate 5-10 high-retention flashcards.
Return ONLY a raw JSON array. No markdown, no triple backticks, no explanations.

Each object MUST have:
1. "question": A clear, concise question.
2. "answer": The factual, correct answer.
3. "options": A list of exactly 4 strings (the correct answer + 3 plausible but incorrect distractors).
4. "subject": A very short (1-2 words) sub-topic or category for this card.

Input Text:
{cleaned_text[:8000]}"""

        try:
            time.sleep(1)
            response = client.models.generate_content(model=MODEL_NAME, contents=prompt)
            text_resp = (response.text or "").strip()
            if text_resp:
                if "```" in text_resp:
                    text_resp = re.sub(r"```json\s*|\s*```", "", text_resp)

                flashcards_data = json.loads(text_resp)
                if isinstance(flashcards_data, list) and flashcards_data:
                    created = _persist_flashcards(topic_name, flashcards_data, "ai_ingest", target_completion_at)
                    if created:
                        database.add_event(f"AI Ingested: {topic_name} ({len(created)} cards)")
                        return created
        except Exception as e:
            print(f"Gemini ingest error, switching to local fallback: {e}")

    fallback_data = _build_local_flashcards(cleaned_text, topic_name)
    created = _persist_flashcards(topic_name, fallback_data, "fallback_ingest", target_completion_at)
    if created:
        database.add_event(f"Fallback Ingested: {topic_name} ({len(created)} cards)")
    return created


def ingest_youtube(url: str, topic_name: str, target_completion_at=None) -> list:
    try:
        video_id = url.split("v=")[1].split("&")[0]
        transcript = YouTubeTranscriptApi.get_transcript(video_id)
        text = " ".join([t["text"] for t in transcript])
        return ingest_text(text[:4000], topic_name, target_completion_at, source_type="youtube_upload")
    except Exception as e:
        print(f"YouTube Ingest Error: {e}")
        return []


def ingest_pdf(file_bytes: bytes, topic_name: str, target_completion_at=None) -> list:
    try:
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
        text = ""
        for page in pdf_reader.pages[:5]:
            text += (page.extract_text() or "")

        if not text.strip():
            text = f"Uploaded PDF for {topic_name}. Text extraction was limited; generating starter cards."

        return ingest_text(text[:4000], topic_name, target_completion_at, source_type="pdf_upload")
    except Exception as e:
        print(f"PDF Ingest Error: {e}")
        return []


def generate_summary(question: str, answer: str) -> str:
    if not client:
        return f"Memory card for {question}"

    try:
        prompt = f"Summarize this into one short, memorable sentence for audio playback: Q:{question} A:{answer}"
        response = client.models.generate_content(model=MODEL_NAME, contents=prompt)
        return (response.text or "").replace("\n", " ").strip()
    except Exception:
        return f"Key takeaway: {answer[:50]}"


def generate_audio(flashcard_id: str, question: str, answer: str) -> str:
    try:
        summary = generate_summary(question, answer)
        database.update_flashcard(flashcard_id, {"summary": summary})

        os.makedirs("audio", exist_ok=True)
        path = f"audio/{flashcard_id}.mp3"
        tts = gTTS(text=summary, lang="en")
        tts.save(path)

        database.update_flashcard(flashcard_id, {"audio_ready": True})
        return path
    except Exception as e:
        print(f"Audio Generation Error: {e}")
        return ""
