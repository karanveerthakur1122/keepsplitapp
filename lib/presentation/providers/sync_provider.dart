import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/offline_sync_engine.dart';
import '../../data/datasources/local/sync_queue_datasource.dart';
import 'auth_provider.dart';
import 'notes_provider.dart';

final syncQueueDatasourceProvider = Provider<SyncQueueDatasource>(
  (ref) => SyncQueueDatasource(ref.watch(databaseProvider)),
);

final offlineSyncEngineProvider = Provider<OfflineSyncEngine>((ref) {
  final engine = OfflineSyncEngine(
    ref.watch(syncQueueDatasourceProvider),
    ref.watch(supabaseClientProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final engine = ref.watch(offlineSyncEngineProvider);
  return engine.onlineStream;
});
