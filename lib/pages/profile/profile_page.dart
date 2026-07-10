import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../models/travel_post.dart';
import '../../providers/order_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart' as app_model;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _contentTab = 0;
  bool _isDebugPaying = false;
  late Future<List<TravelPost>> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = Future.value(const <TravelPost>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPage();
    });
  }

  Future<void> _refreshPage() async {
    await context.read<OrderProvider>().loadOrders();
    _reloadContent();
  }

  void _reloadContent() {
    final provider = context.read<PostProvider>();
    late Future<List<TravelPost>> future;
    switch (_contentTab) {
      case 0:
        future = provider.fetchFollowingPosts();
        break;
      case 1:
        future = provider.fetchLikedPosts();
        break;
      case 2:
        future = provider.fetchFavoritedPosts();
        break;
      default:
        future = provider.fetchFootprints();
    }
    setState(() {
      _contentFuture = future;
    });
  }

  Future<void> _startDebugPayment() async {
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn) {
      _showSnack('请先登录后再发起 0.01 支付测试');
      return;
    }
    if (_isDebugPaying) {
      return;
    }

    setState(() {
      _isDebugPaying = true;
    });
    try {
      final result = await context.read<OrderProvider>().createAndPayDebugOrder();
      if (!mounted) return;
      _showSnack(
        result.success
            ? '0.01 测试订单已创建，正在拉起支付宝'
            : result.message,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('0.01 测试失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDebugPaying = false;
        });
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
                    _buildPostCategoryTabs(),
                    _buildContentSection(),
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
                onTap: () {},
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
      height: 82,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            onTap: _isDebugPaying ? null : _startDebugPayment,
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
                    child: _isDebugPaying
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
                          '0.01 元支付联调测试',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '点击后会直接创建测试订单并拉起支付宝',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _isDebugPaying ? '发起中' : '立即测试',
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

  Widget _buildPostCategoryTabs() {
    const labels = ['关注', '赞过', '收藏', '足迹'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = _contentTab == index;
          return Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: () {
                if (_contentTab == index) return;
                setState(() => _contentTab = index);
                _reloadContent();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContentTabs() {
    const labels = ['关注', '喜欢', '足迹'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = _contentTab == index;
          return Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: () {
                if (_contentTab == index) return;
                setState(() => _contentTab = index);
                _reloadContent();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContentSection() {
    return FutureBuilder<List<TravelPost>>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final posts = snapshot.data ?? const <TravelPost>[];
        if (posts.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 40,
                  color: AppColors.textHint,
                ),
                SizedBox(height: 12),
                Text(
                  '这里暂无内容',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length > 4 ? 4 : posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.61,
            ),
            itemBuilder: (context, index) =>
                _ProfilePostCard(post: posts[index]),
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ProfilePostCard extends StatelessWidget {
  final TravelPost post;

  const _ProfilePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  post.coverImage,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surfaceMuted,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.subtitle?.isNotEmpty == true
                        ? post.subtitle!
                        : '这里是内容摘要',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundImage: post.authorAvatar.isNotEmpty
                            ? NetworkImage(post.authorAvatar)
                            : null,
                        child: post.authorAvatar.isEmpty
                            ? const Icon(Icons.person, size: 10)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: post.isLiked
                            ? const Color(0xFFFF6F7A)
                            : AppColors.textHint,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${post.likes}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
