import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/ecs_api_client.dart';
import '../services/payment_service.dart';
import '../services/session_service.dart';

class OrderProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;
  final PaymentService _paymentService;

  List<Order> _orders = [];
  bool _isLoading = false;

  OrderProvider({
    PaymentService? paymentService,
    SessionService? sessionService,
  })  : _paymentService = paymentService ?? const AlipayPaymentService(),
        _sessionService = sessionService ?? EcsSessionService();

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  int getCountByStatus(OrderStatus status) {
    return _orders.where((order) => order.status == status).length;
  }

  String? _token() => _sessionService.currentSession?.accessToken;

  String _buildMerchantOrderNo(Order order) {
    final compactId = order.id.replaceAll('-', '').toUpperCase();
    final millis = DateTime.now().millisecondsSinceEpoch;
    return 'BX${millis}${compactId.substring(0, compactId.length > 12 ? 12 : compactId.length)}';
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.get('/orders', authToken: _token());
      final data = response['data'];
      if (data is List) {
        _orders = data
            .whereType<Map<String, dynamic>>()
            .map(Order.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Load orders error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentResult> payOrder(String orderId) async {
    try {
      debugPrint('Pay order start: orderId=$orderId');
      final order = _orders.firstWhere((o) => o.id == orderId);
      final merchantOrderNo = order.merchantOrderNo ?? _buildMerchantOrderNo(order);
      debugPrint(
        'Pay order request: merchantOrderNo=$merchantOrderNo, amount=${order.amount}',
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

      final paymentStatus = switch (result.outcome) {
        PaymentOutcome.success => 'processing',
        PaymentOutcome.cancelled => 'cancelled',
        PaymentOutcome.failed => 'failed',
      };

      await _api.put(
        '/orders/$orderId',
        authToken: _token(),
        body: {
          'payment_status': paymentStatus,
          'merchant_order_no': merchantOrderNo,
          if (result.transactionId != null) 'payment_request_id': result.transactionId,
        },
      );

      await loadOrders();
      return result;
    } catch (e) {
      debugPrint('Pay order error: $e');
      throw Exception('Pay order failed: $e');
    }
  }

  Future<void> completeOrder(String orderId) async {
    await _api.post('/orders/$orderId/complete', authToken: _token());
    await loadOrders();
  }

  Future<void> createOrder(Order order) async {
    try {
      debugPrint(
        'Create order start: userId=${order.userId}, guideId=${order.guideId}, amount=${order.amount}',
      );
      final response = await _api.post(
        '/orders',
        authToken: _token(),
        body: order.toJson(),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final createdOrder = Order.fromJson(data);
        _orders.insert(0, createdOrder);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Create order error: $e');
      throw Exception('Create order failed: $e');
    }
  }

  Future<PaymentResult> createAndPayDebugOrder() async {
    final userId = _sessionService.currentSession?.userId;
    if (userId == null) {
      throw Exception('Please log in before starting debug payment');
    }

    debugPrint('Debug payment start: userId=$userId');
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

    await createOrder(testOrder);
    if (_orders.isEmpty) {
      throw Exception('Debug order was not inserted locally after creation');
    }

    final createdOrderId = _orders.first.id;
    debugPrint('Debug payment order created: orderId=$createdOrderId');
    return payOrder(createdOrderId);
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.post('/orders/$orderId/cancel', authToken: _token());
    await loadOrders();
  }
}
