// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/note.dart';

part 'note_model.freezed.dart';
part 'note_model.g.dart';

@freezed
class NoteModel with _$NoteModel {
  const NoteModel._();

  const factory NoteModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @Default('') String title,
    @Default('') String content,
    @Default('#1a1a2e') String color,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'is_archived') @Default(false) bool isArchived,
    @JsonKey(name: 'is_checklist') @Default(false) bool isChecklist,
    @Default([]) List<String> labels,
    @JsonKey(name: 'share_token') String? shareToken,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _NoteModel;

  factory NoteModel.fromJson(Map<String, dynamic> json) => _$NoteModelFromJson(json);

  Note toEntity() => Note(
        id: id,
        userId: userId,
        title: title,
        content: content,
        color: color,
        isPinned: isPinned,
        isArchived: isArchived,
        isChecklist: isChecklist,
        labels: labels,
        shareToken: shareToken,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
      );

  factory NoteModel.fromEntity(Note entity) => NoteModel(
        id: entity.id,
        userId: entity.userId,
        title: entity.title,
        content: entity.content,
        color: entity.color,
        isPinned: entity.isPinned,
        isArchived: entity.isArchived,
        isChecklist: entity.isChecklist,
        labels: entity.labels,
        shareToken: entity.shareToken,
        createdAt: entity.createdAt.toIso8601String(),
        updatedAt: entity.updatedAt.toIso8601String(),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'color': color,
        'is_pinned': isPinned,
        'is_archived': isArchived,
        'is_checklist': isChecklist,
        'labels': labels,
        'share_token': shareToken,
      };

  Map<String, dynamic> toUpdateJson() => {
        'title': title,
        'content': content,
        'color': color,
        'is_pinned': isPinned,
        'is_archived': isArchived,
        'is_checklist': isChecklist,
        'labels': labels,
      };
}
