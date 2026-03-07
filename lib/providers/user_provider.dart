import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class UserProvider extends ChangeNotifier {
  User _user = User.guest();
  bool _isLoading = false;
  String? _verificationId;
  firebase_auth.ConfirmationResult? _webConfirmationResult;

  User get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user.id.isNotEmpty && _user.id != '0';

  UserProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser != null) {
          // User is signed in via Firebase Auth, now sync with Firestore
          await _syncUserWithFirestore(firebaseUser);
        } else {
          // User is signed out.
          _user = User.guest();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('FirebaseAuth Error: $e');
      _user = User.guest();
      notifyListeners();
    }
  }

  Future<void> _syncUserWithFirestore(firebase_auth.User firebaseUser) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        // User exists in Firestore, load their data
        final data = docSnap.data()!;
        _user = User(
          id: firebaseUser.uid,
          nickname: data['nickname'] ?? firebaseUser.phoneNumber ?? '新用户',
          avatar: data['avatar'] ?? 'https://picsum.photos/seed/user/100/100',
          vipLevel: data['vipLevel'] ?? 1,
          title: data['title'] ?? '初级旅行家',
          balance: (data['balance'] ?? 0.0).toDouble(),
          couponCount: data['couponCount'] ?? 0,
          followCount: data['followCount'] ?? 0,
          fansCount: data['fansCount'] ?? 0,
        );
      } else {
        // New user, create a default profile in Firestore
        _user = User(
          id: firebaseUser.uid,
          nickname: firebaseUser.phoneNumber ?? '新用户',
          avatar: 'https://picsum.photos/seed/user/100/100',
          vipLevel: 1,
          title: '初级旅行家',
          balance: 0.0,
          couponCount: 3,
          followCount: 5,
          fansCount: 0,
        );
        
        await docRef.set({
          'id': _user.id,
          'nickname': _user.nickname,
          'avatar': _user.avatar,
          'vipLevel': _user.vipLevel,
          'title': _user.title,
          'balance': _user.balance,
          'couponCount': _user.couponCount,
          'followCount': _user.followCount,
          'fansCount': _user.fansCount,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      // Fallback to basic auth info if Firestore fails
      _user = User(
        id: firebaseUser.uid,
        nickname: firebaseUser.phoneNumber ?? '新用户',
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
      if (kIsWeb) {
        // Web requires a slightly different flow with signInWithPhoneNumber which handles Recaptcha
        _webConfirmationResult = await firebase_auth.FirebaseAuth.instance.signInWithPhoneNumber(
          phoneNumber,
        );
        _isLoading = false;
        notifyListeners();
      } else {
        // Android / iOS / Windows Flow
        await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
            await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
            _isLoading = false;
            notifyListeners();
          },
          verificationFailed: (firebase_auth.FirebaseAuthException e) {
            _isLoading = false;
            notifyListeners();
            throw Exception(e.message ?? '验证失败');
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            _isLoading = false;
            notifyListeners();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("sendSmsCode error: $e");
      rethrow;
    }
  }

  Future<void> verifySmsCode(String smsCode) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw Exception('验证码未发送或已过期');
        }
        await _webConfirmationResult!.confirm(smsCode);
      } else {
        if (_verificationId == null) {
          throw Exception('验证码ID无效，请重新发送');
        }
        firebase_auth.PhoneAuthCredential credential = firebase_auth.PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: smsCode,
        );
        await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("verifySmsCode error: $e");
      throw Exception('验证码错误或已过期');
    }
  }

  void logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
  }

  Future<void> updateUser(User newUser) async {
    _user = newUser;
    notifyListeners();
    
    // Also update in Firestore if logged in with Firebase
    if (isLoggedIn && _user.id != 'mock_123') {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_user.id).update({
          'nickname': _user.nickname,
          'avatar': _user.avatar,
        });
      } catch (e) {
        debugPrint('Error updating user in Firestore: $e');
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
