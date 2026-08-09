import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/guide_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart' as app_model;
import '../../widgets/service_guide_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isCreatingTestOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPage();
    });
  }

  Future<void> _refreshPage() async {
    await Future.wait([
      context.read<OrderProvider>().loadOrders(),
      context.read<GuideProvider>().loadGuides(),
      context.read<GuideProvider>().loadFollowingGuides(notify: false),
    ]);
  }

  Future<void> _createOneCentTestOrder() async {
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn) {
      _showSnack('请先登录后再创建 0.10 测试订单');
      return;
    }
    if (_isCreatingTestOrder) return;

    setState(() => _isCreatingTestOrder = true);
    try {
      final order = await context.read<OrderProvider>().createOneCentTestOrder();
      if (!mounted) return;
      _showSnack('0.10 测试订单已创建，等待地陪接单');
      context.push('/profile/orders?tab=1', extra: order);
    } catch (e) {
      if (!mounted) return;
      _showSnack('创建 0.10 测试订单失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreatingTestOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            children: [
              _buildHeader(user),
              Transform.translate(
                offset: const Offset(0, -10),
                child: Column(
                  children: [
                    _buildVipCard(user),
                    _buildOrdersPanel(orderProvider),
                    _buildMyDemandEntry(),
                    _buildCouponBanner(user),
                    _buildMenuPanel(user),
                    _buildFollowingGuidesSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(app_model.User user) {
    final cityLabel = user.city.trim().isEmpty ? '苏州' : user.city.trim();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCDFF43), Color(0xFFE8FF9A), Color(0xFFF7F7F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.72, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _headerAction(
                    icon: Icons.headset_mic_outlined,
                    label: '客服',
                    onTap: () => _showSnack('在线客服稍后接入'),
                  ),
                  const SizedBox(width: 18),
                  _headerAction(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.push('/settings/profile'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      backgroundImage: user.avatar.isNotEmpty
                          ? NetworkImage(user.avatar)
                          : null,
                      child: user.avatar.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 28,
                              color: AppColors.textHint,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.nickname.isEmpty
                                      ? '未登录用户'
                                      : user.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (user.isGuideApproved)
                                const Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'IP：$cityLabel',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildVipCard(app_model.User user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      constraints: const BoxConstraints(minHeight: 86),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE6A1), Color(0xFFFFF1C9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 92,
            top: -8,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'VIP会员',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B4A00),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.vipLabel.isNotEmpty
                            ? '当前等级 ${user.vipLabel}，享受更多专属权益'
                            : '开通会员轻松畅聊，享VIP权益',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8E6A18),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showSnack('会员入口稍后接入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF4CD),
                    foregroundColor: const Color(0xFF8B6100),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                  ),
                  child: const Text(
                    '开通会员',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.workspace_premium,
                  size: 46,
                  color: Color(0xFFFFA91A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersPanel(OrderProvider orderProvider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '我的订单',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/profile/orders'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '更多',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _orderShortcut(
                icon: Icons.account_balance_wallet_outlined,
                label: '待付款',
                count: orderProvider.getCountByStatus(
                  OrderStatus.pendingPayment,
                ),
                tabIndex: 1,
              ),
              _orderShortcut(
                icon: Icons.hourglass_top_outlined,
                label: '进行中',
                count: orderProvider.getCountByStatus(OrderStatus.inProgress),
                tabIndex: 3,
              ),
              _orderShortcut(
                icon: Icons.edit_note_outlined,
                label: '待评价',
                count: orderProvider.getCountByStatus(
                  OrderStatus.pendingReview,
                ),
                tabIndex: 4,
              ),
              _orderShortcut(
                icon: Icons.inventory_2_outlined,
                label: '已取消',
                count: orderProvider.getCountByStatus(OrderStatus.cancelled),
                tabIndex: 0,
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _isCreatingTestOrder ? null : _createOneCentTestOrder,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE8A3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: _isCreatingTestOrder
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(
                            Icons.bolt_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '创建 0.10 测试订单',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '用户创建订单，地陪接单后再到订单页付款',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _isCreatingTestOrder ? '创建中' : '创建订单',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyDemandEntry() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => context.push('/demands/me'),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: const [
            Icon(
              Icons.assignment_outlined,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '我的需求',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderShortcut({
    required IconData icon,
    required String label,
    required int count,
    required int tabIndex,
  }) {
    return GestureDetector(
      onTap: () => context.push('/profile/orders?tab=$tabIndex'),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 25, color: AppColors.textPrimary),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6C6B),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponBanner(app_model.User user) {
    return GestureDetector(
      onTap: () => context.push('/profile/coupons'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7F2), Color(0xFFFFFBF8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text(
              '优惠券',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              user.couponCount > 0 ? '${user.couponCount} 张可用优惠券' : '30元无门槛优惠券',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFF6D2E),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuPanel(app_model.User user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _menuTile(
            icon: Icons.shield_outlined,
            title: '安全中心',
            onTap: () => context.push('/settings/security'),
          ),
          const Divider(height: 1, indent: 48, endIndent: 16),
          _menuTile(
            icon: Icons.edit_note_outlined,
            title: '建议反馈',
            onTap: () => context.push('/settings/help'),
          ),
          if (user.isGuideApproved) ...[
            const Divider(height: 1, indent: 48, endIndent: 16),
            _menuTile(
              icon: Icons.verified_outlined,
              title: '地陪主页',
              onTap: () => context.push('/guide/${user.id}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingGuidesSection() {
    return Consumer<GuideProvider>(
      builder: (context, provider, _) {
        final guides = provider.followingGuides;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '我关注的地陪',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      context.push('/following').then((_) {
                        if (mounted) _refreshPage();
                      });
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '全部',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (provider.isLoading && guides.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (guides.isEmpty)
                _emptyFollowingGuides()
              else
                ...List.generate(
                  guides.length > 3 ? 3 : guides.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: index == guides.length - 1 ? 0 : 12),
                    child: ServiceGuideCard(
                      guide: guides[index],
                      statusLabel: '已关注，可直接下单',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyFollowingGuides() {
    return InkWell(
      onTap: () {
        context.push('/following').then((_) {
          if (mounted) _refreshPage();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.people_alt_outlined,
              size: 40,
              color: AppColors.textHint,
            ),
            SizedBox(height: 10),
            Text(
              '还没有关注地陪',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '去服务页找到喜欢的地陪并关注',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
