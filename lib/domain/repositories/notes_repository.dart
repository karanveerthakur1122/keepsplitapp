import '../entities/note.dart';

abstract class NotesRepository {
  Future<List<Note>> getNotes();
  Future<Note?> getNote(String id);
  Future<Note> createNote(Note note);
  Future<Note> updateNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> pinNote(String id, bool pinned);
  Future<void> archiveNote(String id, bool archived);
  Future<void> trashNote(String id);
  Future<void> restoreNote(String id);
  Future<String> generateShareToken(String noteId);
  Future<void> removeShareToken(String noteId);
  Future<Note?> getNoteByShareToken(String token);
  Stream<List<Note>> watchNotes();
}
