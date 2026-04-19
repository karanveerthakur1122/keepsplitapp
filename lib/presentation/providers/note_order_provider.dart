import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'custom_note_order';

final noteOrderProvider =
    StateNotifierProvider<NoteOrderNotifier, List<String>>(
  (ref) => NoteOrderNotifier(),
);

class NoteOrderNotifier extends StateNotifier<List<String>> {
  NoteOrderNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? [];
  }

  Future<void> saveOrder(List<String> ids) async {
    state = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids);
  }

  /// Remove IDs that no longer exist (deleted notes) from the persisted order.
  Future<void> prune(Set<String> validIds) async {
    final pruned = state.where(validIds.contains).toList();
    if (pruned.length != state.length) {
      await saveOrder(pruned);
    }
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
