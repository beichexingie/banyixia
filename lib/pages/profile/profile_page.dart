import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../models/travel_post.dart';
import '../../models/user.dart';
import '../../providers/order_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/travel_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<TravelPost>> _followingFuture;
  late Future<List<TravelPost>> _favoriteFuture;
  late Future<List<TravelPost>> _footprintFuture;
  bool _contentInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contentInitialized) return;
    _contentInitialized = true;
    final postProvider = context.read<PostProvider>();
    _followingFuture = postProvider.fetchFollowingPosts();
    _favoriteFuture = postProvider.fetchFavoritedPosts();
    _footprintFuture = postProvider.fetchFootprints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reloadContent() async {
    final postProvider = context.read<PostProvider>();
    setState(() {
      _followingFuture = postProvider.fetchFollowingPosts();
      _favoriteFuture = postProvider.fetchFavoritedPosts();
      _footprintFuture = postProvider.fetchFootprints();
    });
    await Future.wait([_followingFuture, _favoriteFuture, _footprintFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Consumer2<UserProvider, OrderProvider>(
          builder: (context, userProvider, orderProvider, _) {
            final user = userProvider.user;
            return RefreshIndicator(
              color: AppColors.primaryDark,
              onRefresh: _reloadContent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      user: user,
                      onSettingsTap: () => context.push('/settings'),
                      onSupportTap: () => context.push('/settings/help'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _VipBanner(
                      isGuide: user.isGuideApproved,
                      onTap: () => context.push('/settings'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _OrderPanel(
                      orderProvider: orderProvider,
                      onTapTab: (index) =>
                          context.push('/profile/orders?tab=$index'),
                      onDebugPay: () => context.push('/profile/orders?tab=1'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CouponBanner(
                      count: user.couponCount,
                      onTap: () => context.push('/profile/coupons'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _QuickActions(
                      onSecurityTap: () => context.push('/settings/security'),
                      onFeedbackTap: () => context.push('/settings/help'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _ContentTabs(
                      controller: _tabController,
                      onSwitch: (index) => _tabController.animateTo(index),
                    ),
                  ),
                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostFuture(_followingFuture, '暂无关注内容'),
                        _buildPostFuture(_favoriteFuture, '暂无收藏内容'),
                        _buildPostFuture(_footprintFuture, '暂无足迹内容'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostFuture(Future<List<TravelPost>> future, String emptyText) {
    return FutureBuilder<List<TravelPost>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textHint,
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) => TravelCard(post: posts[index]),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;

  const _ProfileHeader({
    required this.user,
    required this.onSettingsTap,
    required this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              _Avatar(url: user.avatar),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nickname.isNotEmpty
                                ? user.nickname
                                : '未登录用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (user.vipLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _InlineBadge(text: user.vipLabel),
                        ],
                        if (user.isGuideApproved) ...[
                          const SizedBox(width: 8),
                          const _InlineBadge(text: '认证'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'IP：${user.city.isEmpty ? '未知' : user.city}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TopIconAction(
                icon: Icons.headset_mic_outlined,
                label: '客服',
                onTap: onSupportTap,
              ),
              const SizedBox(width: 12),
              _TopIconAction(
                icon: Icons.settings_outlined,
                label: '设置',
                onTap: onSettingsTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipBanner extends StatelessWidget {
  final bool isGuide;
  final VoidCallback onTap;

  const _VipBanner({required this.isGuide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 132,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE65B), Color(0xFFFFF0BF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Text(
                  isGuide ? 'VIP会员 · 地陪专属' : 'VIP会员',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8A5A12),
                  ),
                ),
              ),
              const Positioned(
                left: 2,
                bottom: 26,
                child: Text(
                  '开通会员轻松畅聊，享VIP权益',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9A6B1A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1B7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '开通会员',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8A5A12),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 92,
                  color: Colors.orange.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  final OrderProvider orderProvider;
  final ValueChanged<int> onTapTab;
  final VoidCallback onDebugPay;

  const _OrderPanel({
    required this.orderProvider,
    required this.onTapTab,
    required this.onDebugPay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '我的订单',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => onTapTab(0),
                  child: const Text('更多 >'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _OrderShortcut(
                  icon: Icons.credit_card_outlined,
                  label: '待付款',
                  count: orderProvider.getCountByStatus(
                    OrderStatus.pendingPayment,
                  ),
                  onTap: () => onTapTab(1),
                ),
                _OrderShortcut(
                  icon: Icons.hourglass_bottom_outlined,
                  label: '进行中',
                  count: orderProvider.getCountByStatus(
                    OrderStatus.inProgress,
                  ),
                  onTap: () => onTapTab(2),
                ),
                _OrderShortcut(
                  icon: Icons.rate_review_outlined,
                  label: '待评价',
                  count: orderProvider.getCountByStatus(
                    OrderStatus.pendingReview,
                  ),
                  onTap: () => onTapTab(3),
                ),
                _OrderShortcut(
                  icon: Icons.cancel_outlined,
                  label: '已取消',
                  count: orderProvider.getCountByStatus(
                    OrderStatus.cancelled,
                  ),
                  onTap: () => onTapTab(4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onDebugPay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0.01元测试付款',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '点击后可验证支付宝支付链路',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        '去测试',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CouponBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text(
                '优惠券',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count张可用',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              const Text(
                '更多 >',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onSecurityTap;
  final VoidCallback onFeedbackTap;

  const _QuickActions({
    required this.onSecurityTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.shield_outlined, color: AppColors.textPrimary),
              title: const Text(
                '安全中心',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: onSecurityTap,
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            ListTile(
              leading:
                  const Icon(Icons.edit_note_outlined, color: AppColors.textPrimary),
              title: const Text(
                '建议反馈',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: onFeedbackTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTabs extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onSwitch;

  const _ContentTabs({
    required this.controller,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: controller,
          onTap: onSwitch,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          dividerColor: Colors.transparent,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '喜欢'),
            Tab(text: '足迹'),
          ],
        ),
      ),
    );
  }
}

class _TopIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textPrimary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  final String text;

  const _InlineBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;

  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();
    if (imageUrl.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(Icons.person, size: 40, color: AppColors.textHint),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 76,
          height: 76,
          color: Colors.white,
          child: const Icon(Icons.person, size: 40, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _OrderShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _OrderShortcut({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.textPrimary, size: 24),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6A3A),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
