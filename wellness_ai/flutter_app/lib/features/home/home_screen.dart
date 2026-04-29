import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../agent/wellness_agent.dart';
import '../../data/models/wellness_models.dart';

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
          // ── App Bar ──────────────────────────────────────────────────────
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
                        Text(_greeting(),
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
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

                // ── UNIQUE: Wellness Score + Streak row ───────────────────
                profileAsync.when(
                  data: (p) => p != null
                      ? Row(
                          children: [
                            Expanded(child: _WellnessScoreGauge(score: p.wellnessScore)),
                            const SizedBox(width: 12),
                            Expanded(child: _StreakCard(streak: p.streakDays)),
                          ],
                        )
                      : const SizedBox(),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 16),

                // ── UNIQUE: Burnout Alert ─────────────────────────────────
                profileAsync.when(
                  data: (p) {
                    final risk = p?.burnoutRisk;
                    if (risk == null || risk.risk == 'low' || risk.risk == 'unknown') {
                      return const SizedBox();
                    }
                    return _BurnoutAlert(risk: risk);
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // ── UNIQUE: Contextual Nudge ──────────────────────────────
                profileAsync.when(
                  data: (p) => p?.nudge != null
                      ? _NudgeCard(nudge: p!.nudge!)
                      : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 4),

                // ── Today's Routine ───────────────────────────────────────
                routineAsync.when(
                  data: (r) => r != null
                      ? _RoutineSummaryCard(routine: r)
                      : _NoRoutineCard(onGenerate: () => context.go('/checkin')),
                  loading: () => const _LoadingCard(),
                  error: (_, __) => _NoRoutineCard(onGenerate: () => context.go('/checkin')),
                ),
                const SizedBox(height: 16),

                // ── Quick Actions ─────────────────────────────────────────
                const _QuickActions(),
                const SizedBox(height: 16),

                // ── AI Agent prompt ───────────────────────────────────────
                const _AgentPromptCard(),
                const SizedBox(height: 8),
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

// ── UNIQUE WIDGET 1: Wellness Score Arc Gauge ─────────────────────────────────

class _WellnessScoreGauge extends StatefulWidget {
  final WellnessScore? score;
  const _WellnessScoreGauge({this.score});

  @override
  State<_WellnessScoreGauge> createState() => _WellnessScoreGaugeState();
}

class _WellnessScoreGaugeState extends State<_WellnessScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: (widget.score?.score ?? 0) / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = widget.score;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Wellness Score',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    progress: _anim.value,
                    trackColor: cs.surfaceContainerHighest,
                    fillColor: _scoreColor(_anim.value),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${((score?.score ?? 0) * _anim.value).round()}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _scoreColor(_anim.value)),
                        ),
                        Text('/100',
                            style: TextStyle(
                                fontSize: 10, color: cs.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(score?.grade ?? 'No data',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double progress) {
    if (progress >= 0.85) return Colors.green;
    if (progress >= 0.70) return const Color(0xFF6C63FF);
    if (progress >= 0.50) return Colors.orange;
    return Colors.red;
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  _ArcGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, trackPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle * progress, false, fillPaint);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) => old.progress != progress;
}

// ── UNIQUE WIDGET 2: Burnout Alert Banner ─────────────────────────────────────

class _BurnoutAlert extends StatelessWidget {
  final BurnoutRisk risk;
  const _BurnoutAlert({required this.risk});

  @override
  Widget build(BuildContext context) {
    final isHigh = risk.risk == 'high';
    final color = isHigh ? Colors.red.shade700 : Colors.orange.shade700;
    final bgColor = isHigh ? Colors.red.shade50 : Colors.orange.shade50;
    final icon = isHigh ? Icons.warning_rounded : Icons.info_outline_rounded;
    final title = isHigh ? '⚠️ Burnout Risk Detected' : '⚡ Early Burnout Signals';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(risk.reason,
                      style: TextStyle(
                          color: color.withOpacity(0.85), fontSize: 12, height: 1.4)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => GoRouter.of(context).go('/agent'),
                    child: Text('Talk to your AI agent →',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── UNIQUE WIDGET 3: Contextual Nudge Card ────────────────────────────────────

class _NudgeCard extends ConsumerWidget {
  final WellnessNudge nudge;
  const _NudgeCard({required this.nudge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    void onTap() {
      switch (nudge.action) {
        case 'checkin':
          context.go('/checkin');
        case 'routine':
          context.go('/routine');
        case 'agent':
          context.go('/agent');
        default:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: nudge.action != null ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer,
                cs.secondaryContainer,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tips_and_updates_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nudge.message,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.4),
                ),
              ),
              if (nudge.action != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: cs.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Standard Cards ────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text('$streak',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: cs.primary)),
            Text('day streak',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 4),
            Text('Keep it going!',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
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
                const Text("Today's Routine",
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
            const Text('No routine yet today',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
  const _QuickActions();

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
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
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
  const _AgentPromptCard();

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
                    const Text('Ask your AI agent',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('"I\'m feeling tired today, adjust my routine"',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: cs.onSurface.withOpacity(0.4)),
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
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}
