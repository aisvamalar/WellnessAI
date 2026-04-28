"""
Wellness AI MCP Server
Provides tools for the wellness agent to read/write user data,
generate adaptive routines, and track consistency.
"""

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
import json
import asyncio
from datetime import datetime, date
from pathlib import Path
from wellness_engine import WellnessEngine

app = Server("wellness-ai")
engine = WellnessEngine()

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="log_daily_checkin",
            description="Log user's daily check-in: sleep hours, stress level (1-10), energy level (1-10), mood",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "sleep_hours": {"type": "number"},
                    "stress_level": {"type": "integer", "minimum": 1, "maximum": 10},
                    "energy_level": {"type": "integer", "minimum": 1, "maximum": 10},
                    "mood": {"type": "string", "enum": ["great", "good", "neutral", "low", "bad"]},
                    "notes": {"type": "string"}
                },
                "required": ["user_id", "sleep_hours", "stress_level", "energy_level", "mood"]
            }
        ),
        Tool(
            name="generate_daily_routine",
            description="Generate an adaptive daily wellness routine based on user profile and today's check-in",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "available_time_minutes": {"type": "integer"},
                    "schedule_constraints": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "e.g. ['morning_busy', 'lunch_free', 'evening_free']"
                    }
                },
                "required": ["user_id"]
            }
        ),
        Tool(
            name="update_user_goals",
            description="Update user wellness goals",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "goals": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "e.g. ['better_sleep', 'reduce_stress', 'exercise_daily', 'mindfulness']"
                    },
                    "fitness_level": {"type": "string", "enum": ["beginner", "intermediate", "advanced"]}
                },
                "required": ["user_id", "goals"]
            }
        ),
        Tool(
            name="get_consistency_report",
            description="Get user's consistency and progress report over a time period",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "days": {"type": "integer", "default": 7}
                },
                "required": ["user_id"]
            }
        ),
        Tool(
            name="complete_activity",
            description="Mark a routine activity as completed",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "activity_id": {"type": "string"},
                    "completed_at": {"type": "string", "description": "ISO datetime string"}
                },
                "required": ["user_id", "activity_id"]
            }
        ),
        Tool(
            name="get_user_profile",
            description="Get user profile including goals, history summary, and current streak",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"}
                },
                "required": ["user_id"]
            }
        ),
        Tool(
            name="adjust_routine",
            description="Dynamically adjust today's routine based on real-time feedback",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "reason": {"type": "string", "enum": ["too_tired", "short_on_time", "feeling_great", "stressed"]},
                    "available_minutes": {"type": "integer"}
                },
                "required": ["user_id", "reason"]
            }
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    result = {}

    if name == "log_daily_checkin":
        result = engine.log_checkin(arguments)

    elif name == "generate_daily_routine":
        result = engine.generate_routine(arguments)

    elif name == "update_user_goals":
        result = engine.update_goals(arguments)

    elif name == "get_consistency_report":
        result = engine.get_report(arguments)

    elif name == "complete_activity":
        result = engine.complete_activity(arguments)

    elif name == "get_user_profile":
        result = engine.get_profile(arguments)

    elif name == "adjust_routine":
        result = engine.adjust_routine(arguments)

    else:
        result = {"error": f"Unknown tool: {name}"}

    return [TextContent(type="text", text=json.dumps(result, indent=2))]

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
