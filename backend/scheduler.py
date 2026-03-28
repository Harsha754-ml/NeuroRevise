from apscheduler.schedulers.background import BackgroundScheduler
import database
import curve_engine
import time
import requests
import os
import socket

from dotenv import load_dotenv
load_dotenv()

def get_primary_ip():
    """Returns the primary IPv4 address of the host."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "")
# LAPTOP_IP will now be dynamic

def trigger_n8n_webhook(payload):
    """
    Dispatches a proactive notification request to n8n.
    Payload: { topic_name, type, content, title, stage }
    """
    if not N8N_WEBHOOK_URL:
        print("⚠️ n8n Webhook URL not configured. Skipping notification.")
        return False
        
    try:
        response = requests.post(N8N_WEBHOOK_URL, json=payload, timeout=5)
        if response.ok:
            print(f"✅ n8n notification triggered for {payload['topic_name']}")
            return True
        else:
            print(f"❌ n8n failure: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ n8n connection error: {e}")
        return False

def process_learning_plans():
    """
    Checks all active Learning Plans for due steps.
    If a step is due, it triggers n8n and marks it as completed.
    """
    plans = database.get_all_learning_plans()
    now = time.time()
    
    for plan in plans:
        if plan.get("status") != "active":
            continue
            
        # Find next pending step
        pending_steps = [s for s in plan.get("steps", []) if s.get("status") == "pending"]
        if not pending_steps:
            database.update_learning_plan(plan["topic_id"], {"status": "completed"})
            continue
            
        # Sort by stage to ensure sequential processing
        pending_steps.sort(key=lambda s: s["stage"])
        next_step = pending_steps[0]
        
        demo_mode = database.get_demo_mode()
        compression = 1440 if demo_mode else 1
        
        # Calculate simulated elapsed time since plan creation
        elapsed_real = now - plan["created_at"]
        elapsed_sim = elapsed_real * compression
        
        # Target offset from creation
        target_offset = next_step["due_at"] - plan["created_at"]
        
        if elapsed_sim >= target_offset:
            # Trigger n8n and Add to local polling queue
            current_ip = get_primary_ip()
            
            # Find a flashcard for this topic to get audio/summary
            all_fcs = database.get_all_flashcards()
            topic_fcs = [f for f in all_fcs if f["topic_name"] == plan["topic_name"] or f["id"] == plan["topic_id"]]
            audio_url = f"http://{current_ip}:8000/audio/{topic_fcs[0]['id']}" if topic_fcs else ""
            summary = topic_fcs[0].get("summary", "") if topic_fcs else next_step["content"]

            notification = {
                "notification_id": f"notif_plan_{plan['topic_id']}_{next_step['stage']}_{int(time.time())}",
                "flashcard_id": topic_fcs[0]["id"] if topic_fcs else plan["topic_id"],
                "topic_name": plan["topic_name"],
                "question": next_step["title"],
                "retention_score": 100,
                "urgency_level": "safe",
                "action": "open_summary",
                "audio_url": audio_url,
                "summary_text": summary,
                "created_at": time.time()
            }
            database.add_notification(notification)

            payload = {
                "topic_id": plan["topic_id"],
                "topic_name": plan["topic_name"],
                "title": next_step["title"],
                "type": next_step["type"],
                "content": next_step["content"],
                "stage": next_step["stage"],
                "laptop_ip": current_ip
            }
            
            if trigger_n8n_webhook(payload):
                # Update step status
                for step in plan["steps"]:
                    if step["stage"] == next_step["stage"]:
                        step["status"] = "completed"
                
                database.update_learning_plan(plan["topic_id"], {
                    "steps": plan["steps"],
                    "current_stage": next_step["stage"] + 1
                })
                
                database.add_event(f"Chronos Plan: {plan['topic_name']} - Stage {next_step['stage']} active.")

def memory_check_job():
    # Process the Proactive Learning Plans first
    process_learning_plans()
    
    # Existing Flashcard retention logic
    flashcards = database.get_all_flashcards()
    demo_mode = database.get_demo_mode()
    
    for fc in flashcards:
        if fc.get("status") != "active":
            continue
            
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        urgency = curve_engine.get_urgency(score)
        
        if score < 70:
            # Prevent notification spam: alert each card only once after ingest/init.
            if fc.get("notified_once", False):
                continue

            pending = database.get_pending_notifications()
            already_pending = any(n["flashcard_id"] == fc.get("id") for n in pending)

            if not already_pending:
                notification_id = f"notif_{int(time.time()*1000)}"
                notification = {
                    "notification_id": notification_id,
                    "flashcard_id": fc.get("id"),
                    "topic_name": fc.get("topic_name"),
                    "question": fc.get("question"),
                    "retention_score": score,
                    "urgency_level": urgency,
                    "action": "open_quiz" if score < 50 else "open_summary",
                    "audio_url": f"http://{get_primary_ip()}:8000/audio/{fc.get('id')}",
                    "summary_text": fc.get("summary", ""),
                    "next_reminder_minutes": curve_engine.get_next_reminder_minutes(fc["stability"], demo_mode),
                    "created_at": time.time()
                }

                if urgency == "critical":
                    notification["action"] = "force_quiz"

                database.add_notification(notification)
                database.update_flashcard(fc.get("id"), {"notified_once": True})
                database.add_event(f"Legacy Recall: {fc['topic_name']} {score}%")

            # Voice alerts disabled: keep notifications silent during study flow.

def start_scheduler():
    scheduler = BackgroundScheduler()
    # Checking every 5 seconds for responsive learning plans
    scheduler.add_job(memory_check_job, 'interval', seconds=5)
    scheduler.start()



