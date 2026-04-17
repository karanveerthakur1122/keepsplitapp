import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Tracks which list-item indices have already played their entrance animation
/// in this session. Lets us avoid replaying the staggered fade/slide every
/// time the user switches dashboard sections or scrolls a card off-screen
/// and back on. Only the first `_animateUpTo` items ever animate.
final Set<int> _animatedIndices = <int>{};
const int _animateUpTo = 8;

/// Clear the animation memo — call when the signed-in user changes so the
/// new user's first cards get their entrance animation too.
void resetAnimatedListItemMemo() {
  _animatedIndices.clear();
}

class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 30),
  });

  final int index;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    // Only animate the first N items, once per session. Everything else
    // renders instantly — section switches and scroll-back don't replay.
    if (index >= _animateUpTo || _animatedIndices.contains(index)) {
      return child;
    }
    _animatedIndices.add(index);
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
