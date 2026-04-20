import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/entities/expense.dart';
import '../../providers/collaborators_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/expense_settings_provider.dart';
import 'expense_detail_sheet.dart';

class ExpenseBlock extends ConsumerWidget {
  const ExpenseBlock({
    super.key,
    required this.expense,
    required this.noteId,
  });

  final Expense expense;
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsVal =
        ref.watch(noteExpenseSettingsProvider(noteId)).valueOrNull;
    final sym = currencySymbol(settingsVal?.currency ?? 'INR');

    final totalPrice =
        expense.items.fold<double>(0, (sum, item) => sum + item.price);

    // Title: first 2-3 item names joined with commas.
    final names = expense.items
        .map((i) => i.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final title = names.isEmpty
        ? 'No items'
        : (names.length > 3
            ? '${names.take(3).join(', ')}, …'
            : names.join(', '));

    // Payer display name via the shared collaborators list.
    final usersAsync = ref.watch(accessibleUsersProvider(noteId));
    final payerName = usersAsync.maybeWhen(
      data: (users) => resolveDisplayName(users, expense.payerId),
      orElse: () => '...',
    );

    final itemCount = expense.items.length;
    final dateStr = expense.createdAt.formatShort('MMM d, y');

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: scheme.error, size: 22),
      ),
      confirmDismiss: (_) async {
        Haptics.confirm();
        final confirmed = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete expense?'),
            content: Text(
              title == 'No items'
                  ? 'This empty expense will be removed.'
                  : 'This will remove "$title" and all its items. '
                      'This cannot be undone.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          Haptics.warn();
          await ref
              .read(noteExpensesProvider(noteId).notifier)
              .deleteExpense(expense.id);
          return true;
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Haptics.select();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                useRootNavigator: true,
                builder: (_) => ExpenseDetailSheet(
                  expense: expense,
                  noteId: noteId,
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 0.7,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leadingIcon(scheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.1,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              totalPrice.toCurrency(symbol: sym),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Paid by ',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: payerName,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' · $itemCount item${itemCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(ColorScheme scheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.tertiary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
          width: 0.7,
        ),
      ),
      child: Icon(Icons.receipt_long_rounded,
          color: scheme.primary, size: 20),
    );
  }
}
