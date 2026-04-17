import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _layoutKey = 'layout_mode';

enum LayoutMode { card, grid }

final layoutModeProvider =
    StateNotifierProvider<LayoutModeNotifier, LayoutMode>(
  (ref) => LayoutModeNotifier(),
);

class LayoutModeNotifier extends StateNotifier<LayoutMode> {
  LayoutModeNotifier() : super(LayoutMode.card) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_layoutKey);
    if (value == 'grid') state = LayoutMode.grid;
  }

  Future<void> toggle() async {
    state = state == LayoutMode.card ? LayoutMode.grid : LayoutMode.card;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutKey, state.name);
  }
}
