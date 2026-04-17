import 'package:freezed_annotation/freezed_annotation.dart';

part 'collaborator.freezed.dart';
part 'collaborator.g.dart';

enum NotePermission {
  @JsonValue('owner')
  owner,
  @JsonValue('editor')
  editor,
  @JsonValue('viewer')
  viewer,
}

@freezed
class Collaborator with _$Collaborator {
  const factory Collaborator({
    required String id,
    required String noteId,
    required String userId,
    required NotePermission permission,
    String? invitedBy,
    String? invitedEmail,
    required DateTime createdAt,
    String? displayName,
    String? avatarUrl,
  }) = _Collaborator;

  factory Collaborator.fromJson(Map<String, dynamic> json) => _$CollaboratorFromJson(json);
}
