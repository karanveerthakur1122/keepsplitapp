import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/sign_out_helper.dart';
import '../../../data/datasources/remote/supabase_collaborator_datasource.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notes_provider.dart';

class EdgeSwipeDrawer extends ConsumerWidget {
  const EdgeSwipeDrawer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final section = ref.watch(dashboardSectionProvider);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    final displayName = profileAsync.valueOrNull?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        user?.email ??
        '';

    final items = [
      _DrawerItem(Icons.notes_rounded, 'All Notes', DashboardSection.all),
      _DrawerItem(Icons.push_pin_rounded, 'Pinned', DashboardSection.pinned),
      _DrawerItem(Icons.people_rounded, 'Shared', DashboardSection.shared),
      _DrawerItem(Icons.archive_rounded, 'Archived', DashboardSection.archived),
      _DrawerItem(Icons.delete_rounded, 'Trash', DashboardSection.trash),
    ];

    return RepaintBoundary(
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : const Color(0xFFF6F3FF),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border(
            right: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 12, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primary.withValues(alpha: 0.2),
                                scheme.tertiary.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              displayName.initials,
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isEmpty ? 'User' : displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user?.email != null)
                                Text(
                                  user!.email!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onClose,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...items.map((item) {
                    final selected = section == item.section;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 1),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            item.icon,
                            size: 20,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? scheme.primary : null,
                              fontSize: 14,
                            ),
                          ),
                          selected: selected,
                          selectedTileColor:
                              scheme.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          visualDensity:
                              const VisualDensity(horizontal: 0, vertical: -2),
                          onTap: () {
                            Haptics.tap();
                            ref.read(dashboardSectionProvider.notifier).state =
                                item.section;
                            onClose();
                          },
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.vpn_key_outlined, size: 20),
                        title: const Text('Join with code',
                            style: TextStyle(fontSize: 14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity:
                            const VisualDensity(horizontal: 0, vertical: -2),
                        onTap: () {
                          onClose();
                          Haptics.tap();
                          _showJoinDialog(context, ref);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.settings_outlined, size: 20),
                        title: const Text('Settings',
                            style: TextStyle(fontSize: 14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity:
                            const VisualDensity(horizontal: 0, vertical: -2),
                        onTap: () {
                          onClose();
                          context.push('/settings');
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded,
                            size: 20, color: scheme.error.withValues(alpha: 0.8)),
                        title: Text('Sign out',
                            style: TextStyle(
                                fontSize: 14,
                                color: scheme.error.withValues(alpha: 0.8))),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity:
                            const VisualDensity(horizontal: 0, vertical: -2),
                        onTap: () async {
                          onClose();
                          await performSignOut(ref);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem(this.icon, this.label, this.section);
  final IconData icon;
  final String label;
  final DashboardSection section;
}

void _showJoinDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _JoinByCodeDialog(),
  );
}

class _JoinByCodeDialog extends ConsumerStatefulWidget {
  const _JoinByCodeDialog();

  @override
  ConsumerState<_JoinByCodeDialog> createState() => _JoinByCodeDialogState();
}

class _JoinByCodeDialogState extends ConsumerState<_JoinByCodeDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter an invite code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() {
          _error = 'You must be signed in';
          _loading = false;
        });
        return;
      }
      final client = ref.read(supabaseClientProvider);
      final ds = SupabaseCollaboratorDatasource(client);
      // Accept either raw token OR a full URL — extract the last path segment.
      final token = code.contains('/') ? code.split('/').last : code;
      // Capture the messenger BEFORE popping — after pop, this context is
      // deactivated and showing a SnackBar on it will fail silently.
      final messenger = ScaffoldMessenger.maybeOf(context);
      await ds.joinViaToken(token, user.id);
      ref.invalidate(notesProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Successfully joined the note')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid share token')) {
      return 'Invite code is invalid or expired.';
    }
    if (s.contains('not authenticated')) {
      return 'You must be signed in.';
    }
    if (s.contains('violates foreign key') || s.contains('23503')) {
      return 'Account setup incomplete. Please sign out and sign back in, then try again.';
    }
    if (s.contains('does not exist') || s.contains('42883')) {
      return 'Server is not set up for collaboration yet. Ask the note owner to update the database.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('host lookup')) {
      return 'No internet connection.';
    }
    return 'Couldn\'t join. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Join a note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste the invite code someone shared with you.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Invite code',
              prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
            ),
            onSubmitted: (_) => _join(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _join,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}
