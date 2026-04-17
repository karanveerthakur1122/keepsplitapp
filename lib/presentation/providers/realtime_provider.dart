import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/supabase_realtime_datasource.dart';
import 'auth_provider.dart';

final realtimeDatasourceProvider = Provider<SupabaseRealtimeDatasource>(
  (ref) => SupabaseRealtimeDatasource(ref.watch(supabaseClientProvider)),
);

final presenceUsersProvider =
    StateProvider.family<List<PresenceUser>, String>((ref, noteId) => []);
