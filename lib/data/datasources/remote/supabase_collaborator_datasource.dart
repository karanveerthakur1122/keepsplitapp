import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/collaborator_model.dart';

class SupabaseCollaboratorDatasource {
  SupabaseCollaboratorDatasource(this._client);
  final SupabaseClient _client;

  Future<List<CollaboratorModel>> getCollaborators(String noteId) async {
    final response = await _client
        .from('note_collaborators')
        .select('''
          *,
          profiles!note_collaborators_user_id_profiles_fkey (
            display_name,
            avatar_url
          )
        ''')
        .eq('note_id', noteId);

    return (response as List).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final json = Map<String, dynamic>.from(row);
      json.remove('profiles');
      if (profile != null) {
        json['display_name'] = profile['display_name'];
        json['avatar_url'] = profile['avatar_url'];
      }
      return CollaboratorModel.fromJson(json);
    }).toList();
  }

  Future<CollaboratorModel> addCollaborator({
    required String noteId,
    required String userId,
    required String permission,
    required String invitedBy,
    String? invitedEmail,
  }) async {
    final response = await _client
        .from('note_collaborators')
        .insert({
          'note_id': noteId,
          'user_id': userId,
          'permission': permission,
          'invited_by': invitedBy,
          'invited_email': invitedEmail,
        })
        .select()
        .single();

    return CollaboratorModel.fromJson(response);
  }

  Future<void> updatePermission({
    required String collaboratorId,
    required String permission,
  }) async {
    await _client
        .from('note_collaborators')
        .update({'permission': permission})
        .eq('id', collaboratorId);
  }

  Future<void> removeCollaborator(String collaboratorId) async {
    await _client
        .from('note_collaborators')
        .delete()
        .eq('id', collaboratorId);
  }

  Future<void> joinViaToken(String token, String userId) async {
    await _client.rpc('join_note_via_token', params: {'p_token': token});
  }

  Future<void> leaveNote(String noteId, String userId) async {
    await _client
        .from('note_collaborators')
        .delete()
        .eq('note_id', noteId)
        .eq('user_id', userId);
  }
}
