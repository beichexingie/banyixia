import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../services/session_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static late final SessionService sessionService;

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

    debugPrint(
      'AppBootstrap: ECS session initialized, sandbox=${AppConfig.alipayUseSandbox}',
    );
  }
}
