import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/app_notification.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ecs_api_client.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key});

  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  final EcsApiClient _api = EcsApiClient();
  List<AppNotification> _notifications = const [];
  bool _isLoadingNotifications = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => _isLoadingNotifications = true);
    final orderProvider = context.read<OrderProvider>();
    await orderProvider.loadOrders();
    try {
      final response = await _api.get(
        '/notifications/orders',
        authToken: context.read<UserProvider>().accessToken,
      );
      final data = response['data'];
      final notifications = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) =>
                      AppNotification.fromJson(Map<String, dynamic>.from(item)),
                )
                .where(
                  (notification) =>
                      notification.id.isNotEmpty &&
                      notification.orderId.isNotEmpty,
                )
                .toList()
          : <AppNotification>[];
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (error) {
      // Keep the page usable while an older ECS version is being replaced.
      debugPrint('Load order notifications error: $error');
    } finally {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('系统通知')),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          final orders = [...provider.orders]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final notifiedOrderIds = _notifications
              .map((notification) => notification.orderId)
              .toSet();
          final supplementalOrders = orders
              .where((order) => !notifiedOrderIds.contains(order.id))
              .toList();
          if (_isLoadingNotifications &&
              _notifications.isEmpty &&
              orders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDeep),
            );
          }
          if (!_isLoadingNotifications &&
              _notifications.isEmpty &&
              orders.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryDeep,
              onRefresh: _loadNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 130, 28, 40),
                children: const [
                  Icon(
                    Icons.notifications_none,
                    size: 54,
                    color: AppColors.textHint,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '暂无系统通知',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '订单接单、付款、服务完成和评价状态会显示在这里',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryDeep,
            onRefresh: _loadNotifications,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _notifications.length + supplementalOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index < _notifications.length) {
                  return _notificationCard(_notifications[index]);
                }
                return _orderNotice(
                  supplementalOrders[index - _notifications.length],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _notificationCard(AppNotification notification) {
    final presentation = _notificationPresentation(notification);
    return _noticeCard(
      title: notification.title,
      message: notification.body,
      time: _dateTimeText(notification.createdAt),
      orderId: notification.orderId,
      amount: notification.amount,
      action: presentation.action,
      icon: presentation.icon,
      color: presentation.color,
      unread: !notification.isRead,
      onTap: () => _openNotification(notification),
    );
  }

  Widget _orderNotice(Order order) {
    final presentation = _presentation(order);
    return _noticeCard(
      title: presentation.title,
      message: presentation.message,
      time: _dateTimeText(order.createdAt),
      orderId: order.id,
      amount: order.amount,
      action: presentation.action,
      icon: presentation.icon,
      color: presentation.color,
      onTap: () => _openOrder(order),
    );
  }

  Widget _noticeCard({
    required String title,
    required String message,
    required String time,
    required String orderId,
    required double amount,
    required String action,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool unread = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(time, style: AppTextStyles.caption),
                        if (unread) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6D6B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '订单 ${_shortOrderId(orderId)}${amount > 0 ? ' · ¥${amount.toStringAsFixed(2)}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          action,
                          style: const TextStyle(
                            color: Color(0xFF6C9700),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF6C9700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNotification(AppNotification notification) {
    final route = notification.route.trim();
    if (route.isNotEmpty && route.startsWith('/')) {
      context.push(route);
      return;
    }
    context.push('/profile/orders/${notification.orderId}');
  }

  void _openOrder(Order order) {
    if (order.status == OrderStatus.pendingReview) {
      context.push('/profile/orders/${order.id}/review');
      return;
    }
    context.push('/profile/orders/${order.id}');
  }

  _OrderNoticePresentation _presentation(Order order) {
    final service = order.serviceName.trim().isEmpty
        ? '地陪服务订单'
        : order.serviceName.trim();
    switch (order.status) {
      case OrderStatus.pendingPayment:
        final accepted = order.paymentStatus == 'accepted';
        return _OrderNoticePresentation(
          title: accepted ? '订单待付款' : '订单等待接单',
          message: accepted
              ? '你的“$service”订单已被受理，请确认订单信息并完成付款。'
              : '你的“$service”订单已创建，正在等待地陪接单。',
          action: accepted ? '去付款' : '查看订单',
          icon: accepted
              ? Icons.account_balance_wallet_outlined
              : Icons.hourglass_top_outlined,
          color: const Color(0xFFFF9A3D),
        );
      case OrderStatus.inProgress:
        return _OrderNoticePresentation(
          title: '服务订单进行中',
          message: '“$service”已进入服务阶段，可查看订单详情并与地陪保持联系。',
          action: '查看服务',
          icon: Icons.directions_walk_outlined,
          color: const Color(0xFF3A91E8),
        );
      case OrderStatus.pendingReview:
        return _OrderNoticePresentation(
          title: '订单待评价',
          message: '“$service”服务已完成，分享你的真实体验可以帮助平台持续改进。',
          action: '去评价',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF8A65D6),
        );
      case OrderStatus.completed:
        return _OrderNoticePresentation(
          title: '订单已完成',
          message: '“$service”订单已完成，感谢你使用伴一下。',
          action: '查看详情',
          icon: Icons.task_alt,
          color: const Color(0xFF61A927),
        );
      case OrderStatus.cancelled:
        return _OrderNoticePresentation(
          title: '订单已取消',
          message: '“$service”订单已取消，如涉及退款可在订单详情中查看处理状态。',
          action: '查看详情',
          icon: Icons.cancel_outlined,
          color: const Color(0xFF999999),
        );
    }
  }

  _OrderNoticePresentation _notificationPresentation(
    AppNotification notification,
  ) {
    switch (notification.type) {
      case 'order_accepted':
        return const _OrderNoticePresentation(
          title: '地陪已接单',
          message: '',
          action: '去付款',
          icon: Icons.handshake_outlined,
          color: Color(0xFFFF9A3D),
        );
      case 'payment_success':
        return const _OrderNoticePresentation(
          title: '支付成功',
          message: '',
          action: '查看订单',
          icon: Icons.verified_outlined,
          color: Color(0xFF3A91E8),
        );
      case 'order_completed':
        return _OrderNoticePresentation(
          title: '服务状态已更新',
          message: '',
          action: notification.route.contains('/review') ? '去评价' : '查看详情',
          icon: Icons.task_alt,
          color: const Color(0xFF61A927),
        );
      case 'order_cancelled':
        return const _OrderNoticePresentation(
          title: '订单已取消',
          message: '',
          action: '查看详情',
          icon: Icons.cancel_outlined,
          color: Color(0xFF999999),
        );
      case 'review':
        return const _OrderNoticePresentation(
          title: '订单评价已更新',
          message: '',
          action: '查看详情',
          icon: Icons.rate_review_outlined,
          color: Color(0xFF8A65D6),
        );
      default:
        return const _OrderNoticePresentation(
          title: '订单状态更新',
          message: '',
          action: '查看详情',
          icon: Icons.notifications_none,
          color: Color(0xFF3A91E8),
        );
    }
  }

  String _shortOrderId(String value) {
    final normalized = value.replaceAll('-', '');
    if (normalized.length <= 10) return normalized.toUpperCase();
    return normalized.substring(normalized.length - 10).toUpperCase();
  }

  String _dateTimeText(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final time = '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    if (sameDay) return time;
    if (date.year == now.year) {
      return '${_twoDigits(date.month)}-${_twoDigits(date.day)}';
    }
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _OrderNoticePresentation {
  final String title;
  final String message;
  final String action;
  final IconData icon;
  final Color color;

  const _OrderNoticePresentation({
    required this.title,
    required this.message,
    required this.action,
    required this.icon,
    required this.color,
  });
}
