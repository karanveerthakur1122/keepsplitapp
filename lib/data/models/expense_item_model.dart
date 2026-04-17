import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/expense_item.dart';
import 'participant_model.dart';

part 'expense_item_model.freezed.dart';
part 'expense_item_model.g.dart';

@freezed
class ExpenseItemModel with _$ExpenseItemModel {
  const ExpenseItemModel._();

  const factory ExpenseItemModel({
    required String id,
    @JsonKey(name: 'expense_id') required String expenseId,
    @Default('') String name,
    @Default(0) double price,
    @JsonKey(name: 'payer_id') String? payerId,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'expense_item_participants') @Default([]) List<ParticipantModel> expenseItemParticipants,
  }) = _ExpenseItemModel;

  factory ExpenseItemModel.fromJson(Map<String, dynamic> json) => _$ExpenseItemModelFromJson(json);

  ExpenseItem toEntity() => ExpenseItem(
        id: id,
        expenseId: expenseId,
        name: name,
        price: price,
        payerId: payerId,
        createdAt: DateTime.parse(createdAt),
        participants: expenseItemParticipants.map((p) => p.toEntity()).toList(),
      );

  factory ExpenseItemModel.fromEntity(ExpenseItem entity) => ExpenseItemModel(
        id: entity.id,
        expenseId: entity.expenseId,
        name: entity.name,
        price: entity.price,
        payerId: entity.payerId,
        createdAt: entity.createdAt.toIso8601String(),
        expenseItemParticipants: entity.participants.map((p) => ParticipantModel.fromEntity(p)).toList(),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'expense_id': expenseId,
        'name': name,
        'price': price,
        if (payerId != null) 'payer_id': payerId,
      };
}
