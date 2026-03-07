import 'package:flutter/material.dart';
import '../models/order.dart';

/// 订单状态管理
class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  /// 按状态筛选订单
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).toList();
  }

  int getCountByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).length;
  }

  /// 加载订单列表（后续替换为 API 调用）
  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    // TODO: 替换为真实 API 调用
    await Future.delayed(const Duration(milliseconds: 300));

    // 目前为空订单列表，模拟新用户
    _orders = [];

    _isLoading = false;
    notifyListeners();
  }

  /// 创建订单
  Future<void> createOrder(Order order) async {
    // TODO: 调用 API 创建订单
    _orders.insert(0, order);
    notifyListeners();
  }

  /// 取消订单
  Future<void> cancelOrder(String orderId) async {
    // TODO: 调用 API 取消订单
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = Order(
        id: _orders[index].id,
        userId: _orders[index].userId,
        guideId: _orders[index].guideId,
        guideName: _orders[index].guideName,
        guideAvatar: _orders[index].guideAvatar,
        status: OrderStatus.cancelled,
        amount: _orders[index].amount,
        serviceName: _orders[index].serviceName,
        createdAt: _orders[index].createdAt,
        serviceDate: _orders[index].serviceDate,
      );
      notifyListeners();
    }
  }
}
