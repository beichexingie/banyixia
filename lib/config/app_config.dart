class AppConfig {
  const AppConfig._();

  static const double minimumWithdrawalAmount = 0.10;

  static const String appName = '伴一下';

  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String amapWebServiceKey = String.fromEnvironment(
    'AMAP_WEB_SERVICE_KEY',
    defaultValue: '0aed32a4629254c3ae2eaf3f36868391',
  );

  static const String amapAndroidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: 'f365608ae7958031b8930c795f5d7329',
  );

  static const String paymentBackendBaseUrlOverride = String.fromEnvironment(
    'PAYMENT_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const bool alipayUseSandbox = bool.fromEnvironment(
    'ALIPAY_USE_SANDBOX',
    defaultValue: false,
  );

  static String get apiBaseUrl {
    final override = apiBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return 'http://127.0.0.1:3000/api';
  }

  static String get paymentBackendBaseUrl {
    final override = paymentBackendBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return apiBaseUrl;
  }

  static List<String> get missingCoreValues {
    final missing = <String>[];
    if (apiBaseUrl.trim().isEmpty) missing.add('API_BASE_URL');
    return missing;
  }
}
