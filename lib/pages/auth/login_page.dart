import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/auth_config.dart';
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
      _phoneController.text = '13800138000';
      _smsController.text = '123456';
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
    if (phone.isEmpty || phone.length != 11) {
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
    if (phone.isEmpty || phone.length != 11) {
      _showMessage('请输入有效的手机号');
      return;
    }

    final smsCode = _smsController.text.trim();
    if (smsCode.isEmpty || smsCode.length < AuthConfig.otpLength) {
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
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final doodleLeft = screenWidth * 0.08;
    final doodleTop = screenHeight * (601 / 812);
    final doodleWidth = screenWidth * (317 / 375);
    final doodleHeight = screenHeight * (177.36 / 812);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.15,
              colors: [
                Color(0xFFD9FF56),
                Color(0xFFF5FFBC),
                Colors.white,
              ],
              stops: [0.0, 0.30, 0.84],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: 22,
                top: 36,
                child: _HeroMark(),
              ),
              Positioned(
                left: doodleLeft,
                top: doodleTop,
                child: IgnorePointer(
                  child: _BottomDoodle(
                    width: doodleWidth,
                    height: doodleHeight,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight - 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 82),
                      const Text(
                        '手机号登录',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '未注册手机号验证后将自动登录',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFB8B8B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 128),
                      _buildPhoneField(),
                      const SizedBox(height: 16),
                      _buildSmsField(),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF58DCCE),
                        ),
                        child: const Text(
                          '收不到验证码？',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _agreed = !_agreed),
                            child: Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _agreed
                                    ? const Color(0xFFB7FF18)
                                    : Colors.white,
                                border: Border.all(
                                  color: _agreed
                                      ? const Color(0xFFB7FF18)
                                      : const Color(0xFFDADADA),
                                  width: 1.4,
                                ),
                              ),
                              child: _agreed
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.black,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF999999),
                                    height: 1.45,
                                  ),
                                  children: [
                                    TextSpan(text: '我已阅读并同意 '),
                                    TextSpan(
                                      text: '《用户协议》',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    TextSpan(text: ' '),
                                    TextSpan(
                                      text: '《隐私协议》',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: userProvider.isLoading ? null : _verifyAndLogin,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFB7FF18),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: const Color(0xFFE8F6B4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: userProvider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
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
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('密码登录暂未开放')),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                          ),
                          child: const Text(
                            '密码登录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (false && kDebugMode) ...[
                        const SizedBox(height: 32),
                        const Text(
                          '可直接输入测试账号登录，例如：13800138000 / 123456',
                          style: TextStyle(
                            color: Color(0xFF8F8F8F),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => context.read<UserProvider>().mockLogin(),
                              child: const Text(
                                '免验证码快速体验',
                                style: TextStyle(
                                  color: Color(0xFF8F8F8F),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  context.read<UserProvider>().mockAdminLogin(),
                              child: const Text(
                                '管理员测试',
                                style: TextStyle(
                                  color: Color(0xFF8F8F8F),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          prefixIconConstraints: BoxConstraints(minWidth: 78),
          prefixIcon: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 10, 18),
            child: Text(
              AuthConfig.defaultCountryCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          hintText: '请输入手机号',
          hintStyle: TextStyle(
            color: Color(0xFFD0D0D0),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSmsField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _smsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '请输入验证码',
                hintStyle: TextStyle(
                  color: Color(0xFFD0D0D0),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: _sendCode,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF58DCCE),
              padding: const EdgeInsets.fromLTRB(10, 16, 18, 16),
            ),
            child: Text(
              _isCodeSent ? '重新获取' : '获取验证码',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 150,
      height: 220,
      child: Image(
        image: AssetImage('assets/login/Group.png'),
        fit: BoxFit.contain,
      ),
    );
  }
}

class _BottomDoodle extends StatelessWidget {
  final double width;
  final double height;

  const _BottomDoodle({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Image(
        image: AssetImage('assets/login_doodles/Group 1312315300.png'),
        fit: BoxFit.contain,
        color: Color(0xFFD4D4D4),
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
