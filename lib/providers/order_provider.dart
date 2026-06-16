import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../services/payment_service.dart';
import '../services/risk_control_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  final PaymentService _paymentService;

  OrderProvider({PaymentService? paymentService})
      : _paymentService = paymentService ?? const AlipayPaymentService();

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  String _buildMerchantOrderNo(Order order) {
    final compactId = order.id.replaceAll('-', '').toUpperCase();
    final millis = DateTime.now().millisecondsSinceEpoch;
    return 'BX${millis}${compactId.substring(0, compactId.length > 12 ? 12 : compactId.length)}';
  }

  Future<void> _ensureOrderChatRoom(Order order) async {
    if (order.userId.isEmpty || order.guideId.isEmpty || order.id.isEmpty) {
      return;
    }

    final existing = await Supabase.instance.client
        .from('chat_rooms')
        .select('id')
        .eq('order_id', order.id)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    await Supabase.instance.client.from('chat_rooms').insert({
      'participant_ids': [order.userId, order.guideId],
      'order_id': order.id,
    });
  }

  List<Order> getOrdersByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).toList();
  }

  int getCountByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).length;
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _orders = [];
        return;
      }

      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .or('user_id.eq.$userId,guide_id.eq.$userId')
          .order('created_at', ascending: false);

      _orders = (response as List)
          .map((data) => Order.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Load orders error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentResult> payOrder(String orderId) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      final merchantOrderNo =
          order.merchantOrderNo ?? _buildMerchantOrderNo(order);
      debugPrint(
        'OrderProvider: payOrder start orderId=$orderId guideId=${order.guideId} amount=${order.amount}',
      );

      final result = await _paymentService.pay(
        PaymentRequest(
          orderId: order.id,
          merchantOrderNo: merchantOrderNo,
          amount: order.amount,
          subject: order.serviceName.isNotEmpty ? order.serviceName : '地陪服务订单',
          paymentMethod: 'alipay',
        ),
      );
      debugPrint(
        'OrderProvider: payment result outcome=${result.outcome} success=${result.success} msg=${result.message}',
      );

      final paymentStatus = switch (result.outcome) {
        PaymentOutcome.success => 'processing',
        PaymentOutcome.cancelled => 'cancelled',
        PaymentOutcome.failed => 'failed',
      };

      await Supabase.instance.client.from('orders').update({
        'payment_status': paymentStatus,
        'merchant_order_no': merchantOrderNo,
        if (result.transactionId != null)
          'payment_request_id': result.transactionId,
      }).eq('id', orderId);

      await loadOrders();
      return result;
    } catch (e) {
      debugPrint('Pay order error: $e');
      throw Exception('支付失败');
    }
  }

  Future<void> completeOrder(String orderId) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);

      final startOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      ).toIso8601String();

      final salesResponse = await Supabase.instance.client
          .from('orders')
          .select('amount')
          .eq('guide_id', order.guideId)
          .eq('status', OrderStatus.completed.index)
          .gte('created_at', startOfMonth);

      double monthlySales = 0;
      for (final sale in salesResponse) {
        monthlySales += (sale['amount'] ?? 0).toDouble();
      }

      final guideShare =
          RiskControlService.calculateGuideShare(order.amount, monthlySales);
      final platformFee = order.amount - guideShare;

      await Supabase.instance.client
          .from('orders')
          .update({'status': OrderStatus.completed.index})
          .eq('id', orderId);

      await Supabase.instance.client.rpc(
        'unfreeze_and_credit_balance',
        params: {
          'target_user_id': order.guideId,
          'escrow_amount': order.amount,
          'credit_amount': guideShare,
        },
      );

      await Supabase.instance.client.from('transactions').insert({
        'user_id': order.guideId,
        'order_id': order.id,
        'type': 'income',
        'amount': order.amount,
        'platform_fee': platformFee,
        'actual_amount': guideShare,
        'description': '订单完成结算（含阶梯分成）',
      });

      await loadOrders();
    } catch (e) {
      debugPrint('Complete order error: $e');
      throw Exception('结算失败');
    }
  }

  Future<void> createOrder(Order order) async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .insert(order.toJson())
          .select()
          .single();

      final createdOrder = Order.fromJson(response as Map<String, dynamic>);
      await _ensureOrderChatRoom(createdOrder);
      _orders.insert(0, createdOrder);
      notifyListeners();
    } catch (e) {
      debugPrint('Create order error: $e');
      throw Exception('下单失败: $e');
    }
  }

  Future<PaymentResult> createAndPayDebugOrder() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('请先登录后再进行支付联调');
    }

    final testOrder = Order(
      id: '',
      userId: userId,
      guideId: userId,
      guideName: '支付联调',
      guideAvatar: '',
      status: OrderStatus.pendingPayment,
      amount: 0.01,
      serviceName: '0.01元支付联调测试订单',
      paymentMethod: 'alipay',
      paymentStatus: 'pending',
      merchantOrderNo:
          'DBG${DateTime.now().millisecondsSinceEpoch}${userId.replaceAll('-', '').substring(0, userId.length > 8 ? 8 : userId.length)}',
      createdAt: DateTime.now(),
    );

    final response = await Supabase.instance.client
        .from('orders')
        .insert(testOrder.toJson())
        .select()
        .single();

    final createdOrder = Order.fromJson(response as Map<String, dynamic>);
    _orders.insert(0, createdOrder);
    notifyListeners();

    return payOrder(createdOrder.id);
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('orders')
          .update({'status': OrderStatus.cancelled.index})
          .eq('id', orderId);

      await Supabase.instance.client.rpc(
        'increment_cancel_count',
        params: {'target_user_id': userId},
      );

      await loadOrders();
    } catch (e) {
      debugPrint('Cancel order error: $e');
    }
  }
}
