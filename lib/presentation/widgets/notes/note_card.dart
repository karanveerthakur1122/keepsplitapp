import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_toast.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/entities/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaborator_counts_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/expense_settings_provider.dart';
import '../../providers/notes_provider.dart';
import '../common/sheet_drag_handle.dart';
import '../liquid_glass/liquid_glass_card.dart';

class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onShare,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onShare;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  bool _showDeleteConfirm = false;
  bool _passedThreshold = false;

  Note get note => widget.note;
  bool get _isTrashed => note.labels.contains('_trashed_');
  bool get _isArchived => note.isArchived;
  List<String> get _visibleLabels =>
      note.labels.where((l) => !l.startsWith('_')).toList();

  Future<bool> _confirmPermanentDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Delete permanently?'),
          content: const Text(
            'This note will be deleted forever. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  // ── Swipe-right (startToEnd) intent by note state ──────────────────────
  // Normal  → archive
  // Archived → unarchive (restore to main list)
  // Trashed  → restore
  ({IconData icon, Color tint, String? label}) get _leftSwipeIntent {
    if (_isTrashed) {
      return (
        icon: Icons.restore_rounded,
        tint: Colors.green,
        label: 'Restore',
      );
    }
    if (_isArchived) {
      return (
        icon: Icons.unarchive_rounded,
        tint: Colors.blue,
        label: 'Unarchive',
      );
    }
    return (
      icon: Icons.archive_rounded,
      tint: Colors.amber.shade700,
      label: 'Archive',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leftIntent = _leftSwipeIntent;
    // Only watch the current user ID, not the whole User object, so auth
    // state changes that don't affect the id don't rebuild this card.
    final currentUserId = ref.watch(
      currentUserProvider.select((u) => u?.id),
    );
    final iAmOwner = currentUserId == note.userId;
    // Scoped watch: only this note's collaborator count. If another note's
    // collaborator list changes, THIS card does not rebuild.
    final collabCount = ref.watch(
      collaboratorCountsProvider
          .select((async) => async.valueOrNull?[note.id] ?? 0),
    );
    // A note is "shared" if either:
    //  - it was shared WITH me (I'm not the owner), OR
    //  - I own it AND it has at least 1 collaborator.
    final isShared = !iAmOwner || collabCount > 0;

    return Stack(
      children: [
        Dismissible(
          key: ValueKey(note.id),
          // Lower threshold so a confident swipe commits faster and feels
          // more responsive than Flutter's default 40%.
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.32,
            DismissDirection.endToStart: 0.32,
          },
          movementDuration: const Duration(milliseconds: 240),
          resizeDuration: const Duration(milliseconds: 220),
          background: _SwipeBackground(
            icon: leftIntent.icon,
            label: leftIntent.label ?? '',
            tint: leftIntent.tint,
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: _SwipeBackground(
            icon: Icons.delete_rounded,
            label: _isTrashed ? 'Delete forever' : 'Delete',
            tint: scheme.error,
            alignment: Alignment.centerRight,
          ),
          onUpdate: (details) {
            // Arm the haptic tick once the drag crosses 32% so the user
            // knows the action will commit on release.
            final reached = details.progress >= 0.32;
            if (reached && !_passedThreshold) {
              _passedThreshold = true;
              Haptics.select();
            }
            // Disarm as soon as the finger goes back below ~5%, so a second
            // attempt in the same session gets its tick too (and so a
            // cancelled snap-back leaves us in a clean state).
            if (details.progress < 0.05 && _passedThreshold) {
              _passedThreshold = false;
            }
          },
          confirmDismiss: (direction) async {
            Haptics.confirm();
            _passedThreshold = false;
            if (direction == DismissDirection.startToEnd) {
              if (_isTrashed) {
                await ref.read(notesProvider.notifier).restore(note.id);
                AppToast.success('Note restored');
              } else if (_isArchived) {
                await ref.read(notesProvider.notifier).archive(note.id, false);
                AppToast.info('Unarchived');
              } else {
                await ref.read(notesProvider.notifier).archive(note.id, true);
                AppToast.info('Archived');
              }
              return false;
            } else {
              if (_isTrashed) {
                final ok = await _confirmPermanentDelete();
                if (!ok) return false;
                await ref.read(notesProvider.notifier).delete(note.id);
                AppToast.info('Note deleted permanently');
                return true;
              } else {
                setState(() => _showDeleteConfirm = true);
                return false;
              }
            }
          },
          child: LiquidGlassCard(
            onTap: widget.onTap,
            onLongPress: () {
              Haptics.select();
              _showActions(context, ref);
            },
            enable3DTilt: false,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.push_pin_rounded,
                            size: 13, color: scheme.primary),
                      ),
                    Expanded(
                      child: Padding(
                        // Reserve ~22 px on the right so the title doesn't run
                        // into the absolute-positioned shared badge.
                        padding: EdgeInsets.only(right: isShared ? 22 : 0),
                        child: Hero(
                          tag: 'note-title-${note.id}',
                          flightShuttleBuilder: (_, anim, __, ___, ____) {
                            // Keep the text crisp and on top during flight.
                            return Material(
                              type: MaterialType.transparency,
                              child: DefaultTextStyle(
                                style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ) ??
                                    const TextStyle(),
                                child: Text(
                                  note.title.isEmpty
                                      ? 'Untitled'
                                      : note.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              note.title.isEmpty
                                  ? 'Untitled'
                                  : note.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_visibleLabels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _visibleLabels
                        .map((label) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      scheme.primary.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                _ExpensePreview(noteId: note.id),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      note.updatedAt.timeAgo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (isShared)
          Positioned(
            top: 8,
            right: 8,
            child: _SharedBadge(
              sharedWithMe: !iAmOwner,
            ),
          ),

        if (_showDeleteConfirm)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, opacity, child) => Opacity(
                opacity: opacity,
                child: child,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Delete this note?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _showDeleteConfirm = false),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _showDeleteConfirm = false);
                            ref.read(notesProvider.notifier).trash(note.id);
                            AppToast.info('Moved to trash');
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: scheme.error,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }

  @override
  void didUpdateWidget(covariant NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note != widget.note) {
      _showDeleteConfirm = false;
    }
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetDragHandle(topMargin: 0, bottomMargin: 16),
                if (!_isTrashed) ...[
                  ListTile(
                    leading: Icon(
                      note.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                    ),
                    title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final pinning = !note.isPinned;
                      ref.read(notesProvider.notifier).pin(note.id, pinning);
                      AppToast.info(pinning ? 'Pinned' : 'Unpinned');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('Archive'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(notesProvider.notifier).archive(note.id, true);
                      AppToast.info('Archived');
                    },
                  ),
                  if (widget.onShare != null)
                    ListTile(
                      leading: const Icon(Icons.share_outlined),
                      title: const Text('Share'),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onShare?.call();
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: scheme.error),
                    title: Text('Move to Trash',
                        style: TextStyle(color: scheme.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(notesProvider.notifier).trash(note.id);
                      AppToast.info('Moved to trash');
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Restore'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(notesProvider.notifier).restore(note.id);
                      AppToast.success('Note restored');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: scheme.error),
                    title: Text('Delete permanently',
                        style: TextStyle(color: scheme.error)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await _confirmPermanentDelete();
                      if (!ok) return;
                      ref.read(notesProvider.notifier).delete(note.id);
                      AppToast.info('Note deleted permanently');
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpensePreview extends ConsumerWidget {
  const _ExpensePreview({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(noteExpensesProvider(noteId));
    final expenses = expensesAsync.valueOrNull;
    if (expenses == null || expenses.isEmpty) return const SizedBox.shrink();

    final settingsVal =
        ref.watch(noteExpenseSettingsProvider(noteId)).valueOrNull;
    final symbol = currencySymbol(settingsVal?.currency ?? 'INR');

    final totalItems =
        expenses.fold<int>(0, (sum, e) => sum + e.items.length);
    final totalAmount = expenses.fold<double>(
        0, (sum, e) => sum + e.items.fold<double>(0, (s, i) => s + i.price));

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 12, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              '$totalItems item${totalItems == 1 ? '' : 's'} · ${totalAmount.toCurrency(symbol: symbol)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedBadge extends StatelessWidget {
  const _SharedBadge({required this.sharedWithMe});

  /// `true` → this note was shared WITH me (incoming).
  /// `false` → this is my note that I've shared with others (outgoing).
  final bool sharedWithMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: sharedWithMe ? 'Shared with you' : 'You shared this',
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.3),
            width: 0.6,
          ),
        ),
        child: Icon(
          sharedWithMe ? Icons.people_rounded : Icons.share_rounded,
          size: 12,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.tint,
    required this.alignment,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isRight = alignment == Alignment.centerRight;
    final children = [
      Icon(icon, color: tint, size: 22),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    ];
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(left: isRight ? 0 : 20, right: isRight ? 20 : 0),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isRight ? children.reversed.toList() : children,
      ),
    );
  }
}
