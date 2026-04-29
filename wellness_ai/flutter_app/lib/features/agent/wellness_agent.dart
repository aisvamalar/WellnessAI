import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/wellness_mcp_service.dart';
import '../../data/models/wellness_models.dart';
import '../../data/local/hive_adapters.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────

final mcpServiceProvider = Provider<WellnessMcpService>((_) {
  final svc = WellnessMcpService();
  svc.ensureConnected().ignore();
  return svc;
});

final userIdProvider = Provider<String>((ref) {
  return LocalStorage.getUserId() ?? 'user_default';
});

// ─── Profile ──────────────────────────────────────────────────────────────────

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

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

// ─── Routine ──────────────────────────────────────────────────────────────────

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
    for (final act in routine.activities) {
      if (act.routineActivityId == activityId) act.completed = true;
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

  /// Called by the agent to push a routine it already fetched from MCP.
  void setFromAgent(DailyRoutine routine) {
    state = AsyncData(routine);
  }
}

final routineProvider =
    AsyncNotifierProvider<RoutineNotifier, DailyRoutine?>(RoutineNotifier.new);

// ─── Checkin ──────────────────────────────────────────────────────────────────

class CheckinNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  CheckinNotifier(this._ref) : super(const AsyncData(false));

  Future<void> submit(DailyCheckin checkin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = _ref.read(userIdProvider);
      await _ref.read(mcpServiceProvider).logCheckin(checkin, userId);
      await _ref.read(routineProvider.notifier).generate();
      await _ref.read(profileProvider.notifier).refresh();
      return true;
    });
  }
}

final checkinProvider = StateNotifierProvider<CheckinNotifier, AsyncValue<bool>>(
    (ref) => CheckinNotifier(ref));

// ─── Report ───────────────────────────────────────────────────────────────────

final reportProvider =
    FutureProvider.family<ConsistencyReport, int>((ref, days) async {
  final userId = ref.read(userIdProvider);
  return ref.read(mcpServiceProvider).getReport(userId, days: days);
});

// ─── Agent Chat ───────────────────────────────────────────────────────────────

/// Describes an action the agent took — shown as an inline card in chat.
class AgentAction {
  final String type; // 'routine_generated' | 'routine_adjusted' | 'checkin_logged' | 'goals_updated' | 'progress_fetched'
  final String label;
  final String emoji;
  final String route; // where to navigate to see the result
  final dynamic data; // the actual result object

  const AgentAction({
    required this.type,
    required this.label,
    required this.emoji,
    required this.route,
    this.data,
  });
}

class AgentMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isTyping;
  final AgentAction? action; // non-null when agent took a real action

  const AgentMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isTyping = false,
    this.action,
  });
}

class AgentChatNotifier extends StateNotifier<List<AgentMessage>> {
  final Ref _ref;
  bool _thinking = false;

  AgentChatNotifier(this._ref)
      : super([
          AgentMessage(
            text:
                "Hi! I'm your **Wellness AI** 🌱\n\nI don't just answer — I **take action**. Ask me to:\n• Generate or adjust your routine\n• Log how you're feeling\n• Show your progress\n• Give wellness advice\n\nI'll update the whole app automatically.",
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
      AgentMessage(text: '', isUser: false, time: DateTime.now(), isTyping: true),
    ];

    final (reply, action) = await _callAgent(userMessage);

    final updated = List<AgentMessage>.from(state)..removeLast();
    state = [
      ...updated,
      AgentMessage(
        text: reply,
        isUser: false,
        time: DateTime.now(),
        action: action,
      ),
    ];
    _thinking = false;
  }

  Future<(String, AgentAction?)> _callAgent(String userMessage) async {
    final userId = _ref.read(userIdProvider);
    final svc = _ref.read(mcpServiceProvider);

    final history = state
        .where((m) => !m.isTyping && m.text.isNotEmpty)
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

      final error = result['error'];
      if (error != null && error.toString().isNotEmpty) {
        return ("⚠️ Agent error: $error", null);
      }

      final reply = result['reply'] as String? ?? 'Done.';
      final agentUsed = result['agent_used'] as String? ?? '';
      final toolCalls = result['tool_calls'] as List? ?? [];

      // ── Dispatch tool results back into Riverpod state ────────────────────
      AgentAction? action;

      for (final tc in toolCalls) {
        if (tc is! Map) continue;
        final tool = tc['tool'] as String? ?? '';
        final toolResult = tc['result'];

        switch (tool) {
          case 'generate_daily_routine':
            if (toolResult is Map) {
              try {
                final routine = DailyRoutine.fromJson(
                    Map<String, dynamic>.from(toolResult));
                _ref.read(routineProvider.notifier).setFromAgent(routine);
                _ref.read(profileProvider.notifier).refresh();
                action = AgentAction(
                  type: 'routine_generated',
                  label: 'New routine ready — ${routine.activities.length} activities, ${routine.totalDurationMinutes} min',
                  emoji: '📋',
                  route: '/routine',
                  data: routine,
                );
              } catch (_) {
                _ref.read(routineProvider.notifier).generate();
              }
            }

          case 'adjust_routine':
            if (toolResult is Map) {
              try {
                final routine = DailyRoutine.fromJson(
                    Map<String, dynamic>.from(toolResult));
                _ref.read(routineProvider.notifier).setFromAgent(routine);
                action = AgentAction(
                  type: 'routine_adjusted',
                  label: 'Routine adjusted — ${routine.activities.length} activities',
                  emoji: '🔄',
                  route: '/routine',
                  data: routine,
                );
              } catch (_) {
                _ref.read(routineProvider.notifier).adjust('too_tired');
              }
            }

          case 'log_daily_checkin':
            _ref.read(profileProvider.notifier).refresh();
            _ref.read(routineProvider.notifier).generate();
            action = AgentAction(
              type: 'checkin_logged',
              label: 'Check-in logged — routine updated',
              emoji: '✅',
              route: '/checkin',
            );

          case 'get_consistency_report':
            if (toolResult is Map) {
              action = AgentAction(
                type: 'progress_fetched',
                label: 'Progress report loaded',
                emoji: '📊',
                route: '/progress',
                data: toolResult,
              );
            }

          case 'update_user_goals':
            _ref.read(profileProvider.notifier).refresh();
            action = AgentAction(
              type: 'goals_updated',
              label: 'Goals updated',
              emoji: '🎯',
              route: '/home',
            );

          case 'get_user_profile':
            _ref.read(profileProvider.notifier).refresh();
        }
      }

      // Format reply with agent label
      final label = agentUsed.replaceAll('Agent', '').trim();
      final formattedReply = label.isNotEmpty ? '$reply\n\n_— $label Agent_' : reply;

      return (formattedReply, action);
    } on Exception catch (e) {
      final err = e.toString();
      if (err.contains('Cannot reach') ||
          err.contains('connection') ||
          err.contains('SocketException')) {
        return (
          "⚠️ **Can't reach the MCP bridge**\n\n"
              "1. Make sure `http_bridge.py` is running\n"
              "2. Run: `adb reverse tcp:8765 tcp:8765`",
          null
        );
      }
      return ("⚠️ Error: $err", null);
    }
  }
}

final agentChatProvider =
    StateNotifierProvider<AgentChatNotifier, List<AgentMessage>>(
        (ref) => AgentChatNotifier(ref));
