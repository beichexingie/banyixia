import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/travel_post.dart';
import '../../providers/post_provider.dart';
import '../../widgets/travel_card.dart';
import '../main_scaffold.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  late final PageController _bannerController;
  String _selectedCity = '苏州';
  int _bannerIndex = 0;

  final List<String> _banners = const [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=80',
  ];

  final List<_EntryCardData> _entries = const [
    _EntryCardData(
      title: '需求定制',
      subtitle: '根据你的需求定制~',
      icon: Icons.map_outlined,
      route: '/demand/create',
      large: true,
    ),
    _EntryCardData(
      title: '入驻',
      subtitle: '成为地陪',
      icon: Icons.store_mall_directory_outlined,
      route: '/apply/guide',
    ),
    _EntryCardData(
      title: '联系我们',
      subtitle: '快速咨询',
      icon: Icons.support_agent_outlined,
      route: '/profile/help-feedback',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _bannerController = PageController(viewportFraction: 1);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _pickCityWithLocationPicker() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {
        'city': _selectedCity,
        'address': _selectedCity,
      },
    );
    if (result == null || !mounted) return;

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) return;

    setState(() {
      _selectedCity = city;
    });
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) return '';
    const suffixes = ['特别行政区', '自治州', '自治县', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<PostProvider>(
          builder: (context, postProvider, child) {
            return RefreshIndicator(
              color: AppColors.primaryDark,
              onRefresh: () => postProvider.loadPosts(),
              child: NestedScrollView(
                headerSliverBuilder: (context, _) {
                  return [
                    SliverToBoxAdapter(child: _buildHeroHeader()),
                    SliverToBoxAdapter(child: _buildSearchRow()),
                    SliverToBoxAdapter(child: _buildBanner()),
                    SliverToBoxAdapter(child: _buildEntryPanel()),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _HomeTabBarDelegate(
                        child: Container(
                          color: AppColors.background,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicator: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                dividerColor: Colors.transparent,
                                labelColor: AppColors.textPrimary,
                                unselectedLabelColor: AppColors.textSecondary,
                                indicatorSize: TabBarIndicatorSize.tab,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                tabs: const [
                                  Tab(text: '推荐'),
                                  Tab(text: '最新'),
                                  Tab(text: '关注'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostGrid(postProvider.posts),
                    _buildPostGrid(postProvider.posts.reversed.toList()),
                    _buildFollowingContent(postProvider),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_symbols_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '一点就陪',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7FA23D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '一点伴',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.22,
                      child: CustomPaint(painter: _HeroSketchPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 26,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          context.read<PostProvider>().setSearchQuery(value),
                      onSubmitted: (value) =>
                          context.read<PostProvider>().loadPosts(query: value),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索内容',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _pickCityWithLocationPicker,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedCity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          SizedBox(
            height: 214,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() {
                  _bannerIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _banners[index],
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.32),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 24,
                        bottom: 28,
                        child: Text(
                          '在野生活.',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              final isActive = index == _bannerIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textHint.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildEntryCard(_entries[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _buildEntryCard(_entries[1]),
                const SizedBox(height: 12),
                _buildEntryCard(_entries[2]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(_EntryCardData data) {
    return GestureDetector(
      onTap: () => context.push(data.route),
      child: Container(
        height: data.large ? 188 : 88,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.arrow_outward,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: data.large ? 8 : 12,
              child: Icon(
                data.icon,
                size: data.large ? 78 : 52,
                color: AppColors.textPrimary.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostGrid(List<TravelPost> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Text(
          '还没有内容，先去发布第一条动态吧',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
      child: GridView.builder(
        itemCount: posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.67,
        ),
        itemBuilder: (context, index) {
          return TravelCard(
            post: posts[index],
            cityLabel: _selectedCity,
          );
        },
      ),
    );
  }

  Widget _buildFollowingContent(PostProvider postProvider) {
    return FutureBuilder<List<TravelPost>>(
      future: postProvider.fetchFollowingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '暂无关注内容',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '先去服务页或广场关注感兴趣的人吧',
                  style: TextStyle(color: AppColors.textHint),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => MainScaffold.switchTo(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('去看看'),
                ),
              ],
            ),
          );
        }
        return _buildPostGrid(posts);
      },
    );
  }
}

class _EntryCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool large;

  const _EntryCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.large = false,
  });
}

class _HomeTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _HomeTabBarDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 74;

  @override
  double get minExtent => 74;

  @override
  bool shouldRebuild(covariant _HomeTabBarDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _HeroSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7FA23D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.28,
        size.width * 0.56,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.12,
        size.width * 0.94,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.36,
        size.width * 0.62,
        size.height * 0.7,
      );
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      8,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.6),
      12,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.56, size.height * 0.72),
      10,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
