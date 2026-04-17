import 'package:flutter/services.dart';

/// Centralized, tiered haptic feedback helper so the app uses consistent
/// vibration patterns for similar interactions.
///
/// Use [tap] for plain taps (buttons, chips, list tiles), [select] for
/// selection changes (section switch, toggle, swipe-threshold cross),
/// [confirm] for committing a destructive-ish action (archive, pin toggle,
/// submit), and [warn] for irreversible destructive actions (permanent
/// delete, leave note).
class Haptics {
  const Haptics._();

  /// Light click, equivalent to a keyboard tap. Cheap, very subtle.
  static void tap() {
    HapticFeedback.selectionClick();
  }

  /// Slightly weightier tick for selection-like changes (section swap,
  /// chip toggle, swipe passing threshold).
  static void select() {
    HapticFeedback.lightImpact();
  }

  /// Mid-weight thud for committing an action (archive, trash, save).
  static void confirm() {
    HapticFeedback.mediumImpact();
  }

  /// Strong thud for destructive / irreversible actions (permanent
  /// delete, revoking access).
  static void warn() {
    HapticFeedback.heavyImpact();
  }
}
