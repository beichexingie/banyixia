import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_console_header.dart';

class GuideWorkbenchPage extends StatelessWidget {
  final VoidCallback onOpenServiceOps;
  final VoidCallback onOpenPublish;
  final VoidCallback onOpenEmergencyContacts;
  final VoidCallback onOpenServiceItems;
  final VoidCallback onOpenAddressManager;
  final VoidCallback onOpenReviewCenter;
  final VoidCallback onOpenScheduleCenter;

  const GuideWorkbenchPage({
    super.key,
    required this.onOpenServiceOps,
    required this.onOpenPublish,
    required this.onOpenEmergencyContacts,
    required this.onOpenServiceItems,
    required this.onOpenAddressManager,
    required this.onOpenReviewCenter,
    required this.onOpenScheduleCenter,
  });

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final stats = console.stats;

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuideConsoleHeader(
              compact: true,
              onEmergencyTap: onOpenEmergencyContacts,
              onToggleOnlineTap: () => console.setOnline(!console.isOnline),
            ),
            const SizedBox(height: 18),
            _StatsCard(
              totalOrders: stats.totalOrders,
              completedOrders: stats.completedOrders,
              positiveReviews: stats.positiveReviews,
              cancelOrders: stats.cancelOrders,
              cancellationRate: stats.cancellationRate,
            ),
            const SizedBox(height: 18),
            GuideSectionCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'hi～我是你的一点伴专属运营',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  GuidePillButton(
                    label: '联系运营',
                    icon: Icons.mark_chat_unread_outlined,
                    active: true,
                    onTap: onOpenServiceOps,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: console.shortcuts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.74,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final item = console.shortcuts[index];
                final onTap = switch (index) {
                  0 => onOpenScheduleCenter,
                  1 => onOpenServiceItems,
                  2 => onOpenReviewCenter,
                  3 => onOpenPublish,
                  _ => null,
                };
                return InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(item.icon, size: 36, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BigTaskCard(
                    title: console.taskCards[0].title,
                    subtitle: console.taskCards[0].subtitle,
                    icon: console.taskCards[0].icon,
                    backgroundColor: console.taskCards[0].backgroundColor,
                    foregroundColor: console.taskCards[0].foregroundColor,
                    buttonLabel: '立即邀请',
                    tall: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _BigTaskCard(
                        title: console.taskCards[1].title,
                        subtitle: console.taskCards[1].subtitle,
                        icon: console.taskCards[1].icon,
                        backgroundColor: console.taskCards[1].backgroundColor,
                        foregroundColor: console.taskCards[1].foregroundColor,
                      ),
                      const SizedBox(height: 16),
                      _BigTaskCard(
                        title: console.taskCards[2].title,
                        subtitle: console.taskCards[2].subtitle,
                        icon: console.taskCards[2].icon,
                        backgroundColor: console.taskCards[2].backgroundColor,
                        foregroundColor: console.taskCards[2].foregroundColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: onOpenAddressManager,
              borderRadius: BorderRadius.circular(24),
              child: GuideSectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.mark_chat_read_outlined, size: 30),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '服务地址管理',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 30,
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int totalOrders;
  final int completedOrders;
  final int positiveReviews;
  final int cancelOrders;
  final int cancellationRate;

  const _StatsCard({
    required this.totalOrders,
    required this.completedOrders,
    required this.positiveReviews,
    required this.cancelOrders,
    required this.cancellationRate,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('接单量', '$totalOrders'),
      ('完单量', '$completedOrders'),
      ('好评数', '$positiveReviews'),
      ('退单量', '$cancelOrders'),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDDFF80), Color(0xFFF5FFD0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFAB03A),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(28),
                  bottomLeft: Radius.circular(22),
                ),
              ),
              child: Text(
                '近30天退单率: $cancellationRate%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '实时数据',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: items
                      .map(
                        (item) => Expanded(
                          child: Column(
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '昨日',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigTaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? buttonLabel;
  final bool tall;

  const _BigTaskCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.buttonLabel,
    this.tall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tall ? 286 : 135,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: tall ? 26 : 22,
                    fontWeight: FontWeight.w900,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: foregroundColor,
                    height: 1.4,
                  ),
                ),
                if (buttonLabel != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: const Text(
                      '立即邀请',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(icon, size: tall ? 120 : 74, color: foregroundColor),
          ),
        ],
      ),
    );
  }
}
