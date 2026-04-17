import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/note.dart';
import 'drift_database.dart';

class NotesLocalDatasource {
  NotesLocalDatasource(this._db);

  final AppDatabase _db;

  Future<List<Note>> getAllNotes() async {
    final rows = await _db.select(_db.localNotes).get();
    return rows.map(_rowToEntity).toList();
  }

  Future<Note?> getNote(String id) async {
    final query = _db.select(_db.localNotes)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _rowToEntity(row);
  }

  Future<void> upsertNote(Note note) async {
    await _db.into(_db.localNotes).insertOnConflictUpdate(
          LocalNotesCompanion.insert(
            id: note.id,
            userId: note.userId,
            title: Value(note.title),
            content: Value(note.content),
            color: Value(note.color),
            isPinned: Value(note.isPinned),
            isArchived: Value(note.isArchived),
            isChecklist: Value(note.isChecklist),
            labels: Value(jsonEncode(note.labels)),
            shareToken: Value(note.shareToken),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
          ),
        );
  }

  Future<void> upsertNotes(List<Note> notes) async {
    await _db.batch((batch) {
      for (final note in notes) {
        batch.insert(
          _db.localNotes,
          LocalNotesCompanion.insert(
            id: note.id,
            userId: note.userId,
            title: Value(note.title),
            content: Value(note.content),
            color: Value(note.color),
            isPinned: Value(note.isPinned),
            isArchived: Value(note.isArchived),
            isChecklist: Value(note.isChecklist),
            labels: Value(jsonEncode(note.labels)),
            shareToken: Value(note.shareToken),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
          ),
          onConflict: DoUpdate((_) => LocalNotesCompanion(
                title: Value(note.title),
                content: Value(note.content),
                color: Value(note.color),
                isPinned: Value(note.isPinned),
                isArchived: Value(note.isArchived),
                isChecklist: Value(note.isChecklist),
                labels: Value(jsonEncode(note.labels)),
                shareToken: Value(note.shareToken),
                updatedAt: Value(note.updatedAt),
              )),
        );
      }
    });
  }

  Future<void> deleteNote(String id) async {
    await (_db.delete(_db.localNotes)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Note>> watchNotes() {
    return _db.select(_db.localNotes).watch().map(
          (rows) => rows.map(_rowToEntity).toList(),
        );
  }

  Note _rowToEntity(LocalNote row) {
    List<String> labels = [];
    try {
      labels = List<String>.from(jsonDecode(row.labels));
    } catch (_) {}

    return Note(
      id: row.id,
      userId: row.userId,
      title: row.title,
      content: row.content,
      color: row.color,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
      isChecklist: row.isChecklist,
      labels: labels,
      shareToken: row.shareToken,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
