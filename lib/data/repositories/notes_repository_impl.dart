import 'dart:async';

import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/local/notes_local_datasource.dart';
import '../datasources/remote/supabase_notes_datasource.dart';
import '../models/note_model.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._remote, this._local);
  final SupabaseNotesDatasource _remote;
  final NotesLocalDatasource _local;

  @override
  Future<List<Note>> getNotes() async {
    final cached = await _local.getAllNotes();
    if (cached.isNotEmpty) {
      _syncFromRemote();
      return cached;
    }
    return _syncFromRemote();
  }

  Future<List<Note>> _syncFromRemote() async {
    try {
      final models = await _remote.getNotes();
      final entities = models.map((m) => m.toEntity()).toList();
      await _local.upsertNotes(entities);
      return entities;
    } catch (_) {
      return await _local.getAllNotes();
    }
  }

  @override
  Future<Note?> getNote(String id) async {
    final cached = await _local.getNote(id);
    if (cached != null) return cached;
    final model = await _remote.getNote(id);
    if (model == null) return null;
    final entity = model.toEntity();
    await _local.upsertNote(entity);
    return entity;
  }

  @override
  Future<Note> createNote(Note note) async {
    await _local.upsertNote(note);
    try {
      final model = await _remote.createNote(NoteModel.fromEntity(note));
      final entity = model.toEntity();
      await _local.upsertNote(entity);
      return entity;
    } catch (_) {
      return note;
    }
  }

  @override
  Future<Note> updateNote(Note note) async {
    await _local.upsertNote(note);
    try {
      final model = await _remote.updateNote(NoteModel.fromEntity(note));
      final entity = model.toEntity();
      await _local.upsertNote(entity);
      return entity;
    } catch (_) {
      return note;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    await _local.deleteNote(id);
    try {
      await _remote.deleteNote(id);
    } catch (_) {}
  }

  @override
  Future<void> pinNote(String id, bool pinned) async {
    final note = await _local.getNote(id);
    if (note != null) {
      await _local.upsertNote(note.copyWith(isPinned: pinned));
    }
    try {
      await _remote.pinNote(id, pinned);
    } catch (_) {}
  }

  @override
  Future<void> archiveNote(String id, bool archived) async {
    final note = await _local.getNote(id);
    if (note != null) {
      await _local.upsertNote(note.copyWith(isArchived: archived));
    }
    try {
      await _remote.archiveNote(id, archived);
    } catch (_) {}
  }

  @override
  Future<void> trashNote(String id) async {
    final note = await _local.getNote(id);
    if (note != null) {
      final labels = List<String>.from(note.labels);
      if (!labels.contains('_trashed_')) labels.add('_trashed_');
      await _local.upsertNote(note.copyWith(labels: labels));
    }
    try {
      await _remote.trashNote(id);
    } catch (_) {}
  }

  @override
  Future<void> restoreNote(String id) async {
    final note = await _local.getNote(id);
    if (note != null) {
      final labels = List<String>.from(note.labels)..remove('_trashed_');
      await _local.upsertNote(note.copyWith(labels: labels, isArchived: false));
    }
    try {
      await _remote.restoreNote(id);
    } catch (_) {}
  }

  @override
  Future<String> generateShareToken(String noteId) =>
      _remote.generateShareToken(noteId);

  @override
  Future<void> removeShareToken(String noteId) =>
      _remote.removeShareToken(noteId);

  @override
  Future<Note?> getNoteByShareToken(String token) async {
    final model = await _remote.getNoteByShareToken(token);
    return model?.toEntity();
  }

  @override
  Stream<List<Note>> watchNotes() => _local.watchNotes();
}
