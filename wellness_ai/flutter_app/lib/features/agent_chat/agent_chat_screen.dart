import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import '../agent/wellness_agent.dart';
import '../../data/models/wellness_models.dart';

class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _showSuggestions = true;

  final _suggestions = [
    ('🏃 Generate routine', 'Generate my daily routine'),
    ('😴 Tired today', "I'm feeling tired, adjust my routine"),
    ('📊 My progress', 'Show my progress this week'),
    ('😰 Stressed', "I'm stressed, what should I do?"),
    ('⏱️ Short on time', 'I only have 20 minutes today'),
    ('💪 Feeling great', "I'm feeling great, give me a challenge"),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messages = ref.watch(agentChatProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(cs),
      body: Column(
        children: [
          // ── Suggestion chips ─────────────────────────────────────────────
          if (_showSuggestions && messages.length <= 1)
            _SuggestionBar(
              suggestions: _suggestions,
              onTap: _send,
            ),

          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: messages.length,
              itemBuilder: (_, i) => _MessageBubble(
                msg: messages[i],
                onActionTap: (route) => context.go(route),
              ),
            ),
          ),

          // ── Input bar ────────────────────────────────────────────────────
          _InputBar(
            controller: _ctrl,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      elevation: 0,
      backgroundColor: cs.surface,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wellness Agent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Active · MCP powered',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.5))),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.lightbulb_outline, color: cs.primary),
          tooltip: 'Suggestions',
          onPressed: () => setState(() => _showSuggestions = !_showSuggestions),
        ),
      ],
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    setState(() => _showSuggestions = false);
    ref.read(agentChatProvider.notifier).send(text.trim());
    Future.delayed(const Duration(milliseconds: 400), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }
}

// ── Suggestion Bar ────────────────────────────────────────────────────────────

class _SuggestionBar extends StatelessWidget {
  final List<(String, String)> suggestions;
  final void Function(String) onTap;

  const _SuggestionBar({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(suggestions[i].$2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Text(
              suggestions[i].$1,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AgentMessage msg;
  final void Function(String route) onActionTap;

  const _MessageBubble({required this.msg, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Agent avatar
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: msg.isTyping
                      ? _TypingDots(color: cs.onSurface)
                      : isUser
                          ? Text(
                              msg.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5),
                            )
                          : MarkdownBody(
                              data: msg.text,
                              styleSheet: _mdStyle(cs),
                              shrinkWrap: true,
                            ),
                ),
              ),

              if (isUser) const SizedBox(width: 8),
            ],
          ),

          // ── Agentic Action Card ─────────────────────────────────────────
          if (msg.action != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _ActionCard(
                action: msg.action!,
                onTap: () => onActionTap(msg.action!.route),
              ),
            ),
          ],

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
                top: 4, left: isUser ? 0 : 40, right: isUser ? 8 : 0),
            child: Text(
              _formatTime(msg.time),
              style: TextStyle(
                  fontSize: 10, color: cs.onSurface.withOpacity(0.35)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  MarkdownStyleSheet _mdStyle(ColorScheme cs) => MarkdownStyleSheet(
        p: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.55),
        strong: TextStyle(
            color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
        em: TextStyle(
            color: cs.onSurface.withOpacity(0.7),
            fontSize: 13,
            fontStyle: FontStyle.italic),
        listBullet: TextStyle(color: cs.primary, fontSize: 14),
        h1: TextStyle(
            color: cs.onSurface, fontSize: 17, fontWeight: FontWeight.w800),
        h2: TextStyle(
            color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
        code: TextStyle(
            backgroundColor: cs.primary.withOpacity(0.1),
            color: cs.primary,
            fontSize: 13),
        blockquoteDecoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: cs.primary.withOpacity(0.4), width: 3)),
          color: cs.primaryContainer.withOpacity(0.3),
        ),
      );
}

// ── Agentic Action Card ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final AgentAction action;
  final VoidCallback onTap;

  const _ActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build a mini preview for routine actions
    final routine = action.data is DailyRoutine ? action.data as DailyRoutine : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer,
              cs.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(action.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _actionTitle(action.type),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.primary),
                        ),
                        Text(
                          action.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.65)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: cs.primary),
                ],
              ),
            ),

            // Routine mini-preview
            if (routine != null) ...[
              const Divider(height: 1, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: routine.activities
                      .take(3)
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text(_goalEmoji(a.goal),
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withOpacity(0.8)),
                                  ),
                                ),
                                Text(
                                  a.duration > 0 ? '${a.duration}m' : '—',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              if (routine.activities.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 14),
                  child: Text(
                    '+${routine.activities.length - 3} more · tap to view all',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.primary.withOpacity(0.7),
                        fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _actionTitle(String type) {
    switch (type) {
      case 'routine_generated':
        return 'ROUTINE GENERATED';
      case 'routine_adjusted':
        return 'ROUTINE ADJUSTED';
      case 'checkin_logged':
        return 'CHECK-IN LOGGED';
      case 'progress_fetched':
        return 'PROGRESS LOADED';
      case 'goals_updated':
        return 'GOALS UPDATED';
      default:
        return 'ACTION TAKEN';
    }
  }

  String _goalEmoji(String goal) {
    const map = {
      'better_sleep': '😴',
      'reduce_stress': '🧘',
      'exercise_daily': '💪',
      'mindfulness': '🌿',
      'hydration': '💧',
    };
    return map[goal] ?? '✨';
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Tell me what you need...',
                  hintStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.4), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onSubmitted: onSend,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dots ───────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final opacity = (offset < 0.5 ? offset : 1.0 - offset) * 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.3 + opacity * 0.7),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
