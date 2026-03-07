import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _buildSection(
            children: [
              _settingsItem(context, Icons.person_outline, '编辑资料', () {
                _showSnack(context, '资料编辑页稍后完善');
              }),
              const Divider(height: 1, indent: 48),
              _settingsItem(context, Icons.notifications_outlined, '消息通知设置', () {
                context.push('/settings/notifications');
              }),
              const Divider(height: 1, indent: 48),
              _settingsItem(context, Icons.lock_outline, '账号安全', () {
                context.push('/settings/security');
              }),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            children: [
              _settingsItem(context, Icons.help_outline, '帮助与反馈', () {
                context.push('/settings/help');
              }),
              const Divider(height: 1, indent: 48),
              _settingsItem(context, Icons.info_outline, '关于我们', () {
                _showAboutDialog(context);
              }),
            ],
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  userProvider.logout(); // The router will automatically redirect to /login
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.red),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
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

  Widget _settingsItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('伴一下', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('v1.0.0', style: TextStyle(color: AppColors.textHint)),
              const SizedBox(height: 12),
              const Text('出门缺伴？那就伴一下', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好的', style: TextStyle(color: AppColors.primary)),
              ),
            ),
          ],
        );
      },
    );
  }
}
