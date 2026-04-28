"""
Unit tests for Guardrails — input validation, output filtering, message safety.
"""

import sys
import os
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from guardrails import (
    validate_checkin,
    validate_goals,
    validate_adjust_reason,
    validate_tool_args,
    check_message_safety,
    filter_output,
    GuardrailViolation,
)


# ── validate_checkin ──────────────────────────────────────────────────────────

class TestValidateCheckin:
    def test_valid_input_passes(self):
        args = {"user_id": "u1", "sleep_hours": 7.5, "stress_level": 4,
                "energy_level": 7, "mood": "good"}
        result = validate_checkin(args)
        assert result["sleep_hours"] == 7.5
        assert result["mood"] == "good"

    def test_clamps_sleep_hours_too_high(self):
        args = {"sleep_hours": 30.0}
        result = validate_checkin(args)
        assert result["sleep_hours"] == 24.0

    def test_clamps_sleep_hours_too_low(self):
        args = {"sleep_hours": 0.0}
        result = validate_checkin(args)
        assert result["sleep_hours"] == 0.5

    def test_clamps_stress_level(self):
        args = {"stress_level": 15}
        result = validate_checkin(args)
        assert result["stress_level"] == 10

    def test_clamps_energy_level(self):
        args = {"energy_level": -5}
        result = validate_checkin(args)
        assert result["energy_level"] == 1

    def test_invalid_mood_raises(self):
        with pytest.raises(GuardrailViolation):
            validate_checkin({"mood": "ecstatic"})

    def test_non_numeric_sleep_raises(self):
        with pytest.raises(GuardrailViolation):
            validate_checkin({"sleep_hours": "seven"})

    def test_valid_all_moods(self):
        for mood in ["great", "good", "neutral", "low", "bad"]:
            result = validate_checkin({"mood": mood})
            assert result["mood"] == mood


# ── validate_goals ────────────────────────────────────────────────────────────

class TestValidateGoals:
    def test_valid_goals_pass(self):
        args = {"goals": ["better_sleep", "mindfulness"], "fitness_level": "beginner"}
        result = validate_goals(args)
        assert "better_sleep" in result["goals"]

    def test_invalid_goals_filtered(self):
        args = {"goals": ["better_sleep", "fly_to_moon"]}
        result = validate_goals(args)
        assert "fly_to_moon" not in result["goals"]
        assert "better_sleep" in result["goals"]

    def test_all_invalid_goals_raises(self):
        with pytest.raises(GuardrailViolation):
            validate_goals({"goals": ["invalid_goal_1", "invalid_goal_2"]})

    def test_invalid_fitness_level_raises(self):
        with pytest.raises(GuardrailViolation):
            validate_goals({"goals": ["mindfulness"], "fitness_level": "expert"})

    def test_valid_fitness_levels(self):
        for level in ["beginner", "intermediate", "advanced"]:
            result = validate_goals({"goals": ["mindfulness"], "fitness_level": level})
            assert result["fitness_level"] == level


# ── validate_adjust_reason ────────────────────────────────────────────────────

class TestValidateAdjustReason:
    def test_valid_reason_passes(self):
        for reason in ["too_tired", "short_on_time", "feeling_great", "stressed"]:
            result = validate_adjust_reason({"reason": reason})
            assert result["reason"] == reason

    def test_invalid_reason_raises(self):
        with pytest.raises(GuardrailViolation):
            validate_adjust_reason({"reason": "bored"})

    def test_clamps_available_minutes_too_high(self):
        args = {"reason": "too_tired", "available_minutes": 999}
        result = validate_adjust_reason(args)
        assert result["available_minutes"] == 240

    def test_clamps_available_minutes_too_low(self):
        args = {"reason": "too_tired", "available_minutes": 0}
        result = validate_adjust_reason(args)
        assert result["available_minutes"] == 15


# ── validate_tool_args ────────────────────────────────────────────────────────

class TestValidateToolArgs:
    def test_routes_checkin(self):
        args = {"sleep_hours": 7, "stress_level": 5, "energy_level": 5, "mood": "good"}
        result = validate_tool_args("log_daily_checkin", args)
        assert result["mood"] == "good"

    def test_routes_goals(self):
        args = {"goals": ["mindfulness"]}
        result = validate_tool_args("update_user_goals", args)
        assert "mindfulness" in result["goals"]

    def test_passthrough_unknown_tool(self):
        args = {"foo": "bar"}
        result = validate_tool_args("unknown_tool", args)
        assert result == {"foo": "bar"}


# ── check_message_safety ──────────────────────────────────────────────────────

class TestCheckMessageSafety:
    def test_safe_message(self):
        result = check_message_safety("I want to improve my sleep")
        assert result["safe"] is True
        assert result["response"] is None

    def test_crisis_content_blocked(self):
        result = check_message_safety("I want to kill myself")
        assert result["safe"] is False
        assert result["reason"] == "crisis_content"
        assert "988" in result["response"] or "crisis" in result["response"].lower()

    def test_medical_trigger_allowed_with_disclaimer(self):
        result = check_message_safety("I have chest pain")
        assert result["safe"] is True
        assert result["reason"] == "medical_disclaimer"
        assert result["disclaimer"] is not None

    def test_normal_wellness_query_safe(self):
        for msg in ["help me sleep better", "I'm stressed", "generate my routine"]:
            result = check_message_safety(msg)
            assert result["safe"] is True


# ── filter_output ─────────────────────────────────────────────────────────────

class TestFilterOutput:
    def test_normal_response_unchanged(self):
        text = "Here are 3 activities for your routine today."
        assert filter_output(text) == text

    def test_empty_response_replaced(self):
        result = filter_output("")
        assert len(result) > 10

    def test_whitespace_only_replaced(self):
        result = filter_output("   ")
        assert len(result) > 10

    def test_long_response_truncated(self):
        long_text = "a" * 1100
        result = filter_output(long_text)
        assert len(result) <= 1000

    def test_dangerous_medical_advice_removed(self):
        text = "You should stop taking your medication immediately."
        result = filter_output(text)
        assert "stop taking your medication" not in result.lower()
