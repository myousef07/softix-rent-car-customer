import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'firebase_config.dart';
import 'i18n.dart';

/// Notifications from the rental company (contract opened, return reminder, amount due…): the
/// phone's Firebase token is registered after sign-in and removed before sign-out; tapping a
/// notification opens the contract or invoice it is about.
class PushService {
  PushService(this.api);

  final ApiClient api;

  /// Set by the app once the router exists: opens the screen for a notification's data.
  void Function(Map<String, dynamic> data)? onOpen;

  static final _channel = AndroidNotificationChannel(
    'customer_alerts',
    tr('تنبيهات الإيجار'),
    description: tr('العقود ومواعيد الإعادة والمبالغ المستحقة'),
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refresh;
  Map<String, dynamic>? _pending;

  Future<void> init() async {
    if (!FirebaseConfig.enabled) return;

    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload == null ? null : jsonDecode(response.payload!)),
      );
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);

      // In the foreground Firebase shows nothing by itself: show it on the phone's tray.
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(message.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pending = initial.data;

      _ready = true;
    } catch (error) {
      debugPrint('Push unavailable: $error');
    }
  }

  /// After sign-in (or a restored session): ask permission and register this phone.
  Future<void> register() async {
    if (!_ready) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _token = await messaging.getToken();
      if (_token != null) await _send(_token!);
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((token) {
        _token = token;
        _send(token);
      });
    } catch (error) {
      debugPrint('Push registration failed: $error');
    }

    final pending = _pending;
    _pending = null;
    if (pending != null) _open(pending);
  }

  /// Before sign-out, while the API token is still valid.
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    if (!_ready || token == null) return;

    try {
      await api.delete('/devices', data: {'token': token});
    } catch (_) {
      // The server drops it anyway once Firebase reports it dead.
    }
  }

  Future<void> _send(String token) => api.post(
    '/devices',
    data: {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'device_name': 'SOftiX (${defaultTargetPlatform.name})',
    },
  );

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _open(Object? data) {
    if (data is! Map || onOpen == null) {
      if (data is Map) _pending = Map<String, dynamic>.from(data);
      return;
    }
    onOpen!(Map<String, dynamic>.from(data));
  }
}

/// The screen a notification opens, from the `type` and `id` the platform sends.
String? routeForPush(Map<String, dynamic> data) {
  final id = int.tryParse('${data['id'] ?? ''}');

  return switch (data['type']) {
    'rental_contract' when id != null => '/contracts/$id',
    'invoice' => '/invoices',
    _ => null,
  };
}
