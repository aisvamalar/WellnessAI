import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/local/hive_adapters.dart';
import 'data/services/wellness_mcp_service.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Local storage ──────────────────────────────────────────────────────
  await Hive.initFlutter();
  registerHiveAdapters();
  await Hive.openBox('wellness_box');

  // ── Notifications ──────────────────────────────────────────────────────
  await NotificationService.init();

  // ── MCP bridge discovery ───────────────────────────────────────────────
  try {
    await WellnessMcpService().ensureConnected();
  } catch (_) {
    // App still launches; screens show friendly error if bridge unreachable
  }

  runApp(const ProviderScope(child: WellnessApp()));
}

class WellnessApp extends ConsumerStatefulWidget {
  const WellnessApp({super.key});

  @override
  ConsumerState<WellnessApp> createState() => _WellnessAppState();
}

class _WellnessAppState extends ConsumerState<WellnessApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start periodic check if already onboarded
    if (LocalStorage.isOnboarded()) {
      NotificationService.startPeriodicCheck();
      // Also do an immediate check on cold start
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.checkAndNotify();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.stopPeriodicCheck();
    super.dispose();
  }

  /// Check for pending tasks every time the app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && LocalStorage.isOnboarded()) {
      NotificationService.checkAndNotify(notifId: 101);
    }
    if (state == AppLifecycleState.paused) {
      NotificationService.stopPeriodicCheck();
    }
    if (state == AppLifecycleState.resumed) {
      NotificationService.startPeriodicCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Wellness AI',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
