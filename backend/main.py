import os
import time
import asyncio
import re
from uuid import uuid4
from typing import Annotated, List, Optional
from fastapi import FastAPI, BackgroundTasks, UploadFile, File, Form, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import database
import curve_engine
import ingest
import socket
import threading
from scheduler import start_scheduler, trigger_n8n_webhook, get_primary_ip

app = FastAPI(title="NeuroRevise API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def start_ip_beacon():
    """Broadcasts server URL every 5 seconds for mobile discovery."""
    def beacon():
        ip = get_primary_ip()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Enable broadcast
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        print(f"📡 [BEACON] Starting IP discovery on port 5555... ({ip})")
        while True:
            try:
                message = f"MEMORYFORGE_SERVER:http://{ip}:8000"
                sock.sendto(message.encode(), ('<broadcast>', 5555))
                time.sleep(5)
            except Exception as e:
                print(f"❌ [BEACON] Error: {e}")
                time.sleep(10)
    
    thread = threading.Thread(target=beacon, daemon=True)
    thread.start()

@app.on_event("startup")
def startup_event():
    database.init_db()
    start_scheduler()
    start_ip_beacon()

# -----------------
# MODELS
# -----------------
class AddFlashcardReq(BaseModel):
    topic_name: str
    question: str
    answer: str
    source_type: str = "manual"
    target_completion_at: Optional[float] = None

class ReviewReq(BaseModel):
    flashcard_id: str
    result: str

class TextIngestReq(BaseModel):
    text: str
    topic_name: str
    target_completion_at: Optional[float] = None

class YoutubeIngestReq(BaseModel):
    url: str
    topic_name: str
    target_completion_at: Optional[float] = None

class ClearNotifReq(BaseModel):
    notification_id: str

class DemoToggleReq(BaseModel):
    enabled: bool

class PresentationToggleReq(BaseModel):
    enabled: bool

class ReportEmailReq(BaseModel):
    email: str

class GameScoreReq(BaseModel):
    score: int
    result: Optional[str] = None  # for battle mode win/loss
class AIChatReq(BaseModel):
    question: str
    top_k: int = 5

class SpeakReq(BaseModel):
    text: str
    urgency: str = "normal"


# -----------------
# FLASHCARD ENDPOINTS
# -----------------
@app.post("/flashcard/add")
def add_flashcard(req: AddFlashcardReq, background_tasks: BackgroundTasks):
    fc = {
        "id": "fc_" + str(uuid4())[:8],
        "topic_name": req.topic_name,
        "question": req.question,
        "answer": req.answer,
        "source_type": req.source_type,
        "created_at": time.time(),
        "last_reviewed": time.time(),
        "stability": 24.0,
        "review_count": 0,
        "ignore_count": 0,
        "status": "active",
        "summary": "",
        "audio_ready": False,
        "notified_once": False,
        "target_completion_at": req.target_completion_at
    }
    database.add_flashcard(fc)
    database.add_event(f"Added Manual: {req.topic_name}")
    
    background_tasks.add_task(ingest.generate_audio, fc["id"], req.question, req.answer)
    return fc

@app.get("/flashcards")
def get_flashcards():
    flashcards = database.get_all_flashcards()
    demo_mode = database.get_demo_mode()
    
    enriched = []
    for fc in flashcards:
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        urgency = curve_engine.get_urgency(score)
        
        fc_enriched = dict(fc)
        fc_enriched["retention_score"] = score
        fc_enriched["urgency_level"] = urgency
        fc_enriched["next_reminder_minutes"] = curve_engine.get_next_reminder_minutes(fc["stability"], demo_mode)
        fc_enriched["curve_points"] = curve_engine.get_curve_points(fc["last_reviewed"], fc["stability"], demo_mode)
        enriched.append(fc_enriched)
        
    return enriched

@app.get("/flashcard/{id}")
def get_flashcard(id: str):
    cards = get_flashcards()
    for c in cards:
        if c["id"] == id:
            return c
    raise HTTPException(status_code=404, detail="Flashcard not found")

@app.post("/flashcard/review")
def review_flashcard(req: ReviewReq):
    fc = database.get_flashcard(req.flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
        
    new_stability = curve_engine.update_stability(fc["stability"], req.result)
    updates = {
        "stability": new_stability,
        "last_reviewed": time.time(),
        "review_count": fc.get("review_count", 0) + 1,
        "ignore_count": 0
    }
    database.update_flashcard(req.flashcard_id, updates)
    database.add_event(f"Reviewed: {fc['topic_name']} ({req.result})")
    
    # Clear any pending notification for it
    pending = database.get_pending_notifications()
    for p in pending:
        if p["flashcard_id"] == req.flashcard_id:
            database.clear_notification(p["notification_id"])
            
    return get_flashcard(req.flashcard_id)

@app.delete("/flashcard/{id}")
def delete_flashcard(id: str):
    success = database.delete_flashcard(id)
    if success:
        return {"success": True}
    raise HTTPException(status_code=404)


@app.delete("/lesson")
def delete_lesson(topic_name: str):
    name = (topic_name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="topic_name is required")

    result = database.delete_lesson_by_topic(name)
    deleted_cards = result.get("flashcards_deleted", 0)
    deleted_plans = result.get("plans_deleted", 0)

    for fc_id in result.get("flashcard_ids", []):
        try:
            audio_path = f"audio/{fc_id}.mp3"
            if os.path.exists(audio_path):
                os.remove(audio_path)
        except Exception:
            pass

    if deleted_cards == 0 and deleted_plans == 0:
        raise HTTPException(status_code=404, detail="Lesson not found")

    database.add_event(f"Deleted lesson: {name} ({deleted_cards} cards)")
    return {"success": True, "topic_name": name, "deleted_cards": deleted_cards, "deleted_plans": deleted_plans}

# -----------------
# INGEST ENDPOINTS
# -----------------
@app.post("/ingest/text")
def ingest_text_api(req: TextIngestReq):
    try:
        # ingest_text now handles Chronos Plan creation internally
        fcs = ingest.ingest_text(req.text, req.topic_name, req.target_completion_at)
        if not fcs:
            raise HTTPException(status_code=500, detail="Gemini failed or returned empty")
        return fcs
    except Exception as e:
        print(f"Ingest Text Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ingest/youtube")
def ingest_youtube_api(req: YoutubeIngestReq):
    try:
        fcs = ingest.ingest_youtube(req.url, req.topic_name, req.target_completion_at)
        if not fcs:
            raise HTTPException(status_code=500, detail="Gemini/YouTube extraction failed")
        return fcs
    except Exception as e:
        print(f"Ingest URL Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ingest/file")
async def ingest_file_api(
    file: Annotated[UploadFile, File(...)], 
    topic_name: Annotated[str, Form(...)],
    target_completion_at: Annotated[Optional[float], Form()] = None
):
    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")

        original_filename = (file.filename or "upload.txt").strip()
        filename_lower = original_filename.lower()

        if not (filename_lower.endswith(".pdf") or filename_lower.endswith(".txt")):
            raise HTTPException(status_code=400, detail="Unsupported file format (pdf/txt only)")

        uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
        os.makedirs(uploads_dir, exist_ok=True)

        safe_filename = "".join([c for c in original_filename if c.isalnum() or c in "._- "]).strip()
        if not safe_filename:
            safe_filename = "upload.txt"

        save_path = os.path.join(uploads_dir, f"{int(time.time())}_{safe_filename}")
        with open(save_path, "wb") as f:
            f.write(contents)
        print(f"[STORAGE] File saved to: {save_path}")

        if filename_lower.endswith(".pdf"):
            fcs = ingest.ingest_pdf(contents, topic_name, target_completion_at)
        else:
            fcs = ingest.ingest_text(contents.decode("utf-8", errors="ignore"), topic_name, target_completion_at)

        if not fcs:
            raise HTTPException(status_code=500, detail="Failed to parse file or AI failed")

        return {"success": True, "cards": fcs, "saved_at": save_path}
    except Exception as e:
        print(f"Ingest File Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

# -----------------
# LEARNING PLAN ENDPOINTS
# -----------------
@app.get("/learning-plans")
def get_learning_plans():
    return database.get_all_learning_plans()

@app.get("/learning-plan/{topic_id}")
def get_learning_plan(topic_id: str):
    plan = database.get_learning_plan(topic_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    return plan

@app.get("/reports/revision-progress")
def revision_progress_report():
    plans = database.get_all_learning_plans()

    lessons = []
    for plan in plans:
        steps = plan.get("steps", [])
        if steps:
            done = sum(1 for s in steps if s.get("status") == "completed")
            status = "completed" if done == len(steps) else "pending"
        else:
            status = "completed" if plan.get("status") == "completed" else "pending"

        lessons.append({
            "name": plan.get("topic_name") or plan.get("topic_id", "Untitled"),
            "status": status,
        })

    completed = sum(1 for l in lessons if l["status"] == "completed")
    return {
        "completed": completed,
        "total": len(lessons),
        "lessons": lessons,
        "report_email": database.get_report_email(),
    }


# -----------------
# NOTIFICATION ENDPOINTS
# -----------------
@app.get("/notifications/pending")
def pending_notifications():
    return database.get_pending_notifications()

@app.post("/notifications/clear")
def clear_notification(req: ClearNotifReq):
    database.clear_notification(req.notification_id)
    return {"success": True}

@app.post("/notifications/clear-all")
def clear_all_notifications():
    for p in database.get_pending_notifications():
        database.clear_notification(p["notification_id"])
    return {"success": True}

@app.post("/notifications/trigger-manual/{id}")
def trigger_manual_notification(id: str):
    # 1. Try to find as a flashcard
    fc = database.get_flashcard(id)
    if fc:
        # Trigger directly for flashcard
        ip = get_primary_ip()
        notification = {
            "notification_id": f"notif_zap_{int(time.time()*1000)}",
            "flashcard_id": id,
            "topic_name": fc["topic_name"],
            "question": fc["question"],
            "retention_score": fc.get("retention_score", 100),
            "urgency_level": fc.get("urgency_level", "safe"),
            "action": "force_quiz",
            "audio_url": f"http://{ip}:8000/audio/{id}",
            "summary_text": fc.get("summary", ""),
            "created_at": time.time()
        }
        database.add_notification(notification)
        
        payload = notification.copy()
        payload["type"] = "Manual_Zap"
        database.add_event(f"⚡ Manual Zap: {fc['topic_name']}")
        trigger_n8n_webhook(payload)
        return {"success": True, "type": "flashcard"}

    # 2. Try to find as a learning plan
    plan = database.get_learning_plan(id)
    if plan:
        # Find the current pending stage
        pending = [s for s in plan.get("steps", []) if s.get("status") == "pending"]
        if not pending:
            return {"success": False, "detail": "Plan already completed"}
        
        next_step = sorted(pending, key=lambda s: s["stage"])[0]
        
        # Get topic info from any flashcard of this topic
        all_fcs = database.get_all_flashcards()
        topic_fcs = [f for f in all_fcs if f["topic_name"] == plan.get("topic_name", plan["topic_id"]) or f["id"] == plan["topic_id"]]
        
        # Fallback if no specific flashcard
        q = topic_fcs[0]["question"] if topic_fcs else "Recall Session"
        a = topic_fcs[0]["answer"] if topic_fcs else "Review your notes"
        ip = get_primary_ip()

        notification = {
            "notification_id": f"notif_zap_{int(time.time()*1000)}",
            "flashcard_id": id,
            "topic_name": plan.get("topic_name", "Recall"),
            "question": q,
            "retention_score": 100,
            "urgency_level": "safe",
            "action": "open_summary",
            "audio_url": f"http://{ip}:8000/audio/{topic_fcs[0]['id']}" if topic_fcs else "",
            "summary_text": topic_fcs[0].get("summary", "") if topic_fcs else "Plan Update",
            "created_at": time.time()
        }
        database.add_notification(notification)

        payload = {
            "topic_id": plan["topic_id"],
            "topic_name": plan.get("topic_name", plan["topic_id"]),
            "question": q,
            "answer": a,
            "current_stage": next_step["stage"],
            "type": "Manual_Zap"
        }
        database.add_event(f"⚡ Manual Zap (Plan): {plan['topic_id']}")
        trigger_n8n_webhook(payload)
        return {"success": True, "type": "plan"}

    raise HTTPException(status_code=404, detail="Entity not found")

# -----------------
# AUDIO ENDPOINTS
# -----------------
@app.get("/audio/{id}")
def get_audio(id: str):
    path = f"audio/{id}.mp3"
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(path, media_type="audio/mpeg")


def _extract_keywords(text: str):
    words = re.findall(r"[a-zA-Z0-9]+", (text or "").lower())
    stop = {
        "the", "is", "a", "an", "and", "or", "to", "of", "in", "for", "on", "with",
        "what", "how", "why", "when", "where", "who", "which", "this", "that", "from"
    }
    return [w for w in words if len(w) > 2 and w not in stop]


def _score_blob_against_keywords(blob: str, keywords: set) -> int:
    if not keywords:
        return 0
    text = (blob or "").lower()
    return sum(1 for k in keywords if k in text)


def _best_context_snippet(text: str, keywords: set, max_len: int = 450) -> str:
    cleaned = re.sub(r"\s+", " ", (text or "")).strip()
    if not cleaned:
        return ""
    if not keywords:
        return cleaned[:max_len]

    lower = cleaned.lower()
    positions = [lower.find(k) for k in keywords if lower.find(k) != -1]
    if not positions:
        return cleaned[:max_len]

    pivot = min(positions)
    start = max(0, pivot - 140)
    end = min(len(cleaned), start + max_len)
    return cleaned[start:end]


@app.post("/ai/chat")
def ai_chat(req: AIChatReq):
    question = (req.question or "").strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question is required")

    keywords = set(_extract_keywords(question))
    contexts = database.get_uploaded_contexts()
    cards = get_flashcards()

    if not contexts and not cards:
        return {
            "answer": "No uploaded study content found yet. Upload PDF/text/youtube content first, then ask again.",
            "sources": []
        }

    ranked_contexts = sorted(
        contexts,
        key=lambda c: _score_blob_against_keywords(
            f"{c.get('topic_name', '')} {c.get('content', '')}", keywords
        ),
        reverse=True,
    )

    top_contexts = [
        c for c in ranked_contexts[: max(1, min(req.top_k, 8))]
        if _score_blob_against_keywords(f"{c.get('topic_name', '')} {c.get('content', '')}", keywords) > 0
    ]

    if not top_contexts and ranked_contexts:
        top_contexts = ranked_contexts[:2]

    def score_card(c):
        blob = f"{c.get('topic_name','')} {c.get('question','')} {c.get('answer','')} {c.get('summary','')}".lower()
        return _score_blob_against_keywords(blob, keywords)

    ranked_cards = sorted(cards, key=score_card, reverse=True)
    top_cards = [c for c in ranked_cards[:3] if score_card(c) > 0]
    if not top_cards and ranked_cards:
        top_cards = ranked_cards[:1]

    context_lines = []
    source_names = []

    for c in top_contexts[:4]:
        topic = c.get("topic_name", "Unknown")
        source_names.append(topic)
        snippet = _best_context_snippet(c.get("content", ""), keywords)
        context_lines.append(f"Topic: {topic}")
        context_lines.append(f"Uploaded Context: {snippet}")
        context_lines.append("---")

    for c in top_cards:
        source_names.append(c.get("topic_name", "Unknown"))
        context_lines.append(f"Topic: {c.get('topic_name','Unknown')}")
        context_lines.append(f"Flashcard Q: {c.get('question','')}")
        context_lines.append(f"Flashcard A: {c.get('answer','')}")
        context_lines.append("---")

    context = "\n".join(context_lines).strip()
    source_names = list(dict.fromkeys([s for s in source_names if s]))

    if getattr(ingest, "client", None):
        try:
            prompt = f"""You are NeuroRevise AI tutor.
You must answer using ONLY the provided uploaded study context.
If the context does not contain the answer, say: 'I could not find this in your uploaded notes yet.'
Keep the answer concise and practical.

User question:
{question}

Study context:
{context}
"""
            response = ingest.client.models.generate_content(model=ingest.MODEL_NAME, contents=prompt)
            answer = (response.text or "").strip()
            if answer:
                return {
                    "answer": answer,
                    "sources": source_names
                }
        except Exception as e:
            print(f"AI chat model fallback: {e}")

    # Fallback without model: provide closest context snippet
    if top_contexts:
        snippet = _best_context_snippet(top_contexts[0].get("content", ""), keywords)
        return {
            "answer": snippet or "I could not find this in your uploaded notes yet.",
            "sources": source_names
        }

    best = top_cards[0] if top_cards else None
    if not best:
        return {
            "answer": "I could not find this in your uploaded notes yet.",
            "sources": source_names
        }

    return {
        "answer": best.get("answer") or best.get("summary") or "I could not find this in your uploaded notes yet.",
        "sources": source_names
    }

@app.post("/speak")
def speak(req: SpeakReq, background_tasks: BackgroundTasks):
    def _speak_text(text: str):
        try:
            import pyttsx3
            engine = pyttsx3.init()
            engine.setProperty("rate", 165)
            engine.say(text)
            engine.runAndWait()
        except Exception as e:
            print(f"Speak Error: {e}")

    if req.text and req.text.strip():
        background_tasks.add_task(_speak_text, req.text.strip())
    return {"success": True}

# -----------------
# SETTINGS
# -----------------
@app.get("/dashboard")
def dashboard_stats():
    cards = get_flashcards()
    total = len(cards)
    critical = sum(1 for c in cards if c["urgency_level"] == "critical")
    warning = sum(1 for c in cards if c["urgency_level"] == "warning")
    return {
        "total_cards": total,
        "critical_cards": critical,
        "warning_cards": warning,
        "demo_mode": database.get_demo_mode(),
        "presentation_mode": database.get_presentation_mode(),
        "recent_events": database.get_events(limit=5),
        "active_plans": len([p for p in database.get_all_learning_plans() if p.get("status") == "active"]),
        "report_email": database.get_report_email()
    }

@app.get("/events")
def events_endpoint():
    return database.get_events(limit=50)

@app.post("/settings/demo-mode")
def toggle_demo(req: DemoToggleReq):
    database.set_demo_mode(req.enabled)
    database.add_event(f"Demo mode changed: {req.enabled}")
    return {"success": True}

@app.post("/settings/presentation-mode")
def toggle_presentation(req: PresentationToggleReq):
    database.set_presentation_mode(req.enabled)
    database.add_event(f"Presentation mode (3m/7m) changed: {req.enabled}")
    return {"success": True}

@app.get("/settings/report-email")
def get_report_email_setting():
    return {"email": database.get_report_email()}

@app.post("/settings/report-email")
def set_report_email_setting(req: ReportEmailReq):
    email = (req.email or "").strip()
    if email and ("@" not in email or "." not in email.split("@")[-1]):
        raise HTTPException(status_code=400, detail="Invalid email format")
    database.set_report_email(email)
    database.add_event(f"Report email updated: {email if email else 'cleared'}")
    return {"success": True, "email": email}


# -----------------
# GAME ENDPOINTS
# -----------------
@app.get("/game/start/{game_type}")
def start_game(game_type: str):
    all_cards = get_flashcards()
    if not all_cards:
        return {"error": "No cards available. Ingest some thoughts first!"}
    
    import random
    import uuid
    session_id = str(uuid.uuid4())
    
    def enrich_card(c):
        # Fallback for old cards without options or subject
        if "options" not in c:
            # Create semi-plausible distractors from other cards in the same topic if possible
            distractors = [other["answer"] for other in all_cards if other["id"] != c["id"]][:3]
            while len(distractors) < 3:
                distractors.append(f"Synthetic Node {len(distractors) + 1}")
            opts = distractors + [c["answer"]]
            random.shuffle(opts)
            c["options"] = opts
        if "subject" not in c:
            c["subject"] = c.get("topic_name", "General")
        return c

    if game_type == "rapid_fire":
        sample = random.sample(all_cards, min(len(all_cards), 10))
        enriched = [enrich_card(c) for c in sample]
        return {"session_id": session_id, "cards": enriched, "timer": 60, "mode": "sequential", "type": game_type}
        
    elif game_type == "match_cards":
        sample = random.sample(all_cards, min(len(all_cards), 6))
        pairs = []
        for c in sample:
            pairs.append({"id": f"q_{c['id']}", "text": c["question"], "match_id": c["id"], "side": "left"})
            pairs.append({"id": f"a_{c['id']}", "text": c["answer"], "match_id": c["id"], "side": "right"})
        random.shuffle(pairs)
        return {"session_id": session_id, "pairs": pairs, "mode": "match", "timer": 30, "type": game_type}
        
    elif game_type == "weak_spot":
        # Target decayed cards
        weak = [c for c in all_cards if c.get("retention_score", 100) < 70]
        if not weak: weak = random.sample(all_cards, min(len(all_cards), 5))
        enriched = [enrich_card(c) for c in weak]
        return {"session_id": session_id, "cards": enriched, "timer": 45, "mode": "sequential", "type": game_type}
        
    elif game_type == "battle_mode":
        sample = random.sample(all_cards, min(len(all_cards), 8))
        enriched = [enrich_card(c) for c in sample]
        return {
            "session_id": session_id, 
            "cards": enriched, 
            "bot_params": {"speed": 5, "accuracy": 0.8}, 
            "mode": "sequential", 
            "timer": 0, 
            "type": game_type
        }
        
    elif game_type == "panic_game":
        sample = random.sample(all_cards, min(len(all_cards), 15))
        enriched = [enrich_card(c) for c in sample]
        return {"session_id": session_id, "cards": enriched, "timer": 60, "mode": "sequential", "type": game_type}
        
    return {"error": "Unknown game type"}


@app.post("/game/score/{game_type}")
def submit_score(game_type: str, req: GameScoreReq):
    new_stats = database.update_game_score(game_type, req.score, req.result)
    return {"success": True, "stats": new_stats, "points": database.get_neuro_points()}

@app.get("/game/stats")
def get_game_info():
    return {
        "stats": database.get_game_stats(),
        "points": database.get_neuro_points()
    }

# -----------------
# WEBSOCKET
# -----------------
active_connections = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            # Broadcast the unified state every 3 seconds
            data = {
                "flashcards": get_flashcards(),
                "learning_plans": database.get_all_learning_plans(),
                "events": database.get_events(limit=10),
                "dashboard": dashboard_stats(),
                "game_stats": database.get_game_stats(),
                "neuro_points": database.get_neuro_points()
            }
            await websocket.send_json(data)
            await asyncio.sleep(3)
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)
    except Exception as e:
        print(f"WS Error: {e}")
        if websocket in active_connections:
            active_connections.remove(websocket)












