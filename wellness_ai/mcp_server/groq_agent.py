"""
Groq LLM Agent with MCP tool calling + RAG context injection.

Agentic loop:
1. Retrieve relevant wellness knowledge via RAG
2. Call Groq LLM with tools + RAG context
3. Execute any tool calls (MCP tools via WellnessEngine)
4. Loop until LLM produces a final text response
5. Apply output guardrails before returning
"""

import json
import time
import os
from groq import Groq
from wellness_engine import WellnessEngine
from rag_engine import retrieve, format_context
from guardrails import filter_output, check_message_safety
from observability import log_agent_call, log_rag_retrieval

GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
MODEL = "llama-3.3-70b-versatile"

client = Groq(api_key=GROQ_API_KEY)
engine = WellnessEngine()

# ── MCP Tool Definitions for Groq function calling ────────────────────────────

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_user_profile",
            "description": "Get user profile: goals, streak, fitness level, last check-in",
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
            "name": "log_daily_checkin",
            "description": "Log today's check-in: sleep hours, stress (1-10), energy (1-10), mood",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "sleep_hours": {"type": "number"},
                    "stress_level": {"type": "integer"},
                    "energy_level": {"type": "integer"},
                    "mood": {"type": "string", "enum": ["great", "good", "neutral", "low", "bad"]},
                    "notes": {"type": "string"},
                },
                "required": ["user_id", "sleep_hours", "stress_level", "energy_level", "mood"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "generate_daily_routine",
            "description": "Generate an adaptive wellness routine for today based on user state",
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
            "description": "Adjust today's routine based on how the user feels right now",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "reason": {
                        "type": "string",
                        "enum": ["too_tired", "short_on_time", "feeling_great", "stressed"],
                    },
                    "available_minutes": {"type": "integer"},
                },
                "required": ["user_id", "reason"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_consistency_report",
            "description": "Get user's wellness consistency report and progress over N days",
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
            "name": "update_user_goals",
            "description": "Update the user's wellness goals and fitness level",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "goals": {"type": "array", "items": {"type": "string"}},
                    "fitness_level": {
                        "type": "string",
                        "enum": ["beginner", "intermediate", "advanced"],
                    },
                },
                "required": ["user_id", "goals"],
            },
        },
    },
]

TOOL_FN_MAP = {
    "get_user_profile": engine.get_profile,
    "log_daily_checkin": engine.log_checkin,
    "generate_daily_routine": engine.generate_routine,
    "adjust_routine": engine.adjust_routine,
    "get_consistency_report": engine.get_report,
    "update_user_goals": engine.update_goals,
}

SYSTEM_PROMPT = """You are a warm, supportive Wellness AI agent. You help users build healthier habits by:
- Generating adaptive daily wellness routines based on their sleep, stress, and energy
- Adjusting routines dynamically when they're tired, stressed, or short on time
- Tracking consistency and celebrating progress
- Offering evidence-based wellness advice grounded in the provided knowledge context

You have access to tools to read and update the user's wellness data. Always call the relevant tool to get real data before responding. Be concise, warm, and actionable. Use emojis sparingly but effectively.

IMPORTANT: You are a wellness habit assistant, NOT a medical professional. Do not diagnose conditions or prescribe treatments.

CRITICAL: Use the function calling API properly - do NOT write function calls as text like <function=...>. The system will automatically execute your function calls."""


def run_agent(user_id: str, user_message: str, history: list) -> dict:
    """
    Run one turn of the agentic loop:
    1. RAG retrieval for relevant wellness context
    2. Groq LLM call with tools + context
    3. Tool execution loop (MCP tools)
    4. Output guardrail filtering

    Returns: { "reply": str, "tool_calls": [...], "rag_docs": [...], "error": str|None }
    """
    start = time.time()
    tool_calls_made = []

    # ── 1. RAG: retrieve relevant wellness knowledge ──────────────
    rag_start = time.time()
    rag_docs = retrieve(user_message, top_k=3)
    log_rag_retrieval(user_message, rag_docs, (time.time() - rag_start) * 1000)

    rag_context = format_context(rag_docs)

    # ── 2. Build message history ──────────────────────────────────
    system_content = SYSTEM_PROMPT
    if rag_context:
        system_content += f"\n\n{rag_context}"

    messages = [{"role": "system", "content": system_content}]

    # Include last 10 turns of conversation history
    for h in history[-10:]:
        messages.append({"role": h["role"], "content": h["content"]})

    messages.append({"role": "user", "content": user_message})

    try:
        # ── 3. First LLM call ─────────────────────────────────────
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            tools=TOOLS,
            tool_choice="auto",
            max_tokens=1024,
            temperature=0.7,
        )

        msg = response.choices[0].message

        # ── 4. Agentic tool-call loop ─────────────────────────────
        max_iterations = 5  # guardrail: prevent infinite loops
        iteration = 0

        while msg.tool_calls and iteration < max_iterations:
            iteration += 1
            messages.append({
                "role": "assistant",
                "content": msg.content or "",
                "tool_calls": [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        },
                    }
                    for tc in msg.tool_calls
                ],
            })

            # Execute each tool call via MCP engine
            for tc in msg.tool_calls:
                fn_name = tc.function.name
                fn_args = json.loads(tc.function.arguments)

                # Always inject user_id
                if "user_id" not in fn_args:
                    fn_args["user_id"] = user_id

                fn = TOOL_FN_MAP.get(fn_name)
                result = fn(fn_args) if fn else {"error": f"Unknown tool: {fn_name}"}

                tool_calls_made.append({
                    "tool": fn_name,
                    "args": fn_args,
                    "result": result,
                })

                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": json.dumps(result),
                })

            # Next LLM call with tool results
            response = client.chat.completions.create(
                model=MODEL,
                messages=messages,
                tools=TOOLS,
                tool_choice="auto",
                max_tokens=1024,
                temperature=0.7,
            )
            msg = response.choices[0].message

        # ── 5. Output guardrail ───────────────────────────────────
        reply = filter_output(msg.content or "I'm not sure how to respond to that.")

        # ── 6. Observability ──────────────────────────────────────
        log_agent_call(user_id, user_message, tool_calls_made, (time.time() - start) * 1000)

        return {
            "reply": reply,
            "tool_calls": tool_calls_made,
            "rag_docs": [{"id": d["id"], "title": d["title"], "score": d.get("relevance_score")} for d in rag_docs],
            "error": None,
        }

    except Exception as e:
        log_agent_call(user_id, user_message, tool_calls_made, (time.time() - start) * 1000)
        return {
            "reply": "I'm having trouble right now. Please try again in a moment.",
            "tool_calls": tool_calls_made,
            "rag_docs": [],
            "error": str(e),
        }
