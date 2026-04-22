import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/note_order_provider.dart';
import '../../presentation/providers/notes_provider.dart';

/// Wipes every local cache and then signs the user out of Supabase.
///
/// Must be called from a context that has access to a [WidgetRef] (or
/// [Ref]). Every sign-out button in the app should delegate here so
/// the next user never sees stale data from a previous account.
Future<void> performSignOut(WidgetRef ref) async {
  // 1. Clear the Drift SQLite database (notes, expenses, sync queue, etc.)
  try {
    await ref.read(databaseProvider).clearAll();
  } catch (_) {}

  // 2. Clear persisted note drag-order
  try {
    await ref.read(noteOrderProvider.notifier).clear();
  } catch (_) {}

  // 3. Clear any remaining SharedPreferences that are user-specific
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_note_order');
  } catch (_) {}

  // 4. Sign out from Supabase FIRST. This fires the auth state change
  //    stream which causes the router to redirect to /auth and dispose
  //    the dashboard widget tree.
  await ref.read(authRepositoryProvider).signOut();

  // 5. Invalidate ephemeral Riverpod state AFTER sign-out so the
  //    dashboard's ConsumerState is already unmounted and won't try
  //    to rebuild from stale provider notifications.
  scheduleMicrotask(() {
    ref.invalidate(notesProvider);
    ref.invalidate(noteOrderProvider);
    ref.invalidate(dashboardSectionProvider);
    ref.invalidate(searchQueryProvider);
  });
}
