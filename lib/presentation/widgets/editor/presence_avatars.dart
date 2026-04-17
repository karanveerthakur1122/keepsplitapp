import 'package:flutter/material.dart';

import '../../../data/datasources/remote/supabase_realtime_datasource.dart';

class PresenceAvatars extends StatelessWidget {
  const PresenceAvatars({super.key, required this.users});

  final List<PresenceUser> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final typingUsers = users.where((u) => u.isTyping).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...users.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final user = entry.value;
                final color = _parseColor(user.color);
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : -6),
                  child: Tooltip(
                    message: user.displayName +
                        (user.isTyping ? ' (typing...)' : ''),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.2),
                        border: Border.all(
                          color: user.isTyping ? color : Colors.transparent,
                          width: user.isTyping ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _initials(user.displayName),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (users.length > 5)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '+${users.length - 5}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        ),
        if (typingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _TypingIndicator(names: typingUsers.map((u) {
              final parts = u.displayName.trim().split(RegExp(r'\s+'));
              return parts.first;
            }).toList()),
          ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    if (parts[1].isEmpty) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.names});
  final List<String> names;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dots;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _dots = Tween<double>(begin: 0, end: 3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = widget.names.length == 1
        ? widget.names.first
        : '${widget.names.length} people';

    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        final dotCount = _dots.value.floor() + 1;
        return Text(
          '$label typing${'.' * dotCount}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.primary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
        );
      },
    );
  }
}
