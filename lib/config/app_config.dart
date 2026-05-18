class AppConfig {
  const AppConfig._();

  static const String appName = '伴一下';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://npvqebjogjmvzkkgwtss.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_S9-vRUc8U34sv5FhPHUElg_i67bEphP',
  );

  static const String amapWebServiceKey = String.fromEnvironment(
    'AMAP_WEB_SERVICE_KEY',
    defaultValue: '3174fea4534bc0320acc10c5f95d2472',
  );

  static const String paymentBackendBaseUrlOverride = String.fromEnvironment(
    'PAYMENT_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const bool alipayUseSandbox = bool.fromEnvironment(
    'ALIPAY_USE_SANDBOX',
    defaultValue: true,
  );

  static String get paymentBackendBaseUrl {
    final override = paymentBackendBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return '$supabaseUrl/functions/v1';
  }

  static bool get isSupabaseConfigured {
    return supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
  }

  static List<String> get missingCoreValues {
    final missing = <String>[];
    if (supabaseUrl.trim().isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.trim().isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }
}
