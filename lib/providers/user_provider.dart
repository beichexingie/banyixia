import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';

class UserProvider extends ChangeNotifier {
  User _user = User.guest();
  bool _isLoading = false;
  String? _pendingPhoneNumber;

  User get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user.id.isNotEmpty && _user.id != '0';

  UserProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      supabase.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null && session.user != null) {
          // User is signed in via Supabase Auth, now sync with Supabase Database
          await _syncUserWithDatabase(session.user!);
        } else {
          // User is signed out.
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

  Future<void> _syncUserWithDatabase(supabase.User supaUser) async {
    try {
      final client = supabase.Supabase.instance.client;
      final response = await client
          .from('users')
          .select()
          .eq('id', supaUser.id)
          .maybeSingle();

      if (response != null) {
        // 实时统计关注数和粉丝数
        final results = await Future.wait([
          client.from('follows').count().eq('follower_id', supaUser.id),
          client.from('follows').count().eq('followed_id', supaUser.id),
        ]);
        
        // User exists in Database, load their data
        _user = User(
          id: supaUser.id,
          nickname: response['nickname'] ?? supaUser.phone ?? '新用户',
          avatar: response['avatar'] ?? 'https://picsum.photos/seed/user/100/100',
          vipLevel: response['vip_level'] ?? 1,
          title: response['title'] ?? '初级旅行家',
          balance: (response['balance'] ?? 0.0).toDouble(),
          couponCount: response['coupon_count'] ?? 0,
          followCount: results[0] as int? ?? 0,
          fansCount: results[1] as int? ?? 0,
          isBanned: response['is_banned'] ?? false,
          cancelCount: response['cancel_count'] ?? 0,
        );
      } else {
        // New user, create a default profile in Database
        _user = User(
          id: supaUser.id,
          nickname: supaUser.phone ?? '新用户',
          avatar: 'https://picsum.photos/seed/user/100/100',
          vipLevel: 1,
          title: '初级旅行家',
          balance: 0.0,
          couponCount: 3,
          followCount: 0,
          fansCount: 0,
          isBanned: false,
          cancelCount: 0,
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
      // Fallback to basic auth info if Database fails
      _user = User(
        id: supaUser.id,
        nickname: supaUser.phone ?? '新用户',
        avatar: 'https://picsum.photos/seed/user/100/100',
        vipLevel: 1,
        title: '初级旅行家',
        balance: 0.0,
        couponCount: 0,
        followCount: 0,
        fansCount: 0,
      );
      notifyListeners();
    }
  }

  Future<void> sendSmsCode(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      await supabase.Supabase.instance.client.auth.signInWithOtp(
        phone: phoneNumber,
      );
      // Save the phone number so we can verify the OTP against it later
      _pendingPhoneNumber = phoneNumber;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("sendSmsCode error: $e");
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
      await supabase.Supabase.instance.client.auth.verifyOTP(
        type: supabase.OtpType.sms,
        phone: _pendingPhoneNumber,
        token: smsCode,
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("verifySmsCode error: $e");
      if (e is supabase.AuthException) {
         throw Exception('验证码错误: ${e.message}');
      }
      throw Exception('验证失败');
    }
  }

  void logout() async {
    await supabase.Supabase.instance.client.auth.signOut();
  }

  /// 更新用户信息
  Future<void> updateUser(User newUser) async {
    final oldUser = _user;
    _user = newUser;
    notifyListeners();
    
    if (isLoggedIn && !_user.id.startsWith('mock')) {
      try {
        await supabase.Supabase.instance.client.from('users').update({
          'nickname': _user.nickname,
          'avatar': _user.avatar,
        }).eq('id', _user.id);
      } catch (e) {
        _user = oldUser; // 还原状态
        notifyListeners();
        debugPrint('Error updating user in Supabase: $e');
        throw Exception('$e');
      }
    }
  }

  /// 关注用户
  Future<void> followUser(String targetId) async {
    if (!isLoggedIn) throw Exception('请先登录');
    if (user.id == targetId) throw Exception('不能关注自己哦');
    
    // 对于本地死数据的 mock 帖子，避免调用真实 API 报错
    if (targetId.isEmpty || targetId.startsWith('mock_')) {
      return; 
    }

    try {
      await supabase.Supabase.instance.client.from('follows').insert({
        'follower_id': user.id,
        'followed_id': targetId,
      });
      // 这里的用户统计建议通过数据库 Trigger 自动更新，
      // 但为了 UI 实时性，我们可以重新加载一下当前用户信息
      await _syncUserWithDatabase(supabase.Supabase.instance.client.auth.currentUser!);
    } catch (e) {
      debugPrint('Follow error: $e');
      throw Exception('关注失败: 可能未开通此服务或网络异常');
    }
  }

  /// 取消关注
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
      await _syncUserWithDatabase(supabase.Supabase.instance.client.auth.currentUser!);
    } catch (e) {
      debugPrint('Unfollow error: $e');
      throw Exception('取消关注失败');
    }
  }

  /// 检查是否已关注
  Future<bool> isFollowing(String targetId) async {
    if (!isLoggedIn) return false;
    try {
      final response = await supabase.Supabase.instance.client
          .from('follows')
          .select()
          .match({'follower_id': user.id, 'followed_id': targetId})
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// 获取关注列表
  Future<List<User>> getFollowingUsers() async {
    if (!isLoggedIn) return [];
    try {
      final response = await supabase.Supabase.instance.client
          .from('follows')
          .select('*, users!follows_followed_id_fkey(*)')
          .eq('follower_id', user.id);
      
      return (response as List).map((e) {
        final userData = e['users'];
        if (userData == null) return User.guest();
        return User.fromJson(userData as Map<String, dynamic>);
      }).where((u) => u.isLoggedIn).toList();
    } catch (e) {
      debugPrint('getFollowingUsers error: $e');
      return [];
    }
  }

  /// 获取任意用户的公开资料
  Future<User?> fetchUserById(String userId) async {
    try {
      // 1. 获取基本资料
      final response = await supabase.Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;

      // 2. 实时统计关注数和粉丝数 (避免 reads stale counts in 'users' table)
      final results = await Future.wait([
        supabase.Supabase.instance.client
            .from('follows')
            .count()
            .eq('follower_id', userId),
        supabase.Supabase.instance.client
            .from('follows')
            .count()
            .eq('followed_id', userId),
      ]);

      final followCount = results[0] as int? ?? 0;
      final fansCount = results[1] as int? ?? 0;

      return User(
        id: userId,
        nickname: response['nickname'] ?? '用户',
        avatar: response['avatar'] ?? '',
        vipLevel: response['vip_level'] ?? 0,
        title: response['title'] ?? '',
        balance: (response['balance'] ?? 0.0).toDouble(),
        couponCount: response['coupon_count'] ?? 0,
        followCount: followCount,
        fansCount: fansCount,
      );
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
        vipLevel: 1,
        title: '体验用户',
        balance: 100.0,
        couponCount: 1,
        followCount: 10,
        fansCount: 5,
      );
      _isLoading = false;
      notifyListeners();
    });
  }
}
