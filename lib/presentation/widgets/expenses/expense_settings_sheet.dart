import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_toast.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../providers/collaborators_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/expense_settings_provider.dart';
import '../common/sheet_drag_handle.dart';

class ExpenseSettingsSheet extends ConsumerStatefulWidget {
  const ExpenseSettingsSheet({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<ExpenseSettingsSheet> createState() =>
      _ExpenseSettingsSheetState();
}

class _ExpenseSettingsSheetState extends ConsumerState<ExpenseSettingsSheet> {
  final _addUserCtrl = TextEditingController();
  bool _showHistory = false;

  @override
  void dispose() {
    _addUserCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(noteExpenseSettingsProvider(widget.noteId));
    final manualUsersAsync =
        ref.watch(noteManualUsersProvider(widget.noteId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SheetDragHandle(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Expense Settings',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ── Currency ─────────────────────────────────
                    _SectionHeader(
                        icon: Icons.currency_exchange_rounded,
                        label: 'CURRENCY'),
                    const SizedBox(height: 8),
                    _buildCurrencyPicker(scheme, isDark, settingsAsync),

                    const SizedBox(height: 28),

                    // ── Manual Users ────────────────────────────
                    _SectionHeader(
                        icon: Icons.group_add_rounded,
                        label: 'SPLIT USERS'),
                    const SizedBox(height: 4),
                    Text(
                      'Add people for splitting who are not collaborators.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildAddUserField(scheme, isDark),
                    const SizedBox(height: 10),
                    _buildManualUsersList(
                        scheme, isDark, manualUsersAsync),

                    const SizedBox(height: 28),

                    // ── History Timeline ─────────────────────────
                    _SectionHeader(
                        icon: Icons.timeline_rounded,
                        label: 'HISTORY'),
                    const SizedBox(height: 10),
                    if (!_showHistory)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _showHistory = true),
                          icon: const Icon(Icons.expand_more_rounded,
                              size: 18),
                          label: const Text('Show history'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else
                      _buildTimeline(scheme, isDark,
                          ref.watch(noteExpenseAuditsProvider(widget.noteId))),

                    const SizedBox(height: 28),

                    // ── Export ───────────────────────────────────
                    _SectionHeader(
                        icon: Icons.ios_share_rounded,
                        label: 'EXPORT'),
                    const SizedBox(height: 10),
                    _buildExportSection(scheme, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Currency ────────────────────────────────────────────────────

  Widget _buildCurrencyPicker(
    ColorScheme scheme,
    bool isDark,
    AsyncValue<ExpenseSettings> settingsAsync,
  ) {
    final current = settingsAsync.valueOrNull?.currency ?? 'INR';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: currencies.map((c) {
        final selected = c.code == current;
        return ChoiceChip(
          label: Text('${c.symbol}  ${c.code}'),
          selected: selected,
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
          onSelected: (_) {
            Haptics.select();
            updateNoteCurrency(
              ref,
              noteId: widget.noteId,
              currency: c.code,
            );
          },
        );
      }).toList(),
    );
  }

  // ── Manual Users ────────────────────────────────────────────────

  Widget _buildAddUserField(ColorScheme scheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _addUserCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter name',
              hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _addUser(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: _addUser,
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Add'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: Size.zero,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  void _addUser() {
    final name = _addUserCtrl.text.trim();
    if (name.isEmpty) return;
    Haptics.tap();
    _addUserCtrl.clear();
    addManualUser(ref, noteId: widget.noteId, displayName: name);
  }

  Widget _buildManualUsersList(
    ColorScheme scheme,
    bool isDark,
    AsyncValue<List<ManualUser>> usersAsync,
  ) {
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No manual users added yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
            ),
          );
        }
        return Column(
          children: users.map((u) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          scheme.tertiary.withValues(alpha: 0.15),
                      child: Text(
                        u.displayName.isNotEmpty
                            ? u.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        u.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: scheme.error),
                      onPressed: () {
                        Haptics.warn();
                        removeManualUser(ref,
                            noteId: widget.noteId, manualUserId: u.id);
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const Text('Failed to load users'),
    );
  }

  // ── History Timeline ────────────────────────────────────────────

  Widget _buildTimeline(
    ColorScheme scheme,
    bool isDark,
    AsyncValue<List<AuditEntry>> auditsAsync,
  ) {
    return auditsAsync.when(
      data: (audits) {
        if (audits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No activity yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
            ),
          );
        }

        final usersAsync =
            ref.watch(accessibleUsersProvider(widget.noteId));
        final userMap = <String, String>{};
        usersAsync.whenData((users) {
          for (final u in users) {
            userMap[u.userId] = u.displayName;
          }
        });

        return Column(
          children: audits.take(50).map((a) {
            final who = userMap[a.userId] ?? a.userId.take(8);
            final what = _describeAudit(a);
            final when = DateFormat('MMM d, h:mm a').format(a.createdAt.toLocal());
            final isAdd = a.action == 'ADD';

            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAdd
                              ? Colors.green.withValues(alpha: 0.7)
                              : Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 36,
                        color:
                            scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            what,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by $who · $when',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const Text('Failed to load history'),
    );
  }

  String _describeAudit(AuditEntry a) {
    final entity = a.entityType == 'EXPENSE' ? 'expense' : 'item';
    final verb = a.action == 'ADD' ? 'Added' : 'Deleted';
    final details = a.details;
    if (details != null) {
      final name = details['name'] as String?;
      final price = details['price'];
      if (name != null && name.isNotEmpty) {
        final priceStr = price != null ? ' (${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price})' : '';
        return '$verb $entity: $name$priceStr';
      }
    }
    return '$verb $entity';
  }

  // ── Export ──────────────────────────────────────────────────────

  Widget _buildExportSection(ColorScheme scheme, bool isDark) {
    return Column(
      children: [
        _ExportTile(
          icon: Icons.copy_rounded,
          label: 'Copy as Text',
          onTap: () => _exportAsText(scheme),
        ),
        const SizedBox(height: 8),
        _ExportTile(
          icon: Icons.table_chart_outlined,
          label: 'Copy as CSV',
          onTap: () => _exportAsCsv(scheme),
        ),
      ],
    );
  }

  Future<void> _exportAsText(ColorScheme scheme) async {
    final expenses =
        await ref.read(noteExpensesProvider(widget.noteId).future);
    final settingsVal =
        await ref.read(noteExpenseSettingsProvider(widget.noteId).future);
    final sym = currencySymbol(settingsVal.currency);

    final users =
        await ref.read(accessibleUsersProvider(widget.noteId).future);
    final nameMap = <String, String>{};
    for (final u in users) {
      nameMap[u.userId] = u.displayName;
    }

    final buf = StringBuffer('=== Expense Summary ===\n\n');
    var grandTotal = 0.0;

    for (final e in expenses) {
      final payer = nameMap[e.payerId] ?? e.payerId.take(8);
      final total =
          e.items.fold<double>(0, (sum, item) => sum + item.price);
      grandTotal += total;
      buf.writeln('Paid by $payer — $sym${total.toStringAsFixed(2)}');
      for (final item in e.items) {
        buf.writeln(
            '  • ${item.name.isEmpty ? "Item" : item.name}: $sym${item.price.toStringAsFixed(2)}');
      }
      buf.writeln();
    }
    buf.writeln('Total: $sym${grandTotal.toStringAsFixed(2)}');

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    Haptics.confirm();
    AppToast.success('Expense summary copied to clipboard');
  }

  Future<void> _exportAsCsv(ColorScheme scheme) async {
    final expenses =
        await ref.read(noteExpensesProvider(widget.noteId).future);
    final users =
        await ref.read(accessibleUsersProvider(widget.noteId).future);
    final nameMap = <String, String>{};
    for (final u in users) {
      nameMap[u.userId] = u.displayName;
    }

    final buf = StringBuffer('Payer,Item,Price,Participants\n');
    for (final e in expenses) {
      final payer = nameMap[e.payerId] ?? e.payerId.take(8);
      for (final item in e.items) {
        final participants = item.participants
            .map((p) => nameMap[p.userId] ?? p.userId.take(8))
            .join('; ');
        final name = item.name.isEmpty ? 'Item' : item.name;
        buf.writeln(
            '"$payer","$name",${item.price.toStringAsFixed(2)},"$participants"');
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    Haptics.confirm();
    AppToast.success('CSV copied to clipboard');
  }
}

// ── Shared small widgets ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: scheme.onSurface,
              ),
        ),
      ],
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
