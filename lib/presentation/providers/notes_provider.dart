import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/local/drift_database.dart';
import '../../data/datasources/local/notes_local_datasource.dart';
import '../../data/datasources/remote/supabase_notes_datasource.dart';
import '../../data/repositories/notes_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import 'auth_provider.dart';
import 'collaborator_counts_provider.dart';
import 'note_order_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final notesLocalDatasourceProvider = Provider<NotesLocalDatasource>(
  (ref) => NotesLocalDatasource(ref.watch(databaseProvider)),
);

final notesRemoteDatasourceProvider = Provider<SupabaseNotesDatasource>(
  (ref) => SupabaseNotesDatasource(ref.watch(supabaseClientProvider)),
);

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepositoryImpl(
    ref.watch(notesRemoteDatasourceProvider),
    ref.watch(notesLocalDatasourceProvider),
  ),
);

enum DashboardSection { all, pinned, shared, archived, trash }

final dashboardSectionProvider =
    StateProvider<DashboardSection>((ref) => DashboardSection.all);

final searchQueryProvider = StateProvider<String>((ref) => '');

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = ref.watch(notesRepositoryProvider);
    return repo.getNotes();
  }

  /// Hard-refresh from the repository. Flips to AsyncLoading (shimmer / grid
  /// flash). Use only for pull-to-refresh or rollback after an optimistic
  /// mutation fails.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(notesRepositoryProvider).getNotes();
    });
  }

  /// Refetch the notes list without passing through AsyncLoading — the UI
  /// never "flashes". Use for realtime-driven refreshes so a single remote
  /// change doesn't trigger a whole-grid shimmer.
  Future<void> silentRefresh() async {
    try {
      final fresh = await ref.read(notesRepositoryProvider).getNotes();
      state = AsyncData(fresh);
    } catch (_) {
      // Keep current state; the next mutation or explicit refresh recovers.
    }
  }

  /// Patch the local list in-place without flipping to AsyncLoading, so the
  /// UI never "flashes" during mutations.
  void _patch(List<Note> Function(List<Note> current) transform) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(transform(current));
  }

  /// Run [op] in the background; on error, roll back to a fresh fetch.
  /// The UI has already been updated optimistically before this returns.
  void _fireAndForget(Future<void> Function() op) {
    op().catchError((_) {
      refresh();
    });
  }

  Future<Note> create({String title = '', String content = ''}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Not authenticated');
    final now = DateTime.now().toUtc();
    final note = Note(
      id: const Uuid().v4(),
      userId: user.id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    // Await the repo so the editor can open with the real server id; then
    // just prepend to local state (no full refresh).
    final created = await ref.read(notesRepositoryProvider).createNote(note);
    _patch((list) => [created, ...list]);
    return created;
  }

  Future<void> updateNote(Note note) async {
    final updated = note.copyWith(updatedAt: DateTime.now().toUtc());
    _patch((list) =>
        list.map((n) => n.id == updated.id ? updated : n).toList());
    _fireAndForget(
        () => ref.read(notesRepositoryProvider).updateNote(updated));
  }

  Future<void> delete(String id) async {
    _patch((list) => list.where((n) => n.id != id).toList());
    _fireAndForget(() => ref.read(notesRepositoryProvider).deleteNote(id));
  }

  Future<void> pin(String id, bool pinned) async {
    _patch((list) =>
        list.map((n) => n.id == id ? n.copyWith(isPinned: pinned) : n).toList());
    _fireAndForget(
        () => ref.read(notesRepositoryProvider).pinNote(id, pinned));
  }

  Future<void> archive(String id, bool archived) async {
    _patch((list) => list
        .map((n) => n.id == id ? n.copyWith(isArchived: archived) : n)
        .toList());
    _fireAndForget(
        () => ref.read(notesRepositoryProvider).archiveNote(id, archived));
  }

  Future<void> trash(String id) async {
    _patch((list) => list.map((n) {
          if (n.id != id) return n;
          if (n.labels.contains('_trashed_')) return n;
          return n.copyWith(labels: [...n.labels, '_trashed_']);
        }).toList());
    _fireAndForget(() => ref.read(notesRepositoryProvider).trashNote(id));
  }

  Future<void> restore(String id) async {
    _patch((list) => list.map((n) {
          if (n.id != id) return n;
          final labels = [...n.labels]..remove('_trashed_');
          return n.copyWith(labels: labels, isArchived: false);
        }).toList());
    _fireAndForget(() => ref.read(notesRepositoryProvider).restoreNote(id));
  }
}

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final section = ref.watch(dashboardSectionProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final currentUser = ref.watch(currentUserProvider);
  final counts = ref.watch(collaboratorCountsProvider).valueOrNull ??
      const <String, int>{};

  return notesAsync.whenData((notes) {
    var filtered = notes.where((n) {
      final isTrashed = n.labels.contains('_trashed_');
      switch (section) {
        case DashboardSection.all:
          return !isTrashed && !n.isArchived;
        case DashboardSection.pinned:
          return n.isPinned && !isTrashed && !n.isArchived;
        case DashboardSection.shared:
          // A note belongs in "Shared" if either:
          //   - I'm not the owner (it was shared WITH me), OR
          //   - I own it AND there is at least 1 collaborator.
          final isSharedWithMe = n.userId != (currentUser?.id ?? '');
          final iHaveCollabs = n.userId == (currentUser?.id ?? '') &&
              (counts[n.id] ?? 0) > 0;
          return !isTrashed &&
              !n.isArchived &&
              (isSharedWithMe || iHaveCollabs);
        case DashboardSection.archived:
          return n.isArchived && !isTrashed;
        case DashboardSection.trash:
          return isTrashed;
      }
    });

    if (query.isNotEmpty) {
      filtered = filtered.where((n) =>
          n.title.toLowerCase().contains(query) ||
          n.content.toLowerCase().contains(query));
    }

    final list = filtered.toList();

    final customOrder = ref.watch(noteOrderProvider);
    if (customOrder.isNotEmpty) {
      final orderMap = <String, int>{};
      for (int i = 0; i < customOrder.length; i++) {
        orderMap[customOrder[i]] = i;
      }
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aIdx = orderMap[a.id];
        final bIdx = orderMap[b.id];
        if (aIdx != null && bIdx != null) return aIdx.compareTo(bIdx);
        if (aIdx != null) return -1;
        if (bIdx != null) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    } else {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    }

    return list;
  });
});
