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
  late final TabController _tabController;
  final Set<String> _payingOrderIds = <String>{};
  final Set<String> _completingOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _contactGuide(Order order) async {
    try {
      final virtualNumber = await context
          .read<OrderProvider>()
          .getVirtualNumber(order.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('虚拟号联系'),
          content: Text(
            '请拨打平台虚拟号联系地陪：\n\n$virtualNumber\n\n该号码为隐私保护号码，不会暴露双方真实手机号。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    } catch (e) {
      debugPrint('Get virtual number fallback to chat: $e');
    }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _payOrder(Order order) async {
    if (_payingOrderIds.contains(order.id)) return;
    setState(() => _payingOrderIds.add(order.id));
    try {
      final result = await context.read<OrderProvider>().payOrder(order.id);
      if (!mounted) return;
      _showSimpleMessage(result.message);
    } catch (e) {
      if (!mounted) return;
      _showSimpleMessage('支付发起失败: $e');
    } finally {
      if (mounted) {
        setState(() => _payingOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _completeOrder(Order order) async {
    if (_completingOrderIds.contains(order.id)) return;
    setState(() => _completingOrderIds.add(order.id));
    try {
      await context.read<OrderProvider>().completeOrder(order.id);
      if (!mounted) return;
      _showSimpleMessage('订单已确认完成');
    } catch (e) {
      if (!mounted) return;
      _showSimpleMessage('确认完成失败: $e');
    } finally {
      if (mounted) {
        setState(() => _completingOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _reviewOrder(Order order) async {
    var rating = 5;
    final controller = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('评价本次服务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setState(() => rating = index + 1),
                  icon: Icon(index < rating ? Icons.star : Icons.star_border),
                  color: const Color(0xFFE28B24),
                )),
              ),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '说说这次服务的感受'),
              ),
              const SizedBox(height: 8),
              const Text('默认匿名展示，地陪只能看到匿名反馈。', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, {'rating': rating, 'content': controller.text.trim()}), child: const Text('提交')),
          ],
        ),
      ),
    );
    final content = result?['content']?.toString() ?? '';
    final selectedRating = result?['rating'] as int?;
    controller.dispose();
    if (!mounted || selectedRating == null || content.isEmpty) return;
    try {
      await context.read<OrderProvider>().reviewOrder(order.id, rating: selectedRating, content: content);
      if (mounted) _showSimpleMessage('评价已提交');
    } catch (error) {
      if (mounted) _showSimpleMessage('评价提交失败：$error');
    }
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
          '我的订单',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<OrderProvider>().loadOrders(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新订单',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textHint,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              dividerColor: const Color(0xFFF3F3F3),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '全部'),
                Tab(text: '待付款'),
                Tab(text: '待接单'),
                Tab(text: '进行中'),
                Tab(text: '待评价'),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 38,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '暂无相关订单',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '可以先去首页或服务页看看，回来再下单。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(Order order) {
    final (statusText, statusColor) = _statusMeta(order.status);
    final isDebugOrder =
        (order.serviceName.contains('0.01') ||
            order.serviceName.contains('0.10')) ||
        (order.merchantOrderNo?.startsWith('DBG') ?? false) ||
        (order.merchantOrderNo?.startsWith('TEST001') ?? false);
    final waitingGuideAccept = isDebugOrder &&
        order.status == OrderStatus.pendingPayment &&
        order.paymentStatus == 'pending';
    final isPaying = _payingOrderIds.contains(order.id);
    final isCompleting = _completingOrderIds.contains(order.id);

    return InkWell(
      onTap: () => context.push('/profile/orders/${order.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundImage: order.guideAvatar.isNotEmpty
                    ? NetworkImage(order.guideAvatar)
                    : null,
                child: order.guideAvatar.isEmpty
                    ? const Icon(Icons.person, size: 12)
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.guideName.isEmpty ? '用户10938' : order.guideName,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: order.guideAvatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: order.guideAvatar,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _thumbFallback(),
                      )
                    : _thumbFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            isDebugOrder ? '支付联调测试订单' : _serviceTitle(order),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '¥${_formatAmount(order.amount)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF5A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.serviceName.isEmpty
                          ? '内容内容内容内容内容内容'
                          : order.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FBDD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(order.serviceDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.status == OrderStatus.inProgress) ...[
            const SizedBox(height: 12),
            SafetyControlPanel(orderId: order.id),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (order.status == OrderStatus.pendingPayment) ...[
                _outlineAction(
                  label: '申请售后',
                  onTap: () => _showSimpleMessage('售后入口稍后接入'),
                ),
                const SizedBox(width: 8),
                _outlineAction(
                  label: waitingGuideAccept
                      ? '等待接单'
                      : isPaying
                          ? '支付中...'
                          : (isDebugOrder ? '继续支付' : '去支付'),
                  onTap: waitingGuideAccept || isPaying ? null : () => _payOrder(order),
                ),
              ] else if (order.status == OrderStatus.inProgress) ...[
                _outlineAction(
                  label: '联系地陪',
                  onTap: () => _contactGuide(order),
                ),
                const SizedBox(width: 8),
                _outlineAction(
                  label: isCompleting ? '提交中...' : '确认完成',
                  onTap: isCompleting ? null : () => _completeOrder(order),
                ),
              ] else if (order.status == OrderStatus.pendingReview) ...[
                _outlineAction(
                  label: '申请售后',
                  onTap: () => _showSimpleMessage('售后入口稍后接入'),
                ),
                const SizedBox(width: 8),
                _outlineAction(
                  label: '待评价',
                  onTap: () => _reviewOrder(order),
                ),
              ] else if (order.status == OrderStatus.completed) ...[
                _outlineAction(
                  label: '申请售后',
                  onTap: () => _showSimpleMessage('售后入口稍后接入'),
                ),
                const SizedBox(width: 8),
                _outlineAction(
                  label: '已完成',
                  onTap: () => _showSimpleMessage('订单已完成'),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 86,
      height: 86,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textHint),
    );
  }

  Widget _outlineAction({required String label, VoidCallback? onTap}) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: Color(0xFFE7E7E7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _serviceTitle(Order order) {
    if (order.serviceName.trim().isEmpty) {
      return '标题标题标题标题';
    }
    final parts = order.serviceName.split('/');
    return parts.first.trim().isEmpty ? order.serviceName : parts.first.trim();
  }

  (String, Color) _statusMeta(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return ('待支付', const Color(0xFFFF8B2B));
      case OrderStatus.inProgress:
        return ('进行中', const Color(0xFF7CCB2F));
      case OrderStatus.pendingReview:
        return ('待评价', AppColors.textSecondary);
      case OrderStatus.completed:
        return ('已完成', AppColors.textSecondary);
      case OrderStatus.cancelled:
        return ('已取消', AppColors.textHint);
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '2026年6月15日 14:00';
    }
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(double amount) {
    if (amount > 0 && amount < 1) {
      return amount.toStringAsFixed(2);
    }
    return amount.toStringAsFixed(0);
  }

  void _showSimpleMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
