import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/order/voice_call_page.dart';
import 'package:flutter_application_1/providers/call_provider.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_console_header.dart';

class GuideOrderCenterPage extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenServiceOps;
  final ValueChanged<GuideOrderCardData?> onOpenRoute;
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
    final currentUser = context.watch<UserProvider>().user;
    final orders = console.buildGuideOrders(
      orderProvider.orders,
      guideId: currentUser.id,
    );
    final filtered = orders
        .where((item) => item.stage == _selectedStage)
        .toList();

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
                    onToggleOnlineTap: () =>
                        console.setOnline(!console.isOnline),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 22,
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
                        onTap: () => widget.onOpenRoute(
                          filtered.isNotEmpty ? filtered.first : null,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: const Row(
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
                      InkWell(
                        onTap: () => context.read<OrderProvider>().loadOrders(),
                        borderRadius: BorderRadius.circular(999),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 24),
                            SizedBox(width: 6),
                            Text(
                              '刷新',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
                        const SnackBar(
                          content: Text('当前为默认排序，后续可切换按距离/佣金/时间排序'),
                        ),
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
                          onChatTap: () => _contactCustomer(order),
                          onPrimaryTap:
                              order.primaryAction == GuideOrderAction.navigate
                              ? () => widget.onOpenRoute(order)
                              : () async {
                                  if (order.primaryAction ==
                                      GuideOrderAction.accept) {
                                    await _acceptOrder(order);
                                    return;
                                  }
                                  if (order.primaryAction ==
                                      GuideOrderAction.waitingPayment) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已接单，等待用户付款'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (order.primaryAction ==
                                      GuideOrderAction.arrived) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已标记到达服务地点'),
                                      ),
                                    );
                                  } else {
                                    widget.onOpenRoute(order);
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

  Future<void> _contactCustomer(GuideOrderCardData order) async {
    try {
      final payload = await context.read<CallProvider>().createVoiceCall(
        order.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VoiceCallPage(callPayload: payload, peerName: '客户'),
        ),
      );
    } catch (callError) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发起语音通话失败：$callError')));
    }
  }

  Future<void> _acceptOrder(GuideOrderCardData order) async {
    try {
      await context.read<OrderProvider>().acceptOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已接单，等待用户付款')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('接单失败: $e')));
    }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                    style: TextStyle(fontSize: 15, color: AppColors.textHint),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¥${_formatAmount(data.amount)}',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OrderInfoChip(
                  icon: Icons.schedule_outlined,
                  label: _formatServiceTime(data.serviceTime),
                ),
                _OrderInfoChip(
                  icon: Icons.attach_money_rounded,
                  label: '订单金额 ¥${_formatAmount(data.amount)}',
                ),
                _OrderInfoChip(
                  icon: Icons.place_outlined,
                  label: data.distanceText,
                ),
              ],
            ),
          ),
          if (data.stage == GuideOrderStage.inProgress) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFFF1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCDEFD3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: Color(0xFF2F8F43),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已入账 ¥${_formatAmount(data.amount)}，当前为平台托管中，订单完成后可提现',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F8F43),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 390;
              final address = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.address,
                      maxLines: narrow ? 3 : 2,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
              final distance = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [address, const SizedBox(height: 8), distance],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: address),
                  const SizedBox(width: 10),
                  distance,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 360) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineActionButton(
                            icon: Icons.support_agent_rounded,
                            label: '客服',
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OutlineActionButton(
                            icon: Icons.call_outlined,
                            label: '联系',
                            onTap: onChatTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryActionButton(
                        icon: data.primaryAction.icon,
                        label: data.primaryAction.label,
                        active: data.primaryAction == GuideOrderAction.arrived,
                        onTap: onPrimaryTap,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _OutlineActionButton(
                      icon: Icons.support_agent_rounded,
                      label: '客服',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineActionButton(
                      icon: Icons.call_outlined,
                      label: '联系',
                      onTap: onChatTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryActionButton(
                      icon: data.primaryAction.icon,
                      label: data.primaryAction.label,
                      active: data.primaryAction == GuideOrderAction.arrived,
                      onTap: onPrimaryTap,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _formatServiceTime(DateTime serviceTime) {
  final month = serviceTime.month.toString().padLeft(2, '0');
  final day = serviceTime.day.toString().padLeft(2, '0');
  final hour = serviceTime.hour.toString().padLeft(2, '0');
  final minute = serviceTime.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute 服务';
}

String _formatAmount(double amount) {
  if (amount > 0 && amount < 1) {
    return amount.toStringAsFixed(2);
  }
  return amount.toStringAsFixed(0);
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE3E4E8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : const Color(0xFFE3E4E8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
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
    );
  }
}

class _OrderInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OrderInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
