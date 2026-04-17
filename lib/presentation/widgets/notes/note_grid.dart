import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/utils/responsive.dart';
import '../../../domain/entities/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_provider.dart';
import '../../providers/notes_provider.dart';
import '../common/animated_list_item.dart';
import '../common/skeleton_loader.dart';
import 'note_card.dart';

class NoteGrid extends ConsumerWidget {
  const NoteGrid({
    super.key,
    required this.notes,
    required this.isLoading,
    this.onNoteTap,
    this.onNoteShare,
  });

  final List<Note> notes;
  final bool isLoading;
  final void Function(Note note)? onNoteTap;
  final void Function(Note note)? onNoteShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutModeProvider);
    final r = context.responsive;

    if (isLoading && notes.isEmpty) {
      return _buildSkeleton(layout, r);
    }

    if (notes.isEmpty) {
      return _buildEmpty(context);
    }

    final section = ref.watch(dashboardSectionProvider);
    final currentUser = ref.watch(currentUserProvider);

    final child = section == DashboardSection.all
        ? _buildSectioned(context, ref, layout, r, currentUser?.id ?? '')
        : _buildFlat(layout, r);

    // Fade + subtle scale when the user switches dashboard sections so the
    // grid re-enter feels fluid instead of snapping.
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
    BuildContext context,
    WidgetRef ref,
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
        // Any note where I'm not the owner is shared with me — the backend's
        // RLS only returns notes I have access to, so this is safe regardless
        // of whether a share token exists.
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
            return AnimatedListItem(
              index: index,
              child: NoteCard(
                note: sectionNotes[index],
                onTap: () => onNoteTap?.call(sectionNotes[index]),
                onShare: () => onNoteShare?.call(sectionNotes[index]),
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
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index < sectionNotes.length - 1 ? r.gridSpacing : 0),
              child: AnimatedListItem(
                index: index,
                child: NoteCard(
                  note: sectionNotes[index],
                  onTap: () => onNoteTap?.call(sectionNotes[index]),
                  onShare: () => onNoteShare?.call(sectionNotes[index]),
                ),
              ),
            );
          },
          childCount: sectionNotes.length,
        ),
      ),
    );
  }

  Widget _buildFlat(LayoutMode layout, Responsive r) {
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
          return AnimatedListItem(
            index: index,
            child: NoteCard(
              note: notes[index],
              onTap: () => onNoteTap?.call(notes[index]),
              onShare: () => onNoteShare?.call(notes[index]),
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
        return AnimatedListItem(
          index: index,
          child: NoteCard(
            note: notes[index],
            onTap: () => onNoteTap?.call(notes[index]),
            onShare: () => onNoteShare?.call(notes[index]),
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
                size: 14, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
