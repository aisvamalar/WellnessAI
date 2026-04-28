"""
Unit tests for WellnessEngine — core business logic.
"""

import pytest
import json
import shutil
from pathlib import Path
from datetime import date, timedelta

# Point data dir to a temp location for tests
import wellness_engine as we
TEST_DATA_DIR = Path(__file__).parent / "test_data"
we.DATA_DIR = TEST_DATA_DIR
TEST_DATA_DIR.mkdir(exist_ok=True)

from wellness_engine import WellnessEngine

USER = "test_unit_user"


@pytest.fixture(autouse=True)
def clean_user():
    """Remove test user data before each test."""
    f = TEST_DATA_DIR / f"{USER}.json"
    if f.exists():
        f.unlink()
    yield
    if f.exists():
        f.unlink()


@pytest.fixture
def engine():
    return WellnessEngine()


# ── Profile ───────────────────────────────────────────────────────────────────

def test_get_profile_new_user(engine):
    profile = engine.get_profile({"user_id": USER})
    assert profile["user_id"] == USER
    assert profile["streak_days"] == 0
    assert profile["total_checkins"] == 0
    assert "goals" in profile
    assert "fitness_level" in profile


def test_get_profile_returns_defaults(engine):
    profile = engine.get_profile({"user_id": USER})
    assert profile["fitness_level"] == "beginner"
    assert isinstance(profile["goals"], list)


# ── Check-in ──────────────────────────────────────────────────────────────────

def test_log_checkin_success(engine):
    result = engine.log_checkin({
        "user_id": USER,
        "sleep_hours": 7.5,
        "stress_level": 4,
        "energy_level": 7,
        "mood": "good",
        "notes": "feeling okay",
    })
    assert result["success"] is True
    assert result["checkin"]["sleep_hours"] == 7.5
    assert result["checkin"]["mood"] == "good"


def test_log_checkin_updates_profile(engine):
    engine.log_checkin({
        "user_id": USER, "sleep_hours": 8, "stress_level": 3,
        "energy_level": 8, "mood": "great",
    })
    profile = engine.get_profile({"user_id": USER})
    assert profile["total_checkins"] == 1


def test_log_checkin_same_day_overwrites(engine):
    for _ in range(3):
        engine.log_checkin({
            "user_id": USER, "sleep_hours": 7, "stress_level": 5,
            "energy_level": 5, "mood": "neutral",
        })
    user = engine._load_user(USER)
    today_checkins = [c for c in user["checkins"] if c["date"] == date.today().isoformat()]
    assert len(today_checkins) == 1


# ── Routine generation ────────────────────────────────────────────────────────

def test_generate_routine_returns_activities(engine):
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    assert "activities" in routine
    assert len(routine["activities"]) > 0
    assert routine["total_duration_minutes"] <= 45


def test_generate_routine_respects_time_limit(engine):
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 15})
    assert routine["total_duration_minutes"] <= 15


def test_generate_routine_adapts_to_high_stress(engine):
    engine.log_checkin({
        "user_id": USER, "sleep_hours": 6, "stress_level": 9,
        "energy_level": 4, "mood": "bad",
    })
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    goals = [a["goal"] for a in routine["activities"]]
    # High stress should prioritize stress reduction
    assert "reduce_stress" in goals or "mindfulness" in goals


def test_generate_routine_adapts_to_low_sleep(engine):
    engine.log_checkin({
        "user_id": USER, "sleep_hours": 4, "stress_level": 5,
        "energy_level": 3, "mood": "low",
    })
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    assert routine["adapted_for"]["sleep_hours"] == 4


def test_generate_routine_message_not_empty(engine):
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 30})
    assert len(routine["message"]) > 0


# ── Activity completion ───────────────────────────────────────────────────────

def test_complete_activity(engine):
    routine = engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    act_id = routine["activities"][0]["routine_activity_id"]
    result = engine.complete_activity({"user_id": USER, "activity_id": act_id})
    assert result["success"] is True
    assert "completed" in result["progress"]


def test_complete_nonexistent_activity(engine):
    engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    result = engine.complete_activity({"user_id": USER, "activity_id": "fake_id"})
    assert result["success"] is False


# ── Goals ─────────────────────────────────────────────────────────────────────

def test_update_goals(engine):
    result = engine.update_goals({
        "user_id": USER,
        "goals": ["better_sleep", "mindfulness"],
        "fitness_level": "intermediate",
    })
    assert result["success"] is True
    assert "better_sleep" in result["goals"]
    assert result["fitness_level"] == "intermediate"


# ── Consistency report ────────────────────────────────────────────────────────

def test_report_empty_user(engine):
    report = engine.get_report({"user_id": USER, "days": 7})
    assert report["checkin_days"] == 0
    assert report["completion_rate"] == 0


def test_report_after_checkin(engine):
    engine.log_checkin({
        "user_id": USER, "sleep_hours": 7, "stress_level": 4,
        "energy_level": 7, "mood": "good",
    })
    report = engine.get_report({"user_id": USER, "days": 7})
    assert report["checkin_days"] == 1


# ── Streak ────────────────────────────────────────────────────────────────────

def test_streak_single_day(engine):
    engine.log_checkin({
        "user_id": USER, "sleep_hours": 7, "stress_level": 4,
        "energy_level": 7, "mood": "good",
    })
    profile = engine.get_profile({"user_id": USER})
    assert profile["streak_days"] == 1


# ── Adjust routine ────────────────────────────────────────────────────────────

def test_adjust_routine_too_tired(engine):
    engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    result = engine.adjust_routine({
        "user_id": USER, "reason": "too_tired", "available_minutes": 20
    })
    assert "activities" in result
    # All activities should be short or mindfulness
    for act in result["activities"]:
        assert act["duration"] <= 15 or act["goal"] == "mindfulness"


def test_adjust_routine_short_on_time(engine):
    engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    result = engine.adjust_routine({
        "user_id": USER, "reason": "short_on_time", "available_minutes": 10
    })
    assert result["total_duration_minutes"] <= 10


def test_adjust_routine_stressed_adds_calming(engine):
    engine.generate_routine({"user_id": USER, "available_time_minutes": 45})
    result = engine.adjust_routine({
        "user_id": USER, "reason": "stressed", "available_minutes": 30
    })
    goals = [a["goal"] for a in result["activities"]]
    assert "reduce_stress" in goals
