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
  late TabController _tabController;
  bool _isDebugPaying = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.clamp(0, 4);
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initialIndex,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('0.01 test payment is starting...')),
    );

    try {
      debugPrint('OrdersPage: debug payment button pressed');
      final result = await context.read<OrderProvider>().createAndPayDebugOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('0.01 test payment result: ${result.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('0.01 test payment failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDebugPaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的订单'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isDebugPaying ? null : _runDebugPayment,
              icon: const Icon(
                Icons.science_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              label: Text(
                _isDebugPaying ? '处理中...' : '0.01测试',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '待付款'),
            Tab(text: '进行中'),
            Tab(text: '待评价'),
            Tab(text: '已取消'),
          ],
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = orderProvider.orders;
          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList(allOrders),
              _buildOrderList(
                allOrders
                    .where((o) => o.status == OrderStatus.pendingPayment)
                    .toList(),
              ),
              _buildOrderList(
                allOrders
                    .where((o) => o.status == OrderStatus.inProgress)
                    .toList(),
              ),
              _buildOrderList(
                allOrders
                    .where((o) => o.status == OrderStatus.pendingReview)
                    .toList(),
              ),
              _buildOrderList(
                allOrders
                    .where((o) => o.status == OrderStatus.cancelled)
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 60,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text('暂无相关订单', style: AppTextStyles.subtitle),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '右上角的 0.01 测试 用于验证正式支付通路，只测试用户向平台支付，不代表地陪真实结算。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order);
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusMeta = _statusMeta(order.status);
    final isDebugOrder = order.serviceName.contains('0.01');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: order.guideAvatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.background,
                      child: const Icon(Icons.person, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.guideName, style: AppTextStyles.subtitle),
                      const SizedBox(height: 6),
                      Text(
                        order.serviceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusMeta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusMeta.label,
                    style: TextStyle(
                      color: statusMeta.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('订单金额', style: AppTextStyles.caption),
                    Text(
                      '¥${order.amount.toStringAsFixed(2)}',
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if ((order.paymentStatus).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '支付状态：${order.paymentStatus}',
                    style: AppTextStyles.caption,
                  ),
                ],
                if ((order.merchantOrderNo ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '商户单号：${order.merchantOrderNo}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          if (isDebugOrder)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '说明：这笔 0.01 元测试单只验证“用户支付到平台”链路。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A6700),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (order.status == OrderStatus.pendingPayment) ...[
                  OutlinedButton(
                    onPressed: () async {
                      await context.read<OrderProvider>().cancelOrder(order.id);
                    },
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: () => _contactGuide(order),
                  child: const Text('联系地陪'),
                ),
                const SizedBox(width: 8),
                if (order.status == OrderStatus.pendingPayment)
                  FilledButton(
                    onPressed: () async {
                      final result =
                          await context.read<OrderProvider>().payOrder(order.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    },
                    child: const Text('去支付'),
                  ),
                if (order.status == OrderStatus.inProgress)
                  FilledButton(
                    onPressed: () async {
                      await context.read<OrderProvider>().completeOrder(order.id);
                    },
                    child: const Text('确认完成'),
                  ),
              ],
            ),
          ),
          SafetyControlPanel(orderId: order.id),
        ],
      ),
    );
  }

  _OrderStatusMeta _statusMeta(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return const _OrderStatusMeta('待付款', Color(0xFFF59E0B));
      case OrderStatus.inProgress:
        return const _OrderStatusMeta('进行中', Color(0xFF2563EB));
      case OrderStatus.pendingReview:
        return const _OrderStatusMeta('待评价', Color(0xFF7C3AED));
      case OrderStatus.cancelled:
        return const _OrderStatusMeta('已取消', Color(0xFF94A3B8));
      case OrderStatus.completed:
        return const _OrderStatusMeta('已完成', Color(0xFF10B981));
    }
  }
}

class _OrderStatusMeta {
  final String label;
  final Color color;

  const _OrderStatusMeta(this.label, this.color);
}
