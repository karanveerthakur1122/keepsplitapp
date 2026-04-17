import 'package:freezed_annotation/freezed_annotation.dart';
import 'participant.dart';

part 'expense_item.freezed.dart';
part 'expense_item.g.dart';

@freezed
class ExpenseItem with _$ExpenseItem {
  const factory ExpenseItem({
    required String id,
    required String expenseId,
    @Default('') String name,
    @Default(0) double price,
    String? payerId,
    required DateTime createdAt,
    @Default([]) List<Participant> participants,
  }) = _ExpenseItem;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => _$ExpenseItemFromJson(json);
}
