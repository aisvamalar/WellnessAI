"""
HTTP Bridge — Exposes MCP tools, multi-agent chat, and observability endpoints.

Endpoints:
  GET  /health    — liveness check + tool list
  GET  /metrics   — observability snapshot
  POST /tool      — direct MCP tool call
  POST /agent     — multi-agent agentic chat (Groq LLM + RAG + guardrails)
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from wellness_engine import WellnessEngine
from multi_agent import run_multi_agent
from guardrails import validate_tool_args, GuardrailViolation
from observability import get_logger, get_metrics, Trace

logger = get_logger("bridge")
metrics = get_metrics()
engine = WellnessEngine()

TOOL_MAP = {
    "log_daily_checkin": engine.log_checkin,
    "generate_daily_routine": engine.generate_routine,
    "update_user_goals": engine.update_goals,
    "get_consistency_report": engine.get_report,
    "complete_activity": engine.complete_activity,
    "get_user_profile": engine.get_profile,
    "adjust_routine": engine.adjust_routine,
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        logger.info(f"HTTP {format % args}")

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._send_json({
                "status": "ok",
                "tools": list(TOOL_MAP.keys()),
                "agents": ["routine", "progress", "coach", "rag"],
                "features": ["mcp", "rag", "multi_agent", "guardrails", "observability"],
            })
        elif self.path == "/metrics":
            self._send_json(metrics.snapshot())
        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))
        metrics.record_request()

        # ── /agent — multi-agent agentic chat ────────────────────
        if self.path == "/agent":
            user_id = body.get("user_id", "user_default")
            message = body.get("message", "")
            history = body.get("history", [])
            trace = Trace(user_id=user_id)
            trace.span("agent:request", {"message": message[:60]})
            result = run_multi_agent(user_id, message, history)
            trace.finish("ok")
            self._send_json(result)
            return

        # ── /tool — direct MCP tool call ─────────────────────────
        if self.path == "/tool":
            tool_name = body.get("tool")
            arguments = body.get("arguments", {})
            fn = TOOL_MAP.get(tool_name)
            if not fn:
                self._send_json({"error": f"Unknown tool: {tool_name}"}, 400)
                return
            try:
                # Apply guardrails before executing
                arguments = validate_tool_args(tool_name, arguments)
                result = fn(arguments)
                self._send_json(result)
            except GuardrailViolation as e:
                logger.warning(f"Guardrail blocked tool {tool_name}: {e}")
                self._send_json({"error": f"Validation error: {e}"}, 422)
            except Exception as e:
                logger.error(f"Tool {tool_name} error: {e}")
                self._send_json({"error": str(e)}, 500)
            return

        self._send_json({"error": "Not found"}, 404)


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8765), Handler)
    logger.info("Wellness AI MCP Bridge starting on http://localhost:8765")
    print("\n🌱 Wellness AI MCP Bridge")
    print("=" * 40)
    print("  http://localhost:8765/health   — status")
    print("  http://localhost:8765/metrics  — observability")
    print("  POST /tool                     — MCP tools")
    print("  POST /agent                    — AI agent chat")
    print("=" * 40)
    server.serve_forever()
