abstract class PhoneAuthService {
  Future<void> sendCode(String phoneNumber);
  Future<void> verifyCode(String phoneNumber, String smsCode);
}

class DeprecatedPhoneAuthService implements PhoneAuthService {
  @override
  Future<void> sendCode(String phoneNumber) async {
    throw UnimplementedError('Please use ECS session service');
  }

  @override
  Future<void> verifyCode(String phoneNumber, String smsCode) async {
    throw UnimplementedError('Please use ECS session service');
  }
}
