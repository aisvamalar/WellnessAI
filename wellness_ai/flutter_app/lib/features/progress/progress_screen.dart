import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../agent/wellness_agent.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reportAsync = ref.watch(reportProvider(_days));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 14, label: Text('14d')),
              ButtonSegment(value: 30, label: Text('30d')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: reportAsync.when(
        data: (report) => _ReportBody(report: report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔌', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Could not load report', style: TextStyle(color: cs.error)),
              const SizedBox(height: 8),
              const Text('Make sure the MCP bridge is running',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final dynamic report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trendIcon = {
      'improving': ('📈', 'Improving', Colors.green),
      'stable': ('➡️', 'Stable', Colors.orange),
      'needs_attention': ('📉', 'Needs attention', Colors.red),
      'not_enough_data': ('📊', 'Not enough data', Colors.grey),
    }[report.trend] ?? ('📊', report.trend, Colors.grey);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Streak + trend row
          Row(
            children: [
              Expanded(child: _StatCard('🔥', '${report.currentStreakDays}', 'Day Streak', cs.primary)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(trendIcon.$1, trendIcon.$2, 'Trend', trendIcon.$3)),
            ],
          ),
          const SizedBox(height: 12),

          // Completion rate
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activity Completion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: report.completionRate / 100,
                              strokeWidth: 8,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: cs.primary,
                            ),
                            Text('${report.completionRate.toInt()}%',
                                style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${report.activitiesCompleted} completed',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('of ${report.activitiesTotal} total activities',
                              style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                          const SizedBox(height: 4),
                          Text('${report.checkinDays} check-in days',
                              style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Averages bar chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Averages', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  _AverageBar('😴 Sleep', report.averages['sleep_hours'] ?? 0, 12, cs.primary),
                  const SizedBox(height: 12),
                  _AverageBar('⚡ Energy', (report.averages['energy'] ?? 0) * 1.2, 12, cs.secondary),
                  const SizedBox(height: 12),
                  _AverageBar('😰 Stress', (report.averages['stress'] ?? 0) * 1.2, 12, Colors.orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;
  const _StatCard(this.emoji, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _AverageBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  const _AverageBar(this.label, this.value, this.max, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text(value.toStringAsFixed(1),
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
        ],
      );
}
