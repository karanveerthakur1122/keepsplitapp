import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/entities/note.dart';
import '../../providers/collaborator_counts_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../widgets/collaboration/share_dialog.dart';
import '../../widgets/editor/note_editor_sheet.dart';
import '../../widgets/navigation/app_header.dart';
import '../../widgets/navigation/edge_swipe_drawer.dart';
import '../../widgets/liquid_glass/real_liquid_glass.dart';
import '../../widgets/notes/create_note_sheet.dart';
import '../../widgets/notes/note_grid.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  bool _drawerOpen = false;
  late AnimationController _drawerAnimCtrl;
  late Animation<double> _drawerSlide;
  late Animation<double> _drawerFade;
  double _edgeSwipeDx = 0;

  @override
  void initState() {
    super.initState();
    _drawerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _drawerSlide = Tween(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _drawerAnimCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _drawerFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _drawerAnimCtrl, curve: Curves.easeOutCubic),
    );
    _setupRealtimeRefresh();
  }

  @override
  void dispose() {
    _drawerAnimCtrl.dispose();
    final realtime = ref.read(realtimeDatasourceProvider);
    realtime.unsubscribe('notes-list');
    super.dispose();
  }

  void _setupRealtimeRefresh() {
    final realtime = ref.read(realtimeDatasourceProvider);
    realtime.subscribeToNotesList(onAnyChange: () {
      if (!mounted) return;
      // Silent refetch — no AsyncLoading flash — so realtime updates don't
      // undo our optimistic mutations or shimmer the grid on every change.
      ref.read(notesProvider.notifier).silentRefresh();
      ref.invalidate(collaboratorCountsProvider);
    });
  }

  void _toggleDrawer() {
    if (_drawerOpen) {
      _drawerAnimCtrl.reverse().then((_) {
        if (mounted) setState(() => _drawerOpen = false);
      });
    } else {
      setState(() => _drawerOpen = true);
      _drawerAnimCtrl.forward();
    }
  }

  Future<void> _closeDrawerIfOpen() async {
    if (!_drawerOpen) return;
    await _drawerAnimCtrl.reverse();
    if (mounted) setState(() => _drawerOpen = false);
  }

  Future<void> _openEditor(Note note) async {
    Haptics.select();
    await _closeDrawerIfOpen();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => NoteEditorSheet(note: note),
    );
  }

  void _openShare(Note note) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => ShareDialog(note: note),
    );
  }

  Future<void> _createNote() async {
    Haptics.select();
    await _closeDrawerIfOpen();
    if (!mounted) return;
    final result = await showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const CreateNoteSheet(),
    );
    if (result != null && mounted) {
      await _openEditor(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = ref.watch(filteredNotesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // If the drawer is open, back closes the drawer. Otherwise back should
      // exit the app (we're at the root of the app's nav stack).
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_drawerOpen) {
          _toggleDrawer();
          return;
        }
        await SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  AppHeader(
                    onMenuTap: _toggleDrawer,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notesProvider.notifier).refresh(),
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: isDark
                          ? const Color(0xFF1A1730)
                          : Colors.white,
                      strokeWidth: 2.5,
                      displacement: 40,
                      edgeOffset: 8,
                      child: filteredNotes.when(
                        data: (notes) => NoteGrid(
                          notes: notes,
                          isLoading: false,
                          onNoteTap: _openEditor,
                          onNoteShare: _openShare,
                        ),
                        loading: () => const NoteGrid(
                          notes: [],
                          isLoading: true,
                        ),
                        error: (e, _) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Something went wrong',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pull down to retry',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          ref.read(notesProvider.notifier).refresh(),
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Invisible 12-px strip down the left edge that catches a
              // swipe-right gesture and opens the drawer. Narrower than
              // before + requires both enough horizontal distance AND fling
              // velocity, so it doesn't steal a `Dismissible` archive swipe
              // that happens to start near the left edge of a card.
              if (!_drawerOpen)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) {
                      _edgeSwipeDx = 0;
                    },
                    onHorizontalDragUpdate: (details) {
                      _edgeSwipeDx += details.delta.dx;
                    },
                    onHorizontalDragEnd: (details) {
                      final vx = details.primaryVelocity ?? 0;
                      final dx = _edgeSwipeDx;
                      _edgeSwipeDx = 0;
                      if (dx > 24 && vx > 260) {
                        Haptics.select();
                        _toggleDrawer();
                      }
                    },
                  ),
                ),
              // Scrim — always in the tree so its fade reversal can finish.
              // `IgnorePointer` makes it untappable when closed so the grid
              // below stays interactive. The `GestureDetector` is only
              // rebuilt when `_drawerOpen` flips, not every frame.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_drawerOpen,
                  child: FadeTransition(
                    opacity: _drawerFade,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleDrawer,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
              // Drawer panel — always mounted so slide-out plays.
              // `Positioned` MUST be a direct child of the outer Stack, so
              // IgnorePointer / AnimatedBuilder / FractionalTranslation all
              // live INSIDE the Positioned subtree. Reversing this nesting
              // was the source of hundreds of "Incorrect use of
              // ParentDataWidget" errors per drawer animation frame.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_drawerOpen,
                  child: AnimatedBuilder(
                    animation: _drawerSlide,
                    builder: (context, child) => FractionalTranslation(
                      translation: Offset(_drawerSlide.value, 0),
                      child: child,
                    ),
                    child: EdgeSwipeDrawer(onClose: _toggleDrawer),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: RealLiquidGlass.circle(
          child: SizedBox(
            width: 60,
            height: 60,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _createNote,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 26,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              delay: 250.ms,
              duration: 400.ms,
              curve: Curves.elasticOut,
            ),
        ),
      ),
    );
  }
}
