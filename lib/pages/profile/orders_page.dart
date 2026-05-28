import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab < 0
        ? 0
        : (widget.initialTab > 4 ? 4 : widget.initialTab);
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initialIndex,
    );
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的订单'),
        centerTitle: true,
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
              _buildOrderList(allOrders.where((o) => o.status == OrderStatus.pendingPayment).toList()),
              _buildOrderList(allOrders.where((o) => o.status == OrderStatus.inProgress).toList()),
              _buildOrderList(allOrders.where((o) => o.status == OrderStatus.pendingReview).toList()),
              _buildOrderList(allOrders.where((o) => o.status == OrderStatus.cancelled).toList()),
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
            Icon(Icons.receipt_long, size: 60, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('暂无相关订单', style: AppTextStyles.subtitle),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    String statusText;
    Color statusColor;

    switch (order.status) {
      case OrderStatus.pendingPayment:
        statusText = '待付款';
        statusColor = const Color(0xFFFF9800);
        break;
      case OrderStatus.inProgress:
        statusText = '进行中';
        statusColor = AppColors.primary;
        break;
      case OrderStatus.pendingReview:
        statusText = '待评价';
        statusColor = const Color(0xFF4CAF50);
        break;
      case OrderStatus.completed:
        statusText = '已完成';
        statusColor = AppColors.textSecondary;
        break;
      case OrderStatus.cancelled:
        statusText = '已取消';
        statusColor = AppColors.textHint;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '订单号: ${_shortId(order.id)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
              Text(statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
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
                  width: 60, height: 60, fit: BoxFit.cover,
                  placeholder: (context, url) => Container(width: 60, height: 60, color: AppColors.tagBackground),
                  errorWidget: (context, url, err) => Container(width: 60, height: 60, color: AppColors.tagBackground, child: const Icon(Icons.person)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '地陪服务 - ${order.guideName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '服务时间: ${_formatDateTime(order.serviceDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('总价', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Text('¥${order.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          if (order.status == OrderStatus.pendingPayment || order.status == OrderStatus.inProgress) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                if (order.status == OrderStatus.pendingPayment)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final result = await context.read<OrderProvider>().payOrder(order.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('支付失败: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('立即支付'),
                  ),
                if (order.status == OrderStatus.inProgress)
                  ElevatedButton(
                    onPressed: () => _showConfirmComplete(context, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _showConfirmComplete(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认完成服务？'),
        content: const Text('确认后资金将结算给地陪，无法退款。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<OrderProvider>().completeOrder(order.id);
            },
            child: const Text('确认确认'),
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
