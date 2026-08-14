import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../services/push_notification_service.dart';
import '../services/session_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static late final SessionService sessionService;
  static PushNotificationService? pushNotificationService;
  static String appVariant = 'customer';

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final missingValues = AppConfig.missingCoreValues;
    if (missingValues.isNotEmpty) {
      throw StateError(
        'App configuration is incomplete: ${missingValues.join(', ')}',
      );
    }

    sessionService = EcsSessionService();
    await sessionService.initialize();
    pushNotificationService = PushNotificationService(
      sessionService: sessionService,
      appVariant: appVariant,
    );
    // Push notifications are optional at startup. Never block the first
    // Flutter frame when Firebase configuration or the Android plugin is slow.
    await pushNotificationService!.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('Push notification initialization timed out');
      },
    );

    debugPrint(
      'AppBootstrap: ECS session initialized, '
      'apiBaseUrl=${AppConfig.apiBaseUrl}, '
      'paymentBaseUrl=${AppConfig.paymentBackendBaseUrl}, '
      'sandbox=${AppConfig.alipayUseSandbox}, '
      'amapWebKeySet=${AppConfig.amapWebServiceKey.trim().isNotEmpty}, '
      'amapAndroidKeySet=${AppConfig.amapAndroidKey.trim().isNotEmpty}',
    );
  }
}
