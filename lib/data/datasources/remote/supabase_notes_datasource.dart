import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/note_model.dart';

class SupabaseNotesDatasource {
  SupabaseNotesDatasource(this._client);
  final SupabaseClient _client;

  Future<List<NoteModel>> getNotes() async {
    final userId = _client.auth.currentUser!.id;

    final ownedNotes = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    final collaboratorRows = await _client
        .from('note_collaborators')
        .select('note_id')
        .eq('user_id', userId);

    final collabNoteIds = (collaboratorRows as List)
        .map((r) => r['note_id'] as String)
        .toList();

    List<Map<String, dynamic>> collabNotes = [];
    if (collabNoteIds.isNotEmpty) {
      collabNotes = await _client
          .from('notes')
          .select()
          .inFilter('id', collabNoteIds)
          .order('updated_at', ascending: false);
    }

    final allNoteIds = <String>{};
    final allNotes = <NoteModel>[];

    for (final json in [...ownedNotes, ...collabNotes]) {
      final model = NoteModel.fromJson(json);
      if (allNoteIds.add(model.id)) {
        allNotes.add(model);
      }
    }

    return allNotes;
  }

  Future<NoteModel?> getNote(String id) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return NoteModel.fromJson(response);
  }

  Future<NoteModel> createNote(NoteModel note) async {
    final response = await _client
        .from('notes')
        .insert(note.toInsertJson())
        .select()
        .single();

    return NoteModel.fromJson(response);
  }

  Future<NoteModel> updateNote(NoteModel note) async {
    final response = await _client
        .from('notes')
        .update(note.toUpdateJson())
        .eq('id', note.id)
        .select()
        .single();

    return NoteModel.fromJson(response);
  }

  Future<void> deleteNote(String id) async {
    await _client.from('notes').delete().eq('id', id);
  }

  Future<void> pinNote(String id, bool pinned) async {
    await _client.from('notes').update({'is_pinned': pinned}).eq('id', id);
  }

  Future<void> archiveNote(String id, bool archived) async {
    await _client.from('notes').update({'is_archived': archived}).eq('id', id);
  }

  Future<void> trashNote(String id) async {
    final note = await getNote(id);
    if (note == null) return;
    final labels = List<String>.from(note.labels);
    if (!labels.contains('_trashed_')) {
      labels.add('_trashed_');
    }
    await _client.from('notes').update({'labels': labels}).eq('id', id);
  }

  Future<void> restoreNote(String id) async {
    final note = await getNote(id);
    if (note == null) return;
    final labels = List<String>.from(note.labels)..remove('_trashed_');
    await _client.from('notes').update({
      'labels': labels,
      'is_archived': false,
    }).eq('id', id);
  }

  Future<String> generateShareToken(String noteId) async {
    final token = const Uuid().v4();
    await _client
        .from('notes')
        .update({'share_token': token}).eq('id', noteId);
    return token;
  }

  Future<void> removeShareToken(String noteId) async {
    await _client
        .from('notes')
        .update({'share_token': null}).eq('id', noteId);
  }

  Future<NoteModel?> getNoteByShareToken(String token) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('share_token', token)
        .maybeSingle();

    if (response == null) return null;
    return NoteModel.fromJson(response);
  }
}
