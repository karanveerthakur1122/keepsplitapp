import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/collaborator.dart';

part 'collaborator_model.freezed.dart';
part 'collaborator_model.g.dart';

@freezed
class CollaboratorModel with _$CollaboratorModel {
  const CollaboratorModel._();

  const factory CollaboratorModel({
    required String id,
    @JsonKey(name: 'note_id') required String noteId,
    @JsonKey(name: 'user_id') required String userId,
    required String permission,
    @JsonKey(name: 'invited_by') String? invitedBy,
    @JsonKey(name: 'invited_email') String? invitedEmail,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
  }) = _CollaboratorModel;

  factory CollaboratorModel.fromJson(Map<String, dynamic> json) => _$CollaboratorModelFromJson(json);

  Collaborator toEntity() => Collaborator(
        id: id,
        noteId: noteId,
        userId: userId,
        permission: NotePermission.values.firstWhere(
          (e) => e.name == permission,
          orElse: () => NotePermission.viewer,
        ),
        invitedBy: invitedBy,
        invitedEmail: invitedEmail,
        createdAt: DateTime.parse(createdAt),
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

  factory CollaboratorModel.fromEntity(Collaborator entity) => CollaboratorModel(
        id: entity.id,
        noteId: entity.noteId,
        userId: entity.userId,
        permission: entity.permission.name,
        invitedBy: entity.invitedBy,
        invitedEmail: entity.invitedEmail,
        createdAt: entity.createdAt.toIso8601String(),
        displayName: entity.displayName,
        avatarUrl: entity.avatarUrl,
      );

  Map<String, dynamic> toInsertJson() => {
        'note_id': noteId,
        'user_id': userId,
        'permission': permission,
        'invited_by': invitedBy,
        'invited_email': invitedEmail,
      };
}
