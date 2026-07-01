import 'app_config.dart';

class AmapConfig {
  const AmapConfig._();

  // Web Service key for geocode / reverse-geocode requests.
  static const String webServiceKey = AppConfig.amapWebServiceKey;

  // Android native SDK key for AMapWidget / manifest injection.
  static const String androidKey = AppConfig.amapAndroidKey;

  static bool get hasAndroidKey => androidKey.trim().isNotEmpty;
}
