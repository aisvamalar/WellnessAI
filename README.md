# 🌱 Wellness AI

An adaptive AI-powered wellness companion that considers your schedule, stress levels, sleep patterns, and goals to dynamically generate and adjust daily wellness routines — and track consistency over time.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Android)                 │
│  Home · Check-in · Routine · Progress · AI Agent Chat   │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP (ADB reverse / LAN)
┌────────────────────▼────────────────────────────────────┐
│              MCP HTTP Bridge  :8765                      │
│  POST /tool  ·  POST /agent  ·  GET /metrics            │
└──┬──────────────┬──────────────┬────────────────────────┘
   │              │              │
   ▼              ▼              ▼
MCP Tools    Multi-Agent    Observability
(7 tools)    Supervisor     (logs/metrics/traces)
   │          ├─ RoutineAgent
   │          ├─ ProgressAgent
   │          └─ CoachAgent (RAG)
   │
   ▼
WellnessEngine  ←→  ChromaDB (RAG)  ←→  Guardrails
(JSON data store)   (wellness KB)       (validation/safety)
```

### Key Concepts Implemented

| Concept | Implementation |
|---|---|
| **MCP** | 7 tools exposed via `server.py` + HTTP bridge (`http_bridge.py`) |
| **RAG** | ChromaDB vector store with 19 wellness knowledge docs (`rag_engine.py`) |
| **Agentic Framework** | Groq LLM with tool-calling loop, max 5 iterations (`groq_agent.py`) |
| **Multi-Agent** | Supervisor routes to RoutineAgent / ProgressAgent / CoachAgent (`multi_agent.py`) |
| **Guardrails** | Input validation, crisis detection, output filtering (`guardrails.py`) |
| **Observability** | JSON structured logs, metrics, distributed tracing (`observability.py`) |

---

## Project Structure

```
wellness_ai/
├── mcp_server/
│   ├── server.py           # MCP server (stdio transport)
│   ├── http_bridge.py      # REST bridge for Flutter (/tool, /agent, /metrics)
│   ├── wellness_engine.py  # Core business logic + JSON data store
│   ├── groq_agent.py       # Agentic LLM loop (Groq + RAG + tools)
│   ├── multi_agent.py      # Supervisor + 3 specialist agents
│   ├── rag_engine.py       # ChromaDB RAG engine
│   ├── guardrails.py       # Safety, validation, output filtering
│   ├── observability.py    # Structured logging, metrics, tracing
│   ├── requirements.txt
│   ├── .env.example
│   └── tests/
│       ├── test_wellness_engine.py   # 20+ unit tests
│       ├── test_guardrails.py        # 25+ unit tests
│       ├── test_rag_engine.py        # 15+ unit tests
│       └── test_integration.py      # End-to-end HTTP tests
│
└── flutter_app/
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── theme/app_theme.dart
    │   │   └── router/app_router.dart
    │   ├── data/
    │   │   ├── models/wellness_models.dart
    │   │   ├── services/wellness_mcp_service.dart
    │   │   └── local/hive_adapters.dart
    │   └── features/
    │       ├── onboarding/
    │       ├── home/
    │       ├── checkin/
    │       ├── routine/
    │       ├── progress/
    │       ├── agent_chat/
    │       └── agent/wellness_agent.dart   # Agentic flow + Riverpod providers
    └── pubspec.yaml
```

---

## Setup

### Prerequisites

- Python 3.11+
- Flutter 3.x
- Android device or emulator
- [Groq API key](https://console.groq.com) (free tier available)

### 1. MCP Server

```bash
cd wellness_ai/mcp_server

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env and set GROQ_API_KEY=your_key_here

# Start the HTTP bridge
python http_bridge.py
```

The bridge starts at `http://localhost:8765`.

Verify it's running:
```bash
curl http://localhost:8765/health
```

### 2. Flutter App

```bash
cd wellness_ai/flutter_app

# Install Flutter dependencies
flutter pub get

# Connect Android device via USB, then forward port
adb reverse tcp:8765 tcp:8765

# Run the app
flutter run
```

> For a physical Android device on the same Wi-Fi, update the IP in
> `lib/data/services/wellness_mcp_service.dart` to your PC's LAN IP.

---

## MCP Tools

| Tool | Description |
|---|---|
| `get_user_profile` | User goals, streak, fitness level |
| `log_daily_checkin` | Log sleep, stress, energy, mood |
| `generate_daily_routine` | Adaptive routine based on today's state |
| `adjust_routine` | Modify routine (tired / stressed / short on time / feeling great) |
| `complete_activity` | Mark an activity as done |
| `get_consistency_report` | Progress report over N days |
| `update_user_goals` | Change wellness goals and fitness level |

---

## Agentic Flow

```
User message
    │
    ▼
Supervisor (intent classification)
    │
    ├─ "routine/tired/stressed" ──► RoutineAgent
    │                                  └─ generate_daily_routine / adjust_routine
    │
    ├─ "progress/streak/stats" ───► ProgressAgent
    │                                  └─ get_consistency_report / get_user_profile
    │
    └─ "advice/tips/why/how" ─────► CoachAgent
                                       └─ RAG context + get_user_profile
                                       
Each agent:
  1. Retrieves RAG context (ChromaDB semantic search)
  2. Calls Groq LLM with tools + context
  3. Executes tool calls (MCP engine)
  4. Loops until final text response (max 4 iterations)
  5. Output filtered by guardrails
```

---

## Guardrails

- **Input validation**: numeric range clamping, enum validation, type checking
- **Crisis detection**: blocks self-harm / dangerous content, returns crisis resources
- **Medical disclaimer**: appended when medical emergency keywords detected
- **Output filtering**: removes dangerous medical advice, caps response length
- **Tool loop limit**: max 5 LLM iterations to prevent infinite loops

---

## Observability

```bash
# Live metrics
curl http://localhost:8765/metrics

# Logs written to mcp_server/logs/
#   bridge.log   — HTTP request logs
#   agent.log    — agent call traces
#   rag.log      — retrieval logs
#   trace.log    — distributed traces
#   tool.log     — tool call latency
#   guardrails.log — validation events
```

---

## Running Tests

```bash
cd wellness_ai/mcp_server

# Unit tests (no bridge required)
pytest tests/test_wellness_engine.py tests/test_guardrails.py tests/test_rag_engine.py -v

# Integration tests (requires bridge running)
python http_bridge.py &
pytest tests/test_integration.py -v

# All tests with coverage
pytest tests/ -v --cov=. --cov-report=term-missing
```

---

## RAG Knowledge Base

The RAG engine indexes 19 evidence-based wellness facts across 6 topics:
`sleep` · `stress` · `exercise` · `mindfulness` · `hydration` · `nutrition`

ChromaDB uses sentence-transformer embeddings for semantic similarity search.
Relevant facts are injected into the LLM system prompt before each response.
