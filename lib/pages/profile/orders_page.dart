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
    try {
      final result =
          await context.read<OrderProvider>().createAndPayDebugOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('0.01 元测试支付结果：${result.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试支付失败：$e')),
      );
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
          TextButton(
            onPressed: _runDebugPayment,
            child: const Text(
              '0.01测试',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(Order order) {
    final (statusText, statusColor) = _statusMeta(order.status);
    final isDebugOrder = order.serviceName.contains('0.01')
        || (order.merchantOrderNo?.startsWith('DBG') ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '订单号 ${_shortId(order.id)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              if (isDebugOrder)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '测试单',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE68A00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (order.status == OrderStatus.inProgress) ...[
            const SizedBox(height: 12),
            SafetyControlPanel(orderId: order.id),
          ],
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: order.guideAvatar,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: AppColors.tagBackground,
                  ),
                  errorWidget: (context, url, err) => Container(
                    width: 60,
                    height: 60,
                    color: AppColors.tagBackground,
                    child: const Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDebugOrder
                          ? '支付联调测试订单'
                          : '地陪服务 - ${order.guideName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDebugOrder
                          ? '用于验证正式支付、异步回调、订单状态更新'
                          : '服务时间：${_formatDateTime(order.serviceDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    if ((order.merchantOrderNo ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '商户单号：${order.merchantOrderNo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                    if ((order.paymentStatus).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '支付状态：${order.paymentStatus}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '总价',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '¥${order.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (isDebugOrder) ...[
            const SizedBox(height: 10),
            const Text(
              '说明：这笔 0.01 元测试单只验证“用户向平台发起支付”是否成功。地陪真实收款、分账或提现，不依赖这一笔测试。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (order.status == OrderStatus.pendingPayment ||
              order.status == OrderStatus.inProgress) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isDebugOrder) ...[
                  OutlinedButton(
                    onPressed: () => _contactGuide(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('联系地陪'),
                  ),
                  const SizedBox(width: 10),
                ],
                if (order.status == OrderStatus.pendingPayment)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final result =
                            await context.read<OrderProvider>().payOrder(order.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('支付失败：$e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isDebugOrder ? '继续测试支付' : '立即支付'),
                  ),
                if (order.status == OrderStatus.inProgress && !isDebugOrder)
                  ElevatedButton(
                    onPressed: () => _showConfirmComplete(context, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('确认完成'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (String, Color) _statusMeta(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return ('待付款', const Color(0xFFFF9800));
      case OrderStatus.inProgress:
        return ('进行中', AppColors.primary);
      case OrderStatus.pendingReview:
        return ('待评价', const Color(0xFF4CAF50));
      case OrderStatus.completed:
        return ('已完成', AppColors.textSecondary);
      case OrderStatus.cancelled:
        return ('已取消', AppColors.textHint);
    }
  }

  void _showConfirmComplete(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认完成服务？'),
        content: const Text('确认后资金将进入结算流程，通常不再支持退款。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<OrderProvider>().completeOrder(order.id);
            },
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 4)}';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未知';
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
