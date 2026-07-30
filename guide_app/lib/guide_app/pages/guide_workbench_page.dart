import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_console_header.dart';

class GuideWorkbenchPage extends StatelessWidget {
  final VoidCallback onOpenDutySettings;
  final VoidCallback onOpenServiceOps;
  final VoidCallback onOpenPublish;
  final VoidCallback onOpenDemandHall;
  final VoidCallback onOpenEmergencyContacts;
  final VoidCallback onOpenServiceItems;
  final VoidCallback onOpenAddressManager;
  final VoidCallback onOpenReviewCenter;
  final VoidCallback onOpenScheduleCenter;
  final VoidCallback onOpenPromotionCenter;
  final VoidCallback onOpenTaskCenter;
  final VoidCallback onOpenTrainingCenter;

  const GuideWorkbenchPage({
    super.key,
    required this.onOpenDutySettings,
    required this.onOpenServiceOps,
    required this.onOpenPublish,
    required this.onOpenDemandHall,
    required this.onOpenEmergencyContacts,
    required this.onOpenServiceItems,
    required this.onOpenAddressManager,
    required this.onOpenReviewCenter,
    required this.onOpenScheduleCenter,
    required this.onOpenPromotionCenter,
    required this.onOpenTaskCenter,
    required this.onOpenTrainingCenter,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            Row(
              children: [
                _ShortcutItem(
                  title: console.shortcuts[0].title,
                  icon: console.shortcuts[0].icon,
                  onTap: onOpenScheduleCenter,
                ),
                _ShortcutItem(
                  title: console.shortcuts[1].title,
                  icon: console.shortcuts[1].icon,
                  onTap: onOpenServiceItems,
                ),
                _ShortcutItem(
                  title: console.shortcuts[2].title,
                  icon: console.shortcuts[2].icon,
                  onTap: onOpenReviewCenter,
                ),
                _ShortcutItem(
                  title: '我的服务',
                  icon: Icons.public_rounded,
                  onTap: onOpenPublish,
                ),
              ],
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
                    onTap: onOpenPromotionCenter,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _BigTaskCard(
                        title: console.taskCards[1].title,
                        subtitle: console.taskCards[1].subtitle,
                        icon: console.taskCards[1].icon,
                        backgroundColor: console.taskCards[1].backgroundColor,
                        foregroundColor: console.taskCards[1].foregroundColor,
                        buttonLabel: '查看任务',
                        onTap: onOpenTaskCenter,
                      ),
                      const SizedBox(height: 16),
                      _BigTaskCard(
                        title: console.taskCards[2].title,
                        subtitle: console.taskCards[2].subtitle,
                        icon: console.taskCards[2].icon,
                        backgroundColor: console.taskCards[2].backgroundColor,
                        foregroundColor: console.taskCards[2].foregroundColor,
                        buttonLabel: '进入培训',
                        onTap: onOpenTrainingCenter,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: onOpenDutySettings,
              borderRadius: BorderRadius.circular(24),
              child: GuideSectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.mark_chat_unread_outlined, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '接单设置',
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
                Wrap(
                  spacing: 12,
                  runSpacing: 18,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: 64,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '累计',
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
  final VoidCallback? onTap;

  const _BigTaskCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.buttonLabel,
    this.tall = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: tall ? 250 : 120,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                      fontSize: tall ? 24 : 20,
                      fontWeight: FontWeight.w900,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
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
                      child: Text(
                        buttonLabel!,
                        style: const TextStyle(
                          fontSize: 14,
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
              child: Icon(icon, size: tall ? 104 : 62, color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 34, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
