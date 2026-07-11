import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
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
    final compactId = user.id.replaceAll('-', '');
    final visibleId = compactId.isEmpty
        ? '1209384'
        : compactId.substring(0, compactId.length > 6 ? 6 : compactId.length);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        ClipOval(
          child: Image.network(
            user.avatar.isNotEmpty
                ? user.avatar
                : 'https://picsum.photos/seed/guide-user/120/120',
            width: compact ? 52 : 60,
            height: compact ? 52 : 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: compact ? 52 : 60,
              height: compact ? 52 : 60,
              color: const Color(0xFFECEEF2),
              child: const Icon(Icons.person, color: AppColors.textHint),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? 180 : 210,
            maxWidth: compact ? 220 : 260,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.nickname.isNotEmpty ? user.nickname : '用户108937',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1B35B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6A4100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'IP：$visibleId',
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
        ] else ...[
          InkWell(
            onTap: onEmergencyTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        width: 74,
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
