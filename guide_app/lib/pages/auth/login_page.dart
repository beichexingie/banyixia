import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/config/auth_config.dart';

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
  void initState() {
    super.initState();
    if (kDebugMode) {
      _phoneController.text = AuthConfig.testLoginPhone;
      _smsController.text = AuthConfig.testLoginCode;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_agreed) {
      _showMessage('请先勾选协议');
      return;
    }

    final phone = _normalizePhone(_phoneController.text);
    if (phone.length != 11) {
      _showMessage('请输入有效的手机号');
      return;
    }

    try {
      await context
          .read<UserProvider>()
          .sendSmsCode('${AuthConfig.defaultCountryCode}$phone');
      if (!mounted) return;
      setState(() => _isCodeSent = true);
      _showMessage('验证码已发送');
    } catch (e) {
      if (!mounted) return;
      _showMessage('发送失败: $e', isError: true);
    }
  }

  Future<void> _verifyAndLogin() async {
    if (!_agreed) {
      _showMessage('请先勾选协议');
      return;
    }

    final phone = _normalizePhone(_phoneController.text);
    if (phone.length != 11) {
      _showMessage('请输入有效的手机号');
      return;
    }

    final smsCode = _smsController.text.trim();
    if (smsCode.length < AuthConfig.otpLength) {
      _showMessage('请输入有效的验证码');
      return;
    }

    try {
      final userProvider = context.read<UserProvider>();
      if (_isCodeSent) {
        await userProvider.verifySmsCode(smsCode);
      } else {
        await userProvider.verifySmsCodeForPhone(
          '${AuthConfig.defaultCountryCode}$phone',
          smsCode,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('登录失败: $e', isError: true);
    }
  }

  void _fillTestAccount(String phone, String code) {
    setState(() {
      _phoneController.text = phone;
      _smsController.text = code;
      _isCodeSent = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  String _normalizePhone(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('86') && digitsOnly.length == 13) {
      return digitsOnly.substring(2);
    }
    return digitsOnly;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF7FFD9),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          size: 34,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '地陪端登录',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '使用手机号验证码登录伴一下地陪端',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _FieldCard(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            prefixText: '${AuthConfig.defaultCountryCode} ',
                            prefixStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            hintText: '请输入手机号',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FieldCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _smsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '请输入验证码',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: userProvider.isLoading ? null : _sendCode,
                              child: Text(_isCodeSent ? '重新获取' : '获取验证码'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (value) => setState(() => _agreed = value ?? false),
                            activeColor: AppColors.primaryDark,
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                '我已阅读并同意《用户协议》和《隐私协议》',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: userProvider.isLoading ? null : _verifyAndLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: userProvider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : const Text(
                                  '登录',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '调试快捷登录',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton(
                            onPressed: () => _fillTestAccount('13800138000', '123456'),
                            child: const Text('13800138000 / 123456'),
                          ),
                          OutlinedButton(
                            onPressed: () => _fillTestAccount('18860900310', '127244'),
                            child: const Text('18860900310 / 127244'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Widget child;

  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
