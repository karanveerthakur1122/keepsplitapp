import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/sync_queue_entry.dart';
import 'drift_database.dart';

class SyncQueueDatasource {
  SyncQueueDatasource(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required SyncOperation operation,
    required SyncEntity entity,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            operation: operation.name,
            entity: entity.name,
            entityId: entityId,
            payload: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<List<SyncQueueEntry>> getPending() async {
    final query = _db.select(_db.syncQueue)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToEntry).toList();
  }

  Future<void> remove(int localId) async {
    await (_db.delete(_db.syncQueue)..where((t) => t.localId.equals(localId))).go();
  }

  Future<void> incrementRetry(int localId) async {
    final row = await (_db.select(_db.syncQueue)..where((t) => t.localId.equals(localId))).getSingleOrNull();
    if (row != null) {
      await (_db.update(_db.syncQueue)..where((t) => t.localId.equals(localId))).write(
        SyncQueueCompanion(retryCount: Value(row.retryCount + 1)),
      );
    }
  }

  Future<void> clearAll() async {
    await _db.delete(_db.syncQueue).go();
  }

  SyncQueueEntry _rowToEntry(SyncQueueData row) {
    return SyncQueueEntry(
      localId: row.localId,
      operation: SyncOperation.values.firstWhere((e) => e.name == row.operation),
      entity: SyncEntity.values.firstWhere((e) => e.name == row.entity),
      entityId: row.entityId,
      payload: row.payload,
      createdAt: row.createdAt,
      retryCount: row.retryCount,
    );
  }
}
