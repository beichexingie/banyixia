import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  final SessionService sessionService;
  final EcsApiClient _api;
  final String appVariant;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _pendingRoute;
  void Function(String route)? onRoute;

  PushNotificationService({
    required this.sessionService,
    this.appVariant = 'customer',
    EcsApiClient? api,
  }) : _api = api ?? EcsApiClient();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'yidianban_messages',
    '伴一下消息',
    description: '订单、客服和系统通知',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          _openFromData(response.payload);
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);
      final localPermission =
          await androidPlugin?.requestNotificationsPermission();
      debugPrint('Local notification permission: $localPermission');

      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      final permissionSettings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        'Push notification permission: ${permissionSettings.authorizationStatus}',
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      await _registerToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _registerToken(token);
      });
      sessionService.sessionListenable.addListener(_handleSessionChanged);
      _handleSessionChanged();
      _initialized = true;
    } catch (error) {
      // Push is optional infrastructure. Login and core business flows must
      // still work when Firebase has not been configured for this app yet.
      debugPrint('Push notification initialization skipped: $error');
    }
  }

  void _handleSessionChanged() {
    if (sessionService.currentSession != null) {
      _registerToken();
    }
  }

  Future<void> _registerToken([String? refreshedToken]) async {
    final session = sessionService.currentSession;
    if (session == null || session.accessToken?.isEmpty != false) return;

    try {
      final token =
          refreshedToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _api.post(
        '/devices/push-token',
        authToken: session.accessToken,
        body: {
          'token': token,
          'platform': defaultTargetPlatform.name,
          'app_variant': appVariant,
        },
      );
    } catch (error) {
      debugPrint('Register push token error: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? '伴一下',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _openFromData(jsonEncode(message.data));
  }

  void _openFromData(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final data = jsonDecode(rawPayload);
      if (data is! Map) return;
      final route = data['route']?.toString();
      if (route == null || route.isEmpty) return;
      if (onRoute != null) {
        onRoute!(route);
      } else {
        _pendingRoute = route;
      }
    } catch (error) {
      debugPrint('Open push route error: $error');
    }
  }

  void attachRouteHandler(void Function(String route) handler) {
    onRoute = handler;
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) handler(pending);
  }
}
