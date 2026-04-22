import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_toast.dart';
import '../../../data/datasources/remote/supabase_collaborator_datasource.dart';
import '../../../domain/entities/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaborator_counts_provider.dart';
import '../../providers/collaborators_provider.dart';
import '../../providers/notes_provider.dart';
import '../liquid_glass/liquid_glass_input.dart';
import 'collaborator_manager.dart';

class ShareDialog extends ConsumerStatefulWidget {
  const ShareDialog({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<ShareDialog> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _shareToken;
  String _invitePermission = 'editor';

  @override
  void initState() {
    super.initState();
    _shareToken = widget.note.shareToken;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _inviteByEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() => _loading = true);
    try {
      final datasource = SupabaseCollaboratorDatasource(
        ref.read(supabaseClientProvider),
      );
      final authDS = ref.read(authDatasourceProvider);
      final profile = await authDS.getProfileByEmail(email);
      if (profile == null) {
        AppToast.error('No user found with email: $email');
        return;
      }

      final user = ref.read(currentUserProvider);
      await datasource.addCollaborator(
        noteId: widget.note.id,
        userId: profile.userId,
        permission: _invitePermission,
        invitedBy: user?.id ?? '',
        invitedEmail: email,
      );
      // Refresh the collaborator list + the global counts so every note
      // card stays in sync.
      ref.invalidate(collaboratorsProvider(widget.note.id));
      ref.invalidate(collaboratorCountsProvider);
      _emailCtrl.clear();
      AppToast.success('Collaborator added!');
    } catch (e) {
      AppToast.error('Failed to invite collaborator');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateLink() async {
    setState(() => _loading = true);
    try {
      final token = await ref
          .read(notesRepositoryProvider)
          .generateShareToken(widget.note.id);
      setState(() {
        _shareToken = token;
      });
      ref.invalidate(notesProvider);
      AppToast.success('Invite code created');
    } catch (e) {
      AppToast.error('Failed to generate invite code');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeLink() async {
    try {
      await ref
          .read(notesRepositoryProvider)
          .removeShareToken(widget.note.id);
      if (!mounted) return;
      // Refresh notes so the card no longer shows the "shared" icon or stale
      // token locally.
      ref.invalidate(notesProvider);
      setState(() => _shareToken = null);
      AppToast.info('Invite code removed');
    } catch (e) {
      AppToast.error('Failed to remove invite code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    // Leave ≥ 40 px of margin top/bottom, plus make room for the keyboard
    // so the email field stays visible while typing.
    final maxDialogHeight =
        size.height - MediaQuery.viewInsetsOf(context).bottom - 80;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: maxDialogHeight > 240 ? maxDialogHeight : 240,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share Note',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text(
                'Invite by email',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassInput(
                      controller: _emailCtrl,
                      hintText: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _invitePermission,
                        isDense: true,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                        items: const [
                          DropdownMenuItem(
                              value: 'editor', child: Text('Editor')),
                          DropdownMenuItem(
                              value: 'viewer', child: Text('Viewer')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _invitePermission = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _loading ? null : _inviteByEmail,
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Invite code',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Share this code with anyone. They can paste it in '
                '"Join with code" in their drawer menu to collaborate.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 10),
              if (_shareToken != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _shareToken!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: 'monospace',
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy code',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _shareToken!));
                          AppToast.success('Invite code copied to clipboard');
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.link_off_rounded,
                            size: 18, color: scheme.error),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Revoke code',
                        onPressed: _removeLink,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _loading ? null : _generateLink,
                  icon: const Icon(Icons.vpn_key_rounded),
                  label: const Text('Generate invite code'),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              CollaboratorManager(noteId: widget.note.id),
              const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
