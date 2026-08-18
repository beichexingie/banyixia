import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/push_notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushEnabled = true;
  bool _messageEnabled = true;
  bool _likeEnabled = true;
  bool _commentEnabled = true;
  bool _systemEnabled = true;
  bool _systemPermissionEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSystemPermission();
  }

  Future<void> _loadSystemPermission() async {
    try {
      final state = await PushNotificationService.notificationPermissionState();
      if (!mounted) return;
      setState(() {
        _systemPermissionEnabled =
            state['enabled'] == true && state['permission'] != false;
        _pushEnabled = _systemPermissionEnabled;
      });
    } catch (_) {
      // The settings page also runs on web and non-Android platforms.
    }
  }

  Future<void> _enableSystemNotifications() async {
    try {
      await PushNotificationService.requestNotificationPermission();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final state = await PushNotificationService.notificationPermissionState();
      if (!mounted) return;
      setState(() {
        _systemPermissionEnabled =
            state['enabled'] == true && state['permission'] != false;
        _pushEnabled = _systemPermissionEnabled;
      });
    } catch (_) {
      // Keep the settings page usable if the native channel is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('消息通知设置'), centerTitle: true),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _buildSection(
            children: [
              _buildSwitchItem(
                '接收系统推送通知',
                _systemPermissionEnabled ? '系统通知权限已开启' : '需要在系统设置中开启通知权限',
                _systemPermissionEnabled,
                (_) => _enableSystemNotifications(),
              ),
              if (!_systemPermissionEnabled)
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('去系统设置开启通知'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await PushNotificationService.openNotificationSettings();
                    await _loadSystemPermission();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            children: [
              _buildSwitchItem(
                '私信消息通知',
                '',
                _messageEnabled,
                (v) => setState(() => _messageEnabled = v),
              ),
              const Divider(height: 1, indent: 16),
              _buildSwitchItem(
                '获赞与收藏',
                '',
                _likeEnabled,
                (v) => setState(() => _likeEnabled = v),
              ),
              const Divider(height: 1, indent: 16),
              _buildSwitchItem(
                '新增评论',
                '',
                _commentEnabled,
                (v) => setState(() => _commentEnabled = v),
              ),
              const Divider(height: 1, indent: 16),
              _buildSwitchItem(
                '系统与活动通知',
                '',
                _systemEnabled,
                (v) => setState(() => _systemEnabled = v),
              ),
            ],
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: AppTextStyles.caption)
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
