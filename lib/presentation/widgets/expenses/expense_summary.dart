import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../providers/expense_provider.dart';
import '../../providers/expense_settings_provider.dart';
import '../common/section_label.dart';

class ExpenseSummary extends ConsumerWidget {
  const ExpenseSummary({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(settlementProvider(noteId));
    final scheme = Theme.of(context).colorScheme;
    final settingsVal =
        ref.watch(noteExpenseSettingsProvider(noteId)).valueOrNull;
    final sym = currencySymbol(settingsVal?.currency ?? 'INR');

    return resultAsync.when(
      data: (result) {
        if (result.balances.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== BALANCES ==========
            const SectionLabel('BALANCES',
                weight: FontWeight.w800, letterSpacing: 0.8),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.balances.map((b) {
                final isPositive = b.balance > 0;
                return _balancePill(
                  context,
                  name: b.displayName,
                  amount: b.balance,
                  isPositive: isPositive,
                  symbol: sym,
                );
              }).toList(),
            ),

            // ========== SETTLEMENT ==========
            if (result.settlements.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionLabel('SETTLEMENT',
                  weight: FontWeight.w800, letterSpacing: 0.8),
              const SizedBox(height: 10),
              ...result.settlements.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _settlementRow(
                      context,
                      scheme,
                      from: s.from,
                      to: s.to,
                      amount: s.amount,
                      symbol: sym,
                    ),
                  )),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Couldn\'t compute settlements. Pull to refresh.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
        ),
      ),
    );
  }

  Widget _balancePill(
    BuildContext context, {
    required String name,
    required double amount,
    required bool isPositive,
    required String symbol,
  }) {
    final fg = isPositive ? Colors.green.shade300 : Colors.red.shade300;
    final bg =
        (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.14);
    final border =
        (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${isPositive ? '+' : '-'}${amount.abs().toCurrency(symbol: symbol)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementRow(
    BuildContext context,
    ColorScheme scheme, {
    required String from,
    required String to,
    required double amount,
    required String symbol,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    from,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                Flexible(
                  child: Text(
                    to,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              amount.toCurrency(symbol: symbol),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
