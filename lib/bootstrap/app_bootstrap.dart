import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final missingValues = AppConfig.missingCoreValues;
    if (missingValues.isNotEmpty) {
      throw StateError(
        'App configuration is incomplete: ${missingValues.join(', ')}',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    debugPrint(
      'AppBootstrap: Supabase initialized, sandbox=${AppConfig.alipayUseSandbox}',
    );
  }
}
