"""
Notification Agent — Analyses pending wellness activities for a user
and generates a personalised, agent-crafted nudge message.

Called by the HTTP bridge at POST /notify/check.
Uses the MCP wellness engine directly (no LLM call needed for the data part)
and optionally calls Groq to craft a human-sounding nudge.
"""

import json
import os
from datetime import datetime
from dotenv import load_dotenv
from groq import Groq
from wellness_engine import WellnessEngine
from guardrails import filter_output
from observability import logger

load_dotenv()

_client = Groq(api_key=os.environ.get("GROQ_API_KEY"))
_engine = WellnessEngine()
_MODEL = "llama-3.3-70b-versatile"


def check_and_nudge(user_id: str) -> dict:
    """
    1. Fetch today's pending activities via MCP wellness engine.
    2. If pending tasks exist, call Groq to craft a short, warm nudge.
    3. Return structured payload for the Flutter notification service.
    """
    # ── Step 1: Get real data — use 30-day window to catch all routines ───
    report = _engine.get_report({"user_id": user_id, "days": 30})

    pending_names: list[str] = report.get("pending_activity_names", [])
    completed_names: list[str] = report.get("completed_activity_names", [])
    total: int = report.get("activities_total", 0)
    completed: int = report.get("activities_completed", 0)
    pending_count: int = report.get("activities_pending", 0)

    # Prefer today's summary if available (more precise)
    today_summary = report.get("today")
    if today_summary and today_summary.get("total", 0) > 0:
        pending_names = today_summary.get("pending_names", pending_names)
        completed_names = today_summary.get("completed_names", completed_names)
        total = today_summary.get("total", total)
        completed = today_summary.get("completed", completed)
        pending_count = today_summary.get("pending", pending_count)

    if pending_count == 0 and not pending_names:
        logger.info(json.dumps({
            "event": "notification_check",
            "user_id": user_id,
            "should_notify": False,
            "reason": "all_complete",
        }))
        return {
            "user_id": user_id,
            "activities_total": total,
            "activities_completed": completed,
            "activities_pending": 0,
            "pending_activity_names": [],
            "completed_activity_names": completed_names,
            "agent_nudge": None,
            "should_notify": False,
        }

    # ── Step 2: Get user profile for personalisation ──────────────────────
    profile = _engine.get_profile({"user_id": user_id})
    streak = profile.get("streak_days", 0)
    hour = datetime.now().hour
    time_of_day = "morning" if hour < 12 else "afternoon" if hour < 18 else "evening"

    # ── Step 3: Craft agent nudge via Groq ────────────────────────────────
    nudge = _craft_nudge(
        pending_names=pending_names,
        completed_names=completed_names,
        streak=streak,
        time_of_day=time_of_day,
        total=total,
        completed=completed,
    )

    logger.info(json.dumps({
        "event": "notification_check",
        "user_id": user_id,
        "should_notify": True,
        "pending_count": pending_count,
        "nudge_preview": nudge[:60] if nudge else "",
    }))

    return {
        "user_id": user_id,
        "activities_total": total,
        "activities_completed": completed,
        "activities_pending": pending_count,
        "pending_activity_names": pending_names,
        "completed_activity_names": completed_names,
        "agent_nudge": nudge,
        "should_notify": True,
    }


def _craft_nudge(
    pending_names: list[str],
    completed_names: list[str],
    streak: int,
    time_of_day: str,
    total: int,
    completed: int,
) -> str:
    """
    Ask Groq to write a short, warm, motivating push notification body.
    Falls back to a template if the API call fails.
    """
    pending_list = ", ".join(pending_names)
    done_list = ", ".join(completed_names) if completed_names else "none yet"
    streak_note = f"They have a {streak}-day streak." if streak > 0 else ""

    prompt = f"""You are a wellness coach writing a mobile push notification.

Context:
- Time of day: {time_of_day}
- Activities completed today: {completed}/{total} ({done_list})
- Still pending: {pending_list}
- {streak_note}

Write ONE push notification body (max 2 sentences, max 120 characters total).
Rules:
- Warm, encouraging tone — not nagging
- Mention 1-2 specific pending activity names
- End with a gentle call to action
- No emojis in the first word
- Output ONLY the notification body text, nothing else"""

    try:
        response = _client.chat.completions.create(
            model=_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=80,
            temperature=0.7,
        )
        raw = response.choices[0].message.content or ""
        nudge = filter_output(raw.strip().strip('"'))
        return nudge if nudge else _fallback_nudge(pending_names, time_of_day)
    except Exception as e:
        logger.warning(json.dumps({"event": "nudge_craft_failed", "error": str(e)}))
        return _fallback_nudge(pending_names, time_of_day)


def _fallback_nudge(pending_names: list[str], time_of_day: str) -> str:
    """Template-based fallback when Groq is unavailable."""
    greetings = {
        "morning": "Good morning! 🌅",
        "afternoon": "Hey there! 🌤️",
        "evening": "Good evening! 🌙",
    }
    greeting = greetings.get(time_of_day, "Hey!")
    if len(pending_names) == 1:
        return f"{greeting} Don't forget: {pending_names[0]} is still waiting for you."
    listed = " and ".join(pending_names[:2])
    return f"{greeting} You still have {listed} to complete today. You've got this!"
