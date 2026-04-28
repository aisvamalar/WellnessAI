"""
Wellness Engine - Core logic for adaptive routine generation and tracking
"""

import json
import uuid
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Optional

DATA_DIR = Path("data")
DATA_DIR.mkdir(exist_ok=True)

ACTIVITY_LIBRARY = {
    "better_sleep": [
        {"id": "sleep_hygiene", "name": "Sleep Hygiene Routine", "duration": 15, "time_of_day": "evening",
         "description": "Dim lights, no screens 30min before bed, consistent sleep time"},
        {"id": "evening_stretch", "name": "Evening Stretch", "duration": 10, "time_of_day": "evening",
         "description": "Gentle full-body stretch to release tension"},
        {"id": "sleep_meditation", "name": "Sleep Meditation", "duration": 10, "time_of_day": "evening",
         "description": "Body scan meditation for deep relaxation"},
    ],
    "reduce_stress": [
        {"id": "box_breathing", "name": "Box Breathing", "duration": 5, "time_of_day": "any",
         "description": "4-4-4-4 breathing pattern to calm nervous system"},
        {"id": "mindful_walk", "name": "Mindful Walk", "duration": 20, "time_of_day": "any",
         "description": "Slow walk focusing on surroundings and breath"},
        {"id": "journaling", "name": "Stress Journaling", "duration": 10, "time_of_day": "evening",
         "description": "Write down worries and reframe them positively"},
        {"id": "cold_water", "name": "Cold Water Face Splash", "duration": 2, "time_of_day": "morning",
         "description": "Activates vagus nerve, reduces cortisol"},
    ],
    "exercise_daily": [
        {"id": "morning_yoga", "name": "Morning Yoga Flow", "duration": 20, "time_of_day": "morning",
         "description": "Sun salutations and energizing poses"},
        {"id": "hiit_short", "name": "10-min HIIT", "duration": 10, "time_of_day": "any",
         "description": "High intensity intervals: jumping jacks, burpees, squats"},
        {"id": "strength_basic", "name": "Bodyweight Strength", "duration": 25, "time_of_day": "any",
         "description": "Push-ups, squats, lunges, planks"},
        {"id": "walk_10k", "name": "10,000 Steps Goal", "duration": 30, "time_of_day": "any",
         "description": "Aim for 10k steps throughout the day"},
    ],
    "mindfulness": [
        {"id": "morning_meditation", "name": "Morning Meditation", "duration": 10, "time_of_day": "morning",
         "description": "Focused attention meditation to start the day"},
        {"id": "gratitude", "name": "Gratitude Practice", "duration": 5, "time_of_day": "morning",
         "description": "Write 3 things you're grateful for"},
        {"id": "mindful_eating", "name": "Mindful Eating", "duration": 0, "time_of_day": "any",
         "description": "Eat one meal today without distractions"},
        {"id": "body_scan", "name": "Body Scan", "duration": 15, "time_of_day": "any",
         "description": "Progressive relaxation from head to toe"},
    ],
    "hydration": [
        {"id": "water_tracking", "name": "Hydration Tracking", "duration": 0, "time_of_day": "any",
         "description": "Drink 8 glasses of water throughout the day"},
        {"id": "morning_water", "name": "Morning Hydration", "duration": 2, "time_of_day": "morning",
         "description": "Drink 500ml water immediately after waking"},
    ]
}


class WellnessEngine:
    def _user_file(self, user_id: str) -> Path:
        return DATA_DIR / f"{user_id}.json"

    def _load_user(self, user_id: str) -> dict:
        f = self._user_file(user_id)
        if f.exists():
            return json.loads(f.read_text())
        return {
            "user_id": user_id,
            "goals": ["mindfulness", "exercise_daily"],
            "fitness_level": "beginner",
            "checkins": [],
            "routines": [],
            "completed_activities": [],
            "streak": 0,
            "created_at": datetime.now().isoformat()
        }

    def _save_user(self, user_id: str, data: dict):
        self._user_file(user_id).write_text(json.dumps(data, indent=2))

    def log_checkin(self, args: dict) -> dict:
        user_id = args["user_id"]
        user = self._load_user(user_id)
        checkin = {
            "date": date.today().isoformat(),
            "sleep_hours": args["sleep_hours"],
            "stress_level": args["stress_level"],
            "energy_level": args["energy_level"],
            "mood": args["mood"],
            "notes": args.get("notes", ""),
            "timestamp": datetime.now().isoformat()
        }
        # Keep last 30 checkins
        user["checkins"] = [c for c in user["checkins"] if c["date"] != checkin["date"]]
        user["checkins"].append(checkin)
        user["checkins"] = user["checkins"][-30:]
        self._save_user(user_id, user)
        return {"success": True, "checkin": checkin, "message": "Check-in logged successfully"}

    def generate_routine(self, args: dict) -> dict:
        user_id = args["user_id"]
        user = self._load_user(user_id)
        available_time = args.get("available_time_minutes", 45)
        constraints = args.get("schedule_constraints", [])

        # Get today's checkin if available
        today = date.today().isoformat()
        today_checkin = next((c for c in user["checkins"] if c["date"] == today), None)

        # Adaptive logic based on checkin
        stress = today_checkin["stress_level"] if today_checkin else 5
        energy = today_checkin["energy_level"] if today_checkin else 5
        sleep = today_checkin["sleep_hours"] if today_checkin else 7

        selected = []
        total_time = 0

        # Priority adjustments based on state
        goals = list(user["goals"])
        if stress >= 7:
            if "reduce_stress" not in goals:
                goals.insert(0, "reduce_stress")
        if sleep < 6:
            if "better_sleep" not in goals:
                goals.insert(0, "better_sleep")
        if energy < 4:
            # Low energy: lighter activities
            goals = [g for g in goals if g != "exercise_daily"] + ["mindfulness"]

        for goal in goals:
            activities = ACTIVITY_LIBRARY.get(goal, [])
            for act in activities:
                if total_time + act["duration"] <= available_time:
                    # Filter by time constraints
                    if constraints:
                        if "morning_busy" in constraints and act["time_of_day"] == "morning":
                            continue
                        if "evening_busy" in constraints and act["time_of_day"] == "evening":
                            continue
                    act_copy = dict(act)
                    act_copy["goal"] = goal
                    act_copy["routine_activity_id"] = str(uuid.uuid4())[:8]
                    act_copy["completed"] = False
                    selected.append(act_copy)
                    total_time += act["duration"]
                if total_time >= available_time:
                    break

        routine = {
            "routine_id": str(uuid.uuid4())[:12],
            "date": today,
            "activities": selected,
            "total_duration_minutes": total_time,
            "adapted_for": {
                "stress_level": stress,
                "energy_level": energy,
                "sleep_hours": sleep
            },
            "message": self._generate_message(stress, energy, sleep)
        }

        user["routines"] = [r for r in user["routines"] if r["date"] != today]
        user["routines"].append(routine)
        user["routines"] = user["routines"][-30:]
        self._save_user(user_id, user)
        return routine

    def _generate_message(self, stress: int, energy: int, sleep: float) -> str:
        if stress >= 8:
            return "High stress detected. Today's routine focuses on calming your nervous system."
        if sleep < 5:
            return "You're running low on sleep. Light activities and sleep prep are prioritized today."
        if energy >= 8:
            return "You're energized! Great day to push a bit harder on your fitness goals."
        if energy <= 3:
            return "Low energy today — gentle movement and mindfulness will serve you best."
        return "Balanced day ahead. Your routine is set for steady progress."

    def update_goals(self, args: dict) -> dict:
        user_id = args["user_id"]
        user = self._load_user(user_id)
        user["goals"] = args["goals"]
        if "fitness_level" in args:
            user["fitness_level"] = args["fitness_level"]
        self._save_user(user_id, user)
        return {"success": True, "goals": user["goals"], "fitness_level": user["fitness_level"]}

    def get_report(self, args: dict) -> dict:
        user_id = args["user_id"]
        days = args.get("days", 7)
        user = self._load_user(user_id)

        cutoff = (date.today() - timedelta(days=days)).isoformat()
        recent_checkins = [c for c in user["checkins"] if c["date"] >= cutoff]
        recent_routines = [r for r in user["routines"] if r["date"] >= cutoff]

        completed_count = sum(
            1 for r in recent_routines
            for a in r["activities"] if a.get("completed")
        )
        total_count = sum(len(r["activities"]) for r in recent_routines)

        avg_stress = (sum(c["stress_level"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0
        avg_sleep = (sum(c["sleep_hours"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0
        avg_energy = (sum(c["energy_level"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0

        streak = self._calculate_streak(user)

        return {
            "period_days": days,
            "checkin_days": len(recent_checkins),
            "routine_days": len(recent_routines),
            "activities_completed": completed_count,
            "activities_total": total_count,
            "completion_rate": round(completed_count / total_count * 100, 1) if total_count else 0,
            "averages": {
                "stress": round(avg_stress, 1),
                "sleep_hours": round(avg_sleep, 1),
                "energy": round(avg_energy, 1)
            },
            "current_streak_days": streak,
            "trend": self._get_trend(recent_checkins)
        }

    def _calculate_streak(self, user: dict) -> int:
        if not user["checkins"]:
            return 0
        streak = 0
        check_date = date.today()
        dates = {c["date"] for c in user["checkins"]}
        while check_date.isoformat() in dates:
            streak += 1
            check_date -= timedelta(days=1)
        return streak

    def _get_trend(self, checkins: list) -> str:
        if len(checkins) < 3:
            return "not_enough_data"
        recent = checkins[-3:]
        avg_energy = sum(c["energy_level"] for c in recent) / 3
        avg_stress = sum(c["stress_level"] for c in recent) / 3
        if avg_energy >= 7 and avg_stress <= 4:
            return "improving"
        if avg_energy <= 4 or avg_stress >= 7:
            return "needs_attention"
        return "stable"

    def complete_activity(self, args: dict) -> dict:
        user_id = args["user_id"]
        user = self._load_user(user_id)
        today = date.today().isoformat()
        today_routine = next((r for r in user["routines"] if r["date"] == today), None)
        if not today_routine:
            return {"success": False, "message": "No routine found for today"}
        for act in today_routine["activities"]:
            if act["routine_activity_id"] == args["activity_id"]:
                act["completed"] = True
                act["completed_at"] = args.get("completed_at", datetime.now().isoformat())
                self._save_user(user_id, user)
                completed = sum(1 for a in today_routine["activities"] if a.get("completed"))
                total = len(today_routine["activities"])
                return {
                    "success": True,
                    "activity": act["name"],
                    "progress": f"{completed}/{total} activities completed today"
                }
        return {"success": False, "message": "Activity not found"}

    def get_profile(self, args: dict) -> dict:
        user_id = args["user_id"]
        user = self._load_user(user_id)
        streak = self._calculate_streak(user)
        last_checkin = user["checkins"][-1] if user["checkins"] else None
        return {
            "user_id": user_id,
            "goals": user["goals"],
            "fitness_level": user["fitness_level"],
            "streak_days": streak,
            "total_checkins": len(user["checkins"]),
            "last_checkin": last_checkin,
            "member_since": user["created_at"]
        }

    def adjust_routine(self, args: dict) -> dict:
        user_id = args["user_id"]
        reason = args["reason"]
        available = args.get("available_minutes", 20)
        user = self._load_user(user_id)
        today = date.today().isoformat()
        today_routine = next((r for r in user["routines"] if r["date"] == today), None)

        if not today_routine:
            return self.generate_routine({"user_id": user_id, "available_time_minutes": available})

        # Filter activities based on reason
        activities = today_routine["activities"]
        if reason == "too_tired":
            activities = [a for a in activities if a["duration"] <= 10 or a["goal"] == "mindfulness"]
        elif reason == "short_on_time":
            activities = sorted(activities, key=lambda x: x["duration"])
            total = 0
            filtered = []
            for a in activities:
                if total + a["duration"] <= available:
                    filtered.append(a)
                    total += a["duration"]
            activities = filtered
            today_routine["total_duration_minutes"] = total
        elif reason == "feeling_great":
            # Add a bonus activity
            bonus = ACTIVITY_LIBRARY.get("exercise_daily", [])
            if bonus:
                b = dict(bonus[0])
                b["routine_activity_id"] = str(uuid.uuid4())[:8]
                b["completed"] = False
                b["goal"] = "exercise_daily"
                activities.append(b)
        elif reason == "stressed":
            stress_acts = ACTIVITY_LIBRARY.get("reduce_stress", [])
            for a in stress_acts[:2]:
                b = dict(a)
                b["routine_activity_id"] = str(uuid.uuid4())[:8]
                b["completed"] = False
                b["goal"] = "reduce_stress"
                if b not in activities:
                    activities.insert(0, b)

        today_routine["activities"] = activities
        today_routine["adjusted"] = True
        today_routine["adjustment_reason"] = reason
        self._save_user(user_id, user)
        return today_routine
