import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideConsoleHeader extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  final VoidCallback? onServiceOperationTap;
  final VoidCallback? onEmergencyTap;
  final VoidCallback? onToggleOnlineTap;
  final bool compact;

  const GuideConsoleHeader({
    super.key,
    this.onSettingsTap,
    this.onServiceOperationTap,
    this.onEmergencyTap,
    this.onToggleOnlineTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final console = context.watch<GuideConsoleProvider>();
    final statusLabel = console.isOnline ? '在线中' : '下线中';
    final identityText = _buildIdentityText(user);
    final displayName = _buildDisplayName(user);
    final vipLabel = user.vipLabel.isNotEmpty ? user.vipLabel : 'VIP';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: user.avatar.isNotEmpty
              ? Image.network(
                  user.avatar,
                  width: compact ? 50 : 56,
                  height: compact ? 50 : 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _AvatarFallback(compact: compact),
                )
              : _AvatarFallback(compact: compact),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1B35B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      vipLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6A4100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    identityText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                  GuidePillButton(
                    label: statusLabel,
                    icon: Icons.remove_circle,
                    onTap: onToggleOnlineTap,
                    color: const Color(0xFFF3F4F6),
                    foregroundColor: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SideActionButton(
                icon: Icons.mark_chat_unread_outlined,
                label: '接单设置',
                onTap: onSettingsTap,
              ),
              _SideActionButton(
                icon: Icons.person_pin_circle_outlined,
                label: '专属运营',
                onTap: onServiceOperationTap,
              ),
            ],
          ),
        ] else ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onEmergencyTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency_outlined, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '紧急联系人',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _buildDisplayName(User user) {
    if (user.nickname.trim().isNotEmpty) {
      return user.nickname.trim();
    }
    if (user.city.trim().isNotEmpty) {
      return '${user.city.trim()}地陪';
    }
    return '地陪用户';
  }

  String _buildIdentityText(User user) {
    if (user.city.trim().isNotEmpty) {
      return user.city.trim();
    }
    if (user.id.isEmpty) {
      return '未完善资料';
    }
    final compactId = user.id.replaceAll('-', '');
    final suffix = compactId.length <= 6
        ? compactId
        : compactId.substring(compactId.length - 6);
    return 'ID：$suffix';
  }
}

class _AvatarFallback extends StatelessWidget {
  final bool compact;

  const _AvatarFallback({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 50 : 56,
      height: compact ? 50 : 56,
      color: const Color(0xFFECEEF2),
      child: const Icon(Icons.person, color: AppColors.textHint),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SideActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 22, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
