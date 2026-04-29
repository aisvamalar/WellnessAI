import 'package:dio/dio.dart';
import '../models/wellness_models.dart';

/// HTTP service that talks to the WellnessAI MCP bridge (http_bridge.py).
///
/// Host discovery order:
///   1. localhost:8765  — works after `adb reverse tcp:8765 tcp:8765`
///   2. 127.0.0.1:8765  — alias for localhost
///   3. 10.0.2.2:8765   — Android emulator → host loopback
///   4. LAN IPs         — physical device on same Wi-Fi
///
/// Run once in a terminal to enable USB connection:
///   adb reverse tcp:8765 tcp:8765
class WellnessMcpService {
  late final Dio _dio;

  static const _hosts = [
    'http://localhost:8765',
    'http://127.0.0.1:8765',
    'http://10.0.2.2:8765',
    'http://10.137.21.130:8765',
    'http://10.21.102.136:8765',
  ];

  String _activeBase = _hosts[0];
  bool _connected = false;

  WellnessMcpService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// Probe each host until one responds; cache it for the session.
  Future<void> ensureConnected() async {
    if (_connected) return;
    for (final host in _hosts) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        )).get('$host/health');
        if (res.statusCode == 200) {
          _activeBase = host;
          _connected = true;
          return;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception(
      'Cannot reach MCP bridge.\n'
      '1. Make sure http_bridge.py is running on your PC\n'
      '2. For USB: run  adb reverse tcp:8765 tcp:8765\n'
      '3. For Wi-Fi: ensure phone and PC are on the same network',
    );
  }

  Future<Map<String, dynamic>> _callTool(
      String tool, Map<String, dynamic> args) async {
    await ensureConnected();
    try {
      final res = await _dio.post(
        '$_activeBase/tool',
        data: {'tool': tool, 'arguments': args},
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        // Force re-discovery on next call
        _connected = false;
        await ensureConnected();
        final res = await _dio.post(
          '$_activeBase/tool',
          data: {'tool': tool, 'arguments': args},
        );
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }

  // ── MCP Tool Calls ──────────────────────────────────────────────────────────

  Future<UserProfile> getProfile(String userId) async {
    final data = await _callTool('get_user_profile', {'user_id': userId});
    return UserProfile.fromJson(data);
  }

  Future<Map<String, dynamic>> logCheckin(
      DailyCheckin checkin, String userId) async {
    return _callTool('log_daily_checkin', {
      'user_id': userId,
      'sleep_hours': checkin.sleepHours,
      'stress_level': checkin.stressLevel,
      'energy_level': checkin.energyLevel,
      'mood': checkin.mood,
      'notes': checkin.notes,
    });
  }

  Future<DailyRoutine> generateRoutine(
      String userId, int availableMinutes, List<String> constraints) async {
    final data = await _callTool('generate_daily_routine', {
      'user_id': userId,
      'available_time_minutes': availableMinutes,
      'schedule_constraints': constraints,
    });
    return DailyRoutine.fromJson(data);
  }

  Future<Map<String, dynamic>> completeActivity(
      String userId, String activityId) async {
    return _callTool('complete_activity', {
      'user_id': userId,
      'activity_id': activityId,
    });
  }

  Future<DailyRoutine> adjustRoutine(
      String userId, String reason, int availableMinutes) async {
    final data = await _callTool('adjust_routine', {
      'user_id': userId,
      'reason': reason,
      'available_minutes': availableMinutes,
    });
    return DailyRoutine.fromJson(data);
  }

  Future<ConsistencyReport> getReport(String userId, {int days = 7}) async {
    final data = await _callTool('get_consistency_report', {
      'user_id': userId,
      'days': days,
    });
    return ConsistencyReport.fromJson(data);
  }

  Future<Map<String, dynamic>> updateGoals(
      String userId, List<String> goals, String fitnessLevel) async {
    return _callTool('update_user_goals', {
      'user_id': userId,
      'goals': goals,
      'fitness_level': fitnessLevel,
    });
  }

  // ── Agent Chat ──────────────────────────────────────────────────────────────

  /// Send a message to the multi-agent system.
  /// Returns the full response map from the bridge:
  ///   { reply, tool_calls, agent, error }
  Future<Map<String, dynamic>> chatWithAgent({
    required String userId,
    required String message,
    required List<Map<String, String>> history,
  }) async {
    await ensureConnected();
    try {
      final res = await _dio.post(
        '$_activeBase/agent',
        data: {
          'user_id': userId,
          'message': message,
          'history': history,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        _connected = false;
        await ensureConnected();
        final res = await _dio.post(
          '$_activeBase/agent',
          data: {'user_id': userId, 'message': message, 'history': history},
        );
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }

  /// Check if the bridge is reachable right now.
  Future<bool> isHealthy() async {
    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      )).get('$_activeBase/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ask the MCP agent to analyse pending activities and return a nudge message.
  /// Returns: { pending_activity_names, agent_nudge, activities_total, activities_completed }
  Future<Map<String, dynamic>> getPendingActivities(String userId) async {
    await ensureConnected();
    try {
      final res = await _dio.post(
        '$_activeBase/notify/check',
        data: {'user_id': userId},
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        _connected = false;
        await ensureConnected();
        final res = await _dio.post(
          '$_activeBase/notify/check',
          data: {'user_id': userId},
        );
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }
}
