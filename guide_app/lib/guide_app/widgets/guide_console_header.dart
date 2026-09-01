import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_design_icon.dart';

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
    if (compact) {
      return _CompactHeader(
        user: user,
        console: console,
        onEmergencyTap: onEmergencyTap,
        onToggleOnlineTap: onToggleOnlineTap,
      );
    }
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
                  errorBuilder: (_, __, ___) =>
                      _AvatarFallback(compact: compact),
                )
              : _AvatarFallback(compact: compact),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1B35B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      vipLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6A4100),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _InlineStatusBadge(
                    label: console.isOnline ? '在线中' : '下线中',
                    isOnline: console.isOnline,
                    onTap: onToggleOnlineTap,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                identityText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _SideActionButton(
              asset: '接单设置',
              label: '接单设置',
              onTap: onSettingsTap,
            ),
            _SideActionButton(
              asset: '专属运营',
              label: '专属运营',
              onTap: onServiceOperationTap,
            ),
          ],
        ),
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

class _InlineStatusBadge extends StatelessWidget {
  final String label;
  final bool isOnline;
  final VoidCallback? onTap;

  const _InlineStatusBadge({
    required this.label,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isOnline ? const Color(0xFFEFFFF1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.circle : Icons.remove_circle,
              size: 9,
              color: isOnline ? const Color(0xFF39A34A) : AppColors.textHint,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final User user;
  final GuideConsoleProvider console;
  final VoidCallback? onEmergencyTap;
  final VoidCallback? onToggleOnlineTap;

  const _CompactHeader({
    required this.user,
    required this.console,
    required this.onEmergencyTap,
    required this.onToggleOnlineTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.nickname.trim().isNotEmpty
        ? user.nickname.trim()
        : user.city.trim().isNotEmpty
        ? '${user.city.trim()}地陪'
        : '地陪用户';
    final compactId = user.id.replaceAll('-', '');
    final identity = user.city.trim().isNotEmpty
        ? 'IP：${user.city.trim()}'
        : compactId.isEmpty
        ? '未完善资料'
        : 'ID：${compactId.substring(0, compactId.length < 6 ? compactId.length : 6)}';
    final status = console.isOnline ? '在线中' : '下线中';

    return Row(
      children: [
        ClipOval(
          child: user.avatar.isNotEmpty
              ? Image.network(
                  user.avatar,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const _AvatarFallback(compact: true),
                )
              : const _AvatarFallback(compact: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1B35B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      user.vipLabel.isNotEmpty ? user.vipLabel : 'VIP',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6A4100),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _InlineStatusBadge(
                    label: status,
                    isOnline: console.isOnline,
                    onTap: onToggleOnlineTap,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                identity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onEmergencyTap,
          tooltip: '紧急联系人',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: const Icon(Icons.emergency_outlined, size: 20),
        ),
      ],
    );
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
  final String asset;
  final String label;
  final VoidCallback? onTap;

  const _SideActionButton({
    required this.asset,
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: GuideDesignIcon(asset, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
