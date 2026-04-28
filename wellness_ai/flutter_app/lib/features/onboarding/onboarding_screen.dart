import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/hive_adapters.dart';
import '../../data/services/wellness_mcp_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  String _fitnessLevel = 'beginner';
  final Set<String> _selectedGoals = {};
  bool _loading = false;

  final _goals = [
    ('better_sleep', '😴', 'Better Sleep'),
    ('reduce_stress', '🧘', 'Reduce Stress'),
    ('exercise_daily', '💪', 'Daily Exercise'),
    ('mindfulness', '🌿', 'Mindfulness'),
    ('hydration', '💧', 'Hydration'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [_welcomePage(cs), _goalsPage(cs), _fitnessPage(cs)],
              ),
            ),
            _buildDots(cs),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _loading ? null : _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_page == 2 ? 'Get Started' : 'Continue',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(ColorScheme cs) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌱', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            Text('Wellness AI',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: cs.primary)),
            const SizedBox(height: 16),
            Text(
              'Your adaptive wellness companion that learns your schedule, stress, and sleep to build routines that actually work.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.7), height: 1.6),
            ),
          ],
        ),
      );

  Widget _goalsPage(ColorScheme cs) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('What are your goals?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Select all that apply',
                style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: _goals.map((g) {
                  final selected = _selectedGoals.contains(g.$1);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedGoals.remove(g.$1) : _selectedGoals.add(g.$1);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(g.$2, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(g.$3,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected ? cs.primary : cs.onSurface)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );

  Widget _fitnessPage(ColorScheme cs) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('Your fitness level?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 24),
            ...['beginner', 'intermediate', 'advanced'].map((level) {
              final icons = {'beginner': '🌱', 'intermediate': '🔥', 'advanced': '⚡'};
              final desc = {
                'beginner': 'Just starting out',
                'intermediate': 'Exercising regularly',
                'advanced': 'High performance'
              };
              final selected = _fitnessLevel == level;
              return GestureDetector(
                onTap: () => setState(() => _fitnessLevel = level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected ? cs.primary : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(icons[level]!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(level[0].toUpperCase() + level.substring(1),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? cs.primary : cs.onSurface)),
                          Text(desc[level]!,
                              style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );

  Widget _buildDots(ColorScheme cs) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _page == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _page == i ? cs.primary : cs.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            )),
      );

  Future<void> _next() async {
    if (_page < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }
    // Final step: save and go
    setState(() => _loading = true);
    final userId = const Uuid().v4().substring(0, 8);
    await LocalStorage.setUserId(userId);
    await LocalStorage.setOnboarded();
    try {
      await WellnessMcpService().updateGoals(
          userId, _selectedGoals.toList(), _fitnessLevel);
    } catch (_) {}
    if (mounted) context.go('/home');
  }
}
