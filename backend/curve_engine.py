import math
import time

COMPRESSION_RATIO = 1440 # 1 minute real = 24 hours sim

def calculate_retention(last_reviewed: float, stability: float, demo_mode: bool) -> float:
    # t is hours elapsed
    t_sec = time.time() - last_reviewed
    t_hours = t_sec / 3600.0
    if demo_mode:
        t_hours *= COMPRESSION_RATIO
    
    # R = e^(-t/S)
    R = math.exp(-t_hours / stability)
    return max(0.0, min(1.0, R))

def calculate_score(retention: float) -> int:
    return int(retention * 100)

def get_urgency(score: int) -> str:
    if score >= 70:
        return "safe"
    elif score >= 50:
        return "warning"
    elif score >= 30:
        return "danger"
    else:
        return "critical"

def update_stability(stability: float, result: str) -> float:
    if result == "remembered":
        return min(720.0, stability * 2.0)
    elif result == "hard":
        return stability * 1.2
    elif result == "forgot":
        return 24.0
    return stability

def get_next_reminder_minutes(stability: float, demo_mode: bool) -> int:
    # 50% retention time (R=0.5): ln(0.5) = -t / S -> t = -S * ln(0.5)
    t_hours = -stability * math.log(0.5)
    t_minutes = t_hours * 60
    
    if demo_mode:
        t_minutes = t_minutes / COMPRESSION_RATIO
        
    return int(t_minutes)

def get_curve_points(last_reviewed: float, stability: float, demo_mode: bool):
    # Generates a visual 20-point tracking curve
    # Spans 240 simulated hours (10 days)
    total_sim_hours = 240.0
    # True passage of time needed to reach that point
    time_chunk_hours = total_sim_hours / 20.0
    
    if demo_mode:
        real_time_chunk_hours = time_chunk_hours / COMPRESSION_RATIO
    else:
        real_time_chunk_hours = time_chunk_hours

    points = []
    base_time = last_reviewed
    
    for i in range(21):
        target_timestamp = base_time + (i * real_time_chunk_hours * 3600)
        
        # Calculate what the retention *will* be at exactly target_timestamp
        t_sec = target_timestamp - last_reviewed
        t_hours = t_sec / 3600.0
        if demo_mode:
            t_hours *= COMPRESSION_RATIO
            
        r = math.exp(-t_hours / stability)
        score = int(r * 100)
        
        # Generate readable label (+X days or hours)
        simulated_hour = int(i * time_chunk_hours)
        if simulated_hour >= 24:
            label = f"+{simulated_hour // 24}d"
        else:
            label = f"+{simulated_hour}h"
        
        points.append({
            "label": label,
            "score": score
        })
        
    return points
