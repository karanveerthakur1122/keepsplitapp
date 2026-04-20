import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/supabase_collaborator_datasource.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/profile.dart';
import 'auth_provider.dart';
import 'expense_settings_provider.dart';

/// The single source of truth for who has access to a note, including the
/// owner (synthesized at index 0). Invalidate this after inviting/removing
/// collaborators, changing permissions, or transferring ownership.
final collaboratorsProvider =
    FutureProvider.family<List<Collaborator>, String>((ref, noteId) async {
  final client = ref.watch(supabaseClientProvider);
  final ds = SupabaseCollaboratorDatasource(client);
  final authDS = ref.watch(authDatasourceProvider);

  // Fetch the note to get the owner's user_id.
  final noteRow = await client
      .from('notes')
      .select('user_id')
      .eq('id', noteId)
      .maybeSingle();

  final ownerId = noteRow?['user_id'] as String?;

  // Fetch collaborators from note_collaborators table.
  final models = await ds.getCollaborators(noteId);
  final collabs = models.map((m) => m.toEntity()).toList();

  // Synthesize an owner row so the UI can always show them.
  if (ownerId != null && !collabs.any((c) => c.userId == ownerId)) {
    Profile? ownerProfile;
    try {
      final p = await authDS.getProfile(ownerId);
      ownerProfile = p?.toEntity();
    } catch (_) {}

    collabs.insert(
      0,
      Collaborator(
        id: 'owner-$ownerId',
        noteId: noteId,
        userId: ownerId,
        permission: NotePermission.owner,
        createdAt: DateTime.now(),
        displayName: ownerProfile?.displayName,
        avatarUrl: ownerProfile?.avatarUrl,
      ),
    );
  } else {
    // Ensure the existing owner row (if any) is the first entry.
    final ownerIdx = collabs.indexWhere((c) => c.userId == ownerId);
    if (ownerIdx > 0) {
      final owner = collabs.removeAt(ownerIdx);
      collabs.insert(0, owner);
    }
  }

  return collabs;
});

typedef AccessibleUser = ({String userId, String displayName});

/// Derived provider: all users who can participate in expense splits.
/// Merges real collaborators with manually-added users so the payer/split
/// chips show everyone.
final accessibleUsersProvider =
    FutureProvider.family<List<AccessibleUser>, String>((ref, noteId) async {
  final collabs = await ref.watch(collaboratorsProvider(noteId).future);
  final result = collabs
      .map((c) => (
            userId: c.userId,
            displayName: c.displayName ??
                c.invitedEmail ??
                c.userId.take(8),
          ))
      .toList();

  // Append manual users added via Expense Settings.
  final manualUsers =
      await ref.watch(noteManualUsersProvider(noteId).future);
  for (final mu in manualUsers) {
    result.add((userId: mu.id, displayName: mu.displayName));
  }

  return result;
});

/// Shared helper for resolving a user id to a human-readable name using the
/// list from [accessibleUsersProvider]. Falls back to the first 8 chars of
/// the id so the UI never shows a blank string.
String resolveDisplayName(List<AccessibleUser> users, String userId) {
  for (final u in users) {
    if (u.userId == userId) return u.displayName;
  }
  return userId.take(8);
}
