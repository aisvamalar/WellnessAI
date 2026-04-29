
# 🌱 WellnessAI

> **An adaptive AI-powered wellness companion** that considers your schedule, stress levels, sleep patterns, and goals to dynamically generate and adjust daily wellness routines — and track consistency over time.

[![Python](https://img.shields.io/badge/Python-3.11+-blue?logo=python)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Groq](https://img.shields.io/badge/LLM-Groq%20Llama%203.3-orange)](https://console.groq.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Table of Contents

1. [What is WellnessAI?](#what-is-wellnessai)
2. [Key Features](#key-features)
3. [Architecture Overview](#architecture-overview)
4. [System Architecture Diagram](#system-architecture-diagram)
5. [Project Structure](#project-structure)
6. [Prerequisites](#prerequisites)
7. [Quick Start](#quick-start)
8. [MCP Tools Reference](#mcp-tools-reference)
9. [Multi-Agent System](#multi-agent-system)
10. [RAG Engine](#rag-engine)
11. [Guardrails](#guardrails)
12. [Observability](#observability)
13. [Notification System](#notification-system)
14. [Unique Features](#unique-features)
15. [Flutter App Screens](#flutter-app-screens)
16. [API Reference](#api-reference)
17. [Running Tests](#running-tests)
18. [Troubleshooting](#troubleshooting)
19. [Tech Stack](#tech-stack)

---

## What is WellnessAI?

WellnessAI is a **fully agentic wellness application** — not just a chatbot with a wellness skin. The AI agent actively controls the app:

- You say *"I'm tired today"* → the agent calls the MCP tool, adjusts your routine, and the Routine screen updates **automatically**
- You say *"show my progress"* → the agent fetches real data, formats it, and shows you an inline progress card in the chat
- The system **proactively notifies you** when you have pending activities, with a message crafted by the AI based on your actual data

Every interaction goes through the **Model Context Protocol (MCP)** — a standardised tool-calling interface between the LLM and the wellness data engine.

#DEMO SCREESHOTS
<img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 53 43 PM" src="https://github.com/user-attachments/assets/b9c1cbec-fd0f-4e02-95c2-4b9b45ad150e" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 53 52 PM" src="https://github.com/user-attachments/assets/b342a85b-2d36-4dac-99f0-3ceecd6a52d7" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 53 54 PM" src="https://github.com/user-attachments/assets/bc56478f-eb0f-4c87-aa6e-afa1b93e825e" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 53 54 PM" src="https://github.com/user-attachments/assets/7835a946-6da2-46bb-90b1-4d8aa6b5032f" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 53 56 PM" src="https://github.com/user-attachments/assets/b052eb42-a455-4d76-a21c-2adc5ae0549e" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 54 02 PM" src="https://github.com/user-attachments/assets/f501c9e7-f260-41d4-b9e3-2e3dc66bf864" /><img width="300" height="400" alt="image" src="https://github.com/user-attachments/assets/1bf0fab8-eebf-47f0-ad3c-614e3a29be5c" />
<img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 54 04 PM" src="https://github.com/user-attachments/assets/8f843a66-4d11-4203-a4f8-e55a599878e4" /><img width="300" height="400" alt="WhatsApp Image 2026-04-29 at 1 54 07 PM" src="https://github.com/user-attachments/assets/8b40931a-db62-4d50-9423-bf404131a82c" />


---

## Key Features

| Feature | Description |
|---|---|
| 🤖 **Fully Agentic** | AI takes real actions — generates routines, logs check-ins, updates goals — not just text responses |
| 🔗 **MCP Integration** | 7 structured tools exposed via MCP server + HTTP bridge |
| 🧠 **Multi-Agent Supervisor** | 3 specialist agents (Routine, Progress, Coach) routed by intent classifier |
| 📚 **RAG-Powered Coaching** | TF-IDF semantic search over 19 evidence-based wellness documents |
| 🛡️ **Guardrails** | Input validation, crisis detection, PII redaction, output filtering |
| 📊 **Observability** | Structured JSON logs, metrics endpoint, distributed tracing |
| 🔔 **Smart Notifications** | MCP agent analyses pending tasks, Groq crafts personalised nudge messages |
| 🌡️ **Wellness Score** | Composite 0–100 score across sleep, stress, energy, consistency |
| 🔥 **Burnout Detector** | Pattern-based early warning from 5-day check-in history |
| 💡 **Contextual Nudges** | Time-aware + state-aware micro-prompts on the home screen |

---

## Architecture Overview

WellnessAI has two main components that communicate over HTTP:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App  (Android/iOS)                    │
│                                                                  │
│  Riverpod State ──► WellnessMcpService ──► HTTP :8765           │
│  AgentChatNotifier dispatches tool results back into providers  │
│  NotificationService polls /notify/check on resume + timer      │
└──────────────────────────────┬──────────────────────────────────┘
                               │  adb reverse tcp:8765 tcp:8765
┌──────────────────────────────▼──────────────────────────────────┐
│                  MCP HTTP Bridge  (Python)                       │
│                                                                  │
│  POST /tool        ── direct MCP tool call                      │
│  POST /agent       ── multi-agent LLM chat                      │
│  POST /notify/check── pending task analysis + AI nudge          │
│  GET  /health      ── liveness + tool list                      │
│  GET  /metrics     ── observability snapshot                    │
│                                                                  │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────────┐   │
│  │ WellnessEngine│  │  Multi-Agent    │  │ NotificationAgent│   │
│  │ (data store) │  │  Supervisor     │  │ (nudge crafter)  │   │
│  └──────────────┘  └────────┬────────┘  └──────────────────┘   │
│                              │                                   │
│                    ┌─────────┼─────────┐                        │
│                    ▼         ▼         ▼                        │
│              RoutineAgent ProgressAgent CoachAgent              │
│                              │                                   │
│                         RAG Engine                              │
│                    (TF-IDF + cosine sim)                        │
│                              │                                   │
│                    Guardrails + Observability                   │
└─────────────────────────────────────────────────────────────────┘
```
<img width="700" height="700" alt="ChatGPT Image Apr 29, 2026, 12_24_21 PM" src="https://github.com/user-attachments/assets/55eccc1f-252d-4e8d-95b8-ec76e9ece6c1" />

---

## System Architecture Diagram

```
User types: "I'm tired, adjust my routine"
         │
         ▼
AgentChatNotifier.send()
         │
         ▼  POST /agent
MCP HTTP Bridge
         │
         ▼
Supervisor._classify_intent()  →  "routine"
         │
         ▼
RoutineAgent
  ├─ RAG: retrieve("tired routine") → 2 wellness docs
  ├─ Groq LLM call #1: decides to call adjust_routine(reason="too_tired")
  ├─ WellnessEngine.adjust_routine() → filters activities ≤10min
  ├─ Groq LLM call #2: formats structured response
  └─ Returns { reply, tool_calls: [{tool: "adjust_routine", result: {...}}] }
         │
         ▼
AgentChatNotifier receives response
  ├─ routineProvider.setFromAgent(routine)  ← Routine screen updates instantly
  ├─ profileProvider.refresh()              ← Home screen updates
  └─ Shows ActionCard in chat with routine preview + "View Routine →" button
```

---

## Project Structure

```
WellnessAI/
├── README.md
├── LICENSE
├── CHANGELOG.md
│
├── wellness_ai/
│   │
│   ├── mcp_server/                    # Python backend
│   │   ├── server.py                  # MCP server (stdio transport)
│   │   ├── http_bridge.py             # REST bridge — /tool /agent /notify/check /metrics
│   │   ├── wellness_engine.py         # Core data store + business logic
│   │   ├── multi_agent.py             # Supervisor + 3 specialist agents
│   │   ├── rag_engine.py              # TF-IDF semantic retrieval
│   │   ├── guardrails.py              # Validation, safety, output filtering
│   │   ├── observability.py           # Structured logging + metrics
│   │   ├── notification_agent.py      # Pending task analysis + AI nudge
│   │   ├── groq_agent.py              # Standalone Groq agent (legacy)
│   │   ├── requirements.txt
│   │   ├── .env.example
│   │   ├── data/                      # Per-user JSON data store
│   │   │   └── {user_id}.json
│   │   ├── logs/
│   │   │   ├── bridge.log
│   │   │   ├── guardrails.log
│   │   │   └── trace.log
│   │   └── tests/
│   │       ├── test_wellness_engine.py
│   │       ├── test_guardrails.py
│   │       ├── test_rag_engine.py
│   │       └── test_integration.py
│   │
│   └── flutter_app/                   # Flutter frontend
│       ├── pubspec.yaml
│       ├── android/
│       │   └── app/src/main/
│       │       └── AndroidManifest.xml
│       └── lib/
│           ├── main.dart              # App entry + lifecycle observer
│           ├── core/
│           │   ├── theme/app_theme.dart      # Material 3 + Inter font
│           │   └── router/app_router.dart    # GoRouter + notification tap handler
│           ├── data/
│           │   ├── models/wellness_models.dart    # All data models
│           │   ├── services/
│           │   │   ├── wellness_mcp_service.dart  # HTTP client for MCP bridge
│           │   │   └── notification_service.dart  # Local notifications + timer
│           │   └── local/hive_adapters.dart       # Hive local storage
│           └── features/
│               ├── onboarding/onboarding_screen.dart
│               ├── home/home_screen.dart           # Wellness Score + Burnout + Nudge
│               ├── checkin/checkin_screen.dart
│               ├── routine/routine_screen.dart
│               ├── progress/progress_screen.dart
│               ├── agent_chat/agent_chat_screen.dart  # Agentic chat + action cards
│               └── agent/wellness_agent.dart          # Riverpod providers + agent logic
│
└── .github/
    └── workflows/
        └── ci.yml                     # GitHub Actions CI
```

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Python | 3.11+ | For the MCP server |
| Flutter | 3.x | For the mobile app |
| Android SDK | API 21+ | Target device or emulator |
| Groq API Key | Free tier | [console.groq.com](https://console.groq.com) |
| ADB | Any | For USB port forwarding |

---

## Quick Start

### Step 1 — Clone the repository

```bash
git clone https://github.com/your-username/WellnessAI.git
cd WellnessAI
```

### Step 2 — Set up the MCP server

```bash
cd wellness_ai/mcp_server

# Install Python dependencies
pip install -r requirements.txt

# Create your environment file
cp .env.example .env
```

Edit `.env` and add your Groq API key:

```env
GROQ_API_KEY=gsk_your_key_here
```

Start the HTTP bridge:

```bash
python http_bridge.py
```

You should see:

```
🌱 Wellness AI MCP Bridge
========================================
  http://localhost:8765/health   — status
  http://localhost:8765/metrics  — observability
  POST /tool                     — MCP tools
  POST /agent                    — AI agent chat
========================================
```

Verify it's running:

```bash
curl http://localhost:8765/health
```

Expected response:

```json
{
  "status": "ok",
  "tools": ["log_daily_checkin", "generate_daily_routine", ...],
  "agents": ["routine", "progress", "coach"],
  "features": ["mcp", "rag", "multi_agent", "guardrails", "observability", "notifications"]
}
```

### Step 3 — Set up the Flutter app

```bash
cd wellness_ai/flutter_app

# Install Flutter dependencies
flutter pub get
```

### Step 4 — Connect your Android device

**Option A — USB (recommended):**

```bash
# Connect phone via USB, enable USB debugging, then:
adb reverse tcp:8765 tcp:8765
flutter run -d <your-device-id>
```

Find your device ID with:

```bash
flutter devices
```

**Option B — Wi-Fi (same network):**

Open `lib/data/services/wellness_mcp_service.dart` and add your PC's LAN IP to the `_hosts` list:

```dart
static const _hosts = [
  'http://localhost:8765',
  'http://10.0.2.2:8765',      // emulator
  'http://YOUR_PC_IP:8765',    // ← add this
];
```

---

## MCP Tools Reference

The MCP server exposes 7 tools that the AI agents can call:

| Tool | Input | Output | Used By |
|---|---|---|---|
| `get_user_profile` | `user_id` | Goals, streak, fitness level, wellness score, burnout risk, nudge | All agents |
| `log_daily_checkin` | `user_id`, `sleep_hours`, `stress_level` (1-10), `energy_level` (1-10), `mood`, `notes` | Success confirmation | RoutineAgent |
| `generate_daily_routine` | `user_id`, `available_time_minutes`, `schedule_constraints` | Routine with activities list | RoutineAgent |
| `adjust_routine` | `user_id`, `reason` (too_tired/short_on_time/feeling_great/stressed), `available_minutes` | Adjusted routine | RoutineAgent |
| `complete_activity` | `user_id`, `activity_id` | Success + progress string | RoutineAgent |
| `get_consistency_report` | `user_id`, `days` | Completion rate, averages, streak, trend, **pending/completed activity names** | ProgressAgent |
| `update_user_goals` | `user_id`, `goals[]`, `fitness_level` | Success confirmation | CoachAgent |

### Example Tool Call

```bash
curl -X POST http://localhost:8765/tool \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "generate_daily_routine",
    "arguments": {
      "user_id": "test_user",
      "available_time_minutes": 45
    }
  }'
```

---

## Multi-Agent System

The **Supervisor** classifies user intent and routes to the appropriate specialist agent:

### Intent Classification

```python
INTENTS = {
    "routine":  ["routine", "workout", "exercise", "tired", "stressed", 
                 "busy", "adjust", "generate", "create routine"],
    "progress": ["progress", "streak", "stats", "completed", "pending",
                 "tasks", "done", "remaining", "show my"],
    "coach":    ["advice", "tip", "help", "sleep", "stress", "why", "how"]
}
```

### Specialist Agents

#### 1. RoutineAgent

- **Triggers:** "generate my routine", "I'm tired", "short on time"
- **Tools:** `generate_daily_routine`, `adjust_routine`, `get_user_profile`
- **Logic:** Reads today's check-in (stress/sleep/energy) and adapts activity selection
- **Output format:** Structured bullets with emoji, duration, time of day

#### 2. ProgressAgent

- **Triggers:** "show my progress", "what have I completed", "pending tasks"
- **Tools:** `get_consistency_report`, `get_user_profile`
- **Logic:** Fetches real data, lists completed vs pending activities by name
- **Output format:** Stats table + completed list + pending list + next step

#### 3. CoachAgent

- **Triggers:** "why is sleep important", "how to reduce stress", "tips for hydration"
- **Tools:** `get_user_profile`, `update_user_goals`
- **RAG:** Retrieves 2 most relevant wellness documents via TF-IDF cosine similarity
- **Output format:** Science-backed bullets + action steps + watch-out-for

---

## RAG Engine

Pure-Python TF-IDF retrieval — no ChromaDB, no ONNX, no native DLLs. Works on any Python 3.8+ environment.

### Knowledge Base

19 evidence-based wellness documents across 6 topics:

- **Sleep** (4 docs) — circadian rhythm, blue light, temperature, deprivation effects
- **Stress** (4 docs) — box breathing, cold water, journaling, chronic stress
- **Exercise** (4 docs) — aerobic benefits, HIIT, morning BDNF, bodyweight training
- **Mindfulness** (3 docs) — MBSR, gratitude, body scan
- **Hydration** (2 docs) — cognitive impact, morning hydration
- **Nutrition** (2 docs) — time-restricted eating, omega-3

### Retrieval Process

```python
query = "how to reduce stress"
  ↓
Tokenize → ["reduce", "stress"]
  ↓
TF-IDF vector → {reduce: 0.42, stress: 0.91}
  ↓
Cosine similarity with all 19 doc vectors
  ↓
Top 2 results:
  1. "Box breathing 4-4-4-4 activates parasympathetic nervous system..."
  2. "Cold water exposure stimulates vagus nerve..."
  ↓
Injected into CoachAgent system prompt as context
```

---

## Guardrails

### Input Validation

- Numeric range clamping (stress 1-10, energy 1-10, sleep 2-12)
- Enum validation (mood, fitness_level, reason)
- Type checking (user_id must be string, etc.)

### Crisis Detection

Keywords like "suicide", "self-harm", "kill myself" trigger:

```
⚠️ If you're in crisis, please reach out:
• National Suicide Prevention Lifeline: 988
• Crisis Text Line: Text HOME to 741741
```

### Output Filtering

- Medical disclaimer appended when medical keywords detected
- Response length capped at 2000 characters
- Dangerous medical advice removed

### PII Redaction (planned)

- Email addresses → `[EMAIL_REDACTED]`
- Phone numbers → `[PHONE_REDACTED]`
- Aadhaar numbers → `[ID_REDACTED]`

---

## Observability

### Structured Logs

All logs written to `mcp_server/logs/` in JSON format:

```json
{
  "timestamp": "2026-04-29T06:37:58.663900Z",
  "level": "INFO",
  "logger": "wellness.bridge",
  "message": "HTTP \"POST /agent HTTP/1.1\" 200 -"
}
```

### Metrics Endpoint

```bash
curl http://localhost:8765/metrics
```

Returns:

```json
{
  "requests_total": 142,
  "requests_by_endpoint": {
    "/agent": 87,
    "/tool": 45,
    "/notify/check": 10
  },
  "uptime_seconds": 3847
}
```

---

## Notification System

WellnessAI uses a **MCP-driven notification pipeline** — the AI agent analyses your actual data and crafts a personalised message before sending the notification.

### How It Works

```
App resumes / Timer fires (every 3h)
         │
         ▼
NotificationService.checkAndNotify()
         │
         ▼  POST /notify/check  {user_id}
MCP Bridge → notification_agent.py
         │
         ├─ WellnessEngine.get_report(days=30)
         │    → pending_activity_names: ["Morning Meditation", "Mindful Eating"]
         │
         ├─ WellnessEngine.get_profile()
         │    → streak: 3, time_of_day: "evening"
         │
         └─ Groq LLM crafts nudge (80 tokens):
              "You're doing great! Don't forget Morning Meditation —
               take a moment to breathe before bed."
         │
         ▼
flutter_local_notifications.show()
  Title: "⏳ 2 activities still pending"
  Body:  [agent-crafted message]
  Tap → navigates to /routine
```

### Trigger Points

| Trigger | When |
|---|---|
| App cold start | Immediately after launch |
| App resume | Every time user opens the app from background |
| Foreground timer | Every 3 hours while app is open |

### Notification Tap Navigation

When the user taps the notification, the app navigates directly to the Routine screen. This is handled via `LocalStorage.setPendingRoute('/routine')` which the GoRouter `redirect` picks up on next navigation.

---

## Unique Features

### 1. Wellness Score (0–100)

A composite score computed from the last 7 days of check-ins:

| Dimension | Max Points | Formula |
|---|---|---|
| Sleep | 25 | Optimal at 8h; scaled linearly |
| Stress | 25 | Inverted: stress 1 = 25pts, stress 10 = 0pts |
| Energy | 25 | Linear: energy 1 = 0pts, energy 10 = 25pts |
| Consistency | 25 | check-in days / 7 × 25 |

Grades: **Excellent 🌟** (85+) · **Good 💪** (70+) · **Fair 🌱** (50+) · **Needs Care 🤍** (<50)

### 2. Burnout Detector

Analyses the last 5 check-ins for the **triple-threat pattern**:

```
stress ≥ 7  AND  sleep < 6.5h  AND  energy ≤ 4
```

- 3+ days flagged → **High risk** — red alert banner on home screen
- 2 days flagged → **Moderate risk** — amber alert banner
- Rising stress trend → **Moderate risk**

### 3. Contextual Nudge

Time-aware + state-aware micro-prompts on the home screen:

| Time | State | Nudge |
|---|---|---|
| 21:00+ | stress ≥ 7 | "High stress tonight — try 5 min box breathing before bed 🌙" |
| 06:00–09:00 | energy ≤ 3 | "Low energy this morning — a 10-min walk beats coffee ☀️" |
| 12:00–14:00 | stress ≥ 7 | "Midday stress spike — take a 5-min mindful break now 🧘" |
| 18:00+ | energy ≥ 8 | "Great energy tonight — perfect time for an evening workout 💪" |

### 4. Agentic Action Cards

When the AI agent takes an action (generates a routine, adjusts it, logs a check-in), an **inline action card** appears in the chat bubble showing:

- What action was taken (e.g. "ROUTINE GENERATED")
- A mini-preview of the first 3 activities with emoji + duration
- A "tap to view all →" button that navigates to the relevant screen

The app state updates **automatically** — no manual refresh needed.

---

## Flutter App Screens

| Screen | Route | Description |
|---|---|---|
| Onboarding | `/onboarding` | 3-step setup: welcome → goals → fitness level |
| Home | `/home` | Wellness Score gauge, burnout alert, contextual nudge, routine summary |
| Check-in | `/checkin` | Sleep slider, stress/energy scale, mood picker, notes |
| Routine | `/routine` | Activity cards with complete button, adjust menu |
| Progress | `/progress` | Completion rate, averages, 7/14/30 day toggle |
| AI Agent | `/agent` | Agentic chat with action cards, suggestion chips |

---

## API Reference

### POST /agent

Send a message to the multi-agent system.

**Request:**
```json
{
  "user_id": "abc123",
  "message": "I'm feeling tired today, adjust my routine",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

**Response:**
```json
{
  "reply": "**🔄 Routine Adjusted**\n...",
  "agent_used": "RoutineAgent",
  "tool_calls": [
    {
      "tool": "adjust_routine",
      "result": { "routine_id": "...", "activities": [...] }
    }
  ],
  "rag_docs": [{"id": "stress_1", "title": "stress_1"}],
  "error": null
}
```

### POST /notify/check

Analyse pending activities and generate an AI nudge.

**Request:**
```json
{ "user_id": "abc123" }
```

**Response:**
```json
{
  "user_id": "abc123",
  "activities_total": 5,
  "activities_completed": 3,
  "activities_pending": 2,
  "pending_activity_names": ["Morning Meditation", "Mindful Eating"],
  "completed_activity_names": ["Box Breathing", "Morning Yoga Flow", "10-min HIIT"],
  "agent_nudge": "You're doing great! Don't forget Morning Meditation tonight.",
  "should_notify": true
}
```

---

## Running Tests

```bash
cd wellness_ai/mcp_server

# Unit tests only (no bridge required)
pytest tests/test_wellness_engine.py tests/test_guardrails.py tests/test_rag_engine.py -v

# Integration tests (requires bridge running in another terminal)
python http_bridge.py &
pytest tests/test_integration.py -v

# All tests with coverage report
pytest tests/ -v --cov=. --cov-report=term-missing

# Coverage gate (fails if below 80%)
pytest tests/ --cov=. --cov-fail-under=80
```

---

## Troubleshooting

### Bridge won't start — "GROQ_API_KEY not set"

```bash
# Make sure .env exists with your key
cat wellness_ai/mcp_server/.env
# Should show: GROQ_API_KEY=gsk_...
```

### Flutter can't reach the bridge

```bash
# Check bridge is running
curl http://localhost:8765/health

# Re-run ADB reverse
adb reverse tcp:8765 tcp:8765

# Check connected devices
flutter devices
```

### Gradle build fails — "file locked by another process"

```powershell
# Kill all Java/Gradle processes
taskkill /F /IM java.exe /T

# Wait 2 seconds, then retry
Start-Sleep 2
flutter run -d <device-id>
```

### Gradle TLS handshake failure

Add to `android/gradle.properties`:

```properties
org.gradle.jvmargs=... -Dhttps.protocols=TLSv1.2,TLSv1.3
```

### Agent gives wrong progress data

The agent uses `get_consistency_report` with a 30-day window. If you see "no pending tasks" when there are some, check:

```bash
curl -X POST http://localhost:8765/notify/check \
  -H "Content-Type: application/json" \
  -d '{"user_id": "your_user_id"}'
```

The response should show `pending_activity_names` with the correct list.

---

## Tech Stack

### Backend (Python)

| Library | Version | Purpose |
|---|---|---|
| `groq` | ≥0.9.0 | LLM API client (Llama 3.3 70B) |
| `mcp` | ≥1.0.0 | Model Context Protocol server |
| `python-dotenv` | ≥1.0.0 | Environment variable loading |
| `pytest` | ≥8.0.0 | Test framework |
| `pytest-cov` | ≥5.0.0 | Coverage reporting |

### Frontend (Flutter/Dart)

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^14.2.7 | Navigation |
| `dio` | ^5.4.3 | HTTP client |
| `hive_flutter` | ^1.1.0 | Local storage |
| `flutter_local_notifications` | ^17.2.4 | Push notifications |
| `flutter_markdown_plus` | ^1.0.7 | Markdown rendering in chat |
| `fl_chart` | ^0.68.0 | Progress charts |
| `google_fonts` | ^6.2.1 | Inter font |
| `flutter_animate` | ^4.5.0 | Animations |

### AI / ML

| Component | Technology |
|---|---|
| LLM | Groq API — `llama-3.3-70b-versatile` |
| RAG | Pure Python TF-IDF + cosine similarity |
| Tool calling | Groq function calling API |
| Agent loop | Max 4 iterations, temperature 0.4 |

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

<div align="center">
  <p>Built with 🌱 by the WellnessAI team</p>
  <p>
    <a href="https://console.groq.com">Groq</a> ·
    <a href="https://flutter.dev">Flutter</a> ·
    <a href="https://modelcontextprotocol.io">MCP</a>
  </p>
</div>

# AUTHOR
NAME : AISVA MALAR A
EMAIL: aishuarou656@gmail.com
