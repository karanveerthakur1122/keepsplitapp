import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/expense.dart';
import 'expense_item_model.dart';

part 'expense_model.freezed.dart';
part 'expense_model.g.dart';

@freezed
class ExpenseModel with _$ExpenseModel {
  const ExpenseModel._();

  const factory ExpenseModel({
    required String id,
    @JsonKey(name: 'note_id') required String noteId,
    @JsonKey(name: 'payer_id') required String payerId,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'expense_items') @Default([]) List<ExpenseItemModel> expenseItems,
  }) = _ExpenseModel;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => _$ExpenseModelFromJson(json);

  Expense toEntity() => Expense(
        id: id,
        noteId: noteId,
        payerId: payerId,
        createdAt: DateTime.parse(createdAt),
        items: expenseItems.map((e) => e.toEntity()).toList(),
      );

  factory ExpenseModel.fromEntity(Expense entity) => ExpenseModel(
        id: entity.id,
        noteId: entity.noteId,
        payerId: entity.payerId,
        createdAt: entity.createdAt.toIso8601String(),
        expenseItems: entity.items.map((e) => ExpenseItemModel.fromEntity(e)).toList(),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'note_id': noteId,
        'payer_id': payerId,
      };
}
