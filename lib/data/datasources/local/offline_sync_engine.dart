import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/sync_queue_entry.dart';
import 'sync_queue_datasource.dart';

class OfflineSyncEngine {
  OfflineSyncEngine(this._syncQueue, this._client);

  final SyncQueueDatasource _syncQueue;
  final SupabaseClient _client;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicSync;
  bool _syncing = false;
  bool _online = true;

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _online;

  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _online;
      _online = results.any((r) => r != ConnectivityResult.none);
      _onlineController.add(_online);

      if (!wasOnline && _online) {
        processPendingQueue();
      }
    });

    _periodicSync = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_online) processPendingQueue();
      },
    );
  }

  void dispose() {
    _connectivitySub?.cancel();
    _periodicSync?.cancel();
    _onlineController.close();
  }

  Future<void> processPendingQueue() async {
    if (_syncing || !_online) return;
    _syncing = true;

    try {
      final pending = await _syncQueue.getPending();
      for (final entry in pending) {
        try {
          await _processEntry(entry);
          await _syncQueue.remove(entry.localId!);
        } catch (e) {
          if (entry.retryCount >= 5) {
            await _syncQueue.remove(entry.localId!);
          } else {
            await _syncQueue.incrementRetry(entry.localId!);
          }
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _processEntry(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

    switch (entry.entity) {
      case SyncEntity.note:
        await _processNoteSync(entry.operation, entry.entityId, payload);
      case SyncEntity.expense:
        await _processExpenseSync(entry.operation, entry.entityId, payload);
      case SyncEntity.expenseItem:
        await _processExpenseItemSync(entry.operation, entry.entityId, payload);
      case SyncEntity.participant:
        await _processParticipantSync(
            entry.operation, entry.entityId, payload);
      case SyncEntity.collaborator:
        await _processCollaboratorSync(
            entry.operation, entry.entityId, payload);
    }
  }

  Future<void> _processNoteSync(
      SyncOperation op, String id, Map<String, dynamic> payload) async {
    switch (op) {
      case SyncOperation.insert:
        await _client.from('notes').insert(payload);
      case SyncOperation.update:
        await _client.from('notes').update(payload).eq('id', id);
      case SyncOperation.delete:
        await _client.from('notes').delete().eq('id', id);
    }
  }

  Future<void> _processExpenseSync(
      SyncOperation op, String id, Map<String, dynamic> payload) async {
    switch (op) {
      case SyncOperation.insert:
        await _client.from('expenses').insert(payload);
      case SyncOperation.update:
        await _client.from('expenses').update(payload).eq('id', id);
      case SyncOperation.delete:
        await _client.from('expenses').delete().eq('id', id);
    }
  }

  Future<void> _processExpenseItemSync(
      SyncOperation op, String id, Map<String, dynamic> payload) async {
    switch (op) {
      case SyncOperation.insert:
        await _client.from('expense_items').insert(payload);
      case SyncOperation.update:
        await _client.from('expense_items').update(payload).eq('id', id);
      case SyncOperation.delete:
        await _client.from('expense_items').delete().eq('id', id);
    }
  }

  Future<void> _processParticipantSync(
      SyncOperation op, String id, Map<String, dynamic> payload) async {
    switch (op) {
      case SyncOperation.insert:
        await _client.from('expense_item_participants').insert(payload);
      case SyncOperation.update:
        break;
      case SyncOperation.delete:
        await _client
            .from('expense_item_participants')
            .delete()
            .eq('id', id);
    }
  }

  Future<void> _processCollaboratorSync(
      SyncOperation op, String id, Map<String, dynamic> payload) async {
    switch (op) {
      case SyncOperation.insert:
        await _client.from('note_collaborators').insert(payload);
      case SyncOperation.update:
        await _client
            .from('note_collaborators')
            .update(payload)
            .eq('id', id);
      case SyncOperation.delete:
        await _client.from('note_collaborators').delete().eq('id', id);
    }
  }
}
