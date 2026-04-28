import 'package:dio/dio.dart';
import '../models/wellness_models.dart';

/// Tries localhost first (ADB reverse), then falls back to LAN IP.
/// Run once in terminal: adb reverse tcp:8765 tcp:8765
class WellnessMcpService {
  late final Dio _dio;

  // Candidates in priority order
  static const _hosts = [
    'http://localhost:8765',
    'http://127.0.0.1:8765',
    'http://10.0.2.2:8765',       // emulator
    'http://10.137.21.130:8765',  // PC LAN (Ethernet 3)
    'http://10.21.102.136:8765',  // PC LAN (Wi-Fi)
  ];

  String _activeBase = _hosts[0];

  WellnessMcpService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// Probe each host until one responds, cache it for the session.
  Future<void> ensureConnected() async {
    for (final host in _hosts) {
      try {
        final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)))
            .get('$host/health');
        if (res.statusCode == 200) {
          _activeBase = host;
          return;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception(
        'Cannot reach MCP bridge. Make sure http_bridge.py is running on your PC '
        'and run: adb reverse tcp:8765 tcp:8765');
  }

  Future<Map<String, dynamic>> _callTool(
      String tool, Map<String, dynamic> args) async {
    try {
      final res = await _dio.post(
        '$_activeBase/tool',
        data: {'tool': tool, 'arguments': args},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // If connection refused, try re-discovering the host
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await ensureConnected();
        final res = await _dio.post(
          '$_activeBase/tool',
          data: {'tool': tool, 'arguments': args},
        );
        return res.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

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

  /// Send a message to the Groq LLM agent with conversation history.
  /// Returns { "reply": str, "tool_calls": [...], "error": str|null }
  Future<Map<String, dynamic>> chatWithAgent({
    required String userId,
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final res = await _dio.post(
        '$_activeBase/agent',
        data: {
          'user_id': userId,
          'message': message,
          'history': history,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await ensureConnected();
        final res = await _dio.post(
          '$_activeBase/agent',
          data: {'user_id': userId, 'message': message, 'history': history},
        );
        return res.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }
}
