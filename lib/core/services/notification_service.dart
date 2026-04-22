import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/app_toast.dart';

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService with WidgetsBindingObserver {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool get isInForeground => _lifecycleState == AppLifecycleState.resumed;

  NotificationTapCallback? onTap;

  static const _channelId = 'keepbillnotes_channel';
  static const _channelName = 'Keepsplit';
  static const _channelDesc = 'Collaboration and activity notifications';

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  void _onNotificationTapped(NotificationResponse response) {
    onTap?.call(response.payload);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Smart notification: shows an in-app toast when the app is in the
  /// foreground, or a system notification when the app is backgrounded.
  Future<void> showSmart({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (isInForeground) {
      AppToast.info('$title: $body');
    } else {
      await show(title: title, body: body, payload: payload);
    }
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(_nextId++, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('NotificationService.show() failed: $e');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
