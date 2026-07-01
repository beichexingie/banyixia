import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/message_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/safety_control_panel.dart';

class OrdersPage extends StatefulWidget {
  final int initialTab;

  const OrdersPage({super.key, this.initialTab = 0});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isDebugPaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _contactGuide(Order order) async {
    try {
      final roomId = await context.read<MessageProvider>().getOrCreateRoom(
            order.guideId,
          );
      if (!mounted) return;
      context.push(
        '/chat/$roomId?name=${Uri.encodeComponent(order.guideName)}&avatar=${Uri.encodeComponent(order.guideAvatar)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _runDebugPayment() async {
    if (_isDebugPaying) return;

    setState(() => _isDebugPaying = true);
    try {
      final result = await context.read<OrderProvider>().createAndPayDebugOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('0.01 测试失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isDebugPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, child) {
            final allOrders = orderProvider.orders;
            final tabs = [
              allOrders,
              allOrders.where((o) => o.status == OrderStatus.pendingPayment).toList(),
              allOrders.where((o) => o.status == OrderStatus.inProgress).toList(),
              allOrders.where((o) => o.status == OrderStatus.pendingReview).toList(),
            ];

            return Column(
              children: [
                _OrdersHeader(
                  isDebugPaying: _isDebugPaying,
                  onDebugPay: _runDebugPayment,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicator: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: AppColors.textPrimary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                          tabs: const [
                            Tab(text: '新订单'),
                            Tab(text: '待付款'),
                            Tab(text: '进行中'),
                            Tab(text: '待评价'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              '默认排序',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.unfold_more, size: 18, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final list in tabs) _buildOrderList(list),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          '暂无相关订单',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textHint,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<OrderProvider>().loadOrders(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(
            order: order,
            onContact: () => _contactGuide(order),
            onPay: () async {
              final result = await context.read<OrderProvider>().payOrder(order.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            onComplete: () async {
              await context.read<OrderProvider>().completeOrder(order.id);
            },
            onCancel: () async {
              await context.read<OrderProvider>().cancelOrder(order.id);
            },
          );
        },
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  final bool isDebugPaying;
  final VoidCallback onDebugPay;

  const _OrdersHeader({
    required this.isDebugPaying,
    required this.onDebugPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '订单中心',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '处理你的订单、接单和付款流程',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDebugPay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isDebugPaying ? '测试中...' : '0.01测试',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onContact;
  final VoidCallback onPay;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.onContact,
    required this.onPay,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(order.status);
    final actionLabel = switch (order.status) {
      OrderStatus.pendingPayment => '接单',
      OrderStatus.inProgress => '报名',
      OrderStatus.pendingReview => '去评价',
      OrderStatus.completed => '已完成',
      OrderStatus.cancelled => '已取消',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusMeta.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusMeta.tag,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  order.serviceName.isNotEmpty ? order.serviceName : order.guideName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '¥${order.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _OrderImage(url: order.guideAvatar),
              const SizedBox(width: 10),
              _OrderImage(url: order.guideAvatar),
              const SizedBox(width: 10),
              _OrderImage(url: order.guideAvatar),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              order.serviceName.isNotEmpty ? order.serviceName : '订单内容',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.guideName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: order.status == OrderStatus.pendingPayment ? '取消' : '客服',
                  filled: false,
                  onTap: order.status == OrderStatus.pendingPayment ? onCancel : onContact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: actionLabel,
                  filled: true,
                  onTap: order.status == OrderStatus.pendingPayment
                      ? onContact
                      : order.status == OrderStatus.inProgress
                          ? onPay
                          : order.status == OrderStatus.pendingReview
                              ? onComplete
                              : onCancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SafetyControlPanel(orderId: order.id),
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return const _StatusMeta('地陪', Color(0xFFC8FF28));
      case OrderStatus.inProgress:
        return const _StatusMeta('定制', Color(0xFFFF6938));
      case OrderStatus.pendingReview:
        return const _StatusMeta('进行中', Color(0xFFC8FF28));
      case OrderStatus.completed:
        return const _StatusMeta('完成', Color(0xFFD8D8D8));
      case OrderStatus.cancelled:
        return const _StatusMeta('已取消', Color(0xFFD8D8D8));
    }
  }
}

class _OrderImage extends StatelessWidget {
  final String url;

  const _OrderImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CachedNetworkImage(
          imageUrl: url,
          height: 140,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => Container(
            height: 140,
            color: AppColors.tagBackground,
            child: const Icon(Icons.image_outlined, color: AppColors.textHint),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatusMeta {
  final String tag;
  final Color color;

  const _StatusMeta(this.tag, this.color);
}
