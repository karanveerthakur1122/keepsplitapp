import 'dart:isolate';

import 'package:uuid/uuid.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_item.dart';
import '../../domain/entities/participant.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../datasources/local/expenses_local_datasource.dart';
import '../datasources/remote/supabase_expenses_datasource.dart';

class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl(this._remote, this._local);
  final SupabaseExpensesDatasource _remote;
  final ExpensesLocalDatasource _local;

  static const _uuid = Uuid();

  @override
  Future<List<Expense>> getExpensesForNote(String noteId) async {
    try {
      final models = await _remote.getExpensesForNote(noteId);
      final entities = models.map((m) => m.toEntity()).toList();
      await _local.cacheExpenses(noteId, entities);
      return entities;
    } catch (_) {
      return await _local.getExpensesForNote(noteId);
    }
  }

  @override
  Future<Expense> addExpense({
    required String noteId,
    required String payerId,
  }) async {
    final id = _uuid.v4();
    final model = await _remote.addExpense(
      id: id,
      noteId: noteId,
      payerId: payerId,
    );
    final entity = model.toEntity();
    await _local.upsertExpense(entity);
    return entity;
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _local.deleteExpense(expenseId);
    try {
      await _remote.deleteExpense(expenseId);
    } catch (_) {}
  }

  @override
  Future<void> updateExpensePayer({
    required String expenseId,
    required String payerId,
  }) =>
      _remote.updateExpensePayer(expenseId: expenseId, payerId: payerId);

  @override
  Future<ExpenseItem> addExpenseItem({
    required String expenseId,
    required String name,
    required double price,
    String? payerId,
  }) async {
    final id = _uuid.v4();
    final model = await _remote.addExpenseItem(
      id: id,
      expenseId: expenseId,
      name: name,
      price: price,
      payerId: payerId,
    );
    return model.toEntity();
  }

  @override
  Future<void> updateExpenseItem({
    required String itemId,
    String? name,
    double? price,
  }) =>
      _remote.updateExpenseItem(itemId: itemId, name: name, price: price);

  @override
  Future<void> deleteExpenseItem(String itemId) =>
      _remote.deleteExpenseItem(itemId);

  @override
  Future<Participant> addParticipant({
    required String itemId,
    required String userId,
  }) async {
    final id = _uuid.v4();
    final model = await _remote.addParticipant(
      id: id,
      itemId: itemId,
      userId: userId,
    );
    return model.toEntity();
  }

  @override
  Future<void> removeParticipant(String participantId) =>
      _remote.removeParticipant(participantId);

  @override
  Future<SettlementResult> computeSettlements({
    required List<Expense> expenses,
    required Map<String, String> participantNames,
  }) async {
    final input = _SettlementInput(
      expenses: expenses,
      participantNames: participantNames,
    );
    return await Isolate.run(() => _computeInIsolate(input));
  }

  @override
  Stream<List<Expense>> watchExpenses(String noteId) {
    // Polling-based: return a stream that re-fetches periodically
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => getExpensesForNote(noteId));
  }
}

class _SettlementInput {
  _SettlementInput({required this.expenses, required this.participantNames});
  final List<Expense> expenses;
  final Map<String, String> participantNames;
}

SettlementResult _computeInIsolate(_SettlementInput input) {
  final balMap = <String, double>{};
  double total = 0;

  for (final expense in input.expenses) {
    for (final item in expense.items) {
      final price = item.price;
      total += price;
      final partIds = item.participants.map((p) => p.userId).toList();
      if (partIds.isEmpty) continue;
      final share = price / partIds.length;

      // Each item can have its own payer (captured at creation time);
      // fall back to the expense-level payer for legacy rows.
      final payerId = item.payerId ?? expense.payerId;
      balMap[payerId] = (balMap[payerId] ?? 0) + price;
      for (final uid in partIds) {
        balMap[uid] = (balMap[uid] ?? 0) - share;
      }
    }
  }

  final balances = <BalanceEntry>[];
  for (final entry in balMap.entries) {
    if (entry.value.abs() > 0.01) {
      balances.add(BalanceEntry(
        userId: entry.key,
        displayName: input.participantNames[entry.key] ??
            entry.key.substring(0, 8.clamp(0, entry.key.length)),
        balance: (entry.value * 100).roundToDouble() / 100,
      ));
    }
  }

  final creditors = <_SettlementEntry>[];
  final debtors = <_SettlementEntry>[];
  for (final b in balances) {
    if (b.balance > 0.01) {
      creditors.add(_SettlementEntry(b.displayName, b.balance));
    } else if (b.balance < -0.01) {
      debtors.add(_SettlementEntry(b.displayName, -b.balance));
    }
  }

  creditors.sort((a, b) => b.amount.compareTo(a.amount));
  debtors.sort((a, b) => b.amount.compareTo(a.amount));

  final settlements = <Settlement>[];
  int i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final amount = debtors[i].amount < creditors[j].amount
        ? debtors[i].amount
        : creditors[j].amount;
    if (amount > 0.01) {
      settlements.add(Settlement(
        from: debtors[i].name,
        to: creditors[j].name,
        amount: (amount * 100).roundToDouble() / 100,
      ));
    }
    debtors[i].amount -= amount;
    creditors[j].amount -= amount;
    if (debtors[i].amount < 0.01) i++;
    if (creditors[j].amount < 0.01) j++;
  }

  return SettlementResult(
    balances: balances,
    settlements: settlements,
    total: (total * 100).roundToDouble() / 100,
  );
}

class _SettlementEntry {
  _SettlementEntry(this.name, this.amount);
  final String name;
  double amount;
}
