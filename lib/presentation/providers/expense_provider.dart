import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/local/expenses_local_datasource.dart';
import '../../data/datasources/remote/supabase_expenses_datasource.dart';
import '../../data/repositories/expenses_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_item.dart';
import '../../domain/entities/participant.dart';
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

const _uuid = Uuid();

class NoteExpensesNotifier extends FamilyAsyncNotifier<List<Expense>, String> {
  final _undoStack = <List<Expense>>[];
  final _redoStack = <List<Expense>>[];

  @override
  Future<List<Expense>> build(String arg) async {
    return ref.read(expensesRepositoryProvider).getExpensesForNote(arg);
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(
      () => ref.read(expensesRepositoryProvider).getExpensesForNote(arg),
    );
    state = result;
  }

  List<Expense> _current() => state.valueOrNull ?? [];

  void _pushUndo(List<Expense> snapshot) {
    _undoStack.add(snapshot);
    _redoStack.clear();
    if (_undoStack.length > 20) _undoStack.removeAt(0);
  }

  Future<Expense> addExpense(String payerId) async {
    final current = _current();
    _pushUndo(current);
    final id = _uuid.v4();
    final optimistic = Expense(
      id: id,
      noteId: arg,
      payerId: payerId,
      createdAt: DateTime.now(),
      items: const [],
    );
    state = AsyncData([...current, optimistic]);

    try {
      final created = await ref
          .read(expensesRepositoryProvider)
          .addExpense(noteId: arg, payerId: payerId);
      final list = _current();
      state = AsyncData([
        for (final e in list)
          if (e.id == id) created else e,
      ]);
      return created;
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updatePayer({
    required String expenseId,
    required String payerId,
  }) async {
    final current = _current();
    _pushUndo(current);
    state = AsyncData([
      for (final e in current)
        if (e.id == expenseId) e.copyWith(payerId: payerId) else e,
    ]);
    try {
      await ref.read(expensesRepositoryProvider).updateExpensePayer(
            expenseId: expenseId,
            payerId: payerId,
          );
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final current = _current();
    _pushUndo(current);
    state = AsyncData(current.where((e) => e.id != expenseId).toList());
    try {
      await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> addItem({
    required String expenseId,
    required String name,
    required double price,
    String? payerId,
    List<String> participantUserIds = const [],
  }) async {
    final current = _current();
    _pushUndo(current);
    final itemId = _uuid.v4();
    final optimisticItem = ExpenseItem(
      id: itemId,
      expenseId: expenseId,
      name: name,
      price: price,
      payerId: payerId,
      createdAt: DateTime.now(),
      participants: participantUserIds
          .map((uid) => Participant(
                id: _uuid.v4(),
                itemId: itemId,
                userId: uid,
              ))
          .toList(),
    );
    state = AsyncData([
      for (final e in current)
        if (e.id == expenseId)
          e.copyWith(items: [...e.items, optimisticItem])
        else
          e,
    ]);

    try {
      final repo = ref.read(expensesRepositoryProvider);
      final item = await repo.addExpenseItem(
        expenseId: expenseId,
        name: name,
        price: price,
        payerId: payerId,
      );
      if (participantUserIds.isNotEmpty) {
        await Future.wait(
          participantUserIds.map((uid) async {
            try {
              await repo.addParticipant(itemId: item.id, userId: uid);
            } catch (_) {}
          }),
        );
      }
      // Background sync to pick up server-generated IDs.
      _backgroundRefresh();
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> updateItem({
    required String itemId,
    String? name,
    double? price,
  }) async {
    final current = _current();
    _pushUndo(current);
    state = AsyncData([
      for (final e in current)
        e.copyWith(
          items: [
            for (final i in e.items)
              if (i.id == itemId)
                i.copyWith(
                  name: name ?? i.name,
                  price: price ?? i.price,
                )
              else
                i,
          ],
        ),
    ]);
    try {
      await ref.read(expensesRepositoryProvider).updateExpenseItem(
            itemId: itemId,
            name: name,
            price: price,
          );
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> deleteItem(String itemId) async {
    final current = _current();
    _pushUndo(current);
    state = AsyncData([
      for (final e in current)
        e.copyWith(items: e.items.where((i) => i.id != itemId).toList()),
    ]);
    try {
      await ref.read(expensesRepositoryProvider).deleteExpenseItem(itemId);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> addParticipant({
    required String itemId,
    required String userId,
  }) async {
    final current = _current();
    _pushUndo(current);
    final tempId = _uuid.v4();
    state = AsyncData([
      for (final e in current)
        e.copyWith(
          items: [
            for (final i in e.items)
              if (i.id == itemId)
                i.copyWith(
                  participants: [
                    ...i.participants,
                    Participant(id: tempId, itemId: itemId, userId: userId),
                  ],
                )
              else
                i,
          ],
        ),
    ]);
    try {
      await ref.read(expensesRepositoryProvider).addParticipant(
            itemId: itemId,
            userId: userId,
          );
      _backgroundRefresh();
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> removeParticipant(String participantId) async {
    final current = _current();
    _pushUndo(current);
    state = AsyncData([
      for (final e in current)
        e.copyWith(
          items: [
            for (final i in e.items)
              i.copyWith(
                participants:
                    i.participants.where((p) => p.id != participantId).toList(),
              ),
          ],
        ),
    ]);
    try {
      await ref
          .read(expensesRepositoryProvider)
          .removeParticipant(participantId);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> removeParticipants(List<String> participantIds) async {
    if (participantIds.isEmpty) return;
    final current = _current();
    _pushUndo(current);
    final removeSet = participantIds.toSet();
    state = AsyncData([
      for (final e in current)
        e.copyWith(
          items: [
            for (final i in e.items)
              i.copyWith(
                participants: i.participants
                    .where((p) => !removeSet.contains(p.id))
                    .toList(),
              ),
          ],
        ),
    ]);
    try {
      final repo = ref.read(expensesRepositoryProvider);
      await Future.wait(participantIds.map((id) async {
        try {
          await repo.removeParticipant(id);
        } catch (_) {}
      }));
    } catch (_) {
      state = AsyncData(current);
    }
  }

  void _backgroundRefresh() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (state.hasValue) refresh();
    });
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

  final unresolvedIds =
      participantIds.where((id) => !names.containsKey(id)).toList();
  if (unresolvedIds.isNotEmpty) {
    final manualRows = await client
        .from('note_manual_users')
        .select('id, display_name')
        .inFilter('id', unresolvedIds);
    for (final r in manualRows) {
      names[r['id'] as String] = r['display_name'] as String;
    }
  }

  return ref.read(expensesRepositoryProvider).computeSettlements(
        expenses: expenses,
        participantNames: names,
      );
});
