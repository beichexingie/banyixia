import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

/// Registers this Android installation with Alibaba Cloud Mobile Push and
/// stores its DeviceId in the existing server-side device table.
class PushNotificationService {
  static const MethodChannel _platform = MethodChannel('yidianban/aliyun_push');

  final SessionService sessionService;
  final EcsApiClient _api;
  final String appVariant;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  Timer? _retryTimer;
  String? _deviceId;
  String? _pendingRoute;
  void Function(String route)? onRoute;

  PushNotificationService({
    required this.sessionService,
    this.appVariant = 'customer',
    EcsApiClient? api,
  }) : _api = api ?? EcsApiClient() {
    sessionService.sessionListenable.addListener(_handleSessionChanged);
  }

  static Future<Map<String, dynamic>> notificationPermissionState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <String, dynamic>{'enabled': true, 'permission': true};
    }
    final result = await _platform.invokeMethod<dynamic>(
      'notificationPermissionState',
    );
    if (result is Map) {
      return result.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static Future<void> requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _platform.invokeMethod<dynamic>('requestNotificationPermission');
  }

  static Future<void> openNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _platform.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    if (_initialized) {
      await _registerDevice(reason: 'already_initialized');
      return;
    }

    final activeInitialization = _initializationFuture;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }

    final initialization = _initializeNativePush();
    _initializationFuture = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _initializeNativePush() async {
    try {
      final result = await _platform.invokeMethod<Map<Object?, Object?>>(
        'initialize',
      );
      final deviceId = result?['deviceId']?.toString().trim() ?? '';
      if (deviceId.isEmpty) {
        throw StateError('Alibaba Cloud Push returned an empty DeviceId');
      }
      _deviceId = deviceId;
      _initialized = true;
      _retryTimer?.cancel();
      _retryTimer = null;
      final devicePrefix = deviceId.substring(
        0,
        deviceId.length < 12 ? deviceId.length : 12,
      );
      debugPrint(
        'Aliyun Push initialized: appVariant=$appVariant device=$devicePrefix',
      );
      await _registerDevice(reason: 'initialization');
    } catch (error) {
      _initialized = false;
      debugPrint('Aliyun Push initialization failed: $error');
      _scheduleRetry();
    }
  }

  void _handleSessionChanged() {
    if (sessionService.currentSession == null) return;
    unawaited(initialize());
  }

  Future<void> _registerDevice({required String reason}) async {
    final session = sessionService.currentSession;
    final deviceId = _deviceId;
    if (!_initialized ||
        session == null ||
        session.accessToken?.isEmpty != false ||
        deviceId == null ||
        deviceId.isEmpty) {
      return;
    }

    try {
      await _platform.invokeMethod<void>('bindAccount', {
        'userId': session.userId,
      });
      final userPrefix = session.userId.substring(
        0,
        session.userId.length < 8 ? session.userId.length : 8,
      );
      debugPrint('Aliyun Push account bound: user=$userPrefix');
      await _api.post(
        '/devices/push-token',
        authToken: session.accessToken,
        body: {
          'token': deviceId,
          'platform': 'aliyun_android',
          'app_variant': appVariant,
        },
      );
      debugPrint('Aliyun Push device registered: $appVariant ($reason)');
    } catch (error) {
      debugPrint('Aliyun Push device registration failed: $error');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (sessionService.currentSession == null ||
        _retryTimer?.isActive == true) {
      return;
    }
    _retryTimer = Timer(const Duration(seconds: 10), () {
      _retryTimer = null;
      unawaited(initialize());
    });
  }

  Future<void> _consumePendingRoute() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final route = await _platform.invokeMethod<String>('consumePendingRoute');
      if (route != null && route.trim().isNotEmpty) {
        _openRoute(route.trim());
      }
    } catch (error) {
      debugPrint('Aliyun Push route read failed: $error');
    }
  }

  void _openRoute(String route) {
    if (onRoute != null) {
      onRoute!(route);
    } else {
      _pendingRoute = route;
    }
  }

  void attachRouteHandler(void Function(String route) handler) {
    onRoute = handler;
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) handler(pending);
    unawaited(_consumePendingRoute());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(initialize());
    });
  }
}
