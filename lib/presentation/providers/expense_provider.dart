import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/expenses_local_datasource.dart';
import '../../data/datasources/remote/supabase_expenses_datasource.dart';
import '../../data/repositories/expenses_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/expenses_repository.dart';
import 'auth_provider.dart';
import 'notes_provider.dart';

final expensesLocalDatasourceProvider = Provider<ExpensesLocalDatasource>(
  (ref) => ExpensesLocalDatasource(ref.watch(databaseProvider)),
);

final expensesRemoteDatasourceProvider = Provider<SupabaseExpensesDatasource>(
  (ref) => SupabaseExpensesDatasource(ref.watch(supabaseClientProvider)),
);

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepositoryImpl(
    ref.watch(expensesRemoteDatasourceProvider),
    ref.watch(expensesLocalDatasourceProvider),
  ),
);

final noteExpensesProvider =
    AsyncNotifierProvider.family<NoteExpensesNotifier, List<Expense>, String>(
  NoteExpensesNotifier.new,
);

class NoteExpensesNotifier extends FamilyAsyncNotifier<List<Expense>, String> {
  final _undoStack = <List<Expense>>[];
  final _redoStack = <List<Expense>>[];

  @override
  Future<List<Expense>> build(String arg) async {
    return ref.read(expensesRepositoryProvider).getExpensesForNote(arg);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expensesRepositoryProvider).getExpensesForNote(arg),
    );
  }

  void _pushUndo(List<Expense> snapshot) {
    _undoStack.add(snapshot);
    _redoStack.clear();
    if (_undoStack.length > 20) _undoStack.removeAt(0);
  }

  Future<Expense> addExpense(String payerId) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    final created = await ref
        .read(expensesRepositoryProvider)
        .addExpense(noteId: arg, payerId: payerId);
    await refresh();
    return created;
  }

  Future<void> updatePayer({
    required String expenseId,
    required String payerId,
  }) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    await ref.read(expensesRepositoryProvider).updateExpensePayer(
          expenseId: expenseId,
          payerId: payerId,
        );
    await refresh();
  }

  Future<void> deleteExpense(String expenseId) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
    await refresh();
  }

  Future<void> addItem({
    required String expenseId,
    required String name,
    required double price,
    String? payerId,
    List<String> participantUserIds = const [],
  }) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    final repo = ref.read(expensesRepositoryProvider);
    final item = await repo.addExpenseItem(
      expenseId: expenseId,
      name: name,
      price: price,
      payerId: payerId,
    );
    // Add any participants in parallel, ignoring individual failures.
    if (participantUserIds.isNotEmpty) {
      await Future.wait(
        participantUserIds.map((uid) async {
          try {
            await repo.addParticipant(itemId: item.id, userId: uid);
          } catch (_) {
            // Swallow individual failures (e.g. duplicate participant).
          }
        }),
      );
    }
    await refresh();
  }

  Future<void> updateItem({
    required String itemId,
    String? name,
    double? price,
  }) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    await ref.read(expensesRepositoryProvider).updateExpenseItem(
          itemId: itemId,
          name: name,
          price: price,
        );
    await refresh();
  }

  Future<void> deleteItem(String itemId) async {
    final current = state.valueOrNull ?? [];
    _pushUndo(current);
    await ref.read(expensesRepositoryProvider).deleteExpenseItem(itemId);
    await refresh();
  }

  Future<void> addParticipant({
    required String itemId,
    required String userId,
  }) async {
    await ref.read(expensesRepositoryProvider).addParticipant(
          itemId: itemId,
          userId: userId,
        );
    await refresh();
  }

  Future<void> removeParticipant(String participantId) async {
    await ref
        .read(expensesRepositoryProvider)
        .removeParticipant(participantId);
    await refresh();
  }

  /// Remove many participant rows in parallel and do a single refresh at the
  /// end. Use this when clearing a whole item split ("None" chip).
  Future<void> removeParticipants(List<String> participantIds) async {
    if (participantIds.isEmpty) return;
    final repo = ref.read(expensesRepositoryProvider);
    await Future.wait(participantIds.map((id) async {
      try {
        await repo.removeParticipant(id);
      } catch (_) {
        // Ignore individual failures (already removed by another client).
      }
    }));
    await refresh();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final current = state.valueOrNull ?? [];
    _redoStack.add(current);
    state = AsyncData(_undoStack.removeLast());
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final current = state.valueOrNull ?? [];
    _undoStack.add(current);
    state = AsyncData(_redoStack.removeLast());
  }
}

final settlementProvider =
    FutureProvider.family<SettlementResult, String>((ref, noteId) async {
  final expenses = await ref.watch(noteExpensesProvider(noteId).future);
  if (expenses.isEmpty) {
    return const SettlementResult(balances: [], settlements: [], total: 0);
  }

  final participantIds = <String>{};
  for (final e in expenses) {
    participantIds.add(e.payerId);
    for (final item in e.items) {
      for (final p in item.participants) {
        participantIds.add(p.userId);
      }
    }
  }

  final client = ref.read(supabaseClientProvider);
  final profiles = await client
      .from('profiles')
      .select('user_id, display_name')
      .inFilter('user_id', participantIds.toList());

  final names = <String, String>{};
  for (final p in profiles) {
    names[p['user_id'] as String] =
        (p['display_name'] as String?) ??
            ((p['user_id'] as String).length > 8
                ? (p['user_id'] as String).substring(0, 8)
                : p['user_id'] as String);
  }

  return ref.read(expensesRepositoryProvider).computeSettlements(
        expenses: expenses,
        participantNames: names,
      );
});
