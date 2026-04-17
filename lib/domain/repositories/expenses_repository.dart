import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../entities/participant.dart';
import '../entities/settlement.dart';

abstract class ExpensesRepository {
  Future<List<Expense>> getExpensesForNote(String noteId);
  Future<Expense> addExpense({required String noteId, required String payerId});
  Future<void> deleteExpense(String expenseId);
  Future<void> updateExpensePayer({required String expenseId, required String payerId});
  Future<ExpenseItem> addExpenseItem({required String expenseId, required String name, required double price, String? payerId});
  Future<void> updateExpenseItem({required String itemId, String? name, double? price});
  Future<void> deleteExpenseItem(String itemId);
  Future<Participant> addParticipant({required String itemId, required String userId});
  Future<void> removeParticipant(String participantId);
  Future<SettlementResult> computeSettlements({required List<Expense> expenses, required Map<String, String> participantNames});
  Stream<List<Expense>> watchExpenses(String noteId);
}
