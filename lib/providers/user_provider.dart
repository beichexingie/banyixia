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
        // User exists in Database, load their data
        _user = User(
          id: supaUser.id,
          nickname: response['nickname'] ?? supaUser.phone ?? '新用户',
          avatar: response['avatar'] ?? 'https://picsum.photos/seed/user/100/100',
          vipLevel: response['vip_level'] ?? 1,
          title: response['title'] ?? '初级旅行家',
          balance: (response['balance'] ?? 0.0).toDouble(),
          couponCount: response['coupon_count'] ?? 0,
          followCount: response['follow_count'] ?? 0,
          fansCount: response['fans_count'] ?? 0,
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
          followCount: 5,
          fansCount: 0,
        );
        
        await client.from('users').insert({
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

  Future<void> updateUser(User newUser) async {
    _user = newUser;
    notifyListeners();
    
    // Also update in Database if logged in with Supabase
    if (isLoggedIn && _user.id != 'mock_123') {
      try {
        await supabase.Supabase.instance.client.from('users').update({
          'nickname': _user.nickname,
          'avatar': _user.avatar,
        }).eq('id', _user.id);
      } catch (e) {
        debugPrint('Error updating user in Supabase: $e');
      }
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
