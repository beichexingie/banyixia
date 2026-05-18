import 'app_config.dart';

class PaymentConfig {
  static String get backendBaseUrl => AppConfig.paymentBackendBaseUrl;
  static String get supabaseAnonKey => AppConfig.supabaseAnonKey;
  static bool get useSandbox => AppConfig.alipayUseSandbox;
}
