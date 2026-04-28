"""
Integration tests — end-to-end flow through the HTTP bridge.

Tests the full stack: HTTP → guardrails → MCP tools → wellness engine.
Requires the bridge to be running: python http_bridge.py

Run with: pytest tests/test_integration.py -v
Skip if bridge not running: pytest tests/test_integration.py -v --ignore-glob="*integration*"
"""

import sys
import os
import json
import pytest
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BASE_URL = "http://localhost:8765"
TEST_USER = "integration_test_user"


def _post(path: str, data: dict) -> dict:
    body = json.dumps(data).encode()
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def _get(path: str) -> dict:
    with urllib.request.urlopen(f"{BASE_URL}{path}", timeout=5) as resp:
        return json.loads(resp.read())


def bridge_available() -> bool:
    try:
        _get("/health")
        return True
    except Exception:
        return False


# Skip all integration tests if bridge is not running
pytestmark = pytest.mark.skipif(
    not bridge_available(),
    reason="MCP bridge not running — start with: python http_bridge.py",
)


# ── Health & Metrics ──────────────────────────────────────────────────────────

class TestBridgeHealth:
    def test_health_endpoint(self):
        data = _get("/health")
        assert data["status"] == "ok"
        assert "tools" in data
        assert len(data["tools"]) >= 7

    def test_metrics_endpoint(self):
        data = _get("/metrics")
        assert "requests_total" in data
        assert "tool_calls" in data


# ── MCP Tool Calls ────────────────────────────────────────────────────────────

class TestMCPTools:
    def test_get_user_profile(self):
        result = _post("/tool", {"tool": "get_user_profile", "arguments": {"user_id": TEST_USER}})
        assert result["user_id"] == TEST_USER
        assert "goals" in result
        assert "streak_days" in result

    def test_log_checkin(self):
        result = _post("/tool", {
            "tool": "log_daily_checkin",
            "arguments": {
                "user_id": TEST_USER,
                "sleep_hours": 7.5,
                "stress_level": 4,
                "energy_level": 7,
                "mood": "good",
                "notes": "integration test",
            },
        })
        assert result["success"] is True
        assert result["checkin"]["mood"] == "good"

    def test_generate_routine_after_checkin(self):
        result = _post("/tool", {
            "tool": "generate_daily_routine",
            "arguments": {"user_id": TEST_USER, "available_time_minutes": 30},
        })
        assert "activities" in result
        assert len(result["activities"]) > 0
        assert result["total_duration_minutes"] <= 30

    def test_complete_activity(self):
        routine = _post("/tool", {
            "tool": "generate_daily_routine",
            "arguments": {"user_id": TEST_USER, "available_time_minutes": 45},
        })
        act_id = routine["activities"][0]["routine_activity_id"]
        result = _post("/tool", {
            "tool": "complete_activity",
            "arguments": {"user_id": TEST_USER, "activity_id": act_id},
        })
        assert result["success"] is True

    def test_adjust_routine_stressed(self):
        result = _post("/tool", {
            "tool": "adjust_routine",
            "arguments": {"user_id": TEST_USER, "reason": "stressed", "available_minutes": 20},
        })
        assert "activities" in result

    def test_get_consistency_report(self):
        result = _post("/tool", {
            "tool": "get_consistency_report",
            "arguments": {"user_id": TEST_USER, "days": 7},
        })
        assert "completion_rate" in result
        assert "current_streak_days" in result

    def test_update_goals(self):
        result = _post("/tool", {
            "tool": "update_user_goals",
            "arguments": {
                "user_id": TEST_USER,
                "goals": ["better_sleep", "mindfulness"],
                "fitness_level": "intermediate",
            },
        })
        assert result["success"] is True
        assert "better_sleep" in result["goals"]


# ── Guardrail enforcement via bridge ─────────────────────────────────────────

class TestGuardrailsViaHTTP:
    def test_invalid_mood_returns_422(self):
        try:
            _post("/tool", {
                "tool": "log_daily_checkin",
                "arguments": {
                    "user_id": TEST_USER,
                    "sleep_hours": 7,
                    "stress_level": 5,
                    "energy_level": 5,
                    "mood": "ecstatic",  # invalid
                },
            })
            pytest.fail("Expected 422 error")
        except urllib.error.HTTPError as e:
            assert e.code == 422

    def test_invalid_goal_returns_422(self):
        try:
            _post("/tool", {
                "tool": "update_user_goals",
                "arguments": {"user_id": TEST_USER, "goals": ["fly_to_moon"]},
            })
            pytest.fail("Expected 422 error")
        except urllib.error.HTTPError as e:
            assert e.code == 422

    def test_unknown_tool_returns_400(self):
        try:
            _post("/tool", {"tool": "nonexistent_tool", "arguments": {}})
            pytest.fail("Expected 400 error")
        except urllib.error.HTTPError as e:
            assert e.code == 400


# ── Full agentic flow ─────────────────────────────────────────────────────────

class TestAgentFlow:
    def test_agent_responds_to_routine_request(self):
        result = _post("/agent", {
            "user_id": TEST_USER,
            "message": "Generate my routine for today",
            "history": [],
        })
        assert "reply" in result
        assert len(result["reply"]) > 10
        assert result["error"] is None

    def test_agent_responds_to_progress_request(self):
        result = _post("/agent", {
            "user_id": TEST_USER,
            "message": "Show my progress this week",
            "history": [],
        })
        assert "reply" in result
        assert result["error"] is None

    def test_agent_returns_tool_calls(self):
        result = _post("/agent", {
            "user_id": TEST_USER,
            "message": "I'm feeling stressed today",
            "history": [],
        })
        assert "tool_calls" in result
        assert isinstance(result["tool_calls"], list)

    def test_agent_returns_rag_docs(self):
        result = _post("/agent", {
            "user_id": TEST_USER,
            "message": "Give me tips for better sleep",
            "history": [],
        })
        assert "rag_docs" in result

    def test_agent_multi_turn_conversation(self):
        history = [
            {"role": "user", "content": "I want to sleep better"},
            {"role": "assistant", "content": "Here are some sleep tips..."},
        ]
        result = _post("/agent", {
            "user_id": TEST_USER,
            "message": "What about stress reduction?",
            "history": history,
        })
        assert "reply" in result
        assert result["error"] is None
