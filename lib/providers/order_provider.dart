import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../services/risk_control_service.dart';

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

  /// 获取指定状态订单数量
  int getCountByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).length;
  }

  /// 加载订单列表 (从 Supabase 获取)
  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .or('user_id.eq.$userId,guide_id.eq.$userId')
          .order('created_at', ascending: false);

      _orders = (response as List).map((data) => Order.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Load orders error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 模拟支付并进入托管
  Future<void> payOrder(String orderId) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      // 1. 更新订单状态为进行中
      await Supabase.instance.client
          .from('orders')
          .update({'status': OrderStatus.inProgress.index})
          .eq('id', orderId);

      // 2. 进入资金托管 (增加导游的冻结余额)
      await Supabase.instance.client.rpc('increment_pending_balance', params: {
        'target_user_id': order.guideId,
        'amount': order.amount,
      });

      await loadOrders();
    } catch (e) {
      debugPrint('Pay order error: $e');
      throw Exception('支付失败');
    }
  }

  /// 完成订单并解冻资金 (附带阶梯分成算法)
  Future<void> completeOrder(String orderId) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      // 1. 获取导游本月已完成流水 (用于计算阶梯分成)
      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
      final salesResponse = await Supabase.instance.client
          .from('orders')
          .select('amount')
          .eq('guide_id', order.guideId)
          .eq('status', OrderStatus.completed.index)
          .gte('created_at', startOfMonth);
      
      double monthlySales = 0;
      for (var s in salesResponse) {
        monthlySales += (s['amount'] ?? 0).toDouble();
      }

      // 2. 计算导游应得分成
      final guideShare = RiskControlService.calculateGuideShare(order.amount, monthlySales);
      final platformFee = order.amount - guideShare;

      // 3. 事务处理：更新订单状态、更新钱包、记录流水
      await Supabase.instance.client.from('orders')
          .update({'status': OrderStatus.completed.index})
          .eq('id', orderId);

      // 解冻资金并转入可用余额
      await Supabase.instance.client.rpc('unfreeze_and_credit_balance', params: {
        'target_user_id': order.guideId,
        'escrow_amount': order.amount,
        'credit_amount': guideShare,
      });

      // 记录收支明细
      await Supabase.instance.client.from('transactions').insert({
        'user_id': order.guideId,
        'order_id': order.id,
        'type': 'income',
        'amount': order.amount,
        'platform_fee': platformFee,
        'actual_amount': guideShare,
        'description': '订单完成结算 (阶梯分成后)',
      });

      await loadOrders();
    } catch (e) {
      debugPrint('Complete order error: $e');
      throw Exception('结算失败');
    }
  }

  /// 创建订单
  Future<void> createOrder(Order order) async {
    try {
      await Supabase.instance.client.from('orders').insert(order.toJson());
      _orders.insert(0, order);
      notifyListeners();
    } catch (e) {
      debugPrint('Create order error: $e');
      throw Exception('下单失败');
    }
  }

  /// 取消订单
  Future<void> cancelOrder(String orderId) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': OrderStatus.cancelled.index})
          .eq('id', orderId);
      
      await loadOrders();
    } catch (e) {
      debugPrint('Cancel order error: $e');
    }
  }
}
