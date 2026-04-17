import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/datasources/remote/supabase_collaborator_datasource.dart';
import '../../../domain/entities/collaborator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaborator_counts_provider.dart';
import '../../providers/collaborators_provider.dart';
import '../../providers/notes_provider.dart';

class CollaboratorManager extends ConsumerWidget {
  const CollaboratorManager({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collabsAsync = ref.watch(collaboratorsProvider(noteId));
    final scheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collaborators',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        collabsAsync.when(
          data: (collabs) {
            if (collabs.isEmpty) {
              return Text(
                'No collaborators yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              );
            }

            final isCurrentUserCollaborator = currentUser != null &&
                collabs.any((c) =>
                    c.userId == currentUser.id &&
                    c.permission != NotePermission.owner);

            return Column(
              children: [
                ...collabs.map((c) {
                  final label = (c.displayName ?? c.invitedEmail ?? '?');
                  final initial =
                      label.isEmpty ? '?' : label[0].toUpperCase();
                  final isOwner = c.permission == NotePermission.owner;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          scheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      label.isEmpty ? c.userId.take(8) : label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: isOwner
                        ? Chip(
                            label: const Text('Owner'),
                            labelStyle:
                                Theme.of(context).textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )
                        : DropdownButton<String>(
                            value: c.permission.name,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            style:
                                Theme.of(context).textTheme.labelSmall,
                            items: const [
                              DropdownMenuItem(
                                  value: 'editor',
                                  child: Text('Editor')),
                              DropdownMenuItem(
                                  value: 'viewer',
                                  child: Text('Viewer')),
                            ],
                            onChanged: (value) async {
                              if (value == null) return;
                              final client =
                                  ref.read(supabaseClientProvider);
                              final ds =
                                  SupabaseCollaboratorDatasource(client);
                              await ds.updatePermission(
                                collaboratorId: c.id,
                                permission: value,
                              );
                              ref.invalidate(
                                  collaboratorsProvider(noteId));
                            },
                          ),
                  );
                }),
                if (isCurrentUserCollaborator) ...[
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveNote(context, ref),
                      icon: Icon(Icons.exit_to_app_rounded,
                          size: 16, color: scheme.error),
                      label: Text('Leave note',
                          style: TextStyle(color: scheme.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Future<void> _leaveNote(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave note?'),
        content: const Text(
            'You will lose access to this note. You can be re-invited later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    Haptics.confirm();
    final client = ref.read(supabaseClientProvider);
    final ds = SupabaseCollaboratorDatasource(client);
    await ds.leaveNote(noteId, user.id);
    ref.invalidate(notesProvider);
    ref.invalidate(collaboratorsProvider(noteId));
    ref.invalidate(collaboratorCountsProvider);

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
