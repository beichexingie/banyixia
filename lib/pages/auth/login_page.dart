import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/auth_config.dart';
import '../../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCodeSent = false;
  bool _agreed = true;
  bool _passwordMode = false;
  bool _resetMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _phone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.startsWith('86') && digits.length == 13
        ? digits.substring(2)
        : digits;
  }

  bool _validatePhone() {
    if (_phone().length == 11) return true;
    _showMessage('请输入有效的手机号', isError: true);
    return false;
  }

  bool _validatePassword(String password) {
    return RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d!@#\$%^&*._-]{8,64}$',
    ).hasMatch(password);
  }

  Future<void> _sendCode() async {
    if (!_agreed || !_validatePhone()) return;
    try {
      await context.read<UserProvider>().sendSmsCode(
        '${AuthConfig.defaultCountryCode}${_phone()}',
        purpose: _resetMode ? 'reset_password' : 'login',
      );
      if (!mounted) return;
      setState(() => _isCodeSent = true);
      _showMessage('验证码已发送');
    } catch (e) {
      if (mounted) _showMessage('发送失败: $e', isError: true);
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      _showMessage('请先勾选协议', isError: true);
      return;
    }
    if (!_validatePhone()) return;
    final provider = context.read<UserProvider>();
    try {
      if (_resetMode) {
        final code = _smsController.text.trim();
        final password = _passwordController.text;
        if (code.length < AuthConfig.otpLength) {
          _showMessage('请输入有效的验证码', isError: true);
          return;
        }
        if (!_validatePassword(password)) {
          _showMessage('密码需为8-64位，并同时包含字母和数字', isError: true);
          return;
        }
        if (password != _confirmPasswordController.text) {
          _showMessage('两次输入的密码不一致', isError: true);
          return;
        }
        await provider.resetPassword(
          '${AuthConfig.defaultCountryCode}${_phone()}',
          code,
          password,
        );
        if (!mounted) return;
        setState(() {
          _resetMode = false;
          _passwordMode = true;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        _showMessage('密码设置成功，请使用新密码登录');
        return;
      }

      if (_passwordMode) {
        final password = _passwordController.text;
        if (!_validatePassword(password)) {
          _showMessage('密码需为8-64位，并同时包含字母和数字', isError: true);
          return;
        }
        await provider.loginWithPassword(
          '${AuthConfig.defaultCountryCode}${_phone()}',
          password,
        );
      } else {
        final code = _smsController.text.trim();
        if (code.length < AuthConfig.otpLength) {
          _showMessage('请输入有效的验证码', isError: true);
          return;
        }
        await provider.verifySmsCodeForPhone(
          '${AuthConfig.defaultCountryCode}${_phone()}',
          code,
        );
      }
    } catch (e) {
      if (mounted) _showMessage('操作失败: $e', isError: true);
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

  void _setMode({required bool password, bool reset = false}) {
    setState(() {
      _passwordMode = password;
      _resetMode = reset;
      _isCodeSent = false;
      _smsController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.15,
              colors: [Color(0xFFD9FF56), Color(0xFFF5FFBC), Colors.white],
              stops: [0.0, 0.30, 0.84],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(right: 22, top: 36, child: _HeroMark()),
              Positioned(
                left: size.width * .08,
                top: size.height * (601 / 812),
                child: IgnorePointer(
                  child: _BottomDoodle(
                    width: size.width * (317 / 375),
                    height: size.height * (177.36 / 812),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      ),
                      const SizedBox(height: 82),
                      Text(
                        _resetMode
                            ? '设置新密码'
                            : (_passwordMode ? '密码登录' : '手机号登录'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _resetMode
                            ? '验证手机号后设置新的登录密码'
                            : (_passwordMode ? '使用手机号和密码登录' : '未注册手机号验证后将自动登录'),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFB8B8B8),
                        ),
                      ),
                      const SizedBox(height: 54),
                      _buildPhoneField(),
                      const SizedBox(height: 16),
                      if (!_passwordMode || _resetMode) ...[
                        _buildSmsField(),
                        const SizedBox(height: 12),
                      ],
                      if (_passwordMode || _resetMode) ...[
                        _buildPasswordField(
                          _resetMode ? '新密码' : '请输入密码',
                          _passwordController,
                        ),
                        if (_resetMode) ...[
                          const SizedBox(height: 12),
                          _buildPasswordField(
                            '确认新密码',
                            _confirmPasswordController,
                          ),
                        ],
                        if (_passwordMode && !_resetMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  _setMode(password: true, reset: true),
                              child: const Text('忘记密码？'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      _buildAgreement(),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFB7FF18),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: const Color(0xFFE8F6B4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: provider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _resetMode ? '确认设置' : '登录',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () => _setMode(password: !_passwordMode),
                          child: Text(
                            _resetMode || _passwordMode ? '短信验证码登录' : '密码登录',
                          ),
                        ),
                      ),
                      if (_resetMode)
                        Center(
                          child: TextButton(
                            onPressed: () => _setMode(password: true),
                            child: const Text('返回密码登录'),
                          ),
                        ),
                      const SizedBox(height: 100),
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

  Widget _buildPhoneField() => _LoginField(
    child: TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        prefixText: '${AuthConfig.defaultCountryCode}  ',
        border: InputBorder.none,
        hintText: '请输入手机号',
      ),
    ),
  );

  Widget _buildSmsField() => _LoginField(
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _smsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '请输入验证码',
            ),
          ),
        ),
        TextButton(
          onPressed: providerLoading ? null : _sendCode,
          child: Text(_isCodeSent ? '重新获取' : '获取验证码'),
        ),
      ],
    ),
  );

  bool get providerLoading => context.read<UserProvider>().isLoading;

  Widget _buildPasswordField(String hint, TextEditingController controller) =>
      _LoginField(
        child: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        ),
      );

  Widget _buildAgreement() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => setState(() => _agreed = !_agreed),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _agreed ? const Color(0xFFB7FF18) : Colors.white,
            border: Border.all(
              color: _agreed
                  ? const Color(0xFFB7FF18)
                  : const Color(0xFFDADADA),
            ),
          ),
          child: _agreed ? const Icon(Icons.check, size: 14) : null,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          '我已阅读并同意《用户协议》和《隐私协议》',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF999999),
            height: 1.45,
          ),
        ),
      ),
    ],
  );
}

class _LoginField extends StatelessWidget {
  final Widget child;
  const _LoginField({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF6F6F6),
      borderRadius: BorderRadius.circular(18),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: child,
  );
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 150,
    height: 220,
    child: Image(
      image: AssetImage('assets/login/Group.png'),
      fit: BoxFit.contain,
    ),
  );
}

class _BottomDoodle extends StatelessWidget {
  final double width;
  final double height;
  const _BottomDoodle({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
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
