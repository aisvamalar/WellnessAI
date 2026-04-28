import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agent/wellness_agent.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineAsync = ref.watch(routineProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Routine"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Adjust routine',
            onSelected: (reason) =>
                ref.read(routineProvider.notifier).adjust(reason),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'too_tired', child: Text('😴 I\'m too tired')),
              const PopupMenuItem(value: 'short_on_time', child: Text('⏱️ Short on time')),
              const PopupMenuItem(value: 'feeling_great', child: Text('⚡ Feeling great!')),
              const PopupMenuItem(value: 'stressed', child: Text('😰 I\'m stressed')),
            ],
          ),
        ],
      ),
      body: routineAsync.when(
        data: (routine) => routine == null
            ? _EmptyRoutine(onGenerate: () =>
                ref.read(routineProvider.notifier).generate())
            : _RoutineBody(routine: routine, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Could not load routine', style: TextStyle(color: cs.error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(routineProvider.notifier).generate(),
                child: const Text('Generate Routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineBody extends StatelessWidget {
  final dynamic routine;
  final WidgetRef ref;
  const _RoutineBody({required this.routine, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = routine.completedCount;
    final total = routine.activities.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Adaptive message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(routine.message,
                            style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$completed / $total completed',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${routine.totalDurationMinutes} min total',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 10,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final act = routine.activities[i];
                return _ActivityCard(
                  activity: act,
                  onComplete: () => ref
                      .read(routineProvider.notifier)
                      .completeActivity(act.routineActivityId),
                );
              },
              childCount: routine.activities.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final dynamic activity;
  final VoidCallback onComplete;
  const _ActivityCard({required this.activity, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goalIcons = {
      'better_sleep': '😴',
      'reduce_stress': '🧘',
      'exercise_daily': '💪',
      'mindfulness': '🌿',
      'hydration': '💧',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: activity.completed
                ? cs.secondaryContainer
                : cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              goalIcons[activity.goal] ?? '✨',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(
          activity.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: activity.completed ? TextDecoration.lineThrough : null,
            color: activity.completed ? cs.onSurface.withOpacity(0.5) : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activity.description,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 12, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  activity.duration > 0 ? '${activity.duration} min' : 'All day',
                  style: TextStyle(fontSize: 11, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule_outlined, size: 12, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  activity.timeOfDay,
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
        trailing: activity.completed
            ? Icon(Icons.check_circle, color: cs.secondary)
            : IconButton(
                icon: Icon(Icons.radio_button_unchecked, color: cs.primary),
                onPressed: onComplete,
              ),
      ),
    );
  }
}

class _EmptyRoutine extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyRoutine({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('No routine yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Complete your daily check-in first, or generate a routine now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Routine'),
            ),
          ],
        ),
      ),
    );
  }
}
