import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/participant.dart';

part 'participant_model.freezed.dart';
part 'participant_model.g.dart';

@freezed
class ParticipantModel with _$ParticipantModel {
  const ParticipantModel._();

  const factory ParticipantModel({
    required String id,
    @JsonKey(name: 'item_id') required String itemId,
    @JsonKey(name: 'user_id') required String userId,
  }) = _ParticipantModel;

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => _$ParticipantModelFromJson(json);

  Participant toEntity() => Participant(id: id, itemId: itemId, userId: userId);

  factory ParticipantModel.fromEntity(Participant entity) => ParticipantModel(
        id: entity.id,
        itemId: entity.itemId,
        userId: entity.userId,
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'item_id': itemId,
        'user_id': userId,
      };
}
