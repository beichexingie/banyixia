import 'app_config.dart';

class AmapConfig {
  const AmapConfig._();

  // Web Service key for geocode / reverse-geocode requests.
  static const String webServiceKey = AppConfig.amapWebServiceKey;
  static const String androidKey = AppConfig.amapAndroidKey;

  static bool get hasAndroidKey => androidKey.trim().isNotEmpty;
}
