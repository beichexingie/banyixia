import 'app_config.dart';

class PaymentConfig {
  static String get backendBaseUrl => AppConfig.paymentBackendBaseUrl;
  static bool get useSandbox => AppConfig.alipayUseSandbox;
}
