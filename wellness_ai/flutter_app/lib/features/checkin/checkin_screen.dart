import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/wellness_models.dart';
import '../agent/wellness_agent.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  double _sleep = 7;
  int _stress = 5;
  int _energy = 5;
  String _mood = 'neutral';
  final _notesCtrl = TextEditingController();

  final _moods = [
    ('great', '😄'),
    ('good', '🙂'),
    ('neutral', '😐'),
    ('low', '😔'),
    ('bad', '😞'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checkinState = ref.watch(checkinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Check-in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('How did you sleep?'),
            Row(
              children: [
                Text('${_sleep.toStringAsFixed(1)}h',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.primary)),
                Expanded(
                  child: Slider(
                    value: _sleep,
                    min: 2,
                    max: 12,
                    divisions: 20,
                    onChanged: (v) => setState(() => _sleep = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _sectionTitle('Stress level'),
            _ScaleSelector(
              value: _stress,
              onChanged: (v) => setState(() => _stress = v),
              lowLabel: 'Calm',
              highLabel: 'Very stressed',
              color: _stressColor(cs),
            ),
            const SizedBox(height: 20),

            _sectionTitle('Energy level'),
            _ScaleSelector(
              value: _energy,
              onChanged: (v) => setState(() => _energy = v),
              lowLabel: 'Drained',
              highLabel: 'Energized',
              color: cs.secondary,
            ),
            const SizedBox(height: 20),

            _sectionTitle('How are you feeling?'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _moods.map((m) {
                final selected = _mood == m.$1;
                return GestureDetector(
                  onTap: () => setState(() => _mood = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? cs.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected ? cs.primary : Colors.transparent, width: 2),
                    ),
                    child: Text(m.$2, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _sectionTitle('Any notes? (optional)'),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'How are you feeling today?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 32),

            checkinState.when(
              data: (done) => done
                  ? _SuccessBanner(onViewRoutine: () => context.go('/routine'))
                  : _SubmitButton(onSubmit: _submit),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Column(
                children: [
                  Text('Error: $e', style: TextStyle(color: cs.error)),
                  const SizedBox(height: 8),
                  _SubmitButton(onSubmit: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );

  Color _stressColor(ColorScheme cs) {
    if (_stress <= 3) return cs.secondary;
    if (_stress <= 6) return Colors.orange;
    return cs.error;
  }

  void _submit() {
    final checkin = DailyCheckin(
      date: DateTime.now().toIso8601String().substring(0, 10),
      sleepHours: _sleep,
      stressLevel: _stress,
      energyLevel: _energy,
      mood: _mood,
      notes: _notesCtrl.text,
    );
    ref.read(checkinProvider.notifier).submit(checkin);
  }
}

class _ScaleSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String lowLabel;
  final String highLabel;
  final Color color;

  const _ScaleSelector({
    required this.value,
    required this.onChanged,
    required this.lowLabel,
    required this.highLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(10, (i) {
            final v = i + 1;
            final selected = v == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 36,
                  decoration: BoxDecoration(
                    color: v <= value ? color.withOpacity(0.2 + (v / 10) * 0.6) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: selected ? color : Colors.transparent, width: 2),
                  ),
                  child: Center(
                    child: Text('$v',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                            color: v <= value ? color : Colors.grey)),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(highLabel, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onSubmit;
  const _SubmitButton({required this.onSubmit});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onSubmit,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate My Routine'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}

class _SuccessBanner extends StatelessWidget {
  final VoidCallback onViewRoutine;
  const _SuccessBanner({required this.onViewRoutine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('Check-in complete!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.secondary)),
          const SizedBox(height: 4),
          Text('Your routine has been adapted for today.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onViewRoutine,
            icon: const Icon(Icons.self_improvement),
            label: const Text('View My Routine'),
          ),
        ],
      ),
    );
  }
}
