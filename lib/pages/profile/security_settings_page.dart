import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';
import 'password_change_page.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('账号安全'), centerTitle: true),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) => ListView(
          children: [
            const SizedBox(height: 12),
            _buildSection(
              children: [
                _buildItem(
                  context,
                  '修改密码',
                  userProvider.phoneNumber.isEmpty ? '未绑定手机号' : '通过短信验证后修改',
                  onTap: () => context.push(
                    '/settings/password',
                    extra: const PasswordChangePage(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              children: [
                ListTile(
                  title: const Text(
                    '注销账号',
                    style: TextStyle(fontSize: 15, color: Colors.red),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textHint,
                  ),
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
      child: Column(children: children),
    );
  }

  Widget _buildItem(
    BuildContext context,
    String title,
    String value, {
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: highlight ? AppColors.primary : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
      onTap: onTap ?? () => _showSnack(context, '$title暂未开放'),
    );
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
