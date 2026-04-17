import 'package:intl/intl.dart';

extension StringExtension on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Safe substring that never throws on short strings.
  /// Returns at most the first [count] characters.
  String take(int count) {
    if (count <= 0 || isEmpty) return '';
    if (length <= count) return this;
    return substring(0, count);
  }

  String get initials {
    final parts = trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || (parts.length == 1 && parts.single.isEmpty)) {
      return '?';
    }
    if (parts.length == 1) {
      final word = parts.single;
      if (word.length >= 2) {
        return word.substring(0, 2).toUpperCase();
      }
      return word[0].toUpperCase();
    }
    final first = parts[0];
    final second = parts[1];
    if (first.isEmpty) return '?';
    if (second.isEmpty) return first[0].toUpperCase();
    return '${first[0]}${second[0]}'.toUpperCase();
  }
}

extension DateTimeExtension on DateTime {
  String get timeAgo {
    final now = DateTime.now().toUtc();
    final past = toUtc();
    var delta = now.difference(past);
    if (delta.isNegative) {
      delta = Duration.zero;
    }

    if (delta.inSeconds < 45) return 'just now';
    if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    if (delta.inDays < 30) return '${(delta.inDays / 7).floor()}w ago';
    if (delta.inDays < 365) return '${(delta.inDays / 30).floor()}mo ago';
    return '${(delta.inDays / 365).floor()}y ago';
  }

  String formatShort([String pattern = 'MMM d, y']) {
    return DateFormat(pattern).format(toLocal());
  }
}

extension DoubleExtension on double {
  String toCurrency({String symbol = r'$'}) {
    final formatted = toStringAsFixed(2);
    return '$symbol$formatted';
  }
}
