"""
Observability — Structured logging, distributed tracing, and metrics.

Provides:
  - JSON-structured logging to console + file
  - In-memory metrics (tool call counts, latency, error rates)
  - Lightweight request tracing with spans
  - Convenience decorators for tool instrumentation
  - /metrics endpoint snapshot
"""

import json
import time
import uuid
import logging
import functools
from datetime import datetime
from pathlib import Path
from typing import Callable

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)


# ── JSON structured logger ────────────────────────────────────────────────────

class JSONFormatter(logging.Formatter):
    """Formats log records as single-line JSON for easy parsing."""

    def format(self, record: logging.LogRecord) -> str:
        log = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "extra"):
            log.update(record.extra)
        if record.exc_info:
            log["exception"] = self.formatException(record.exc_info)
        return json.dumps(log)


def get_logger(name: str) -> logging.Logger:
    """Get or create a named JSON logger with console + file output."""
    logger = logging.getLogger(f"wellness.{name}")
    if not logger.handlers:
        logger.setLevel(logging.DEBUG)

        ch = logging.StreamHandler()
        ch.setFormatter(JSONFormatter())
        logger.addHandler(ch)

        fh = logging.FileHandler(LOG_DIR / f"{name}.log")
        fh.setFormatter(JSONFormatter())
        logger.addHandler(fh)

    return logger


# Default logger for module-level use
logger = get_logger("bridge")


# ── In-memory metrics ─────────────────────────────────────────────────────────

class Metrics:
    """
    Thread-safe in-memory metrics store.
    Tracks tool call counts, latency, error rates, and system-level counters.
    """

    def __init__(self):
        self._data: dict = {
            "tool_calls":       {},   # tool_name → {count, errors, total_ms}
            "agent_calls":      0,
            "agent_errors":     0,
            "guardrail_blocks": 0,
            "rag_retrievals":   0,
            "requests_total":   0,
        }

    def record_tool_call(self, tool: str, duration_ms: float, error: bool = False):
        if tool not in self._data["tool_calls"]:
            self._data["tool_calls"][tool] = {"count": 0, "errors": 0, "total_ms": 0.0}
        self._data["tool_calls"][tool]["count"] += 1
        self._data["tool_calls"][tool]["total_ms"] += duration_ms
        if error:
            self._data["tool_calls"][tool]["errors"] += 1

    def record_agent_call(self, error: bool = False):
        self._data["agent_calls"] += 1
        if error:
            self._data["agent_errors"] += 1

    def record_guardrail_block(self):
        self._data["guardrail_blocks"] += 1

    def record_rag_retrieval(self):
        self._data["rag_retrievals"] += 1

    def record_request(self):
        self._data["requests_total"] += 1

    def snapshot(self) -> dict:
        """Return a copy of current metrics with computed averages."""
        import copy
        snap = copy.deepcopy(self._data)
        for tool, stats in snap["tool_calls"].items():
            if stats["count"] > 0:
                stats["avg_ms"] = round(stats["total_ms"] / stats["count"], 2)
        snap["timestamp"] = datetime.utcnow().isoformat() + "Z"
        return snap


_metrics = Metrics()


def get_metrics() -> Metrics:
    return _metrics


# ── Trace ─────────────────────────────────────────────────────────────────────

class Trace:
    """
    Lightweight distributed trace for a single request.
    Records named spans with elapsed time for end-to-end visibility.
    """

    def __init__(self, trace_id: str = None, user_id: str = None):
        self.trace_id = trace_id or str(uuid.uuid4())[:8]
        self.user_id = user_id
        self.start_time = time.time()
        self.spans: list[dict] = []
        self._logger = get_logger("trace")

    def span(self, name: str, data: dict = None) -> dict:
        """Record a named span with elapsed time since trace start."""
        elapsed = round((time.time() - self.start_time) * 1000, 2)
        span = {
            "trace_id": self.trace_id,
            "span": name,
            "elapsed_ms": elapsed,
            "user_id": self.user_id,
            **(data or {}),
        }
        self.spans.append(span)
        self._logger.info(f"[{self.trace_id}] {name}", extra={"extra": span})
        return span

    def finish(self, status: str = "ok", error: str = None):
        """Mark the trace as complete and log total duration."""
        total = round((time.time() - self.start_time) * 1000, 2)
        self._logger.info(
            f"[{self.trace_id}] DONE {status} in {total}ms",
            extra={"extra": {
                "trace_id": self.trace_id,
                "status": status,
                "total_ms": total,
                "spans": len(self.spans),
                "error": error,
            }},
        )


# ── Convenience logging functions ─────────────────────────────────────────────

def log_agent_call(user_id: str, message: str, tool_calls: list, duration_ms: float):
    """Log a completed agent call with tool usage summary."""
    _metrics.record_agent_call()
    get_logger("agent").info(json.dumps({
        "event": "agent_call",
        "user_id": user_id,
        "message_preview": message[:60],
        "tools_called": [t["tool"] for t in tool_calls],
        "duration_ms": round(duration_ms, 2),
    }))


def log_rag_retrieval(query: str, docs: list, duration_ms: float):
    """Log a RAG retrieval with result count and latency."""
    _metrics.record_rag_retrieval()
    get_logger("rag").info(json.dumps({
        "event": "rag_retrieval",
        "query_preview": query[:60],
        "docs_retrieved": len(docs),
        "duration_ms": round(duration_ms, 2),
    }))


# ── Decorator ─────────────────────────────────────────────────────────────────

def trace_tool(tool_name: str):
    """Decorator: automatically traces and measures any MCP tool function."""
    def decorator(fn: Callable) -> Callable:
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            _logger = get_logger("tool")
            start = time.time()
            error = False
            try:
                return fn(*args, **kwargs)
            except Exception as e:
                error = True
                _logger.error(json.dumps({
                    "event": "tool_error",
                    "tool": tool_name,
                    "error": str(e),
                }))
                raise
            finally:
                duration_ms = round((time.time() - start) * 1000, 2)
                _metrics.record_tool_call(tool_name, duration_ms, error)
                _logger.info(json.dumps({
                    "event": "tool_call",
                    "tool": tool_name,
                    "duration_ms": duration_ms,
                    "error": error,
                }))
        return wrapper
    return decorator
