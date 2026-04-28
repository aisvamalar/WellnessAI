"""
Multi-Agent System — Supervisor + Specialist Agents.

Architecture:
  SupervisorAgent
    ├── RoutineAgent     — generates and adjusts daily routines
    ├── ProgressAgent    — analyzes trends and consistency
    └── CoachAgent       — motivational coaching + habit advice (RAG-powered)

The supervisor classifies the user's intent and routes to the right specialist.
Each specialist has its own system prompt, tool subset, and RAG focus.
"""

import json
import time
import os
from groq import Groq
from wellness_engine import WellnessEngine
from rag_engine import retrieve, format_context
from guardrails import filter_output
from observability import logger

GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
MODEL = "llama-3.3-70b-versatile"

client = Groq(api_key=GROQ_API_KEY)
engine = WellnessEngine()

# ── Intent Categories ─────────────────────────────────────────────────────────

INTENTS = {
    "routine":  ["routine", "workout", "exercise", "activities", "plan", "schedule",
                 "tired", "stressed", "busy", "time", "adjust", "generate"],
    "progress": ["progress", "streak", "stats", "report", "trend", "week", "month",
                 "consistency", "how am i doing", "summary"],
    "coach":    ["advice", "tip", "help", "habit", "sleep", "stress", "nutrition",
                 "hydration", "mindfulness", "meditation", "why", "how", "what"],
}

# ── Specialist Agent Definitions ──────────────────────────────────────────────

class RoutineAgent:
    """Handles routine generation and adjustment."""

    SYSTEM = """You are the Routine Specialist agent. Your job is to generate and adjust
wellness routines based on the user's current state (sleep, stress, energy).
Always call the appropriate tool to get or modify the routine. Be specific about
activities, durations, and timing. Keep responses concise and actionable.

IMPORTANT: Use the function calling API - do NOT write function calls as text like <function=...>.
The system will automatically execute your function calls."""

    TOOLS = [
        {
            "type": "function",
            "function": {
                "name": "generate_daily_routine",
                "description": "Generate adaptive routine for today",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "available_time_minutes": {"type": "integer"},
                        "schedule_constraints": {"type": "array", "items": {"type": "string"}},
                    },
                    "required": ["user_id"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "adjust_routine",
                "description": "Adjust routine based on current feeling",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "reason": {"type": "string", "enum": ["too_tired", "short_on_time", "feeling_great", "stressed"]},
                        "available_minutes": {"type": "integer"},
                    },
                    "required": ["user_id", "reason"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "get_user_profile",
                "description": "Get user goals and fitness level",
                "parameters": {
                    "type": "object",
                    "properties": {"user_id": {"type": "string"}},
                    "required": ["user_id"],
                },
            },
        },
    ]

    TOOL_MAP = {
        "generate_daily_routine": engine.generate_routine,
        "adjust_routine": engine.adjust_routine,
        "get_user_profile": engine.get_profile,
    }


class ProgressAgent:
    """Handles progress tracking and trend analysis."""

    SYSTEM = """You are the Progress Analyst agent. Your job is to analyze the user's
wellness consistency, streaks, and trends. Always fetch the actual report data before
responding. Highlight improvements, identify patterns, and give specific actionable
suggestions based on the data. Be encouraging but honest.

IMPORTANT: Use the function calling API - do NOT write function calls as text like <function=...>.
The system will automatically execute your function calls."""

    TOOLS = [
        {
            "type": "function",
            "function": {
                "name": "get_consistency_report",
                "description": "Get wellness consistency report",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "days": {"type": "integer"},
                    },
                    "required": ["user_id"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "get_user_profile",
                "description": "Get user profile and streak",
                "parameters": {
                    "type": "object",
                    "properties": {"user_id": {"type": "string"}},
                    "required": ["user_id"],
                },
            },
        },
    ]

    TOOL_MAP = {
        "get_consistency_report": engine.get_report,
        "get_user_profile": engine.get_profile,
    }


class CoachAgent:
    """Motivational coach with RAG-powered wellness knowledge."""

    SYSTEM = """You are the Wellness Coach agent. You provide evidence-based advice on
sleep, stress, exercise, mindfulness, nutrition, and habit formation. Use the provided
knowledge context to ground your advice in science. Be warm, motivating, and specific.
Never give medical diagnoses or prescriptions.

IMPORTANT: Use the function calling API - do NOT write function calls as text like <function=...>.
The system will automatically execute your function calls."""

    TOOLS = [
        {
            "type": "function",
            "function": {
                "name": "get_user_profile",
                "description": "Get user goals to personalize advice",
                "parameters": {
                    "type": "object",
                    "properties": {"user_id": {"type": "string"}},
                    "required": ["user_id"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "update_user_goals",
                "description": "Update user goals if they want to change focus",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "goals": {"type": "array", "items": {"type": "string"}},
                        "fitness_level": {"type": "string", "enum": ["beginner", "intermediate", "advanced"]},
                    },
                    "required": ["user_id", "goals"],
                },
            },
        },
    ]

    TOOL_MAP = {
        "get_user_profile": engine.get_profile,
        "update_user_goals": engine.update_goals,
    }


# ── Supervisor Agent ──────────────────────────────────────────────────────────

def _classify_intent(message: str) -> str:
    """Simple keyword-based intent classifier."""
    msg = message.lower()
    scores = {intent: 0 for intent in INTENTS}
    for intent, keywords in INTENTS.items():
        for kw in keywords:
            if kw in msg:
                scores[intent] += 1
    best = max(scores, key=lambda k: scores[k])
    return best if scores[best] > 0 else "coach"


def _run_specialist(
    agent_class,
    user_id: str,
    message: str,
    history: list,
    rag_context: str = "",
) -> dict:
    """Run a specialist agent with its own tools and system prompt."""
    system = agent_class.SYSTEM
    if rag_context:
        system += f"\n\n{rag_context}"

    messages = [{"role": "system", "content": system}]
    for h in history[-6:]:
        messages.append({"role": h["role"], "content": h["content"]})
    messages.append({"role": "user", "content": message})

    tool_calls_made = []
    max_iter = 4

    for _ in range(max_iter):
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            tools=agent_class.TOOLS,
            tool_choice="auto",
            max_tokens=800,
            temperature=0.7,
        )
        msg = response.choices[0].message

        if not msg.tool_calls:
            return {
                "reply": filter_output(msg.content or ""),
                "tool_calls": tool_calls_made,
            }

        messages.append({
            "role": "assistant",
            "content": msg.content or "",
            "tool_calls": [
                {"id": tc.id, "type": "function",
                 "function": {"name": tc.function.name, "arguments": tc.function.arguments}}
                for tc in msg.tool_calls
            ],
        })

        for tc in msg.tool_calls:
            fn_name = tc.function.name
            fn_args = json.loads(tc.function.arguments)
            if "user_id" not in fn_args:
                fn_args["user_id"] = user_id
            fn = agent_class.TOOL_MAP.get(fn_name)
            result = fn(fn_args) if fn else {"error": f"Unknown tool: {fn_name}"}
            tool_calls_made.append({"tool": fn_name, "result": result})
            messages.append({"role": "tool", "tool_call_id": tc.id, "content": json.dumps(result)})

    return {"reply": "I've processed your request.", "tool_calls": tool_calls_made}


def run_multi_agent(user_id: str, message: str, history: list) -> dict:
    """
    Supervisor routes message to the appropriate specialist agent.

    Returns: {
        "reply": str,
        "agent_used": str,
        "tool_calls": [...],
        "rag_docs": [...],
        "error": str|None
    }
    """
    start = time.time()

    # ── Supervisor: classify intent ───────────────────────────────
    intent = _classify_intent(message)
    agent_map = {
        "routine":  RoutineAgent,
        "progress": ProgressAgent,
        "coach":    CoachAgent,
    }
    agent_class = agent_map[intent]

    logger.info(json.dumps({
        "event": "supervisor_routing",
        "user_id": user_id,
        "intent": intent,
        "agent": agent_class.__name__,
        "message_preview": message[:60],
    }))

    # ── RAG: retrieve context (especially useful for CoachAgent) ──
    rag_docs = retrieve(message, top_k=2)
    rag_context = format_context(rag_docs) if rag_docs else ""

    try:
        result = _run_specialist(agent_class, user_id, message, history, rag_context)
        elapsed = round((time.time() - start) * 1000, 1)

        logger.info(json.dumps({
            "event": "multi_agent_done",
            "user_id": user_id,
            "agent": agent_class.__name__,
            "tools_called": len(result["tool_calls"]),
            "elapsed_ms": elapsed,
        }))

        return {
            "reply": result["reply"],
            "agent_used": agent_class.__name__,
            "tool_calls": result["tool_calls"],
            "rag_docs": [{"id": d["id"], "title": d["title"]} for d in rag_docs],
            "error": None,
        }

    except Exception as e:
        logger.error(json.dumps({"event": "multi_agent_error", "error": str(e)}))
        return {
            "reply": "I'm having trouble right now. Please try again.",
            "agent_used": agent_class.__name__,
            "tool_calls": [],
            "rag_docs": [],
            "error": str(e),
        }
