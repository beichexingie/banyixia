import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_console_header.dart';

class GuideOrderCenterPage extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenServiceOps;
  final VoidCallback onOpenRoute;
  final VoidCallback onOpenChat;

  const GuideOrderCenterPage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenServiceOps,
    required this.onOpenRoute,
    required this.onOpenChat,
  });

  @override
  State<GuideOrderCenterPage> createState() => _GuideOrderCenterPageState();
}

class _GuideOrderCenterPageState extends State<GuideOrderCenterPage> {
  GuideOrderStage _selectedStage = GuideOrderStage.inProgress;

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final orders = console.buildGuideOrders(orderProvider.orders);
    final filtered = orders.where((item) => item.stage == _selectedStage).toList();

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuideConsoleHeader(
                    onSettingsTap: widget.onOpenSettings,
                    onServiceOperationTap: widget.onOpenServiceOps,
                    onToggleOnlineTap: () => console.setOnline(!console.isOnline),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final stage in GuideOrderStage.values)
                        _OrderStageTab(
                          label: stage.label,
                          active: stage == _selectedStage,
                          onTap: () => setState(() => _selectedStage = stage),
                        ),
                      InkWell(
                        onTap: widget.onOpenRoute,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.route_outlined, size: 24),
                              SizedBox(width: 6),
                              Text(
                                '路线',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GuidePillButton(
                    label: '默认排序',
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('当前为默认排序，后续可切换按距离/佣金/时间排序')),
                      );
                    },
                    color: Colors.white,
                    foregroundColor: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    GuideSectionCard(
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 56,
                            color: AppColors.textHint.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '当前阶段暂无订单',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '可以切换阶段查看，或先去工作台完善接单设置',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    )
                  else
                    ...filtered.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _GuideOrderCard(
                          data: order,
                          onChatTap: widget.onOpenChat,
                          onPrimaryTap: order.primaryAction == GuideOrderAction.navigate
                              ? widget.onOpenRoute
                              : () {
                                  if (order.primaryAction == GuideOrderAction.arrived) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已标记到达服务地点')),
                                    );
                                  } else {
                                    widget.onOpenRoute();
                                  }
                                },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStageTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OrderStageTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: active ? FontWeight.w900 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 40 : 0,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideOrderCard extends StatelessWidget {
  final GuideOrderCardData data;
  final VoidCallback onChatTap;
  final VoidCallback onPrimaryTap;

  const _GuideOrderCard({
    required this.data,
    required this.onChatTap,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = switch (data.serviceLabel) {
      '定制' => const Color(0xFFFF6B43),
      '帮忙' => const Color(0xFFFFC14D),
      _ => AppColors.primary,
    };
    final labelTextColor = data.serviceLabel == '定制'
        ? Colors.white
        : AppColors.textPrimary;
    return GuideSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  data.serviceLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: labelTextColor,
                  ),
                ),
              ),
              Text(
                data.etaText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF9B33),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '预计佣金',
                    style: TextStyle(fontSize: 16, color: AppColors.textHint),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${data.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF5A3C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: data.imageUrls
                .map(
                  (image) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: image == data.imageUrls.last ? 0 : 10,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFECEEF2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE6E7EB)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              data.content,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primaryDark, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.distanceText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OutlineActionButton(
                icon: Icons.call_outlined,
                label: '联系用户',
                onTap: onChatTap,
              ),
              SizedBox(
                width: 188,
                child: InkWell(
                  onTap: onPrimaryTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: data.primaryAction == GuideOrderAction.arrived
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: data.primaryAction == GuideOrderAction.arrived
                            ? AppColors.primary
                            : const Color(0xFFE3E4E8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.primaryAction.icon,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data.primaryAction.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE3E4E8)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
