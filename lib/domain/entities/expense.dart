import 'package:freezed_annotation/freezed_annotation.dart';
import 'expense_item.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String noteId,
    required String payerId,
    required DateTime createdAt,
    @Default([]) List<ExpenseItem> items,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
}
