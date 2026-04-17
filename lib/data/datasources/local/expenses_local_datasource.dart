import 'package:drift/drift.dart';

import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_item.dart';
import '../../../domain/entities/participant.dart';
import 'drift_database.dart';

class ExpensesLocalDatasource {
  ExpensesLocalDatasource(this._db);

  final AppDatabase _db;

  Future<List<Expense>> getExpensesForNote(String noteId) async {
    final expenses = await (_db.select(_db.localExpenses)
          ..where((t) => t.noteId.equals(noteId)))
        .get();

    final result = <Expense>[];
    for (final exp in expenses) {
      final items = await (_db.select(_db.localExpenseItems)
            ..where((t) => t.expenseId.equals(exp.id)))
          .get();

      final expenseItems = <ExpenseItem>[];
      for (final item in items) {
        final participants = await (_db.select(_db.localItemParticipants)
              ..where((t) => t.itemId.equals(item.id)))
            .get();

        expenseItems.add(ExpenseItem(
          id: item.id,
          expenseId: item.expenseId,
          name: item.name,
          price: item.price,
          createdAt: item.createdAt,
          participants: participants
              .map((p) => Participant(id: p.id, itemId: p.itemId, userId: p.userId))
              .toList(),
        ));
      }

      result.add(Expense(
        id: exp.id,
        noteId: exp.noteId,
        payerId: exp.payerId,
        createdAt: exp.createdAt,
        items: expenseItems,
      ));
    }
    return result;
  }

  Future<void> upsertExpense(Expense expense) async {
    await _db.into(_db.localExpenses).insertOnConflictUpdate(
          LocalExpensesCompanion.insert(
            id: expense.id,
            noteId: expense.noteId,
            payerId: expense.payerId,
            createdAt: expense.createdAt,
          ),
        );

    for (final item in expense.items) {
      await _db.into(_db.localExpenseItems).insertOnConflictUpdate(
            LocalExpenseItemsCompanion.insert(
              id: item.id,
              expenseId: item.expenseId,
              name: Value(item.name),
              price: Value(item.price),
              createdAt: item.createdAt,
            ),
          );

      for (final participant in item.participants) {
        await _db.into(_db.localItemParticipants).insertOnConflictUpdate(
              LocalItemParticipantsCompanion.insert(
                id: participant.id,
                itemId: participant.itemId,
                userId: participant.userId,
              ),
            );
      }
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final items = await (_db.select(_db.localExpenseItems)
          ..where((t) => t.expenseId.equals(expenseId)))
        .get();

    for (final item in items) {
      await (_db.delete(_db.localItemParticipants)
            ..where((t) => t.itemId.equals(item.id)))
          .go();
    }

    await (_db.delete(_db.localExpenseItems)
          ..where((t) => t.expenseId.equals(expenseId)))
        .go();

    await (_db.delete(_db.localExpenses)
          ..where((t) => t.id.equals(expenseId)))
        .go();
  }

  Future<void> deleteExpensesForNote(String noteId) async {
    final expenses = await (_db.select(_db.localExpenses)
          ..where((t) => t.noteId.equals(noteId)))
        .get();

    for (final exp in expenses) {
      await deleteExpense(exp.id);
    }
  }

  Future<void> cacheExpenses(String noteId, List<Expense> expenses) async {
    await deleteExpensesForNote(noteId);
    for (final expense in expenses) {
      await upsertExpense(expense);
    }
  }
}
