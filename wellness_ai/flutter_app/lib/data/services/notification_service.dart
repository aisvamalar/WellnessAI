import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../local/hive_adapters.dart';
import 'wellness_mcp_service.dart';

/// Manages local push notifications and periodic MCP-driven pending-task checks.
///
/// Strategy (no WorkManager needed):
///   - On app resume → immediate check
///   - While app is in foreground → check every 3 hours via Timer
///   - On notification tap → navigate to /routine via LocalStorage pending route
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _periodicTimer;

  // ── Android notification channel ─────────────────────────────────────────

  static const _channelId = 'wellness_reminders';
  static const _channelName = 'Wellness Reminders';
  static const _channelDesc =
      'Reminders to complete your pending wellness activities';

  static const _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
    playSound: true,
  );

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Call once in main() before runApp.
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create Android channel
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Periodic foreground check ─────────────────────────────────────────────

  /// Start a repeating 3-hour check while the app is in the foreground.
  /// Call this after onboarding completes.
  static void startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(hours: 3), (_) {
      checkAndNotify();
    });
  }

  /// Stop the periodic timer (e.g. when app goes to background or user logs out).
  static void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Cancel all pending notifications.
  static Future<void> cancelAll() async {
    stopPeriodicCheck();
    await _plugin.cancelAll();
  }

  // ── Check & notify ────────────────────────────────────────────────────────

  /// Ask the MCP bridge for pending activities and show a notification if any.
  /// Safe to call on every app resume — silently no-ops if nothing is pending
  /// or if the bridge is unreachable.
  static Future<void> checkAndNotify({int notifId = 100}) async {
    final userId = LocalStorage.getUserId();
    if (userId == null) return;

    try {
      final svc = WellnessMcpService();
      await svc.ensureConnected();

      final report = await svc.getPendingActivities(userId);
      final shouldNotify = report['should_notify'] as bool? ?? false;
      if (!shouldNotify) return;

      final pending =
          List<String>.from(report['pending_activity_names'] as List? ?? []);
      final nudge = report['agent_nudge'] as String?;

      if (pending.isEmpty) return;
      await _show(pending: pending, nudge: nudge, id: notifId);
    } catch (_) {
      // Best-effort — never crash the app over a notification
    }
  }

  // ── Show notification ─────────────────────────────────────────────────────

  static Future<void> _show({
    required List<String> pending,
    String? nudge,
    int id = 100,
  }) async {
    final count = pending.length;
    final title = count == 1
        ? '⏳ 1 activity still pending'
        : '⏳ $count activities still pending';
    final body = nudge ?? _buildBody(pending);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF6C63FF),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: pending.take(3).join(' · '),
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(id, title, body, details,
        payload: jsonEncode({'route': '/routine'}));
  }

  /// Show a custom agent-crafted notification immediately (called from chat).
  static Future<void> showAgentNotification({
    required String title,
    required String body,
    int id = 300,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF6C63FF),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details,
        payload: jsonEncode({'route': '/routine'}));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _buildBody(List<String> pending) {
    if (pending.length == 1) {
      return 'You still need to complete: ${pending[0]}. Tap to open your routine.';
    }
    final listed = pending.take(2).join(', ');
    final extra =
        pending.length > 2 ? ' and ${pending.length - 2} more' : '';
    return 'Still pending: $listed$extra. Your wellness agent is ready to help.';
  }

  static void _onTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map;
      final route = data['route'] as String? ?? '/routine';
      LocalStorage.setPendingRoute(route);
    } catch (_) {}
  }
}
