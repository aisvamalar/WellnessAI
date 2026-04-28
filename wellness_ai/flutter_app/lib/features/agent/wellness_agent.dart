import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/wellness_mcp_service.dart';
import '../../data/models/wellness_models.dart';
import '../../data/local/hive_adapters.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final mcpServiceProvider = Provider<WellnessMcpService>((_) {
  final svc = WellnessMcpService();
  // Fire-and-forget host discovery; individual calls retry on failure
  svc.ensureConnected().ignore();
  return svc;
});

final userIdProvider = Provider<String>((ref) {
  return LocalStorage.getUserId() ?? 'user_default';
});

// ─── Agent State ─────────────────────────────────────────────────────────────

enum AgentStatus { idle, thinking, done, error }

class AgentState {
  final AgentStatus status;
  final String? message;
  final dynamic result;

  const AgentState({this.status = AgentStatus.idle, this.message, this.result});

  AgentState copyWith({AgentStatus? status, String? message, dynamic result}) =>
      AgentState(
        status: status ?? this.status,
        message: message ?? this.message,
        result: result ?? this.result,
      );
}

// ─── Profile Notifier ────────────────────────────────────────────────────────

class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final userId = ref.read(userIdProvider);
    try {
      return await ref.read(mcpServiceProvider).getProfile(userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(userIdProvider);
      return ref.read(mcpServiceProvider).getProfile(userId);
    });
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

// ─── Routine Notifier ────────────────────────────────────────────────────────

class RoutineNotifier extends AsyncNotifier<DailyRoutine?> {
  @override
  Future<DailyRoutine?> build() async => null;

  Future<void> generate({int minutes = 45, List<String> constraints = const []}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(userIdProvider);
      return ref.read(mcpServiceProvider).generateRoutine(userId, minutes, constraints);
    });
  }

  Future<void> completeActivity(String activityId) async {
    final routine = state.value;
    if (routine == null) return;
    final userId = ref.read(userIdProvider);
    await ref.read(mcpServiceProvider).completeActivity(userId, activityId);
    // Update local state
    for (final act in routine.activities) {
      if (act.routineActivityId == activityId) {
        act.completed = true;
      }
    }
    state = AsyncData(routine);
  }

  Future<void> adjust(String reason, {int minutes = 20}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(userIdProvider);
      return ref.read(mcpServiceProvider).adjustRoutine(userId, reason, minutes);
    });
  }
}

final routineProvider = AsyncNotifierProvider<RoutineNotifier, DailyRoutine?>(RoutineNotifier.new);

// ─── Checkin Notifier ────────────────────────────────────────────────────────

class CheckinNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  CheckinNotifier(this._ref) : super(const AsyncData(false));

  Future<void> submit(DailyCheckin checkin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = _ref.read(userIdProvider);
      await _ref.read(mcpServiceProvider).logCheckin(checkin, userId);
      // Auto-generate routine after checkin
      await _ref.read(routineProvider.notifier).generate();
      await _ref.read(profileProvider.notifier).refresh();
      return true;
    });
  }
}

final checkinProvider =
    StateNotifierProvider<CheckinNotifier, AsyncValue<bool>>(
        (ref) => CheckinNotifier(ref));

// ─── Report Notifier ─────────────────────────────────────────────────────────

final reportProvider = FutureProvider.family<ConsistencyReport, int>((ref, days) async {
  final userId = ref.read(userIdProvider);
  return ref.read(mcpServiceProvider).getReport(userId, days: days);
});

// ─── Agent Chat ───────────────────────────────────────────────────────────────

class AgentMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isTyping;
  const AgentMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isTyping = false,
  });
}

class AgentChatNotifier extends StateNotifier<List<AgentMessage>> {
  final Ref _ref;
  bool _thinking = false;

  AgentChatNotifier(this._ref) : super([
    AgentMessage(
      text: "Hi! I'm your Wellness AI agent 🌱 powered by Groq.\n\nI understand natural language — just tell me how you're feeling or what you need.",
      isUser: false,
      time: DateTime.now(),
    )
  ]);

  Future<void> send(String userMessage) async {
    if (_thinking) return;
    _thinking = true;

    state = [
      ...state,
      AgentMessage(text: userMessage, isUser: true, time: DateTime.now()),
      AgentMessage(text: '...', isUser: false, time: DateTime.now(), isTyping: true),
    ];

    final response = await _callGroqAgent(userMessage);

    final updated = [...state];
    updated.removeLast(); // remove typing indicator
    state = [...updated, AgentMessage(text: response, isUser: false, time: DateTime.now())];
    _thinking = false;
  }

  Future<String> _callGroqAgent(String userMessage) async {
    final userId = _ref.read(userIdProvider);
    final svc = _ref.read(mcpServiceProvider);

    // Build history from current messages (exclude typing indicators)
    final history = state
        .where((m) => !m.isTyping)
        .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    try {
      final result = await svc.chatWithAgent(
        userId: userId,
        message: userMessage,
        history: history,
      );

      // Refresh local state if agent called routine/checkin tools
      final toolCalls = result['tool_calls'] as List? ?? [];
      for (final tc in toolCalls) {
        final tool = tc['tool'] as String? ?? '';
        if (tool == 'generate_daily_routine' || tool == 'adjust_routine') {
          _ref.read(routineProvider.notifier).generate();
        }
        if (tool == 'log_daily_checkin') {
          _ref.read(profileProvider.notifier).refresh();
          _ref.read(routineProvider.notifier).generate();
        }
      }

      final error = result['error'];
      if (error != null && error.toString().isNotEmpty) {
        return "⚠️ Agent error: $error";
      }

      return result['reply'] as String? ?? 'No response.';
    } on Exception catch (e) {
      final err = e.toString();
      if (err.contains('Cannot reach') || err.contains('connection')) {
        return "⚠️ Can't reach the MCP bridge.\n\n1. Make sure http_bridge.py is running\n2. Run: adb reverse tcp:8765 tcp:8765";
      }
      return "Error: $err";
    }
  }
}

final agentChatProvider =
    StateNotifierProvider<AgentChatNotifier, List<AgentMessage>>(
        (ref) => AgentChatNotifier(ref));
