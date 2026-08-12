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
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _codeSent = false;
  bool _agreed = true;
  bool _passwordMode = false;
  bool _resetMode = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.startsWith('86') && digits.length == 13
        ? digits.substring(2)
        : digits;
  }

  bool _validPhone() {
    if (_normalizedPhone.length == 11) return true;
    _message('请输入有效的手机号', error: true);
    return false;
  }

  bool _validPassword(String value) => RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d!@#\$%^&*._-]{8,64}$',
  ).hasMatch(value);

  Future<void> _sendCode() async {
    if (!_agreed || !_validPhone()) return;
    try {
      await context.read<UserProvider>().sendSmsCode(
        '${AuthConfig.defaultCountryCode}$_normalizedPhone',
      );
      if (!mounted) return;
      setState(() => _codeSent = true);
      _message('验证码已发送');
    } catch (e) {
      if (mounted) _message('发送失败: $e', error: true);
    }
  }

  Future<void> _submit() async {
    if (!_agreed) return _message('请先勾选协议', error: true);
    if (!_validPhone()) return;
    final provider = context.read<UserProvider>();
    try {
      if (_resetMode) {
        if (_code.text.trim().length < AuthConfig.otpLength) {
          return _message('请输入有效的验证码', error: true);
        }
        if (!_validPassword(_password.text)) {
          return _message('密码需为8-64位，并同时包含字母和数字', error: true);
        }
        if (_password.text != _confirmPassword.text) {
          return _message('两次输入的密码不一致', error: true);
        }
        await provider.resetPassword(
          '${AuthConfig.defaultCountryCode}$_normalizedPhone',
          _code.text.trim(),
          _password.text,
        );
        if (!mounted) return;
        setState(() {
          _resetMode = false;
          _passwordMode = true;
          _password.clear();
          _confirmPassword.clear();
        });
        _message('密码设置成功，请使用新密码登录');
      } else if (_passwordMode) {
        if (!_validPassword(_password.text)) {
          return _message('密码需为8-64位，并同时包含字母和数字', error: true);
        }
        await provider.loginWithPassword(
          '${AuthConfig.defaultCountryCode}$_normalizedPhone',
          _password.text,
        );
      } else {
        if (_code.text.trim().length < AuthConfig.otpLength) {
          return _message('请输入有效的验证码', error: true);
        }
        await provider.verifySmsCodeForPhone(
          '${AuthConfig.defaultCountryCode}$_normalizedPhone',
          _code.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) _message('操作失败: $e', error: true);
    }
  }

  void _mode(bool password, {bool reset = false}) {
    setState(() {
      _passwordMode = password;
      _resetMode = reset;
      _codeSent = false;
      _code.clear();
      _password.clear();
      _confirmPassword.clear();
    });
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final title = _resetMode ? '设置新密码' : (_passwordMode ? '密码登录' : '地陪端登录');
    final subtitle = _resetMode
        ? '验证手机号后设置新的登录密码'
        : (_passwordMode ? '使用手机号和密码登录伴一下地陪端' : '使用手机号验证码登录伴一下地陪端');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7FFD9), Colors.white],
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
                        color: Colors.black.withValues(alpha: .06),
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
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _field(
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            prefixText: '${AuthConfig.defaultCountryCode} ',
                            border: InputBorder.none,
                            hintText: '请输入手机号',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!_passwordMode || _resetMode) ...[
                        _field(
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _code,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '请输入验证码',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : _sendCode,
                                child: Text(_codeSent ? '重新获取' : '获取验证码'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_passwordMode || _resetMode) ...[
                        _field(
                          TextField(
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: _resetMode ? '新密码' : '请输入密码',
                            ),
                          ),
                        ),
                        if (_resetMode) ...[
                          const SizedBox(height: 14),
                          _field(
                            TextField(
                              controller: _confirmPassword,
                              obscureText: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '确认新密码',
                              ),
                            ),
                          ),
                        ],
                        if (_passwordMode && !_resetMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _mode(true, reset: true),
                              child: const Text('忘记密码？'),
                            ),
                          ),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (value) =>
                                setState(() => _agreed = value ?? false),
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
                          onPressed: provider.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: provider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
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
                          onPressed: () => _mode(!_passwordMode),
                          child: Text(
                            _resetMode || _passwordMode ? '短信验证码登录' : '密码登录',
                          ),
                        ),
                      ),
                      if (_resetMode)
                        Center(
                          child: TextButton(
                            onPressed: () => _mode(true),
                            child: const Text('返回密码登录'),
                          ),
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

  Widget _field(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}
