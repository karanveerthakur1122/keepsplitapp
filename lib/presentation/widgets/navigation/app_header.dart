import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/sign_out_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_provider.dart';
import '../../providers/notes_provider.dart';
import '../liquid_glass/liquid_glass_elevated.dart';

class AppHeader extends ConsumerStatefulWidget {
  const AppHeader({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  int _debounceVersion = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceVersion++;
    final version = _debounceVersion;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (version == _debounceVersion && mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });
  }

  String _sectionTitle(DashboardSection section) {
    switch (section) {
      case DashboardSection.all:
        return 'All Notes';
      case DashboardSection.pinned:
        return 'Pinned';
      case DashboardSection.shared:
        return 'Shared';
      case DashboardSection.archived:
        return 'Archived';
      case DashboardSection.trash:
        return 'Trash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final section = ref.watch(dashboardSectionProvider);
    final layout = ref.watch(layoutModeProvider);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    final displayName = profileAsync.valueOrNull?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        '';

    return LiquidGlassElevated(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onMenuTap,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.menu_rounded, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  ),
                  child: _searching
                      ? TextField(
                          key: const ValueKey('search'),
                          controller: _searchCtrl,
                          autofocus: true,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search notes...',
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: _onSearchChanged,
                        )
                      : Text(
                          _sectionTitle(section),
                          key: ValueKey(section),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                        ),
                ),
              ),
              _HeaderIconButton(
                icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                onPressed: () {
                  Haptics.tap();
                  setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _searchCtrl.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    }
                  });
                },
              ),
              _HeaderIconButton(
                icon: layout == LayoutMode.card
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_rounded,
                onPressed: () {
                  Haptics.tap();
                  ref.read(layoutModeProvider.notifier).toggle();
                },
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      displayName.initials,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: const Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: scheme.error),
                        const SizedBox(width: 10),
                        Text('Sign out',
                            style: TextStyle(color: scheme.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'settings') {
                    context.push('/settings');
                  } else if (value == 'signout') {
                    await performSignOut(ref);
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
