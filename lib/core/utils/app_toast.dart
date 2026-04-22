import 'package:flutter/material.dart';

class AppToast {
  AppToast._();

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(String message) => _show(message, _Type.success);
  static void error(String message) => _show(message, _Type.error);
  static void info(String message) => _show(message, _Type.info);

  static void _show(String message, _Type type) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    final (bg, icon, duration) = switch (type) {
      _Type.success => (
        const Color(0xFF1B5E20),
        Icons.check_circle_rounded,
        const Duration(seconds: 2),
      ),
      _Type.error => (
        const Color(0xFFB71C1C),
        Icons.error_rounded,
        const Duration(seconds: 4),
      ),
      _Type.info => (
        const Color(0xFF1A237E),
        Icons.info_rounded,
        const Duration(seconds: 2),
      ),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}

enum _Type { success, error, info }
