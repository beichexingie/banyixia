import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('账号安全'),
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) => ListView(
        children: [
          const SizedBox(height: 12),
          _buildSection(
            children: [
              _buildItem(
                context,
                '绑定手机',
                _maskPhone(userProvider.phoneNumber),
                onTap: () => _showSnack(context, '手机号登录账号暂不支持在应用内更换，请联系客服处理'),
              ),
              const Divider(height: 1, indent: 16),
              _buildItem(context, '绑定微信', '未绑定', highlight: true),
              const Divider(height: 1, indent: 16),
              _buildItem(context, '绑定 QQ', '未绑定', highlight: true),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            children: [
              _buildItem(context, '修改密码', '', onTap: () => _showSnack(context, '当前账号使用短信验证码登录，无独立密码')),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            children: [
              ListTile(
                title: const Text('注销账号', style: TextStyle(fontSize: 15, color: Colors.red)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                onTap: () {
                  _showSnack(context, '如需注销账号，请联系客服');
                },
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, String value, {bool highlight = false, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: TextStyle(color: highlight ? AppColors.primary : AppColors.textSecondary, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
      onTap: onTap ?? () => _showBindingDialog(context, title),
    );
  }

  String _maskPhone(String phone) {
    final value = phone.trim();
    if (value.length < 7) return value.isEmpty ? '未绑定' : value;
    return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  }

  void _showBindingDialog(BuildContext context, String title) {
    _showSnack(context, '$title需要通过客服人工核验后处理');
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
