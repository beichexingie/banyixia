import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ecs_api_client.dart';

class AppSession {
  final String userId;
  final String? phone;
  final String? accessToken;

  const AppSession({
    required this.userId,
    this.phone,
    this.accessToken,
  });
}

abstract class SessionService {
  ValueListenable<AppSession?> get sessionListenable;
  AppSession? get currentSession;
  Future<void> initialize();
  Future<void> sendSmsCode(String phoneNumber);
  Future<void> verifySmsCode(String phoneNumber, String smsCode);
  Future<void> logout();
}

class EcsSessionService extends ValueNotifier<AppSession?>
    implements SessionService {
  static const _sessionPhoneKey = 'ecs_session_phone';
  static const _sessionUserIdKey = 'ecs_session_user_id';
  static const _sessionTokenKey = 'ecs_session_token';

  final EcsApiClient _apiClient;
  SharedPreferences? _prefs;

  EcsSessionService({EcsApiClient? apiClient})
      : _apiClient = apiClient ?? EcsApiClient(),
        super(null);

  @override
  AppSession? get currentSession => value;

  @override
  ValueListenable<AppSession?> get sessionListenable => this;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> initialize() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_sessionTokenKey);
    final userId = prefs.getString(_sessionUserIdKey);
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      value = null;
      return;
    }
    value = AppSession(
      userId: userId,
      phone: prefs.getString(_sessionPhoneKey),
      accessToken: token,
    );
  }

  @override
  Future<void> sendSmsCode(String phoneNumber) async {
    await _apiClient.post('/auth/send-code', body: {'phone': phoneNumber});
  }

  @override
  Future<void> verifySmsCode(String phoneNumber, String smsCode) async {
    final result = await _apiClient.post(
      '/auth/verify-code',
      body: {'phone': phoneNumber, 'code': smsCode},
    );
    final session = result['session'];
    if (session is! Map<String, dynamic>) {
      throw EcsApiException(500, '登录失败');
    }
    final token = session['access_token']?.toString() ?? '';
    final userId = session['user_id']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw EcsApiException(500, '登录失败');
    }

    final prefs = await _getPrefs();
    await prefs.setString(_sessionTokenKey, token);
    await prefs.setString(_sessionUserIdKey, userId);
    await prefs.setString(_sessionPhoneKey, phoneNumber);
    value = AppSession(userId: userId, phone: phoneNumber, accessToken: token);
  }

  @override
  Future<void> logout() async {
    try {
      final token = value?.accessToken;
      if (token != null && token.isNotEmpty) {
        await _apiClient.post('/auth/logout', authToken: token);
      }
    } catch (_) {}
    final prefs = await _getPrefs();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionPhoneKey);
    value = null;
  }
}
