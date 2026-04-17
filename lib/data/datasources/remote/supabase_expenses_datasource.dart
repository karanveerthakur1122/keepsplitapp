import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/expense_model.dart';
import '../../models/expense_item_model.dart';
import '../../models/participant_model.dart';

class SupabaseExpensesDatasource {
  SupabaseExpensesDatasource(this._client);
  final SupabaseClient _client;

  Future<List<ExpenseModel>> getExpensesForNote(String noteId) async {
    final response = await _client
        .from('expenses')
        .select('''
          *,
          expense_items (
            *,
            expense_item_participants (*)
          )
        ''')
        .eq('note_id', noteId)
        .order('created_at', ascending: true);

    return (response as List).map((e) => ExpenseModel.fromJson(e)).toList();
  }

  Future<ExpenseModel> addExpense({
    required String id,
    required String noteId,
    required String payerId,
  }) async {
    final response = await _client
        .from('expenses')
        .insert({
          'id': id,
          'note_id': noteId,
          'payer_id': payerId,
        })
        .select('''
          *,
          expense_items (
            *,
            expense_item_participants (*)
          )
        ''')
        .single();

    return ExpenseModel.fromJson(response);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  Future<void> updateExpensePayer({
    required String expenseId,
    required String payerId,
  }) async {
    await _client
        .from('expenses')
        .update({'payer_id': payerId}).eq('id', expenseId);
  }

  Future<ExpenseItemModel> addExpenseItem({
    required String id,
    required String expenseId,
    required String name,
    required double price,
    String? payerId,
  }) async {
    final response = await _client
        .from('expense_items')
        .insert({
          'id': id,
          'expense_id': expenseId,
          'name': name,
          'price': price,
          if (payerId != null) 'payer_id': payerId,
        })
        .select('''
          *,
          expense_item_participants (*)
        ''')
        .single();

    return ExpenseItemModel.fromJson(response);
  }

  Future<void> updateExpenseItem({
    required String itemId,
    String? name,
    double? price,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (price != null) updates['price'] = price;
    if (updates.isEmpty) return;

    await _client.from('expense_items').update(updates).eq('id', itemId);
  }

  Future<void> deleteExpenseItem(String itemId) async {
    await _client.from('expense_items').delete().eq('id', itemId);
  }

  Future<ParticipantModel> addParticipant({
    required String id,
    required String itemId,
    required String userId,
  }) async {
    final response = await _client
        .from('expense_item_participants')
        .insert({
          'id': id,
          'item_id': itemId,
          'user_id': userId,
        })
        .select()
        .single();

    return ParticipantModel.fromJson(response);
  }

  Future<void> removeParticipant(String participantId) async {
    await _client
        .from('expense_item_participants')
        .delete()
        .eq('id', participantId);
  }
}
