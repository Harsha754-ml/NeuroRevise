import json
import os
import time
from uuid import uuid4

DB_FILE = "database.json"

DEFAULT_DB = {
    "flashcards": [],
    "events": [],
    "pending_notifications": [],
    "learning_plans": [],
    "demo_mode": False,
    "presentation_mode": False,
    "settings": {
        "compression_ratio": 1440
    },
    "game_stats": {
        "rapid_fire": {"high_score": 0, "total_played": 0},
        "match_cards": {"high_score": 0, "total_played": 0},
        "weak_spot": {"high_score": 0, "total_played": 0},
        "battle_mode": {"wins": 0, "losses": 0, "total_played": 0},
        "panic_game": {"high_score": 0, "total_played": 0}
    },
    "neuro_points": 0
}

STEM_CARDS = [
    # Physics
    {
        "topic_name": "Newtonian Mechanics",
        "subject": "Physics",
        "question": "What is Newton's Second Law of Motion?",
        "answer": "F = ma",
        "options": ["F = m/a", "F = ma", "E = mc^2", "P = mv"],
        "summary": "Force equals mass times acceleration. This defines the relationship between an object's mass and the force applied to it."
    },
    {
        "topic_name": "Newtonian Mechanics",
        "subject": "Physics",
        "question": "What is the acceleration due to gravity on Earth?",
        "answer": "9.8 m/s^2",
        "options": ["9.8 m/s^2", "1.6 m/s^2", "12.5 m/s^2", "5.0 m/s^2"],
        "summary": "Gravitational acceleration (g) is approximately 9.8 meters per second squared near the surface of the Earth."
    },
    {
        "topic_name": "Thermodynamics",
        "subject": "Physics",
        "question": "Which law states that energy cannot be created or destroyed?",
        "answer": "First Law of Thermodynamics",
        "options": ["First Law of Thermodynamics", "Second Law of Thermodynamics", "Third Law of Thermodynamics", "Zeroth Law"],
        "summary": "The First Law (Conservation of Energy) states that the total energy of an isolated system is constant."
    },
    # Chemistry
    {
        "topic_name": "Periodic Table",
        "subject": "Chemistry",
        "question": "What is the atomic number of Hydrogen?",
        "answer": "1",
        "options": ["1", "2", "6", "8"],
        "summary": "Hydrogen is the first element on the periodic table, consisting of one proton and one electron."
    },
    {
        "topic_name": "Periodic Table",
        "subject": "Chemistry",
        "question": "What is the chemical symbol for Gold?",
        "answer": "Au",
        "options": ["Ag", "Au", "Fe", "Cu"],
        "summary": "The symbol 'Au' comes from the Latin word for gold, 'aurum'."
    },
    {
        "topic_name": "Organic Chemistry",
        "subject": "Chemistry",
        "question": "What is the simplest alkane?",
        "answer": "Methane",
        "options": ["Ethane", "Methane", "Propane", "Butane"],
        "summary": "Methane (CH4) is the simplest alkane and the primary component of natural gas."
    },
    # Mathematics
    {
        "topic_name": "Calculus",
        "subject": "Mathematics",
        "question": "What is the derivative of sin(x)?",
        "answer": "cos(x)",
        "options": ["-sin(x)", "cos(x)", "-cos(x)", "tan(x)"],
        "summary": "The instantaneous rate of change of the sine function at any point x is the cosine of x."
    },
    {
        "topic_name": "Calculus",
        "subject": "Mathematics",
        "question": "What is the integral of 1/x dx?",
        "answer": "ln|x| + C",
        "options": ["x^2/2", "ln|x| + C", "e^x", "log(x)"],
        "summary": "The antiderivative of 1/x is the natural logarithm of the absolute value of x plus a constant."
    },
    {
        "topic_name": "Geometry",
        "subject": "Mathematics",
        "question": "What is the formula for the area of a circle?",
        "answer": "πr²",
        "options": ["2πr", "πr²", "4πr²", "πd"],
        "summary": "Area equals Pi multiplied by the square of the radius."
    },
    {
        "topic_name": "Trigonometry",
        "subject": "Mathematics",
        "question": "In a right triangle, what is sin(θ) equal to?",
        "answer": "Opposite / Hypotenuse",
        "options": ["Adjacent / Hypotenuse", "Opposite / Adjacent", "Opposite / Hypotenuse", "Hypotenuse / Opposite"],
        "summary": "The sine of an angle is the ratio of the length of the opposite side to the hypotenuse."
    }
]

def seed():
    # Reset internal state
    db = DEFAULT_DB.copy()
    
    for card in STEM_CARDS:
        fc = {
            "id": "fc_" + str(uuid4())[:8],
            "topic_name": card["topic_name"],
            "subject": card["subject"],
            "question": card["question"],
            "answer": card["answer"],
            "options": card["options"],
            "summary": card["summary"],
            "created_at": time.time(),
            "last_reviewed": time.time(),
            "stability": 24.0,
            "review_count": 0,
            "ignore_count": 0,
            "status": "active",
            "audio_ready": False
        }
        db["flashcards"].append(fc)
    
    db["events"].append({
        "id": f"evt_{int(time.time()*1000)}",
        "text": "Neural Archives reset to STEM standard (Math/Phys/Chem).",
        "type": "info",
        "timestamp": time.time()
    })
    
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)
    
    print(f"✅ Seeding complete: {len(db['flashcards'])} STEM records established.")

if __name__ == "__main__":
    seed()
