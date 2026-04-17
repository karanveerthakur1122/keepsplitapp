import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_queue_entry.freezed.dart';
part 'sync_queue_entry.g.dart';

enum SyncOperation { insert, update, delete }
enum SyncEntity { note, expense, expenseItem, participant, collaborator }

@freezed
class SyncQueueEntry with _$SyncQueueEntry {
  const factory SyncQueueEntry({
    required int? localId,
    required SyncOperation operation,
    required SyncEntity entity,
    required String entityId,
    required String payload,
    required DateTime createdAt,
    @Default(0) int retryCount,
  }) = _SyncQueueEntry;

  factory SyncQueueEntry.fromJson(Map<String, dynamic> json) => _$SyncQueueEntryFromJson(json);
}
