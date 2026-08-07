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
      if (order.paymentStatus == 'paid') {
        return const PaymentResult(
          outcome: PaymentOutcome.success,
          success: true,
          message: '该订单已经支付成功',
        );
      }
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

      final confirmed = await _waitForPaymentConfirmation(orderId);
      await loadOrders();

      final latest = _orders.cast<Order?>().firstWhere(
        (item) => item?.id == orderId,
        orElse: () => null,
      );
      if (confirmed?['payment_status'] == 'paid' ||
          latest?.paymentStatus == 'paid') {
        return PaymentResult(
          outcome: PaymentOutcome.success,
          success: true,
          message: '支付成功，订单已确认',
          transactionId: confirmed?['provider_trade_no']?.toString() ??
              result.transactionId,
          orderString: result.orderString,
        );
      }

      if (result.outcome == PaymentOutcome.cancelled) {
        return result;
      }

      if (result.outcome == PaymentOutcome.success) {
        return PaymentResult(
          outcome: PaymentOutcome.success,
          success: true,
          message: '支付宝已受理，服务器正在确认支付结果，请稍后刷新订单',
          transactionId: result.transactionId,
          orderString: result.orderString,
        );
      }

      return PaymentResult(
        outcome: PaymentOutcome.failed,
        success: false,
        message: '支付结果暂未确认。若支付宝已经扣款，请不要重复支付，稍后刷新订单。',
        transactionId: result.transactionId,
        orderString: result.orderString,
      );
    } catch (e) {
      debugPrint('Pay order error: $e');
      throw Exception('Pay order failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _waitForPaymentConfirmation(String orderId) async {
    for (var attempt = 0; attempt < 6; attempt += 1) {
      try {
        final response = await _api.get(
          '/alipay-status/$orderId',
          authToken: _token(),
        );
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final status = data['payment_status']?.toString();
          if (status == 'paid' || status == 'closed') {
            return data;
          }
        }
      } catch (error) {
        debugPrint('Payment status check attempt ${attempt + 1} failed: $error');
      }

      if (attempt < 5) {
        await Future<void>.delayed(Duration(seconds: attempt == 0 ? 1 : 2));
      }
    }
    return null;
  }

  Future<void> completeOrder(String orderId) async {
    await _api.post('/orders/$orderId/complete', authToken: _token());
    await loadOrders();
  }

  Future<void> reviewOrder(String orderId, {required int rating, required String content, bool anonymous = true}) async {
    await _api.post(
      '/orders/$orderId/review',
      authToken: _token(),
      body: {'rating': rating, 'content': content, 'is_anonymous': anonymous},
    );
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

  Future<Order> createOneCentTestOrder({String? guideId}) async {
    final response = await _api.post(
      '/orders/one-cent-test',
      authToken: _token(),
      body: {
        if (guideId != null && guideId.trim().isNotEmpty) 'guide_id': guideId.trim(),
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('0.10 test order response is invalid');
    }
    final order = Order.fromJson(data);
    _orders = [order, ..._orders.where((item) => item.id != order.id)];
    notifyListeners();
    return order;
  }

  Future<void> acceptOrder(String orderId) async {
    final response = await _api.post('/orders/$orderId/accept', authToken: _token());
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final accepted = Order.fromJson(data);
      _orders = _orders
          .map((item) => item.id == accepted.id ? accepted : item)
          .toList();
      if (!_orders.any((item) => item.id == accepted.id)) {
        _orders.insert(0, accepted);
      }
      notifyListeners();
    } else {
      await loadOrders();
    }
  }

  Future<Order> _buildDebugOrder(String userId) async {
    for (final order in _orders) {
      if (order.guideId.trim().isNotEmpty && order.guideId != userId) {
        return Order(
          id: '',
          userId: userId,
          guideId: order.guideId,
          guideName: order.guideName,
          guideAvatar: order.guideAvatar,
          status: OrderStatus.pendingPayment,
          amount: 0.10,
          serviceName: '0.10元支付联调测试订单',
          paymentMethod: 'alipay',
          paymentStatus: 'pending',
          merchantOrderNo:
              'DBG${DateTime.now().millisecondsSinceEpoch}${userId.replaceAll('-', '').substring(0, userId.length > 8 ? 8 : userId.length)}',
          createdAt: DateTime.now(),
        );
      }
    }

    final response = await _api.get('/guides', authToken: _token());
    final data = response['data'];
    if (data is! List || data.isEmpty) {
      throw Exception('No guide available for debug payment order');
    }

    final firstGuide = data.first;
    if (firstGuide is! Map<String, dynamic>) {
      throw Exception('Guide data is invalid for debug payment order');
    }

    final guideId = firstGuide['id']?.toString() ?? '';
    if (guideId.isEmpty) {
      throw Exception('Guide id is missing for debug payment order');
    }

    return Order(
      id: '',
      userId: userId,
      guideId: guideId,
      guideName: firstGuide['name']?.toString() ?? '测试地陪',
      guideAvatar: firstGuide['avatar']?.toString() ?? '',
      status: OrderStatus.pendingPayment,
      amount: 0.10,
      serviceName: '0.10元支付联调测试订单',
      paymentMethod: 'alipay',
      paymentStatus: 'pending',
      merchantOrderNo:
          'DBG${DateTime.now().millisecondsSinceEpoch}${userId.replaceAll('-', '').substring(0, userId.length > 8 ? 8 : userId.length)}',
      createdAt: DateTime.now(),
    );
  }

  Future<PaymentResult> createAndPayDebugOrder() async {
    final userId = _sessionService.currentSession?.userId;
    if (userId == null) {
      throw Exception('Please log in before starting debug payment');
    }

    debugPrint('Debug payment start: userId=$userId');
    final testOrder = await _buildDebugOrder(userId);
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

  Future<String> getVirtualNumber(String orderId) async {
    final response = await _api.post(
      '/orders/$orderId/virtual-number',
      authToken: _token(),
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final phoneNoX = data['phone_no_x']?.toString() ?? '';
      if (phoneNoX.trim().isNotEmpty) {
        return phoneNoX.trim();
      }
    }
    throw Exception('虚拟号返回为空');
  }
}
