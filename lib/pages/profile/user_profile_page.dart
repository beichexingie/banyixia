import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../models/travel_post.dart';
import '../../models/user.dart';
import '../../providers/guide_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _profileUser;
  Guide? _guideProfile;
  List<TravelPost> _userPosts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final postProvider = context.read<PostProvider>();
      final guideProvider = context.read<GuideProvider>();

      final results = await Future.wait([
        userProvider.fetchUserById(widget.userId),
        postProvider.fetchPostsByUser(widget.userId),
        userProvider.isFollowing(widget.userId),
      ]);

      final loadedUser = results[0] as User?;
      Guide? guideProfile;

      if (loadedUser?.isGuideApproved == true) {
        for (final guide in guideProvider.guides) {
          if (guide.id == widget.userId) {
            guideProfile = guide;
            break;
          }
        }
        guideProfile ??= await guideProvider.getGuideById(widget.userId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profileUser = loadedUser;
        _guideProfile = guideProfile;
        _userPosts = results[1] as List<TravelPost>;
        _isFollowing = results[2] as bool;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) {
      return;
    }
    setState(() => _isFollowLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      if (_isFollowing) {
        await userProvider.unfollowUser(widget.userId);
      } else {
        await userProvider.followUser(widget.userId);
      }
      final following = await userProvider.isFollowing(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() => _isFollowing = following);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Future<void> _copyDisplayCode() async {
    await Clipboard.setData(ClipboardData(text: _displayCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('编号已复制')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = _profileUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: Text('未找到该用户', style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    final isSelf = context.read<UserProvider>().user.id == widget.userId;
    final heroImage = _heroImage(user);
    final guideForOrder = _resolvedGuide(user);
    final displayPosts = _displayPosts(user, heroImage);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      bottomNavigationBar: !isSelf && user.isGuideApproved
          ? _buildBottomCta(guideForOrder)
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHero(user, isSelf, heroImage),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabSwitcher(user.isGuideApproved),
                    const SizedBox(height: 16),
                    if (user.isGuideApproved && _selectedTab == 0)
                      _buildServiceTab(user, guideForOrder)
                    else
                      _buildDynamicTab(displayPosts),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(User user, bool isSelf, String heroImage) {
    return SizedBox(
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: heroImage,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: const Color(0xFF9CADBA)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.36),
                  Colors.black.withValues(alpha: 0.52),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _topCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                        size: 38,
                      ),
                      const Spacer(),
                      _topCircleButton(
                        icon: Icons.autorenew_rounded,
                        onTap: _loadData,
                        size: 56,
                        iconSize: 28,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 3),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.avatar.isNotEmpty
                                ? user.avatar
                                : heroImage,
                            width: 106,
                            height: 106,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 106,
                              height: 106,
                              color: Colors.white24,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.person,
                                size: 38,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  _displayName(user),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                if (user.isGuideApproved) _buildGuideBadge(),
                                Text(
                                  '${_displayRating().toStringAsFixed(1)}分',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF2A439),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _copyDisplayCode,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '编号：$_displayCode',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 22,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _heroStat(
                        '${user.fansCount == 0 ? 12 : user.fansCount}',
                        '粉丝',
                      ),
                      const SizedBox(width: 42),
                      _heroStat(
                        '${user.followCount == 0 ? 28 : user.followCount}',
                        '收藏',
                      ),
                      const SizedBox(width: 42),
                      _heroStat(
                        '${_guideProfile?.views == 0 || _guideProfile == null ? 105 : _guideProfile!.views}',
                        '接单',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _heroChip('IP：${_displayCity(user)}'),
                            _heroChip(_ageLabel(user)),
                            _heroCheckChip(
                              user.isGuideApproved ? '已实名' : '已认证',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _followButton(
                        label: isSelf
                            ? '编辑资料'
                            : (_isFollowing ? '已关注' : '+ 关注'),
                        onTap: isSelf
                            ? () => context.push('/settings')
                            : _toggleFollow,
                        filled: !isSelf,
                        loading: _isFollowLoading,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(bool showService) {
    final tabs = showService ? const ['服务', '动态'] : const ['动态'];

    return Row(
      children: List.generate(tabs.length, (index) {
        final selected = _selectedTab == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected
                        ? AppColors.textPrimary
                        : const Color(0xFF8D8D8D),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 24 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildServiceTab(User user, Guide guide) {
    final intro = _guideIntroduction(user);
    final tags = guide.tags.isNotEmpty ? guide.tags : _defaultServiceTags();

    return Column(
      children: [
        _buildMetricsCard(user),
        const SizedBox(height: 12),
        _buildInfoSection(
          title: '个人介绍：',
          child: Text(
            intro,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoSection(
          title: '服务类型说明：',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: tags.take(4).map(_buildServiceTagChip).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoSection(
          title: '额外费用说明：',
          child: const Text(
            '这是额外说明这是额外说明这是额外说明这是额外说明这是额外说明这是额外说明这是额外说明',
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildReviewsCard(),
      ],
    );
  }

  Widget _buildDynamicTab(List<TravelPost> posts) {
    if (posts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 54),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 44,
              color: AppColors.textHint,
            ),
            SizedBox(height: 12),
            Text(
              '还没有发布动态',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, index) => _PostCard(post: posts[index]),
    );
  }

  Widget _buildMetricsCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
        children: [
          _metricCell('${_guideProfile?.likes ?? 123}', '入驻'),
          _metricCell(
            '${(_displayRating() * 20.8).clamp(80, 99.8).toStringAsFixed(1)}%',
            '好评率',
          ),
          _metricCell('${(_guideProfile?.fans ?? 80).clamp(80, 99)}%', '回购率'),
          _metricCell('汉', '民族'),
          _metricCell(_zodiacLabel(user), '星座'),
          _metricCell(user.occupation.isEmpty ? '本科' : user.occupation, '学历'),
          _metricCell('${170 + ((_guideProfile?.likes ?? 13) % 18)}', '身高'),
          _metricCell('${48 + ((_guideProfile?.fans ?? 32) % 36)}kg', '体重'),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8D8D8D),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildReviewsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '用户评价（10）',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '查看更多',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHint.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _reviewCard(
            name: '用户1028er',
            content:
                '这是评论内容，这是评论内容。这是评论内容，这是评论内容这是评论内容，这是评论内容这是评论内容，这是评论内容这是评论内容。',
          ),
          _reviewCard(
            name: '用户1028er',
            content: '这是评论内容，这是评论内容。这是评论内容，这是评论内容这是评论内容，这是评论内容这是评论内容，这是评论内容。',
            imageCount: 3,
          ),
          _reviewCard(
            name: '用户1028er',
            content: '这是评论内容，这是评论内容。这是评论内容，这是评论内容这是评论内容，这是评论内容这是评论内容，这是评论内容。',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta(Guide guide) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: () => context.push(
              '/order/create?guideId=${widget.userId}',
              extra: guide,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '找TA下单',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideBadge() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text(
        '导',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildServiceTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCFFF36), Color(0xFFF1FFC3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_serviceTagIcon(label), size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _heroChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _heroCheckChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _followButton({
    required String label,
    required VoidCallback onTap,
    required bool filled,
    required bool loading,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? AppColors.primary : Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _topCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    double? iconSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize ?? (size * 0.5), color: Colors.white),
      ),
    );
  }

  Widget _metricCell(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _reviewCard({
    required String name,
    required String content,
    int imageCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://picsum.photos/seed/review-user/80/80',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
          if (imageCount > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                imageCount,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == imageCount - 1 ? 0 : 10,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://picsum.photos/seed/review-$index/280/280',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Guide _resolvedGuide(User user) {
    final intro = _guideIntroduction(user);
    return _guideProfile ??
        Guide(
          id: user.id,
          name: _displayName(user),
          avatar: user.avatar,
          verified: user.isGuideApproved,
          tags: user.guideTags,
          description: intro,
          city: _displayCity(user),
          gender: user.gender,
          rating: _displayRating(),
          images: _guideProfile?.images ?? const [],
        );
  }

  List<TravelPost> _displayPosts(User user, String heroImage) {
    if (_userPosts.isNotEmpty) {
      return _userPosts;
    }

    return List.generate(
      4,
      (index) => TravelPost(
        id: 'mock_profile_$index',
        title: '川西徒步带队2.0，爬升1.5km',
        subtitle: '超级收获大大的。',
        content: '超级收获大大的。',
        coverImage: heroImage,
        authorId: user.id,
        authorName: _displayName(user),
        authorAvatar: user.avatar,
        likes: 12,
        commentCount: 0,
      ),
    );
  }

  List<String> _defaultServiceTags() {
    return const ['休闲游玩', '商务陪同'];
  }

  IconData _serviceTagIcon(String label) {
    if (label.contains('商务') || label.contains('公务')) {
      return Icons.people_outline_rounded;
    }
    if (label.contains('户外') || label.contains('运动')) {
      return Icons.terrain_outlined;
    }
    return Icons.spa_outlined;
  }

  String get _displayCode {
    final digits = widget.userId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      return digits.substring(0, 6);
    }
    if (digits.isNotEmpty) {
      return digits;
    }
    return '109283';
  }

  String _displayName(User user) {
    return user.nickname.trim().isEmpty ? '本地导游' : user.nickname.trim();
  }

  String _displayCity(User user) {
    final city = user.city.trim();
    if (city.isNotEmpty) {
      return city;
    }
    if ((_guideProfile?.city ?? '').trim().isNotEmpty) {
      return _guideProfile!.city.trim();
    }
    return '苏州';
  }

  String _guideIntroduction(User user) {
    return [
      user.guideIntroduction,
      _guideProfile?.description ?? '',
      user.bio,
    ].firstWhere(
      (item) => item.trim().isNotEmpty,
      orElse: () => '这是个人介绍这是个人介绍这是个人介绍这是个人介绍这是个人介绍这是个人介绍这是个人介绍',
    );
  }

  String _heroImage(User user) {
    if (_guideProfile?.images.isNotEmpty == true) {
      return _guideProfile!.images.first;
    }
    if (user.avatar.isNotEmpty) {
      return user.avatar;
    }
    return 'https://picsum.photos/seed/profile-hero-${user.id}/1200/900';
  }

  double _displayRating() {
    final rating = _guideProfile?.rating ?? 0;
    return rating <= 0 ? 4.8 : rating;
  }

  String _ageLabel(User user) {
    final birthday = DateTime.tryParse(user.birthday);
    if (birthday == null) {
      return user.gender.isEmpty ? '女·26' : '${user.gender}·26';
    }
    final now = DateTime.now();
    var age = now.year - birthday.year;
    final hadBirthday =
        now.month > birthday.month ||
        (now.month == birthday.month && now.day >= birthday.day);
    if (!hadBirthday) {
      age -= 1;
    }
    final prefix = user.gender.isEmpty ? '女·' : '${user.gender}·';
    return '$prefix$age';
  }

  String _zodiacLabel(User user) {
    final birthday = DateTime.tryParse(user.birthday);
    if (birthday == null) {
      return '水瓶座';
    }
    final month = birthday.month;
    final day = birthday.day;
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return '水瓶座';
    if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return '双鱼座';
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return '白羊座';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return '金牛座';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 21)) return '双子座';
    if ((month == 6 && day >= 22) || (month == 7 && day <= 22)) return '巨蟹座';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return '狮子座';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return '处女座';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 23)) return '天秤座';
    if ((month == 10 && day >= 24) || (month == 11 && day <= 22)) return '天蝎座';
    if ((month == 11 && day >= 23) || (month == 12 && day <= 21)) return '射手座';
    return '摩羯座';
  }
}

class _PostCard extends StatelessWidget {
  final TravelPost post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final isMock = post.id.startsWith('mock_profile_');

    return GestureDetector(
      onTap: isMock ? null : () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.88,
              child: CachedNetworkImage(
                imageUrl: post.coverImage,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.surfaceMuted),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceMuted,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (post.subtitle?.isNotEmpty == true)
                        ? post.subtitle!
                        : (post.content?.isNotEmpty == true
                              ? post.content!
                              : '超级收获大大的。'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: post.authorAvatar,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 24,
                            height: 24,
                            color: AppColors.surfaceMuted,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              size: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.authorName.isEmpty ? '用户昵称' : post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes == 0 ? 12 : post.likes}',
                        style: const TextStyle(
                          fontSize: 13,
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
