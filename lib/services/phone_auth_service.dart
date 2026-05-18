import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

abstract class PhoneAuthService {
  Future<void> sendCode(String phoneNumber);
  Future<void> verifyCode(String phoneNumber, String smsCode);
}

class SupabasePhoneAuthService implements PhoneAuthService {
  @override
  Future<void> sendCode(String phoneNumber) async {
    await supabase.Supabase.instance.client.auth.signInWithOtp(
      phone: phoneNumber,
    );
  }

  @override
  Future<void> verifyCode(String phoneNumber, String smsCode) async {
    await supabase.Supabase.instance.client.auth.verifyOTP(
      type: supabase.OtpType.sms,
      phone: phoneNumber,
      token: smsCode,
    );
  }
}
