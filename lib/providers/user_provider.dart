import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class UserProvider extends ChangeNotifier {
  final SessionService _sessionService;
  final EcsApiClient _api;

  User _user = User.guest();
  bool _isLoading = false;
  String? _pendingPhoneNumber;

  User get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn =>
      _user.id.isNotEmpty && _user.id != '0' && !_user.id.startsWith('guest');
  bool get isAdmin => _user.canAccessAdmin;
  bool get isGuide => _user.isGuideApproved;
  bool get isBanned => _user.isBanned;
  String? get accessToken => _sessionService.currentSession?.accessToken;
  String get phoneNumber => _sessionService.currentSession?.phone ?? '';

  UserProvider({
    required SessionService sessionService,
    EcsApiClient? apiClient,
  })  : _sessionService = sessionService,
        _api = apiClient ?? EcsApiClient() {
    _sessionService.sessionListenable.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  void _handleSessionChanged() {
    final session = _sessionService.currentSession;
    if (session == null) {
      _user = User.guest();
      notifyListeners();
      return;
    }
    _loadCurrentUser(session);
  }

  String? _authToken() {
    return _sessionService.currentSession?.accessToken;
  }

  Map<String, dynamic> _normalizeUserPayload(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'nickname': json['nickname'] ?? '',
      'avatar': json['avatar'] ?? '',
      'bio': json['bio'] ?? '',
      'gender': json['gender'] ?? '',
      'city': json['city'] ?? '',
      'birthday': json['birthday'] ?? '',
      'wechat': json['wechat'] ?? '',
      'occupation': json['occupation'] ?? '',
      'guide_introduction': json['guide_introduction'] ?? '',
      'guide_tags': json['guide_tags'] ?? const [],
      'vip_level': json['vip_level'] ?? 0,
      'title': json['title'] ?? '',
      'balance': json['balance'] ?? 0,
      'coupon_count': json['coupon_count'] ?? 0,
      'follow_count': json['follow_count'] ?? 0,
      'fans_count': json['fans_count'] ?? 0,
      'is_banned': json['is_banned'] ?? false,
      'cancel_count': json['cancel_count'] ?? 0,
      'is_admin': json['is_admin'] ?? false,
      'is_guide': json['is_guide'] ?? false,
      'guide_application_status': json['guide_application_status'],
    };
  }

  User _buildUserFromApi(Map<String, dynamic> json) {
    return User.fromJson(_normalizeUserPayload(json));
  }

  Future<void> _loadCurrentUser(AppSession session) async {
    try {
      final response = await _api.get(
        '/users/me',
        authToken: session.accessToken,
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _user = _buildUserFromApi(data);
      } else {
        _user = User(
          id: session.userId,
          nickname: session.phone ?? '新用户',
          avatar: 'https://picsum.photos/seed/user/100/100',
        );
      }
    } catch (e) {
      debugPrint('Load current user error: $e');
      _user = User(
        id: session.userId,
        nickname: session.phone ?? '新用户',
        avatar: 'https://picsum.photos/seed/user/100/100',
      );
    }
    notifyListeners();
  }

  Future<void> sendSmsCode(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _sessionService.sendSmsCode(phoneNumber);
      _pendingPhoneNumber = phoneNumber;
    } catch (e) {
      debugPrint('sendSmsCode error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifySmsCode(String smsCode) async {
    if (_pendingPhoneNumber == null) {
      throw Exception('请先获取验证码');
    }

    _isLoading = true;
    notifyListeners();
    try {
      await _sessionService.verifySmsCode(_pendingPhoneNumber!, smsCode);
      final session = _sessionService.currentSession;
      if (session != null) {
        await _loadCurrentUser(session);
      }
    } catch (e) {
      debugPrint('verifySmsCode error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifySmsCodeForPhone(String phoneNumber, String smsCode) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _sessionService.verifySmsCode(phoneNumber, smsCode);
      final session = _sessionService.currentSession;
      if (session != null) {
        await _loadCurrentUser(session);
      }
    } catch (e) {
      debugPrint('verifySmsCodeForPhone error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _sessionService.logout();
    _user = User.guest();
    notifyListeners();
  }

  Future<void> updateUser(User newUser) async {
    final oldUser = _user;
    _user = newUser;
    notifyListeners();

    try {
      final token = _authToken();
      if (token == null || token.isEmpty || newUser.id.startsWith('mock')) {
        return;
      }
      final response = await _api.put(
        '/users/me',
        authToken: token,
        body: newUser.toJson(),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _user = _buildUserFromApi(data);
        notifyListeners();
      }
    } catch (e) {
      _user = oldUser;
      notifyListeners();
      throw Exception('更新失败: $e');
    }
  }

  Future<void> followUser(String targetId) async {
    if (!isLoggedIn) throw Exception('请先登录后操作');
    if (targetId.isEmpty || targetId.startsWith('mock_')) return;
    if (targetId == user.id) throw Exception('不能关注自己');

    try {
      await _api.post(
        '/users/$targetId/follow',
        authToken: _authToken(),
      );
      await _loadCurrentUser(_sessionService.currentSession!);
    } catch (e) {
      throw Exception('关注失败: $e');
    }
  }

  Future<void> unfollowUser(String targetId) async {
    if (!isLoggedIn) throw Exception('请先登录');
    if (targetId.isEmpty || targetId.startsWith('mock_')) return;

    try {
      await _api.delete(
        '/users/$targetId/follow',
        authToken: _authToken(),
      );
      await _loadCurrentUser(_sessionService.currentSession!);
    } catch (e) {
      throw Exception('取消关注失败: $e');
    }
  }

  Future<bool> isFollowing(String targetId) async {
    if (!isLoggedIn || targetId.isEmpty || targetId == user.id) return false;
    try {
      final response = await _api.get(
        '/users/$targetId/context',
        authToken: _authToken(),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data['is_following'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getFollowingUsers() async {
    if (!isLoggedIn) return [];
    try {
      final response = await _api.get(
        '/users/me/following',
        authToken: _authToken(),
      );
      final data = response['data'];
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();
    } catch (e) {
      debugPrint('getFollowingUsers error: $e');
      return [];
    }
  }

  Future<User?> fetchUserById(String userId) async {
    try {
      final response = await _api.get(
        '/users/$userId',
        authToken: _authToken(),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return _buildUserFromApi(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> mockLogin() async {
    _user = User(
      id: 'mock_user',
      nickname: '测试用户',
      avatar: 'https://picsum.photos/seed/mock-user/100/100',
      city: '北京',
    );
    notifyListeners();
  }

  Future<void> mockAdminLogin() async {
    _user = User(
      id: 'mock_admin',
      nickname: '管理员',
      avatar: 'https://picsum.photos/seed/mock-admin/100/100',
      isAdmin: true,
      city: '北京',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionService.sessionListenable.removeListener(_handleSessionChanged);
    super.dispose();
  }
}
