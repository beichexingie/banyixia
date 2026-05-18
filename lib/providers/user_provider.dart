import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/user.dart';
import '../services/phone_auth_service.dart';

class UserProvider extends ChangeNotifier {
  final PhoneAuthService _phoneAuthService;
  User _user = User.guest();
  bool _isLoading = false;
  String? _pendingPhoneNumber;

  User get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user.id.isNotEmpty && _user.id != '0';
  bool get isAdmin => _user.canAccessAdmin;
  bool get isGuide => _user.isGuideApproved;
  bool get isBanned => _user.isBanned;

  UserProvider({PhoneAuthService? phoneAuthService})
    : _phoneAuthService = phoneAuthService ?? SupabasePhoneAuthService() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      supabase.Supabase.instance.client.auth.onAuthStateChange.listen((
        data,
      ) async {
        final session = data.session;
        if (session?.user != null) {
          await _syncUserWithDatabase(session!.user);
        } else {
          _user = User.guest();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Supabase Auth Error: $e');
      _user = User.guest();
      notifyListeners();
    }
  }

  Map<String, dynamic> _metadataFromAuthUser(supabase.User user) {
    final raw = user.userMetadata;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return <String, dynamic>{};
  }

  List<String> _parseGuideTags(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[,，/\s]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  User _buildUserFromSources({
    required supabase.User authUser,
    required _UserRoleContext roleContext,
    Map<String, dynamic>? dbRow,
    String? fallbackNickname,
    String? fallbackAvatar,
  }) {
    final metadata = _metadataFromAuthUser(authUser);
    final row = dbRow ?? const <String, dynamic>{};
    return User(
      id: authUser.id,
      nickname: _firstNonEmptyString([
            row['nickname'],
            metadata['nickname'],
            fallbackNickname,
            authUser.phone,
          ]) ??
          '新用户',
      avatar: _firstNonEmptyString([
            row['avatar'],
            metadata['avatar'],
            fallbackAvatar,
          ]) ??
          'https://picsum.photos/seed/user/100/100',
      bio: _firstNonEmptyString([row['bio'], metadata['bio']]) ?? '',
      gender: _firstNonEmptyString([row['gender'], metadata['gender']]) ?? '',
      city: _firstNonEmptyString([row['city'], metadata['city']]) ?? '',
      birthday:
          _firstNonEmptyString([row['birthday'], metadata['birthday']]) ?? '',
      wechat: _firstNonEmptyString([row['wechat'], metadata['wechat']]) ?? '',
      occupation:
          _firstNonEmptyString([row['occupation'], metadata['occupation']]) ??
          '',
      guideIntroduction:
          _firstNonEmptyString([
            row['guide_introduction'],
            metadata['guide_introduction'],
          ]) ??
          '',
      guideTags: _parseGuideTags(row['guide_tags'] ?? metadata['guide_tags']),
      vipLevel: row['vip_level'] ?? row['vipLevel'] ?? 1,
      title: _firstNonEmptyString([row['title'], metadata['title']]) ?? '初级旅行家',
      balance: (row['balance'] ?? 0.0).toDouble(),
      couponCount: row['coupon_count'] ?? row['couponCount'] ?? 0,
      followCount: roleContext.followCount,
      fansCount: roleContext.fansCount,
      isBanned: row['is_banned'] ?? false,
      cancelCount: row['cancel_count'] ?? 0,
      isAdmin: row['is_admin'] ?? false,
      isGuide: roleContext.isGuide,
      guideApplicationStatus: roleContext.applicationStatus,
    );
  }

  Map<String, dynamic> _profileMetadataFromUser(User user) {
    return {
      'nickname': user.nickname,
      'avatar': user.avatar,
      'bio': user.bio,
      'gender': user.gender,
      'city': user.city,
      'birthday': user.birthday,
      'wechat': user.wechat,
      'occupation': user.occupation,
      'guide_introduction': user.guideIntroduction,
      'guide_tags': user.guideTags,
      'title': user.title,
    };
  }

  Future<void> _syncUserWithDatabase(supabase.User supaUser) async {
    try {
      final client = supabase.Supabase.instance.client;
      final response = await client
          .from('users')
          .select()
          .eq('id', supaUser.id)
          .maybeSingle();
      final roleContext = await _loadRoleContext(supaUser.id);

      if (response != null) {
        _user = _buildUserFromSources(
          authUser: supaUser,
          roleContext: roleContext,
          dbRow: response,
        );
      } else {
        _user = _buildUserFromSources(
          authUser: supaUser,
          roleContext: roleContext,
          fallbackNickname: supaUser.phone ?? '新用户',
          fallbackAvatar: 'https://picsum.photos/seed/user/100/100',
        );

        await client.from('users').upsert({
          'id': _user.id,
          'nickname': _user.nickname,
          'avatar': _user.avatar,
          'vip_level': _user.vipLevel,
          'title': _user.title,
          'balance': _user.balance,
          'coupon_count': _user.couponCount,
          'follow_count': _user.followCount,
          'fans_count': _user.fansCount,
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase Sync Error: $e');
      _user = _buildUserFromSources(
        authUser: supaUser,
        roleContext: const _UserRoleContext(),
        fallbackNickname: supaUser.phone ?? '新用户',
        fallbackAvatar: 'https://picsum.photos/seed/user/100/100',
      );
      notifyListeners();
    }
  }

  Future<_UserRoleContext> _loadRoleContext(String userId) async {
    final client = supabase.Supabase.instance.client;
    try {
      final results = await Future.wait<Object?>([
        client.from('follows').count().eq('follower_id', userId),
        client.from('follows').count().eq('followed_id', userId),
        client.from('guides').select('id').eq('id', userId).maybeSingle(),
        client
            .from('guide_applications')
            .select('status')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      ]);

      final guideRow = results[2];
      final applicationRow = results[3];
      final applicationStatus = applicationRow is Map<String, dynamic>
          ? applicationRow['status']?.toString()
          : null;

      return _UserRoleContext(
        followCount: results[0] as int? ?? 0,
        fansCount: results[1] as int? ?? 0,
        isGuide: guideRow != null || applicationStatus == 'approved',
        applicationStatus: applicationStatus,
      );
    } catch (e) {
      debugPrint('loadRoleContext error: $e');
      return const _UserRoleContext();
    }
  }

  Future<void> sendSmsCode(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _phoneAuthService.sendCode(phoneNumber);
      _pendingPhoneNumber = phoneNumber;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('sendSmsCode error: $e');
      if (e is supabase.AuthException) {
        throw Exception('发送失败: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> verifySmsCode(String smsCode) async {
    if (_pendingPhoneNumber == null) {
      throw Exception('请先获取验证码');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _phoneAuthService.verifyCode(_pendingPhoneNumber!, smsCode);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('verifySmsCode error: $e');
      if (e is supabase.AuthException) {
        throw Exception('验证码错误: ${e.message}');
      }
      throw Exception('验证失败');
    }
  }

  void logout() async {
    await supabase.Supabase.instance.client.auth.signOut();
  }

  Future<void> updateUser(User newUser) async {
    final oldUser = _user;
    _user = newUser;
    notifyListeners();

    if (isLoggedIn && !_user.id.startsWith('mock')) {
      try {
        final client = supabase.Supabase.instance.client;
        await client.auth.updateUser(
          supabase.UserAttributes(data: _profileMetadataFromUser(_user)),
        );
        await client.from('users').update({
          'nickname': _user.nickname,
          'avatar': _user.avatar,
          'title': _user.title,
        }).eq('id', _user.id);

        if (_user.isGuideApproved) {
          await client
              .from('guides')
              .update({
                'name': _user.nickname,
                'avatar': _user.avatar,
                'description': _user.guideIntroduction.isNotEmpty
                    ? _user.guideIntroduction
                    : _user.bio,
                'city': _user.city,
                'gender': _user.gender,
                'tags': _user.guideTags,
              })
              .eq('id', _user.id);
        }
      } catch (e) {
        _user = oldUser;
        notifyListeners();
        debugPrint('Error updating user in Supabase: $e');
        throw Exception('$e');
      }
    }
  }

  Future<void> followUser(String targetId) async {
    if (!isLoggedIn) throw Exception('请先登录后操作');

    if (targetId.isEmpty || targetId.startsWith('mock_')) {
      return;
    }

    try {
      await supabase.Supabase.instance.client.from('follows').insert({
        'follower_id': user.id,
        'followed_id': targetId,
      });
      await _syncUserWithDatabase(
        supabase.Supabase.instance.client.auth.currentUser!,
      );
    } catch (e) {
      debugPrint('Follow error: $e');
      throw Exception('关注失败: 可能未开通此服务或网络异常');
    }
  }

  Future<void> unfollowUser(String targetId) async {
    if (!isLoggedIn) throw Exception('请先登录');

    if (targetId.isEmpty || targetId.startsWith('mock_')) {
      return;
    }

    try {
      await supabase.Supabase.instance.client.from('follows').delete().match({
        'follower_id': user.id,
        'followed_id': targetId,
      });
      await _syncUserWithDatabase(
        supabase.Supabase.instance.client.auth.currentUser!,
      );
    } catch (e) {
      debugPrint('Unfollow error: $e');
      throw Exception('取消关注失败');
    }
  }

  Future<bool> isFollowing(String targetId) async {
    if (!isLoggedIn) return false;
    try {
      final response = await supabase.Supabase.instance.client
          .from('follows')
          .select()
          .match({'follower_id': user.id, 'followed_id': targetId})
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getFollowingUsers() async {
    if (!isLoggedIn) return [];
    try {
      final response = await supabase.Supabase.instance.client
          .from('follows')
          .select('*, users!follows_followed_id_fkey(*)')
          .eq('follower_id', user.id);

      return (response as List)
          .map((e) {
            final userData = e['users'];
            if (userData == null) return User.guest();
            return User.fromJson(userData as Map<String, dynamic>);
          })
          .where((u) => u.isLoggedIn)
          .toList();
    } catch (e) {
      debugPrint('getFollowingUsers error: $e');
      return [];
    }
  }

  Future<User?> fetchUserById(String userId) async {
    try {
      final client = supabase.Supabase.instance.client;
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;

      final results = await Future.wait([
        client.from('follows').count().eq('follower_id', userId),
        client.from('follows').count().eq('followed_id', userId),
      ]);

      return User.fromJson({
        ...response,
        'follow_count': results[0] as int? ?? 0,
        'fans_count': results[1] as int? ?? 0,
      });
    } catch (e) {
      debugPrint('fetchUserById error: $e');
      return null;
    }
  }

  void mockLogin() {
    _isLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), () {
      _user = User(
        id: 'mock_123',
        nickname: '本地测试用户',
        avatar: 'https://picsum.photos/seed/me/100/100',
        city: '苏州',
        bio: '喜欢城市漫游、打卡和临时约伴。',
        occupation: '自由职业',
        vipLevel: 1,
        title: '体验用户',
        balance: 100.0,
        couponCount: 1,
        followCount: 10,
        fansCount: 5,
        isAdmin: false,
        isGuide: false,
      );
      _isLoading = false;
      notifyListeners();
    });
  }

  void mockAdminLogin() {
    _isLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), () {
      _user = User(
        id: 'mock_admin_001',
        nickname: '本地测试管理员',
        avatar: 'https://picsum.photos/seed/admin/100/100',
        city: '苏州',
        vipLevel: 1,
        title: '平台管理员',
        balance: 100.0,
        couponCount: 0,
        followCount: 0,
        fansCount: 0,
        isAdmin: true,
      );
      _isLoading = false;
      notifyListeners();
    });
  }
}

class _UserRoleContext {
  final int followCount;
  final int fansCount;
  final bool isGuide;
  final String? applicationStatus;

  const _UserRoleContext({
    this.followCount = 0,
    this.fansCount = 0,
    this.isGuide = false,
    this.applicationStatus,
  });
}
