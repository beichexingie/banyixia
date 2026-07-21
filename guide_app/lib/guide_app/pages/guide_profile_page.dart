import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideProfilePage extends StatelessWidget {
  final VoidCallback onOpenDutySettings;
  final VoidCallback onOpenAddressManager;
  final VoidCallback onOpenCityPicker;
  final VoidCallback onOpenCertification;
  final VoidCallback onOpenPlatformRules;

  const GuideProfilePage({
    super.key,
    required this.onOpenDutySettings,
    required this.onOpenAddressManager,
    required this.onOpenCityPicker,
    required this.onOpenCertification,
    required this.onOpenPlatformRules,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final console = context.watch<GuideConsoleProvider>();
    final stats = console.stats;

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.network(
                  user.avatar.isNotEmpty
                      ? user.avatar
                      : 'https://picsum.photos/seed/guide-profile/120/120',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: const Color(0xFFECEEF2),
                    child: const Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname.isNotEmpty ? user.nickname : '地陪运营账号',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.identityLabel,
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GuidePillButton(
                          label: console.isOnline ? '在线中' : '下线中',
                          active: console.isOnline,
                          onTap: () => console.setOnline(!console.isOnline),
                        ),
                        const SizedBox(width: 10),
                        GuidePillButton(
                          label: console.selectedCity,
                          onTap: onOpenCityPicker,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GuideSectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProfileStat(label: '接单量', value: '${stats.totalOrders}'),
                _ProfileStat(label: '完单量', value: '${stats.completedOrders}'),
                _ProfileStat(label: '好评数', value: '${stats.positiveReviews}'),
                _ProfileStat(label: '退单量', value: '${stats.cancelOrders}'),
              ],
            ),
          ),
          if (false) GuideSectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _ProfileStat(label: '接单量', value: '1290'),
                _ProfileStat(label: '完单量', value: '880'),
                _ProfileStat(label: '好评数', value: '10'),
                _ProfileStat(label: '退单量', value: '2'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GuideSectionCard(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.settings_outlined,
                  title: '接单设置',
                  onTap: onOpenDutySettings,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  title: '认证资料',
                  onTap: onOpenCertification,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.location_on_outlined,
                  title: '服务地址管理',
                  onTap: onOpenAddressManager,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.policy_outlined,
                  title: '平台规则',
                  onTap: onOpenPlatformRules,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<UserProvider>().logout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE85B47),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                '退出当前账号',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
