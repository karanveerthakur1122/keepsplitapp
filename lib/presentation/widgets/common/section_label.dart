import 'package:flutter/material.dart';

/// A compact all-caps label used for sheet/grid section headings like
/// "PAID BY", "ITEMS", "BALANCES", "SETTLEMENT". Kept in one place so
/// styling (letter-spacing, weight, color) stays consistent across
/// expense sheets and summaries.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.weight = FontWeight.w700,
    this.letterSpacing = 0.7,
  });

  final String text;
  final FontWeight weight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: weight,
            letterSpacing: letterSpacing,
          ),
    );
  }
}
