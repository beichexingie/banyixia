import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideReferencePage extends StatelessWidget {
  final VoidCallback onOpenDemandHall;
  final VoidCallback onOpenAddressManager;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenRoute;

  const GuideReferencePage({
    super.key,
    required this.onOpenDemandHall,
    required this.onOpenAddressManager,
    required this.onOpenMessages,
    required this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final orders = context.watch<OrderProvider>().orders;
    final currentUser = context.watch<UserProvider>().user;
    final guideOrders = console.buildGuideOrders(
      orders,
      guideId: currentUser.id,
    );
    final currentOrder = guideOrders.isNotEmpty ? guideOrders.first : null;

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '地陪端参考页',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        console.isOnline ? '当前状态：在线接单' : '当前状态：离线休息',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: console.isOnline,
                  activeColor: AppColors.primary,
                  onChanged: (value) => console.setOnline(value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GuideSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '快捷入口',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _RefActionChip(
                        label: '需求大厅',
                        icon: Icons.assignment_turned_in_outlined,
                        onTap: onOpenDemandHall,
                      ),
                      _RefActionChip(
                        label: '地址管理',
                        icon: Icons.place_outlined,
                        onTap: onOpenAddressManager,
                      ),
                      _RefActionChip(
                        label: '消息',
                        icon: Icons.chat_bubble_outline,
                        onTap: onOpenMessages,
                      ),
                      _RefActionChip(
                        label: '路线',
                        icon: Icons.route_outlined,
                        onTap: onOpenRoute,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuideSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '接单概览',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _RefStatCard(
                        label: '累计接单',
                        value: '${console.stats.totalOrders}',
                      ),
                      _RefStatCard(
                        label: '已完成',
                        value: '${console.stats.completedOrders}',
                      ),
                      _RefStatCard(
                        label: '好评',
                        value: '${console.stats.positiveReviews}',
                      ),
                      _RefStatCard(
                        label: '近30天退单率',
                        value: '${console.stats.cancellationRate}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuideSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前定位',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    console.currentLocation.summary,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    console.currentLocation.detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuideSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '服务地址',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  ...console.serviceAddresses
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RefAddressTile(address: item),
                        ),
                      ),
                ],
              ),
            ),
            if (currentOrder != null) ...[
              const SizedBox(height: 16),
              GuideSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前订单',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RefOrderPreview(order: currentOrder),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RefActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _RefStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefAddressTile extends StatelessWidget {
  final GuideAddress address;

  const _RefAddressTile({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address.summary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            address.detail,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefOrderPreview extends StatelessWidget {
  final GuideOrderCardData order;

  const _RefOrderPreview({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.serviceLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                order.distanceText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.address,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
