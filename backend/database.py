import copy
import json
import os
import time

DB_FILE = os.path.join(os.path.dirname(__file__), "database.json")
LEGACY_DB_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "database.json")

DEFAULT_DB = {
    "flashcards": [],
    "uploaded_contexts": [],
    "events": [],
    "pending_notifications": [],
    "learning_plans": [],
    "demo_mode": False,
    "presentation_mode": False,
    "settings": {
        "compression_ratio": 1440,
        "report_email": ""
    },
    "game_stats": {
        "rapid_fire": {"high_score": 0, "total_played": 0},
        "match_cards": {"high_score": 0, "total_played": 0},
        "weak_spot": {"high_score": 0, "total_played": 0},
        "battle_mode": {"wins": 0, "losses": 0, "total_played": 0},
        "panic_game": {"high_score": 0, "total_played": 0}
    },
    "neuro_points": 0,
}


def _read_json_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def write_db(data):
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def migrate_legacy_db_if_needed():
    """
    One-time compatibility migration:
    If backend DB has no flashcards but legacy root DB has data, import it.
    """
    if not os.path.exists(LEGACY_DB_FILE):
        return

    current = _read_json_file(DB_FILE) or copy.deepcopy(DEFAULT_DB)
    if current.get("flashcards"):
        return

    legacy = _read_json_file(LEGACY_DB_FILE)
    if not legacy or not legacy.get("flashcards"):
        return

    merged = copy.deepcopy(DEFAULT_DB)
    merged.update(legacy)
    write_db(merged)


def init_db():
    if not os.path.exists(DB_FILE):
        write_db(DEFAULT_DB)
    migrate_legacy_db_if_needed()


def read_db():
    try:
        with open(DB_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return copy.deepcopy(DEFAULT_DB)


def _append_event_to_data(data, text, event_type="info"):
    event = {
        "id": f"evt_{int(time.time()*1000)}",
        "text": text,
        "type": event_type,
        "timestamp": time.time(),
    }
    data.setdefault("events", []).append(event)
    if len(data["events"]) > 200:
        data["events"] = data["events"][-200:]


# --- LEARNING PLANS (CHRONOS) ---

def add_learning_plan(plan):
    data = read_db()
    if "learning_plans" not in data:
        data["learning_plans"] = []
    data["learning_plans"] = [p for p in data["learning_plans"] if p.get("topic_id") != plan.get("topic_id")]
    data["learning_plans"].append(plan)
    write_db(data)
    return plan


def get_all_learning_plans():
    return read_db().get("learning_plans", [])


def update_learning_plan(topic_id, updates):
    data = read_db()
    plans = data.get("learning_plans", [])
    for i, p in enumerate(plans):
        if p.get("topic_id") == topic_id:
            data["learning_plans"][i].update(updates)
            write_db(data)
            return data["learning_plans"][i]
    return None


def get_learning_plan(topic_id):
    plans = get_all_learning_plans()
    for p in plans:
        if p.get("topic_id") == topic_id:
            return p
    return None


# --- FLASHCARDS ---

def add_flashcard(flashcard):
    data = read_db()
    data["flashcards"].append(flashcard)
    write_db(data)
    return flashcard


def add_uploaded_context(topic_name, content, source_type="upload", max_chars=40000):
    text = (content or "").strip()
    name = (topic_name or "").strip()
    if not text or not name:
        return None

    data = read_db()
    if "uploaded_contexts" not in data or not isinstance(data["uploaded_contexts"], list):
        data["uploaded_contexts"] = []

    context_item = {
        "id": f"ctx_{int(time.time()*1000)}",
        "topic_name": name,
        "source_type": source_type,
        "content": text[:max_chars],
        "created_at": time.time(),
    }
    data["uploaded_contexts"].append(context_item)

    if len(data["uploaded_contexts"]) > 300:
        data["uploaded_contexts"] = data["uploaded_contexts"][-300:]

    write_db(data)
    return context_item


def get_uploaded_contexts(topic_name=None):
    contexts = read_db().get("uploaded_contexts", [])
    if not topic_name:
        return contexts
    name = (topic_name or "").strip()
    return [c for c in contexts if c.get("topic_name") == name]


def get_all_flashcards():
    return read_db().get("flashcards", [])


def get_flashcard(flashcard_id):
    flashcards = read_db().get("flashcards", [])
    for fc in flashcards:
        if fc.get("id") == flashcard_id:
            return fc
    return None


def update_flashcard(flashcard_id, updates):
    data = read_db()
    for i, fc in enumerate(data["flashcards"]):
        if fc.get("id") == flashcard_id:
            data["flashcards"][i].update(updates)
            write_db(data)
            return data["flashcards"][i]
    return None


def delete_flashcard(flashcard_id):
    data = read_db()
    original_len = len(data["flashcards"])
    data["flashcards"] = [fc for fc in data["flashcards"] if fc.get("id") != flashcard_id]
    if len(data["flashcards"]) < original_len:
        write_db(data)
        return True
    return False


def delete_lesson_by_topic(topic_name):
    data = read_db()
    name = (topic_name or "").strip()
    if not name:
        return {"flashcards_deleted": 0, "plans_deleted": 0, "contexts_deleted": 0, "flashcard_ids": []}

    removed_ids = [fc.get("id") for fc in data.get("flashcards", []) if fc.get("topic_name") == name]
    original_flashcards = len(data.get("flashcards", []))
    data["flashcards"] = [fc for fc in data.get("flashcards", []) if fc.get("topic_name") != name]
    flashcards_deleted = original_flashcards - len(data["flashcards"])

    original_plans = len(data.get("learning_plans", []))
    data["learning_plans"] = [p for p in data.get("learning_plans", []) if p.get("topic_name") != name]
    plans_deleted = original_plans - len(data["learning_plans"])

    original_contexts = len(data.get("uploaded_contexts", []))
    data["uploaded_contexts"] = [c for c in data.get("uploaded_contexts", []) if c.get("topic_name") != name]
    contexts_deleted = original_contexts - len(data["uploaded_contexts"])

    data["pending_notifications"] = [
        n for n in data.get("pending_notifications", [])
        if (n.get("topic_name") != name and n.get("flashcard_id") not in removed_ids)
    ]

    if flashcards_deleted > 0 or plans_deleted > 0 or contexts_deleted > 0:
        write_db(data)

    return {
        "flashcards_deleted": flashcards_deleted,
        "plans_deleted": plans_deleted,
        "contexts_deleted": contexts_deleted,
        "flashcard_ids": removed_ids,
    }


def add_event(text, event_type="info"):
    data = read_db()
    _append_event_to_data(data, text, event_type)
    write_db(data)


def get_events(limit=50):
    events = read_db().get("events", [])
    return sorted(events, key=lambda x: x["timestamp"], reverse=True)[:limit]


def add_notification(notification):
    data = read_db()
    data["pending_notifications"] = [
        n for n in data["pending_notifications"] if n.get("flashcard_id") != notification.get("flashcard_id")
    ]
    data["pending_notifications"].append(notification)
    write_db(data)


def get_pending_notifications():
    return read_db().get("pending_notifications", [])


def clear_notification(notification_id):
    data = read_db()
    original = len(data["pending_notifications"])
    data["pending_notifications"] = [
        n for n in data["pending_notifications"] if n.get("notification_id") != notification_id
    ]
    if len(data["pending_notifications"]) < original:
        write_db(data)
        return True
    return False


def get_demo_mode():
    return read_db().get("demo_mode", False)


def set_demo_mode(enabled: bool):
    data = read_db()
    data["demo_mode"] = enabled
    write_db(data)


def get_presentation_mode():
    return read_db().get("presentation_mode", False)


def set_presentation_mode(enabled: bool):
    data = read_db()
    data["presentation_mode"] = enabled
    write_db(data)


def get_report_email():
    data = read_db()
    return data.get("settings", {}).get("report_email", "")


def set_report_email(email: str):
    data = read_db()
    if "settings" not in data or not isinstance(data["settings"], dict):
        data["settings"] = {}
    data["settings"]["report_email"] = email
    write_db(data)


def get_game_stats():
    return read_db().get("game_stats", DEFAULT_DB["game_stats"])


def update_game_score(game_type, score, result=None):
    data = read_db()
    if "game_stats" not in data:
        data["game_stats"] = copy.deepcopy(DEFAULT_DB["game_stats"])

    stats = data["game_stats"].get(game_type, {"high_score": 0, "total_played": 0})
    stats["total_played"] += 1

    if "high_score" in stats and score > stats["high_score"]:
        stats["high_score"] = score
        _append_event_to_data(data, f"New High Score in {game_type.replace('_', ' ').title()}: {score}")

    if result is not None and "wins" in stats:
        if result == "win":
            stats["wins"] += 1
            _append_event_to_data(data, "You defeated NeuroBot in Battle Mode!")
        else:
            stats["losses"] += 1

    data["game_stats"][game_type] = stats
    earned_points = max(1, score // 10)
    data["neuro_points"] = data.get("neuro_points", 0) + earned_points
    write_db(data)
    return stats


def get_neuro_points():
    return read_db().get("neuro_points", 0)
