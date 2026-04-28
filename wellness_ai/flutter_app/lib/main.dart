import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/local/hive_adapters.dart';
import 'data/services/wellness_mcp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  registerHiveAdapters();
  await Hive.openBox('wellness_box');

  // Auto-discover MCP bridge host at startup
  try {
    await WellnessMcpService().ensureConnected();
  } catch (_) {
    // App still launches; screens show friendly error if bridge unreachable
  }

  runApp(const ProviderScope(child: WellnessApp()));
}

class WellnessApp extends ConsumerWidget {
  const WellnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
