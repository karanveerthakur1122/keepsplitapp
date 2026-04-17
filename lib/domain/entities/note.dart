import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';
part 'note.g.dart';

@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String userId,
    @Default('') String title,
    @Default('') String content,
    @Default('#1a1a2e') String color,
    @Default(false) bool isPinned,
    @Default(false) bool isArchived,
    @Default(false) bool isChecklist,
    @Default([]) List<String> labels,
    String? shareToken,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
