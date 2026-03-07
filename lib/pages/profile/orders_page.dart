import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
              Text('订单号: ${order.id}', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
              Text(statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
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
                    Text('地陪服务 - ${order.guideName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('服务时间: ${order.serviceDate}', style: AppTextStyles.caption),
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
        ],
      ),
    );
  }
}
