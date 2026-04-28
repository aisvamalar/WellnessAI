"""
Guardrails — Safety, validation, and constraint enforcement.

Applied at three layers:
  1. Input validation  — validate tool arguments before MCP execution
  2. Message safety    — screen user messages for unsafe/crisis content
  3. Output filtering  — post-process LLM responses for safety and quality
"""

import re
from observability import get_logger

logger = get_logger("guardrails")

# ── Valid value sets ──────────────────────────────────────────────────────────

CHECKIN_RULES = {
    "sleep_hours":  (0.5, 24.0),
    "stress_level": (1, 10),
    "energy_level": (1, 10),
}
VALID_MOODS           = {"great", "good", "neutral", "low", "bad"}
VALID_FITNESS         = {"beginner", "intermediate", "advanced"}
VALID_GOALS           = {"better_sleep", "reduce_stress", "exercise_daily", "mindfulness", "hydration"}
VALID_ADJUST_REASONS  = {"too_tired", "short_on_time", "feeling_great", "stressed"}

# ── Unsafe content patterns ───────────────────────────────────────────────────

_CRISIS_PATTERNS = [
    r"\b(suicide|self.harm|kill myself|end my life)\b",
    r"\b(overdose|starve|purge|binge)\b",
    r"\b(illegal drug|cocaine|heroin|meth)\b",
]

_MEDICAL_TRIGGERS = [
    "chest pain", "heart attack", "stroke", "seizure",
    "can't breathe", "severe pain", "emergency",
]

_DANGEROUS_OUTPUT_PATTERNS = [
    r"stop taking your medication",
    r"don't see a doctor",
    r"you don't need medical",
    r"diagnos(e|is|ed)",
]


# ── Exception ─────────────────────────────────────────────────────────────────

class GuardrailViolation(Exception):
    """Raised when a hard guardrail is violated (invalid input that cannot be clamped)."""
    def __init__(self, message: str, field: str = None):
        super().__init__(message)
        self.field = field


# ── Input validators ──────────────────────────────────────────────────────────

def validate_checkin(args: dict) -> dict:
    """
    Validate check-in inputs. Clamps numeric values to valid range (soft validation).
    Raises GuardrailViolation only for type errors.
    """
    for field, (min_val, max_val) in CHECKIN_RULES.items():
        if field in args:
            val = args[field]
            if not isinstance(val, (int, float)):
                raise GuardrailViolation(f"{field} must be a number, got {type(val).__name__}", field)
            if not (min_val <= val <= max_val):
                clamped = max(min_val, min(max_val, val))
                logger.warning(f"Clamped {field}={val} → {clamped}")
                args[field] = clamped

    if "mood" in args and args["mood"] not in VALID_MOODS:
        raise GuardrailViolation(f"mood must be one of {VALID_MOODS}, got '{args['mood']}'", "mood")

    return args


def validate_goals(args: dict) -> dict:
    """Validate goal update inputs. Filters unknown goals, raises if none remain."""
    if "goals" in args:
        invalid = [g for g in args["goals"] if g not in VALID_GOALS]
        if invalid:
            logger.warning(f"Filtering invalid goals: {invalid}")
            args["goals"] = [g for g in args["goals"] if g in VALID_GOALS]
        if not args["goals"]:
            raise GuardrailViolation("At least one valid goal is required. "
                                     f"Valid: {VALID_GOALS}")

    if "fitness_level" in args and args["fitness_level"] not in VALID_FITNESS:
        raise GuardrailViolation(
            f"fitness_level must be one of {VALID_FITNESS}, got '{args['fitness_level']}'",
            "fitness_level",
        )
    return args


def validate_adjust_reason(args: dict) -> dict:
    """Validate routine adjustment reason and clamp available_minutes."""
    reason = args.get("reason", "")
    if reason not in VALID_ADJUST_REASONS:
        raise GuardrailViolation(
            f"reason must be one of {VALID_ADJUST_REASONS}, got '{reason}'", "reason"
        )
    if "available_minutes" in args:
        mins = args["available_minutes"]
        if not isinstance(mins, int) or mins < 1:
            args["available_minutes"] = 15
            logger.warning("Clamped available_minutes to 15")
        elif mins > 240:
            args["available_minutes"] = 240
            logger.warning("Clamped available_minutes to 240")
    return args


def validate_tool_args(tool_name: str, args: dict) -> dict:
    """Route to the correct validator based on tool name. Pass-through if no validator."""
    validators = {
        "log_daily_checkin": validate_checkin,
        "update_user_goals": validate_goals,
        "adjust_routine":    validate_adjust_reason,
    }
    validator = validators.get(tool_name)
    return validator(args) if validator else args


# ── Message safety ────────────────────────────────────────────────────────────

def check_message_safety(message: str) -> dict:
    """
    Screen a user message for unsafe or crisis content.

    Returns:
        { "safe": bool, "reason": str|None, "response": str|None, "disclaimer": str|None }
    """
    msg_lower = message.lower()

    for pattern in _CRISIS_PATTERNS:
        if re.search(pattern, msg_lower):
            logger.warning(f"Crisis content detected: pattern={pattern[:30]}")
            return {
                "safe": False,
                "reason": "crisis_content",
                "response": (
                    "I'm not able to help with that, but please reach out to a mental health "
                    "professional or crisis line immediately.\n\n"
                    "🆘 US: 988 Suicide & Crisis Lifeline — call or text 988\n"
                    "🆘 International: https://findahelpline.com"
                ),
                "disclaimer": None,
            }

    for trigger in _MEDICAL_TRIGGERS:
        if trigger in msg_lower:
            logger.info(f"Medical disclaimer triggered: {trigger}")
            return {
                "safe": True,
                "reason": "medical_disclaimer",
                "response": None,
                "disclaimer": (
                    "⚠️ If this is a medical emergency, please call emergency services immediately. "
                    "I'm a wellness assistant, not a medical professional."
                ),
            }

    return {"safe": True, "reason": None, "response": None, "disclaimer": None}


# ── Output filtering ──────────────────────────────────────────────────────────

def filter_output(response: str) -> str:
    """
    Post-process LLM output:
    - Ensure non-empty response
    - Cap length to keep responses concise
    - Remove dangerous medical advice patterns
    """
    if not response or len(response.strip()) < 5:
        return "I'm here to help with your wellness journey. What would you like to work on today?"

    # Cap at 1000 chars
    if len(response) > 1000:
        response = response[:997] + "..."
        logger.info("LLM response truncated to 1000 chars")

    for pattern in _DANGEROUS_OUTPUT_PATTERNS:
        if re.search(pattern, response, re.IGNORECASE):
            logger.warning(f"Removed dangerous pattern from output: {pattern}")
            response = re.sub(pattern, "[see a healthcare professional]", response, flags=re.IGNORECASE)

    return response.strip()


# Alias used in groq_agent.py
check_input_safety = check_message_safety
