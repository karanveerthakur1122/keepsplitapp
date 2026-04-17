import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_item.dart';
import '../../providers/collaborators_provider.dart';
import '../../providers/expense_provider.dart';
import '../common/section_label.dart';
import '../common/sheet_drag_handle.dart';

typedef _User = ({String userId, String displayName});

class ExpenseDetailSheet extends ConsumerStatefulWidget {
  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    required this.noteId,
  });

  final Expense expense;
  final String noteId;

  @override
  ConsumerState<ExpenseDetailSheet> createState() =>
      _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<ExpenseDetailSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  // Key placed on the "Add item" form so we can scroll it into view
  // when the keyboard appears.
  final _addFormKey = GlobalKey();
  final _sheetController = DraggableScrollableController();

  /// User ids selected to split the NEW item being added.
  /// `null` = "not yet initialized" (will default to all collaborators
  /// once the list loads).
  Set<String>? _newItemSplit;

  /// Id of the item currently being edited inline.
  final _editingItemId = ValueNotifier<String?>(null);
  final _editNameCtrl = TextEditingController();
  final _editPriceCtrl = TextEditingController();

  // Sheet-snap haptics: fire a subtle tick when the sheet crosses a snap
  // point so the drag feels "alive".
  static const _snapPoints = [0.4, 0.85, 0.95];
  int? _lastSnapBucket;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onInputFocus);
    _priceFocus.addListener(_onInputFocus);
    _sheetController.addListener(_onSheetSizeChanged);
    // Scroll to the "Add Item" form as soon as the sheet is laid out so
    // the user can start typing immediately — don't make them scroll past
    // existing items to reach the form.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _addFormKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    // Map current size to the closest snap point index. When that changes,
    // fire a tick.
    int closest = 0;
    double minDist = (size - _snapPoints[0]).abs();
    for (var i = 1; i < _snapPoints.length; i++) {
      final d = (size - _snapPoints[i]).abs();
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    if (minDist < 0.015 && _lastSnapBucket != closest) {
      _lastSnapBucket = closest;
      Haptics.tap();
    } else if (minDist >= 0.02) {
      // Reset so re-crossing the same snap fires again.
      _lastSnapBucket = null;
    }
  }

  void _onInputFocus() {
    if (!_nameFocus.hasFocus && !_priceFocus.hasFocus) return;
    // We ONLY expand the sheet to max size so the keyboard has room.
    // We DO NOT call Scrollable.ensureVisible on every focus change — that
    // was fighting the user's own scrolling and snapping them away from the
    // input while they were typing. The dynamic bottom padding (equal to
    // `viewInsets.bottom`) is enough to keep the focused field visible
    // above the keyboard; Flutter's default focus handling takes care of
    // the minimal scroll needed on its own.
    Future.delayed(const Duration(milliseconds: 80), () async {
      if (!mounted) return;
      try {
        if (_sheetController.isAttached &&
            _sheetController.size < 0.94) {
          await _sheetController.animateTo(
            0.95,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onInputFocus);
    _priceFocus.removeListener(_onInputFocus);
    _nameFocus.dispose();
    _priceFocus.dispose();
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _editNameCtrl.dispose();
    _editPriceCtrl.dispose();
    _editingItemId.dispose();
    super.dispose();
  }

  Future<void> _addItem(List<_User> users, String currentPayerId) async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) return;

    // Default split = all collaborators if user hasn't touched the chips yet.
    final selected = _newItemSplit ?? users.map((u) => u.userId).toSet();

    Haptics.select();
    await ref.read(noteExpensesProvider(widget.noteId).notifier).addItem(
          expenseId: widget.expense.id,
          name: name,
          price: price,
          // Capture the CURRENT payer at add-time, so later changes to the
          // expense-level payer don't silently rewrite this item's payer.
          payerId: currentPayerId,
          participantUserIds: selected.toList(),
        );
    if (!mounted) return;
    _nameCtrl.clear();
    _priceCtrl.clear();
    // Reset split to "all" for the next item.
    setState(() => _newItemSplit = null);
  }

  void _startEditItem(ExpenseItem item) {
    _editNameCtrl.text = item.name;
    _editPriceCtrl.text = item.price.toString();
    _editingItemId.value = item.id;
  }

  Future<void> _saveEditItem(ExpenseItem item) async {
    final newName = _editNameCtrl.text.trim();
    final newPrice = double.tryParse(_editPriceCtrl.text.trim());

    final nameChanged = newName.isNotEmpty && newName != item.name;
    final priceChanged = newPrice != null && newPrice != item.price;

    // Make sure the item still exists before saving — another client may
    // have deleted it during edit.
    final liveList = ref.read(noteExpensesProvider(widget.noteId)).valueOrNull;
    final stillExists = liveList
            ?.firstWhere((e) => e.id == widget.expense.id,
                orElse: () => widget.expense)
            .items
            .any((i) => i.id == item.id) ??
        true;
    if (!stillExists) {
      if (mounted) _editingItemId.value = null;
      return;
    }

    if (nameChanged || priceChanged) {
      await ref.read(noteExpensesProvider(widget.noteId).notifier).updateItem(
            itemId: item.id,
            name: nameChanged ? newName : null,
            price: priceChanged ? newPrice : null,
          );
    }
    if (!mounted) return;
    _editingItemId.value = null;
  }

  Future<void> _toggleParticipant({
    required String itemId,
    required String userId,
    required bool currentlyParticipating,
    required String? participantRowId,
  }) async {
    Haptics.select();
    final notifier = ref.read(noteExpensesProvider(widget.noteId).notifier);
    if (currentlyParticipating) {
      if (participantRowId != null) {
        await notifier.removeParticipant(participantRowId);
      }
    } else {
      await notifier.addParticipant(itemId: itemId, userId: userId);
    }
  }

  Future<void> _setSplitNone({required ExpenseItem item}) async {
    if (item.participants.isEmpty) return;
    Haptics.select();
    await ref
        .read(noteExpensesProvider(widget.noteId).notifier)
        .removeParticipants(
          item.participants.map((p) => p.id).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Live expense data — so we see additions/edits immediately.
    final liveExpenses = ref.watch(noteExpensesProvider(widget.noteId));
    final expense = liveExpenses.maybeWhen(
      data: (list) => list.firstWhere(
        (e) => e.id == widget.expense.id,
        orElse: () => widget.expense,
      ),
      orElse: () => widget.expense,
    );

    // Auto-close if the expense is deleted elsewhere.
    ref.listen<AsyncValue<List<Expense>>>(
      noteExpensesProvider(widget.noteId),
      (_, next) {
        final gone = next.maybeWhen(
          data: (list) => !list.any((e) => e.id == widget.expense.id),
          orElse: () => false,
        );
        if (gone && mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      },
    );

    final usersAsync = ref.watch(accessibleUsersProvider(widget.noteId));
    final users = usersAsync.valueOrNull ?? const <_User>[];

    // Total across all items.
    final total = expense.items.fold<double>(0, (s, i) => s + i.price);

    // Dynamic bottom padding so the last row of the list is never hidden
    // behind the keyboard.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.4, 0.85, 0.95],
      builder: (context, sheetScrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13102B) : const Color(0xFFFAF8FF),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SheetDragHandle(),
              _header(context, scheme),
              Divider(
                height: 1,
                thickness: 0.5,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(
                child: ListView(
                  controller: sheetScrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    // Keep the bottom clear of the keyboard + a small
                    // breathing area for the "Add Item" button.
                    keyboardInset > 0 ? keyboardInset + 16 : 32,
                  ),
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 400,
                  children: [
                    const SectionLabel('PAID BY'),
                    const SizedBox(height: 8),
                    _paidByDropdown(context, scheme, isDark, expense, users),
                    const SizedBox(height: 20),
                    _itemsHeader(context, scheme, total),
                    const SizedBox(height: 10),
                    if (expense.items.isEmpty)
                      _noItemsPlaceholder(context, scheme)
                    else
                      ValueListenableBuilder<String?>(
                        valueListenable: _editingItemId,
                        builder: (context, editingId, _) {
                          return Column(
                            children: expense.items
                                .map((item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: editingId == item.id
                                          ? _editableItem(
                                              context, scheme, isDark, item)
                                          : _itemRow(context, scheme, isDark,
                                              item, users, expense.payerId),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 20),
                    // Wrap the add-item section in a column with a key so we
                    // can Scrollable.ensureVisible into it when the keyboard
                    // opens.
                    Column(
                      key: _addFormKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('ADD ITEM'),
                        const SizedBox(height: 10),
                        _addItemForm(
                            context, scheme, isDark, users, expense.payerId),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============== Widgets ==============

  Widget _header(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Expense Details',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: scheme.error),
            onPressed: () {
              Haptics.confirm();
              final expenseId = widget.expense.id;
              final noteId = widget.noteId;
              Navigator.of(context, rootNavigator: true).pop();
              ref
                  .read(noteExpensesProvider(noteId).notifier)
                  .deleteExpense(expenseId);
            },
            tooltip: 'Delete expense',
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).maybePop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _paidByDropdown(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    Expense expense,
    List<_User> users,
  ) {
    final currentUserId = expense.payerId;
    final hasCurrent = users.any((u) => u.userId == currentUserId);
    final currentLabel = resolveDisplayName(users, currentUserId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasCurrent ? currentUserId : null,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: scheme.onSurfaceVariant),
          hint: Text(
            currentLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          items: users
              .map((u) => DropdownMenuItem(
                    value: u.userId,
                    child: Text(
                      u.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: users.length <= 1
              ? null
              : (newId) {
                  if (newId == null || newId == currentUserId) return;
                  Haptics.select();
                  ref
                      .read(noteExpensesProvider(widget.noteId).notifier)
                      .updatePayer(
                        expenseId: expense.id,
                        payerId: newId,
                      );
                },
        ),
      ),
    );
  }

  Widget _itemsHeader(BuildContext context, ColorScheme scheme, double total) {
    return Row(
      children: [
        const SectionLabel('ITEMS'),
        const Spacer(),
        Text(
          total.toCurrency(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _noItemsPlaceholder(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No items yet. Add one below.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    ExpenseItem item,
    List<_User> users,
    String expensePayerId,
  ) {
    // Prefer the item's own payer (captured at creation time). Fall back to
    // the expense-level payer for legacy rows that pre-date the per-item
    // column.
    final effectivePayerId = item.payerId ?? expensePayerId;
    final payerName = resolveDisplayName(users, effectivePayerId);
    return GestureDetector(
      onDoubleTap: () {
        Haptics.select();
        _startEditItem(item);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name.isEmpty ? 'Untitled item' : item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                Text(
                  '₹ ',
                  style: TextStyle(
                      color:
                          scheme.onSurfaceVariant.withValues(alpha: 0.55)),
                ),
                Text(
                  item.price.toStringAsFixed(
                      item.price.truncateToDouble() == item.price ? 0 : 2),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit_rounded,
                      size: 16,
                      color:
                          scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _startEditItem(item),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: scheme.error),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    Haptics.confirm();
                    ref
                        .read(noteExpensesProvider(widget.noteId).notifier)
                        .deleteItem(item.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _splitChips(
              context,
              scheme,
              users: users,
              selectedIds: item.participants.map((p) => p.userId).toSet(),
              onToggleUser: (uid) {
                final existing = item.participants
                    .where((p) => p.userId == uid)
                    .toList();
                _toggleParticipant(
                  itemId: item.id,
                  userId: uid,
                  currentlyParticipating: existing.isNotEmpty,
                  participantRowId:
                      existing.isNotEmpty ? existing.first.id : null,
                );
              },
              onSelectNone: () => _setSplitNone(item: item),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'PAID BY:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    payerName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableItem(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    ExpenseItem item,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _editNameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: _compactInputDecoration(
                      scheme, hint: 'Name'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _editPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveEditItem(item),
                  decoration: _compactInputDecoration(
                      scheme, hint: 'Price'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _editingItemId.value = null,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _saveEditItem(item),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _compactInputDecoration(ColorScheme scheme,
      {required String hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }

  Widget _addItemForm(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    List<_User> users,
    String currentPayerId,
  ) {
    // Default selection = all collaborators (until user toggles).
    final selected = _newItemSplit ?? users.map((u) => u.userId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocus.requestFocus(),
                decoration:
                    _compactInputDecoration(scheme, hint: 'Item name'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _priceCtrl,
                focusNode: _priceFocus,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(users, currentPayerId),
                decoration:
                    _compactInputDecoration(scheme, hint: '₹ Price'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _splitChips(
          context,
          scheme,
          users: users,
          selectedIds: selected,
          onToggleUser: (uid) {
            setState(() {
              final next = {...selected};
              if (next.contains(uid)) {
                next.remove(uid);
              } else {
                next.add(uid);
              }
              _newItemSplit = next;
            });
          },
          onSelectNone: () {
            setState(() => _newItemSplit = <String>{});
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _addItem(users, currentPayerId),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Item'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reusable `[None] [User A] [User B] ...` chip row.
  Widget _splitChips(
    BuildContext context,
    ColorScheme scheme, {
    required List<_User> users,
    required Set<String> selectedIds,
    required void Function(String userId) onToggleUser,
    required VoidCallback onSelectNone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: Text(
            'SPLIT:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                context,
                label: 'None',
                selected: selectedIds.isEmpty,
                onTap: onSelectNone,
              ),
              ...users.map((u) {
                final isSel = selectedIds.contains(u.userId);
                return _chip(
                  context,
                  label: u.displayName,
                  selected: isSel,
                  onTap: () => onToggleUser(u.userId),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
