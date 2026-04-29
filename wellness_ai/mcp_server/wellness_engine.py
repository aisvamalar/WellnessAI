"""
Wellness Engine - Core logic for adaptive routine generation and tracking.

Unique features:
  - Wellness Score: composite 0-100 score across sleep/stress/energy/consistency
  - Burnout Detector: pattern-based early warning from 5-day check-in history
  - Contextual Nudge: time-aware + state-aware micro-prompts
"""

import json
import uuid
from datetime import datetime, date, timedelta
from pathlib import Path

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

    # ── Core Tools ────────────────────────────────────────────────────────────

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

        today = date.today().isoformat()
        today_checkin = next((c for c in user["checkins"] if c["date"] == today), None)

        stress = today_checkin["stress_level"] if today_checkin else 5
        energy = today_checkin["energy_level"] if today_checkin else 5
        sleep = today_checkin["sleep_hours"] if today_checkin else 7

        selected = []
        total_time = 0
        goals = list(user["goals"])

        if stress >= 7 and "reduce_stress" not in goals:
            goals.insert(0, "reduce_stress")
        if sleep < 6 and "better_sleep" not in goals:
            goals.insert(0, "better_sleep")
        if energy < 4:
            goals = [g for g in goals if g != "exercise_daily"] + ["mindfulness"]

        for goal in goals:
            for act in ACTIVITY_LIBRARY.get(goal, []):
                if total_time + act["duration"] <= available_time:
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
            "adapted_for": {"stress_level": stress, "energy_level": energy, "sleep_hours": sleep},
            "message": self._generate_message(stress, energy, sleep)
        }

        user["routines"] = [r for r in user["routines"] if r["date"] != today]
        user["routines"].append(routine)
        user["routines"] = user["routines"][-30:]
        self._save_user(user_id, user)
        return routine

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

        # ── Activity breakdown: completed vs pending ──────────────────────
        completed_activities = []
        pending_activities = []
        for r in recent_routines:
            for a in r["activities"]:
                entry = {
                    "name": a["name"],
                    "goal": a.get("goal", ""),
                    "duration": a.get("duration", 0),
                    "routine_date": r["date"],
                    "completed": a.get("completed", False),
                    "completed_at": a.get("completed_at"),
                }
                if a.get("completed"):
                    completed_activities.append(entry)
                else:
                    pending_activities.append(entry)

        completed_count = len(completed_activities)
        total_count = completed_count + len(pending_activities)

        avg_stress = (sum(c["stress_level"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0
        avg_sleep = (sum(c["sleep_hours"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0
        avg_energy = (sum(c["energy_level"] for c in recent_checkins) / len(recent_checkins)) if recent_checkins else 0

        # Also include today's routine even if checkin was before the cutoff
        today = date.today().isoformat()
        today_routine = next((r for r in user["routines"] if r["date"] == today), None)
        today_summary = None
        if today_routine:
            today_done = [a["name"] for a in today_routine["activities"] if a.get("completed")]
            today_pending = [a["name"] for a in today_routine["activities"] if not a.get("completed")]
            today_summary = {
                "total": len(today_routine["activities"]),
                "completed": len(today_done),
                "pending": len(today_pending),
                "completed_names": today_done,
                "pending_names": today_pending,
            }

        return {
            "period_days": days,
            "checkin_days": len(recent_checkins),
            "routine_days": len(recent_routines),
            "activities_completed": completed_count,
            "activities_total": total_count,
            "activities_pending": len(pending_activities),
            "completed_activity_names": [a["name"] for a in completed_activities],
            "pending_activity_names": [a["name"] for a in pending_activities],
            "completion_rate": round(completed_count / total_count * 100, 1) if total_count else 0,
            "today": today_summary,
            "averages": {
                "stress": round(avg_stress, 1),
                "sleep_hours": round(avg_sleep, 1),
                "energy": round(avg_energy, 1)
            },
            "current_streak_days": self._calculate_streak(user),
            "trend": self._get_trend(recent_checkins)
        }

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
        last_checkin = user["checkins"][-1] if user["checkins"] else None
        return {
            "user_id": user_id,
            "goals": user["goals"],
            "fitness_level": user["fitness_level"],
            "streak_days": self._calculate_streak(user),
            "total_checkins": len(user["checkins"]),
            "last_checkin": last_checkin,
            "member_since": user["created_at"],
            # ── Unique features ──────────────────────────────────
            "wellness_score": self._compute_wellness_score(user),
            "burnout_risk": self._detect_burnout(user),
            "nudge": self._get_contextual_nudge(user),
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

        activities = list(today_routine["activities"])
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
            bonus = ACTIVITY_LIBRARY.get("exercise_daily", [])
            if bonus:
                b = dict(bonus[0])
                b["routine_activity_id"] = str(uuid.uuid4())[:8]
                b["completed"] = False
                b["goal"] = "exercise_daily"
                activities.append(b)
        elif reason == "stressed":
            for a in ACTIVITY_LIBRARY.get("reduce_stress", [])[:2]:
                b = dict(a)
                b["routine_activity_id"] = str(uuid.uuid4())[:8]
                b["completed"] = False
                b["goal"] = "reduce_stress"
                activities.insert(0, b)

        today_routine["activities"] = activities
        today_routine["adjusted"] = True
        today_routine["adjustment_reason"] = reason
        self._save_user(user_id, user)
        return today_routine

    # ── Private helpers ───────────────────────────────────────────────────────

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

    # ── Unique Feature: Wellness Score ────────────────────────────────────────

    def _compute_wellness_score(self, user: dict) -> dict:
        """
        Composite 0-100 wellness score from last 7 days.
        Dimensions: sleep (25pts), stress (25pts), energy (25pts), consistency (25pts).
        """
        checkins = user["checkins"][-7:] if user["checkins"] else []
        if not checkins:
            return {"score": 0, "grade": "No data yet", "dimensions": {}}

        avg_sleep = sum(c["sleep_hours"] for c in checkins) / len(checkins)
        sleep_score = min(25.0, 25 * (avg_sleep / 8.0) if avg_sleep <= 8 else max(0, 25 - (avg_sleep - 8) * 5))

        avg_stress = sum(c["stress_level"] for c in checkins) / len(checkins)
        stress_score = max(0.0, 25 * (1 - (avg_stress - 1) / 9))

        avg_energy = sum(c["energy_level"] for c in checkins) / len(checkins)
        energy_score = max(0.0, 25 * ((avg_energy - 1) / 9))

        consistency_score = min(25.0, len(checkins) / 7 * 25)

        total = round(sleep_score + stress_score + energy_score + consistency_score)
        grade = (
            "Excellent 🌟" if total >= 85 else
            "Good 💪" if total >= 70 else
            "Fair 🌱" if total >= 50 else
            "Needs Care 🤍"
        )
        return {
            "score": total,
            "grade": grade,
            "dimensions": {
                "sleep": round(sleep_score),
                "stress": round(stress_score),
                "energy": round(energy_score),
                "consistency": round(consistency_score),
            }
        }

    # ── Unique Feature: Burnout Detector ─────────────────────────────────────

    def _detect_burnout(self, user: dict) -> dict:
        """
        Detects burnout risk from the triple-threat pattern:
        high stress + low sleep + low energy across recent check-ins.
        """
        checkins = user["checkins"][-5:] if user["checkins"] else []
        if len(checkins) < 3:
            return {"risk": "unknown", "reason": "Not enough data yet", "days_flagged": 0}

        flagged = sum(
            1 for c in checkins
            if c["stress_level"] >= 7 and c["sleep_hours"] < 6.5 and c["energy_level"] <= 4
        )

        if flagged >= 3:
            return {
                "risk": "high",
                "reason": "High stress, poor sleep, and low energy detected across multiple days",
                "days_flagged": flagged,
            }
        if flagged >= 2:
            return {
                "risk": "moderate",
                "reason": "Early burnout signals — stress and fatigue building up",
                "days_flagged": flagged,
            }

        stresses = [c["stress_level"] for c in checkins]
        if all(stresses[i] <= stresses[i + 1] for i in range(len(stresses) - 1)) and stresses[-1] >= 7:
            return {
                "risk": "moderate",
                "reason": "Stress has been rising steadily over the past few days",
                "days_flagged": flagged,
            }

        return {"risk": "low", "reason": "You're managing well", "days_flagged": 0}

    # ── Unique Feature: Contextual Nudge ─────────────────────────────────────

    def _get_contextual_nudge(self, user: dict) -> dict:
        """
        Time-aware + state-aware micro-nudge.
        Returns a short actionable message based on current hour + last check-in.
        """
        hour = datetime.now().hour
        last = user["checkins"][-1] if user["checkins"] else None

        if last is None:
            msg = "Start your day right — do your morning check-in 🌅" if hour < 10 else "How are you feeling today? Log your check-in 📋"
            return {"message": msg, "icon": "check_circle", "action": "checkin"}

        stress = last.get("stress_level", 5)
        energy = last.get("energy_level", 5)
        sleep = last.get("sleep_hours", 7)

        if hour >= 21 and stress >= 7:
            return {"message": "High stress tonight — try 5 min box breathing before bed 🌙", "icon": "air", "action": "agent"}
        if hour >= 21 and sleep < 6:
            return {"message": "Sleep-deprived? Aim for 8h tonight — no screens after 10pm 📵", "icon": "bedtime", "action": "agent"}
        if 6 <= hour <= 9 and energy <= 3:
            return {"message": "Low energy this morning — a 10-min walk beats coffee ☀️", "icon": "directions_walk", "action": "routine"}
        if 12 <= hour <= 14 and stress >= 7:
            return {"message": "Midday stress spike — take a 5-min mindful break now 🧘", "icon": "self_improvement", "action": "agent"}
        if hour >= 18 and energy >= 8:
            return {"message": "Great energy tonight — perfect time for an evening workout 💪", "icon": "fitness_center", "action": "routine"}
        if stress >= 8:
            return {"message": "Stress is high — your agent has calming techniques ready 🤖", "icon": "psychology", "action": "agent"}
        if energy <= 3:
            return {"message": "Running low? Your routine has been lightened for today 🌿", "icon": "battery_low", "action": "routine"}
        if stress <= 3 and energy >= 7:
            return {"message": "You're in a great state today — keep the momentum! 🚀", "icon": "rocket_launch", "action": None}

        return {"message": "Stay consistent — every check-in builds your streak 🔥", "icon": "local_fire_department", "action": "checkin"}
