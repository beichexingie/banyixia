import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_backend_provider.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_console_header.dart';
import '../widgets/guide_design_icon.dart';

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
    final backend = context.watch<GuideBackendProvider>();
    final stats = console.stats;
    final positiveReviews = backend.reviews.where((item) {
      final value = item['rating'];
      final rating = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0;
      return rating >= 4;
    }).length;

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuideConsoleHeader(
              compact: true,
              onEmergencyTap: onOpenEmergencyContacts,
              onToggleOnlineTap: () => console.setOnline(!console.isOnline),
            ),
            const SizedBox(height: 14),
            _StatsCard(
              totalOrders: stats.totalOrders,
              completedOrders: stats.completedOrders,
              positiveReviews: positiveReviews,
              cancelOrders: stats.cancelOrders,
              cancellationRate: stats.cancellationRate,
            ),
            const SizedBox(height: 10),
            GuideSectionCard(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'hi～我是你的一点伴专属运营',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onOpenServiceOps,
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        '联系运营',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ShortcutItem(
                  asset: '时间管理',
                  title: console.shortcuts[0].title,
                  onTap: onOpenScheduleCenter,
                ),
                _ShortcutItem(
                  asset: '服务项目',
                  title: console.shortcuts[1].title,
                  onTap: onOpenServiceItems,
                ),
                _ShortcutItem(
                  asset: '客户评价',
                  title: console.shortcuts[2].title,
                  onTap: onOpenReviewCenter,
                ),
                _ShortcutItem(
                  asset: '我的动态',
                  title: '我的动态',
                  onTap: onOpenPublish,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TaskCard(
                    asset: '拉新赚钱',
                    onTap: onOpenPromotionCenter,
                    tall: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _TaskCard(asset: '任务中心', onTap: onOpenTaskCenter),
                      const SizedBox(height: 10),
                      _TaskCard(asset: '培训中心', onTap: onOpenTrainingCenter),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenDutySettings,
              borderRadius: BorderRadius.circular(14),
              child: GuideSectionCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const GuideDesignIcon('接单设置', size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '接单设置',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: AppColors.textSecondary,
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
      ('接单量', totalOrders),
      ('完单量', completedOrders),
      ('好评数', positiveReviews),
      ('退单量', cancelOrders),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDFFF90), Color(0xFFF1FFD0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '实时数据',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB52F),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  '近30天退单率: $cancellationRate%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Column(
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.$2}',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          '累计',
                          style: TextStyle(
                            fontSize: 10,
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
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String asset;
  final String title;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.asset,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: GuideDesignIcon(asset, size: 32),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final bool tall;

  const _TaskCard({
    required this.asset,
    required this.onTap,
    this.tall = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: AspectRatio(
          aspectRatio: tall ? 168 / 166 : 168 / 78,
          child: GuideDesignIcon(
            asset,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}
