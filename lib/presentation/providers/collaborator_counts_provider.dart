import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'notes_provider.dart';

/// Returns a map of note id → number of collaborator rows for that note.
/// Counts only entries in `note_collaborators` (the owner is NOT counted).
/// A note is considered "shared" when this count is > 0 (i.e. owner + at
/// least one invited user).
///
/// Fetches counts for ALL notes the user can access in a single batched
/// query, so it's cheap even for dozens of notes on screen.
final collaboratorCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final notes = await ref.watch(notesProvider.future);
  if (notes.isEmpty) return const <String, int>{};

  final ids = notes.map((n) => n.id).toList();
  final client = ref.watch(supabaseClientProvider);

  try {
    final rows = await client
        .from('note_collaborators')
        .select('note_id')
        .inFilter('note_id', ids);

    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = row['note_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  } catch (_) {
    // If RLS or network fails, return an empty map — the UI falls back to
    // treating all notes as "not shared" which is a safe default.
    return const <String, int>{};
  }
});

/// Convenience: is this specific note shared (has at least one collaborator
/// besides the owner)?
bool isNoteSharedFromCounts(Map<String, int> counts, String noteId) {
  return (counts[noteId] ?? 0) > 0;
}
