import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/constants/demo_data.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/datasources/remote/supabase_realtime_datasource.dart';
import '../../../domain/entities/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaborator_counts_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../widgets/collaboration/share_dialog.dart';
import '../../widgets/editor/note_editor_sheet.dart';
import '../../widgets/navigation/app_header.dart';
import '../../widgets/navigation/edge_swipe_drawer.dart';
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
  late final SupabaseRealtimeDatasource _realtime;

  final _fabKey = GlobalKey();
  final _demoNoteCardKey = GlobalKey();
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    _realtime = ref.read(realtimeDatasourceProvider);
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
    _realtime.unsubscribe('notes-list');
    _realtime.unsubscribe('collab-notifs');
    super.dispose();
  }

  void _setupRealtimeRefresh() {
    _realtime.subscribeToNotesList(onAnyChange: () {
      if (!mounted) return;
      ref.read(notesProvider.notifier).silentRefresh();
      ref.invalidate(collaboratorCountsProvider);
    });

    final user = ref.read(currentUserProvider);
    if (user != null) {
      _realtime.subscribeToCollabNotifications(
        currentUserId: user.id,
        onCollabEvent: (eventType, record) {
          if (!mounted) return;
          final permission = record['permission'] as String? ?? '';
          final notif = NotificationService.instance;

          if (eventType == 'invited') {
            notif.showSmart(
              title: 'You were added to a note',
              body: 'Someone invited you as $permission.',
            );
          } else if (eventType == 'permission_changed') {
            notif.showSmart(
              title: 'Permission updated',
              body: 'Your role was changed to $permission.',
            );
          }
        },
      );
    }
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

  Future<void> _openEditor(Note note, {bool isDemoTutorial = false}) async {
    Haptics.select();
    await _closeDrawerIfOpen();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => NoteEditorSheet(
        note: note,
        showTutorial: isDemoTutorial,
      ),
    );
    if (isDemoTutorial && mounted) {
      ref.read(tutorialProvider.notifier).markComplete();
    }
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

  void _maybeStartTutorial() {
    if (_tutorialShown) return;
    final hasSeenTutorial = ref.read(tutorialProvider);
    if (hasSeenTutorial) return;
    _tutorialShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_demoNoteCardKey.currentContext == null) return;

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'fab',
          keyTarget: _fabKey,
          alignSkip: Alignment.topCenter,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _CoachContent(
                title: 'Create a note',
                body: 'Tap + to create a new note and start splitting expenses.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'demo_note',
          keyTarget: _demoNoteCardKey,
          alignSkip: Alignment.bottomCenter,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _CoachContent(
                title: 'Sample note',
                body:
                    'This is a demo note with expenses already added. Tap it to see how splits and settlements work!',
              ),
            ),
          ],
        ),
      ];

      final tutorial = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.75,
        textSkip: 'SKIP',
        paddingFocus: 6,
        onClickTarget: (target) {
          if (target.identify == 'demo_note') {
            _openEditor(demoNote, isDemoTutorial: true);
          }
        },
        onSkip: () {
          ref.read(tutorialProvider.notifier).markComplete();
          return true;
        },
      );

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) tutorial.show(context: context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = ref.watch(filteredNotesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentSection = ref.watch(dashboardSectionProvider);
    final isHome = currentSection == DashboardSection.all;

    return PopScope(
      // Block system pop when drawer is open OR we're on a sub-section,
      // so we can intercept and navigate back to "All" first.
      canPop: !_drawerOpen && isHome,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_drawerOpen) {
          _toggleDrawer();
          return;
        }
        if (!isHome) {
          ref.read(dashboardSectionProvider.notifier).state =
              DashboardSection.all;
          return;
        }
        await SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
        body: ColoredBox(
          color: isDark
              ? const Color(0xFF0C0A1D)
              : const Color(0xFFF3F1F9),
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
                        data: (notes) {
                          _maybeStartTutorial();
                          return NoteGrid(
                            notes: notes,
                            isLoading: false,
                            onNoteTap: (note) => _openEditor(note),
                            onNoteShare: _openShare,
                            demoNoteKey: _demoNoteCardKey,
                          );
                        },
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
        floatingActionButton: FloatingActionButton(
          key: _fabKey,
          onPressed: _createNote,
          child: const Icon(Icons.add_rounded, size: 26),
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

class _CoachContent extends StatelessWidget {
  const _CoachContent({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
