import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/constants/demo_data.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_provider.dart';
import '../../providers/note_order_provider.dart';
import '../../providers/notes_provider.dart';
import '../common/animated_list_item.dart';
import '../common/skeleton_loader.dart';
import '../liquid_glass/liquid_glass_card.dart';
import 'note_card.dart';

class NoteGrid extends ConsumerStatefulWidget {
  const NoteGrid({
    super.key,
    required this.notes,
    required this.isLoading,
    this.onNoteTap,
    this.onNoteShare,
    this.demoNoteKey,
  });

  final List<Note> notes;
  final bool isLoading;
  final void Function(Note note)? onNoteTap;
  final void Function(Note note)? onNoteShare;
  final GlobalKey? demoNoteKey;

  @override
  ConsumerState<NoteGrid> createState() => _NoteGridState();
}

class _NoteGridState extends ConsumerState<NoteGrid> {
  List<Note> _localNotes = [];
  bool _isDragging = false;
  String? _lastHoveredTargetId;

  List<Note> get _displayNotes =>
      _isDragging ? _localNotes : widget.notes;

  @override
  void initState() {
    super.initState();
    _localNotes = List.of(widget.notes);
  }

  @override
  void didUpdateWidget(covariant NoteGrid old) {
    super.didUpdateWidget(old);
    if (!_isDragging) {
      _localNotes = List.of(widget.notes);
    }
  }

  Widget _buildNoteCard(Note note) {
    final card = NoteCard(
      key: note.id == demoNoteId ? widget.demoNoteKey : null,
      note: note,
      onTap: () => widget.onNoteTap?.call(note),
      onShare: () => widget.onNoteShare?.call(note),
    );
    return card;
  }

  // ── Drag callbacks ────────────────────────────────────────────

  void _onDragStarted(String noteId) {
    setState(() {
      _isDragging = true;
      _localNotes = List.of(widget.notes);
      _lastHoveredTargetId = null;
    });
    Haptics.confirm();
  }

  void _onDragEnd() {
    if (_isDragging) {
      ref.read(noteOrderProvider.notifier).saveOrder(
            _localNotes.map((n) => n.id).toList(),
          );
    }
    setState(() {
      _isDragging = false;
      _lastHoveredTargetId = null;
    });
  }

  void _onDragCancelled() {
    setState(() {
      _isDragging = false;
      _localNotes = List.of(widget.notes);
      _lastHoveredTargetId = null;
    });
  }

  void _onHover(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    if (targetId == _lastHoveredTargetId) return;
    _lastHoveredTargetId = targetId;

    final from = _localNotes.indexWhere((n) => n.id == draggedId);
    final to = _localNotes.indexWhere((n) => n.id == targetId);
    if (from == -1 || to == -1) return;

    setState(() {
      final note = _localNotes.removeAt(from);
      _localNotes.insert(to, note);
    });
    Haptics.tap();
  }

  // ── Cell width for the drag feedback overlay ──────────────────

  double _cellWidth(Responsive r) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = r.horizontalPadding * 2;
    final spacing = r.gridSpacing * (r.gridCrossAxisCount - 1);
    return (width - pad - spacing) / r.gridCrossAxisCount;
  }

  // ── Drag wrapper ──────────────────────────────────────────────

  Widget _wrapDraggable({
    required Note note,
    required int index,
    required Responsive r,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final cellWidth = _cellWidth(r);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        _onHover(details.data, note.id);
        return false;
      },
      builder: (context, candidates, rejected) {
        return LongPressDraggable<String>(
          data: note.id,
          delay: const Duration(milliseconds: 200),
          hapticFeedbackOnStart: true,
          maxSimultaneousDrags: 1,
          onDragStarted: () => _onDragStarted(note.id),
          onDragEnd: (_) => _onDragEnd(),
          onDraggableCanceled: (_, __) => _onDragCancelled(),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: cellWidth,
              child: Transform.scale(
                scale: 1.05,
                child: Opacity(
                  opacity: 0.92,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.65)
                              : Colors.black.withValues(alpha: 0.18),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: LiquidGlassCard(
                      enable3DTilt: false,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            style: Theme.of(this.context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              note.content,
                              style:
                                  Theme.of(this.context).textTheme.bodySmall,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
              color: scheme.primary.withValues(alpha: 0.04),
            ),
          ),
          child: child,
        );
      },
    );
  }

  // ── Build helpers ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(layoutModeProvider);
    final r = context.responsive;
    final notes = _displayNotes;

    if (widget.isLoading && widget.notes.isEmpty) {
      return _buildSkeleton(layout, r);
    }

    if (widget.notes.isEmpty) {
      return _buildEmpty(context);
    }

    final section = ref.watch(dashboardSectionProvider);
    final currentUser = ref.watch(currentUserProvider);

    final child = section == DashboardSection.all
        ? _buildSectioned(notes, layout, r, currentUser?.id ?? '')
        : _buildFlat(notes, layout, r);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(section),
        child: child,
      ),
    );
  }

  Widget _buildSectioned(
    List<Note> notes,
    LayoutMode layout,
    Responsive r,
    String currentUserId,
  ) {
    final pinned = <Note>[];
    final shared = <Note>[];
    final others = <Note>[];

    for (final note in notes) {
      if (note.isPinned) {
        pinned.add(note);
      } else if (note.userId != currentUserId) {
        shared.add(note);
      } else {
        others.add(note);
      }
    }

    final padding = EdgeInsets.symmetric(horizontal: r.horizontalPadding);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      cacheExtent: 500,
      slivers: [
        if (pinned.isNotEmpty) ...[
          _SectionHeader(title: 'Pinned', icon: Icons.push_pin_rounded),
          _buildNoteSliver(pinned, layout, r, padding),
        ],
        if (shared.isNotEmpty) ...[
          _SectionHeader(title: 'Shared with me', icon: Icons.people_rounded),
          _buildNoteSliver(shared, layout, r, padding),
        ],
        if (others.isNotEmpty) ...[
          if (pinned.isNotEmpty || shared.isNotEmpty)
            _SectionHeader(title: 'Others', icon: Icons.notes_rounded),
          _buildNoteSliver(others, layout, r, padding),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildNoteSliver(
    List<Note> sectionNotes,
    LayoutMode layout,
    Responsive r,
    EdgeInsets padding,
  ) {
    if (layout == LayoutMode.grid) {
      return SliverPadding(
        padding: padding,
        sliver: SliverMasonryGrid.count(
          crossAxisCount: r.gridCrossAxisCount,
          mainAxisSpacing: r.gridSpacing,
          crossAxisSpacing: r.gridSpacing,
          childCount: sectionNotes.length,
          itemBuilder: (context, index) {
            final note = sectionNotes[index];
            return KeyedSubtree(
              key: ValueKey(note.id),
              child: _wrapDraggable(
                note: note,
                index: index,
                r: r,
                child: AnimatedListItem(
                  index: index,
                  child: _buildNoteCard(note),
                ),
              ),
            );
          },
        ),
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final note = sectionNotes[index];
            return Padding(
              key: ValueKey(note.id),
              padding: EdgeInsets.only(
                  bottom: index < sectionNotes.length - 1 ? r.gridSpacing : 0),
              child: _wrapDraggable(
                note: note,
                index: index,
                r: r,
                child: AnimatedListItem(
                  index: index,
                  child: _buildNoteCard(note),
                ),
              ),
            );
          },
          childCount: sectionNotes.length,
        ),
      ),
    );
  }

  Widget _buildFlat(List<Note> notes, LayoutMode layout, Responsive r) {
    final padding = EdgeInsets.symmetric(
      horizontal: r.horizontalPadding,
      vertical: 8,
    );

    if (layout == LayoutMode.grid) {
      return MasonryGridView.count(
        crossAxisCount: r.gridCrossAxisCount,
        mainAxisSpacing: r.gridSpacing,
        crossAxisSpacing: r.gridSpacing,
        padding: padding,
        cacheExtent: 500,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return KeyedSubtree(
            key: ValueKey(note.id),
            child: _wrapDraggable(
              note: note,
              index: index,
              r: r,
              child: AnimatedListItem(
                index: index,
                child: _buildNoteCard(note),
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: padding,
      cacheExtent: 500,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: notes.length,
      separatorBuilder: (_, __) => SizedBox(height: r.gridSpacing),
      itemBuilder: (context, index) {
        final note = notes[index];
        return KeyedSubtree(
          key: ValueKey(note.id),
          child: _wrapDraggable(
            note: note,
            index: index,
            r: r,
            child: AnimatedListItem(
              index: index,
              child: _buildNoteCard(note),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  size: 56,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.25),
                ),
                const SizedBox(height: 16),
                Text(
                  'No notes yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to create your first note',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(LayoutMode layout, Responsive r) {
    if (layout == LayoutMode.grid) {
      return Padding(
        padding: EdgeInsets.all(r.horizontalPadding),
        child: MasonryGridView.count(
          crossAxisCount: r.gridCrossAxisCount,
          mainAxisSpacing: r.gridSpacing,
          crossAxisSpacing: r.gridSpacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          itemBuilder: (_, __) => const NoteCardSkeleton(),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(r.horizontalPadding),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: r.gridSpacing),
      itemBuilder: (_, __) => const NoteCardSkeleton(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
