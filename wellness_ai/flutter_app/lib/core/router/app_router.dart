import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/checkin/checkin_screen.dart';
import '../../features/routine/routine_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/agent_chat/agent_chat_screen.dart';
import '../../data/local/hive_adapters.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final onboarded = LocalStorage.isOnboarded();
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (onboarded && onOnboarding) return '/home';
      if (!onboarded && !onOnboarding) return '/onboarding';

      // Handle notification tap — navigate to pending route if set
      if (onboarded && !onOnboarding) {
        final pending = LocalStorage.getPendingRoute();
        if (pending != null && pending != state.matchedLocation) {
          LocalStorage.clearPendingRoute();
          return pending;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/checkin', builder: (_, __) => const CheckinScreen()),
          GoRoute(path: '/routine', builder: (_, __) => const RoutineScreen()),
          GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/agent', builder: (_, __) => const AgentChatScreen()),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = ['/home', '/checkin', '/routine', '/progress', '/agent']
        .indexOf(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx < 0 ? 0 : idx,
        onDestinationSelected: (i) {
          const routes = ['/home', '/checkin', '/routine', '/progress', '/agent'];
          context.go(routes[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Check-in'),
          NavigationDestination(icon: Icon(Icons.self_improvement_outlined), selectedIcon: Icon(Icons.self_improvement), label: 'Routine'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'AI Agent'),
        ],
      ),
    );
  }
}
