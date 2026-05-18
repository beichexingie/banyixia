import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/auth_config.dart';
import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  bool _isCodeSent = false;
  bool _agreed = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先勾选协议')),
      );
      return;
    }

    final phone = _normalizePhone(_phoneController.text);
    if (phone.isEmpty || phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的手机号')),
      );
      return;
    }

    try {
      await context.read<UserProvider>().sendSmsCode('${AuthConfig.defaultCountryCode}$phone');
      if (!mounted) return;
      setState(() => _isCodeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _normalizePhone(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('86') && digitsOnly.length == 13) {
      return digitsOnly.substring(2);
    }
    return digitsOnly;
  }

  Future<void> _verifyAndLogin() async {
    final smsCode = _smsController.text.trim();
    if (smsCode.isEmpty || smsCode.length < AuthConfig.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的验证码')),
      );
      return;
    }

    try {
      await context.read<UserProvider>().verifySmsCode(smsCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8FAFF), Color(0xFFF4F6FB)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '手机号登录',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '未注册手机号验证后将自动登录',
                      style: TextStyle(color: AppColors.textHint, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    _buildPhoneField(),
                    const SizedBox(height: 16),
                    if (_isCodeSent) _buildSmsField(),
                    if (_isCodeSent) const SizedBox(height: 8),
                    if (_isCodeSent)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('收不到验证码？', style: TextStyle(color: AppColors.textHint)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (value) => setState(() => _agreed = value ?? false),
                          activeColor: const Color(0xFF3D6CF5),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 11),
                            child: Text(
                              '我已阅读并同意《用户协议》和《隐私政策》',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: userProvider.isLoading
                            ? null
                            : (_isCodeSent ? _verifyAndLogin : _sendCode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D6CF5),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.divider,
                          disabledForegroundColor: AppColors.textHint,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: userProvider.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_isCodeSent ? '登录' : '获取验证码', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.read<UserProvider>().mockLogin(),
                          child: const Text(
                            '免验证码快速体验',
                            style: TextStyle(color: AppColors.textHint, decoration: TextDecoration.underline),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => context.read<UserProvider>().mockAdminLogin(),
                            child: const Text(
                              '管理员测试',
                              style: TextStyle(color: AppColors.textHint, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        '伴一下',
                        style: TextStyle(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(AuthConfig.defaultCountryCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          hintText: '请输入手机号',
          hintStyle: TextStyle(color: AppColors.textHint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSmsField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _smsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: '请输入验证码',
                hintStyle: TextStyle(color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: _sendCode,
            child: const Text('获取验证码', style: TextStyle(color: Color(0xFF3D6CF5), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
