import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/debouncer.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/entities/note.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/realtime_provider.dart';
import '../collaboration/collaborator_manager.dart';
import '../collaboration/share_dialog.dart';
import '../common/sheet_drag_handle.dart';
import '../expenses/expense_block.dart';
import '../expenses/expense_detail_sheet.dart';
import '../expenses/expense_summary.dart';
import 'presence_avatars.dart';

class NoteEditorSheet extends ConsumerStatefulWidget {
  const NoteEditorSheet({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  // Expenses visible by default now — users toggle to hide.
  bool _showExpenses = true;
  // Description is optional. Shown when note already has content OR the user
  // explicitly toggles it on. Title + expenses alone is a valid layout.
  late bool _showDescription;
  late bool _isPinned;
  // When true, the title TextField is rendered without the Hero wrapper.
  // Set just before a destructive pop (trash/delete) so Hero doesn't try
  // to reverse-fly into a card that's being removed at the same time.
  bool _skipHero = false;
  // Stored so we can close it cleanly in dispose().
  ProviderSubscription<AsyncValue<Profile?>>? _profileSub;

  // Labels that act as per-note preferences for the editor. They're private
  // (start with `_`) so `_visibleLabels` hides them from the UI.
  static const _labelDescHidden = '_desc_hidden_';
  static const _labelDescShown = '_desc_shown_';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _isPinned = widget.note.isPinned;
    _showDescription = _resolveInitialShowDescription(widget.note);
    _setupRealtime();
  }

  bool _resolveInitialShowDescription(Note note) {
    // User explicitly hid the description on this note → keep it hidden.
    if (note.labels.contains(_labelDescHidden)) return false;
    // User explicitly toggled it on → keep it shown even if currently empty.
    if (note.labels.contains(_labelDescShown)) return true;
    // No explicit preference → auto: show if there's content to display.
    return note.content.isNotEmpty;
  }

  void _setupRealtime() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final realtime = ref.read(realtimeDatasourceProvider);
    realtime.subscribeToNote(widget.note.id, onUpdate: (data) {
      if (!mounted) return;
      final newTitle = data['title'] as String? ?? '';
      final newContent = data['content'] as String? ?? '';

      // Preserve caret position when syncing remote edits, otherwise the
      // cursor jumps to the start on every keystroke from another user.
      if (_titleCtrl.text != newTitle) {
        _titleCtrl.value = _titleCtrl.value.copyWith(
          text: newTitle,
          selection: TextSelection.collapsed(offset: newTitle.length),
          composing: TextRange.empty,
        );
      }
      if (_contentCtrl.text != newContent) {
        _contentCtrl.value = _contentCtrl.value.copyWith(
          text: newContent,
          selection: TextSelection.collapsed(offset: newContent.length),
          composing: TextRange.empty,
        );
      }

      // Sync pin state so the toolbar icon reflects live changes from other
      // clients / devices.
      final remotePinned = data['is_pinned'] as bool? ?? _isPinned;
      if (remotePinned != _isPinned) {
        setState(() => _isPinned = remotePinned);
      }

      // The dashboard's own realtime subscription silently refetches the
      // notes list for background cards — no need to do it here too (doing
      // so would shimmer the grid on every keystroke from a collaborator).
    });

    _trackPresenceWhenReady(user.id, user.email ?? '');

    realtime.subscribeToExpenses(widget.note.id, onAnyChange: () {
      if (mounted) ref.invalidate(noteExpensesProvider(widget.note.id));
    });
  }

  void _trackPresenceWhenReady(String userId, String fallbackName) {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final displayName = profile?.displayName ?? fallbackName;

    final realtime = ref.read(realtimeDatasourceProvider);
    realtime.trackPresence(
      widget.note.id,
      userId: userId,
      displayName: displayName.isEmpty ? 'User' : displayName,
      onSync: (users) {
        if (mounted) {
          ref.read(presenceUsersProvider(widget.note.id).notifier).state = users;
        }
      },
    );

    if (profile == null) {
      _profileSub = ref.listenManual(currentProfileProvider, (_, next) {
        final name = next.valueOrNull?.displayName;
        if (name != null && name.isNotEmpty && mounted) {
          realtime.trackPresence(
            widget.note.id,
            userId: userId,
            displayName: name,
            onSync: (users) {
              if (mounted) {
                ref.read(presenceUsersProvider(widget.note.id).notifier).state =
                    users;
              }
            },
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _profileSub?.close();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _debouncer.dispose();
    final realtime = ref.read(realtimeDatasourceProvider);
    realtime.unsubscribe('note-${widget.note.id}');
    realtime.unsubscribe('presence-${widget.note.id}');
    realtime.unsubscribe('expenses-${widget.note.id}');
    super.dispose();
  }

  /// Builds the title input. Wraps it in a `Hero` that morphs from the note
  /// card's title — unless we're in the middle of a destructive close
  /// (`_skipHero`), in which case the card may be gone and the reverse
  /// flight would have nothing to land on.
  Widget _buildTitleField(BuildContext context, ColorScheme scheme) {
    final titleField = Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _titleCtrl,
        onChanged: (_) => _onTextChanged(),
        textInputAction: TextInputAction.next,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
        decoration: InputDecoration(
          hintText: 'Title',
          hintStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
              ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
    if (_skipHero) return titleField;
    return Hero(
      tag: 'note-title-${widget.note.id}',
      // TextField can't be rendered in the Hero overlay, so during the
      // flight we show a plain Text in the matching headline style.
      flightShuttleBuilder: (_, anim, __, ___, ____) {
        return Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ) ??
                const TextStyle(),
            child: Text(
              widget.note.title.isEmpty ? 'Untitled' : widget.note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
      child: titleField,
    );
  }

  /// Persist the user's show/hide description preference on the note itself
  /// (via internal labels) so reopening the note preserves the choice.
  void _persistDescriptionPreference(bool show) {
    final labels = [...widget.note.labels]
      ..remove(_labelDescHidden)
      ..remove(_labelDescShown);
    labels.add(show ? _labelDescShown : _labelDescHidden);
    ref.read(notesProvider.notifier).updateNote(
          widget.note.copyWith(labels: labels),
        );
  }

  // Throttle the "is typing" realtime signal: fire at most once per 400ms
  // while the user is actively typing, so we don't spam the realtime channel
  // on every keystroke (which was contributing to typing latency).
  DateTime? _lastTypingSignalAt;

  void _onTextChanged() {
    final realtime = ref.read(realtimeDatasourceProvider);
    final now = DateTime.now();
    final last = _lastTypingSignalAt;
    if (last == null || now.difference(last).inMilliseconds > 400) {
      realtime.updateTyping(widget.note.id, true);
      _lastTypingSignalAt = now;
    }

    _debouncer.run(() {
      // The widget may have been disposed between the keystroke and this
      // delayed callback — guard every `ref`/realtime use.
      if (!mounted) return;
      realtime.updateTyping(widget.note.id, false);
      _lastTypingSignalAt = null;
      ref.read(notesProvider.notifier).updateNote(
            widget.note.copyWith(
              title: _titleCtrl.text,
              content: _contentCtrl.text,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presenceUsers = ref.watch(presenceUsersProvider(widget.note.id));
    final expensesAsync = ref.watch(noteExpensesProvider(widget.note.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.4, 0.88, 0.96],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF13102B)
                : const Color(0xFFFAF8FF),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    PresenceAvatars(users: presenceUsers),
                    // Toolbar buttons scroll horizontally if the device is
                    // narrow, so they never cause overflow warnings.
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                    _ToolbarButton(
                      icon: _isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      isActive: _isPinned,
                      color: scheme.primary,
                      onPressed: () {
                        Haptics.select();
                        setState(() => _isPinned = !_isPinned);
                        ref
                            .read(notesProvider.notifier)
                            .pin(widget.note.id, _isPinned);
                      },
                    ),
                    _ToolbarButton(
                      icon: Icons.person_add_outlined,
                      color: scheme.primary,
                      onPressed: () {
                        Haptics.select();
                        showDialog(
                          context: context,
                          useRootNavigator: true,
                          builder: (_) => ShareDialog(note: widget.note),
                        );
                      },
                    ),
                    _ToolbarButton(
                      icon: Icons.people_outlined,
                      color: scheme.primary,
                      onPressed: () {
                        Haptics.select();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useRootNavigator: true,
                          builder: (sheetCtx) =>
                              _CollaboratorsSheet(noteId: widget.note.id),
                        );
                      },
                    ),
                    _ToolbarButton(
                      icon: _showDescription
                          ? Icons.subject_rounded
                          : Icons.short_text_rounded,
                      isActive: _showDescription,
                      color: scheme.primary,
                      tooltip: _showDescription
                          ? 'Hide description'
                          : 'Add description',
                      onPressed: () {
                        Haptics.select();
                        final next = !_showDescription;
                        setState(() => _showDescription = next);
                        _persistDescriptionPreference(next);
                      },
                    ),
                    _ToolbarButton(
                      icon: _showExpenses
                          ? Icons.receipt_long_rounded
                          : Icons.receipt_long_outlined,
                      isActive: _showExpenses,
                      color: scheme.primary,
                      onPressed: () {
                        Haptics.select();
                        setState(() => _showExpenses = !_showExpenses);
                      },
                    ),
                    _ToolbarButton(
                      icon: Icons.delete_outline_rounded,
                      color: scheme.error,
                      onPressed: () {
                        Haptics.confirm();
                        final noteId = widget.note.id;
                        // The card for this note is about to disappear from
                        // the grid (optimistic trash), so turn off Hero to
                        // avoid a broken reverse flight into a missing
                        // destination. Unfocus first so the keyboard doesn't
                        // steal the pop frame.
                        setState(() => _skipHero = true);
                        FocusScope.of(context).unfocus();
                        Navigator.of(context, rootNavigator: true).pop();
                        ref.read(notesProvider.notifier).trash(noteId);
                      },
                    ),
                    const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    // Leave room for the keyboard when any field is focused.
                    MediaQuery.viewInsetsOf(context).bottom + 40,
                  ),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  cacheExtent: 600,
                  children: [
                    _buildTitleField(context, scheme),
                    if (_showDescription) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentCtrl,
                        onChanged: (_) => _onTextChanged(),
                        minLines: 3,
                        maxLines: 200,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                        decoration: InputDecoration(
                          hintText: 'Start writing...',
                          hintStyle:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                  ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    if (_showExpenses) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 16, color: scheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'EXPENSES',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Consumer(
                            builder: (context, ref, _) {
                              ref.watch(noteExpensesProvider(widget.note.id));
                              final notifier = ref.read(
                                  noteExpensesProvider(widget.note.id)
                                      .notifier);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.undo_rounded,
                                        size: 18),
                                    onPressed: notifier.canUndo
                                        ? () => notifier.undo()
                                        : null,
                                    tooltip: 'Undo',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.redo_rounded,
                                        size: 18),
                                    onPressed: notifier.canRedo
                                        ? () => notifier.redo()
                                        : null,
                                    tooltip: 'Redo',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              );
                            },
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              Haptics.select();
                              // Make sure expenses are visible so the new
                              // expense card isn't created "offscreen".
                              if (!_showExpenses) {
                                setState(() => _showExpenses = true);
                              }
                              final created = await ref
                                  .read(noteExpensesProvider(widget.note.id)
                                      .notifier)
                                  .addExpense(user.id);
                              if (!context.mounted) return;
                              // Auto-open the detail sheet so the user can
                              // immediately start adding items.
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                useRootNavigator: true,
                                builder: (_) => ExpenseDetailSheet(
                                  expense: created,
                                  noteId: widget.note.id,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Expense'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 34),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      expensesAsync.when(
                        data: (expenses) {
                          if (expenses.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No expenses yet. Tap + to add one.',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...expenses.map((e) => ExpenseBlock(
                                    expense: e,
                                    noteId: widget.note.id,
                                  )),
                              const SizedBox(height: 16),
                              ExpenseSummary(noteId: widget.note.id),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error loading expenses',
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? color : color.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// A properly-bounded scrollable sheet wrapper around [CollaboratorManager].
/// Ensures the content never overflows the screen and scrolls smoothly when
/// there are many collaborators.
class _CollaboratorsSheet extends StatelessWidget {
  const _CollaboratorsSheet({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.3, 0.55, 0.92],
      expand: false,
      builder: (context, scrollController) {
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
              const SheetDragHandle(bottomMargin: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Members',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context,
                              rootNavigator: true)
                          .maybePop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: CollaboratorManager(noteId: noteId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
