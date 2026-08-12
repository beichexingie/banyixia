import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/auth_config.dart';
import '../../providers/user_provider.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _phoneNumber(UserProvider userProvider) {
    final value = userProvider.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (value.startsWith('+86')) {
      return value;
    }
    if (value.length == 11 && value.startsWith('1')) {
      return '${AuthConfig.defaultCountryCode}$value';
    }
    return value;
  }

  bool _validPassword(String value) {
    return RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d!@#\$%^&*._-]{8,64}$',
    ).hasMatch(value);
  }

  Future<void> _sendCode(UserProvider userProvider) async {
    final phone = _phoneNumber(userProvider);
    if (phone.isEmpty) {
      _snack('当前账号未绑定手机号，无法修改密码', error: true);
      return;
    }
    try {
      await userProvider.sendSmsCode(phone, purpose: 'reset_password');
      if (!mounted) return;
      setState(() => _codeSent = true);
      _snack('验证码已发送');
    } catch (e) {
      _snack('发送失败: $e', error: true);
    }
  }

  Future<void> _submit(UserProvider userProvider) async {
    final phone = _phoneNumber(userProvider);
    if (phone.isEmpty) {
      _snack('当前账号未绑定手机号，无法修改密码', error: true);
      return;
    }
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (code.length < AuthConfig.otpLength) {
      _snack('请输入有效的验证码', error: true);
      return;
    }
    if (!_validPassword(password)) {
      _snack('密码需为8-64位，并同时包含字母和数字', error: true);
      return;
    }
    if (password != confirm) {
      _snack('两次输入的密码不一致', error: true);
      return;
    }
    try {
      await userProvider.resetPassword(phone, code, password);
      if (!mounted) return;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _snack('密码修改成功');
      Navigator.of(context).maybePop();
    } catch (e) {
      _snack('修改失败: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final phoneText = userProvider.phoneNumber.isEmpty
        ? '未绑定手机号'
        : userProvider.phoneNumber;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('修改密码'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前手机号',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phoneText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '先获取验证码，再设置新密码。密码需包含字母和数字，且长度为 8-64 位。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '请输入验证码',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: userProvider.isLoading
                      ? null
                      : () => _sendCode(userProvider),
                  child: Text(_codeSent ? '重新获取' : '获取验证码'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _field(
            child: TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入新密码',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请再次输入新密码',
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: userProvider.isLoading
                  ? null
                  : () => _submit(userProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: userProvider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '确认修改',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
