import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../agent/wellness_agent.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final routineAsync = ref.watch(routineProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        profileAsync.when(
                          data: (p) => Text(
                            p != null ? 'Welcome back 👋' : 'Welcome to Wellness AI',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          loading: () => const Text('Loading...',
                              style: TextStyle(color: Colors.white70)),
                          error: (_, __) => const Text('Wellness AI',
                              style: TextStyle(color: Colors.white, fontSize: 22)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Streak card
                profileAsync.when(
                  data: (p) => p != null ? _StreakCard(streak: p.streakDays) : const SizedBox(),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 16),

                // Today's routine summary
                routineAsync.when(
                  data: (r) => r != null
                      ? _RoutineSummaryCard(routine: r)
                      : _NoRoutineCard(onGenerate: () => context.go('/checkin')),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => _NoRoutineCard(onGenerate: () => context.go('/checkin')),
                ),
                const SizedBox(height: 16),

                // Quick actions
                _QuickActions(),
                const SizedBox(height: 16),

                // AI Agent prompt
                _AgentPromptCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$streak day streak',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.primary)),
                Text('Keep it going!', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineSummaryCard extends StatelessWidget {
  final dynamic routine;
  const _RoutineSummaryCard({required this.routine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = routine.completedCount;
    final total = routine.activities.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's Routine",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: () => context.go('/routine'),
                    child: const Text('View all')),
              ],
            ),
            Text(routine.message,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text('$completed / $total activities completed',
                style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _NoRoutineCard extends StatelessWidget {
  final VoidCallback onGenerate;
  const _NoRoutineCard({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('No routine yet today', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Do your daily check-in to get a personalized routine',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Start Check-in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Check-in', Icons.check_circle_outline, '/checkin'),
      ('Routine', Icons.self_improvement, '/routine'),
      ('Progress', Icons.bar_chart, '/progress'),
      ('AI Agent', Icons.smart_toy_outlined, '/agent'),
    ];
    return Row(
      children: actions.map((a) {
        final cs = Theme.of(context).colorScheme;
        return Expanded(
          child: GestureDetector(
            onTap: () => context.go(a.$3),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(a.$2, color: cs.primary),
                    const SizedBox(height: 6),
                    Text(a.$1,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AgentPromptCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.go('/agent'),
      child: Card(
        color: cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.smart_toy, color: cs.secondary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask your AI agent',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('"I\'m feeling tired today, adjust my routine"',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
