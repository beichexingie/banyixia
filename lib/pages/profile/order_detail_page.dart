import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '订单详情',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          Order? order;
          for (final item in provider.orders) {
            if (item.id == widget.orderId) {
              order = item;
              break;
            }
          }
          if (order == null) {
            return const Center(child: Text('订单不存在或尚未加载'));
          }
          final (statusLabel, color) = _statusMeta(order);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.serviceName.isEmpty ? '地陪服务订单' : order.serviceName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('订单号：${order.id}'),
                    const SizedBox(height: 8),
                    Text('地陪：${order.guideName.isEmpty ? '未命名地陪' : order.guideName}'),
                    const SizedBox(height: 8),
                    Text('金额：¥${order.amount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Text('支付方式：${order.paymentMethod.isEmpty ? '未设置' : order.paymentMethod}'),
                    const SizedBox(height: 8),
                    Text('支付状态：${order.paymentStatus.isEmpty ? 'pending' : order.paymentStatus}'),
                    const SizedBox(height: 8),
                    Text('创建时间：${_fmt(order.createdAt)}'),
                    if (order.serviceDate != null) ...[
                      const SizedBox(height: 8),
                      Text('服务时间：${_fmt(order.serviceDate!)}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '状态说明',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _timeline('待支付', order.status.index >= OrderStatus.pendingPayment.index),
                    _timeline('进行中', order.status.index >= OrderStatus.inProgress.index),
                    _timeline('待评价', order.status.index >= OrderStatus.pendingReview.index),
                    _timeline('已完成', order.status == OrderStatus.completed),
                    _timeline('已取消', order.status == OrderStatus.cancelled),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _timeline(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: active ? AppColors.primaryDark : AppColors.textHint,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusMeta(Order order) {
    switch (order.status) {
      case OrderStatus.pendingPayment:
        return ('待支付', const Color(0xFFFFE7B0));
      case OrderStatus.inProgress:
        return ('进行中', const Color(0xFFDDF6B6));
      case OrderStatus.pendingReview:
        return ('待评价', const Color(0xFFE9EDF3));
      case OrderStatus.completed:
        return ('已完成', const Color(0xFFE9EDF3));
      case OrderStatus.cancelled:
        return ('已取消', const Color(0xFFF1D4D2));
    }
  }

  String _fmt(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
