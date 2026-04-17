import 'package:flutter/material.dart';

/// The small horizontal bar at the top of a modal bottom sheet that signals
/// "drag me". Centralized so every sheet in the app looks identical.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({
    super.key,
    this.topMargin = 10,
    this.bottomMargin = 6,
  });

  final double topMargin;
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
