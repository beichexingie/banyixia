import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../providers/guide_provider.dart';
import '../main_scaffold.dart';
import '../../widgets/service_guide_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  String _selectedCity = '苏州';
  bool _signedToday = false;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GuideProvider>();
      provider.setCity(_selectedCity);
      provider.loadGuides();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_currentTab == _tabController.index) {
      return;
    }
    setState(() {
      _currentTab = _tabController.index;
    });
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    context.read<GuideProvider>().setSearchQuery(_searchController.text.trim());
  }

  Future<void> _pickCityWithLocationPicker() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {
        'city': _selectedCity,
        'address': _selectedCity,
      },
    );
    if (result == null || !mounted) {
      return;
    }

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) {
      return;
    }

    setState(() {
      _selectedCity = city;
    });
    context.read<GuideProvider>().setCity(city);
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) {
      return '';
    }

    const suffixes = ['特别行政区', '自治州', '自治县', '自治旗', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }

  void _searchGuides() {
    context.read<GuideProvider>().setSearchQuery(_searchController.text.trim());
  }

  void _showSignInFeedback() {
    if (_signedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天已经签到过了')),
      );
      return;
    }

    setState(() {
      _signedToday = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('签到成功，获得 10 积分')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                minExtentHeight: topInset + 84,
                maxExtentHeight: topInset + 608,
                builder: (context, progress) {
                  return _buildHeroSection(
                    collapseProgress: progress,
                    topInset: topInset,
                  );
                },
              ),
            ),
          ];
        },
        body: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7F2),
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGuideList(),
              _buildGuideList(sortByHot: false),
              _buildGuideList(showFallbackAction: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required double collapseProgress,
    required double topInset,
  }) {
    final eased = Curves.easeOutCubic.transform(collapseProgress);
    final searchTop = lerpDouble(topInset + 124, topInset + 10, eased)!;
    final brandOpacity = (1 - eased * 1.2).clamp(0.0, 1.0);
    final bannerOpacity = (1 - eased * 1.5).clamp(0.0, 1.0);
    final featureOpacity = (1 - eased * 1.8).clamp(0.0, 1.0);
    final tabOpacity = (1 - eased * 2.1).clamp(0.0, 1.0);
    final contentOffset = 40 * eased;
    final headerShadowOpacity = (eased - 0.72).clamp(0.0, 0.22);

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFC7FF1B),
              const Color(0xFFD8FF66),
              Color.lerp(
                const Color(0xFFF7F7F2),
                const Color(0xFFEFF8CC),
                eased * 0.45,
              )!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.63, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: headerShadowOpacity),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 10),
                child: Transform.translate(
                  offset: Offset(0, -contentOffset),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -4,
                        right: -22,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: brandOpacity,
                            child: Image.asset(
                              'assets/home/top_sketch/插画 2.png',
                              width: 232,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: brandOpacity <= 0.02,
                          child: Opacity(
                            opacity: brandOpacity,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildBrandBlock()),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, right: 2),
                                  child: IconButton(
                                    onPressed: _showSignInFeedback,
                                    iconSize: 22,
                                    splashRadius: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    icon: Icon(
                                      _signedToday
                                          ? Icons.wb_sunny
                                          : Icons.wb_sunny_outlined,
                                      color: const Color(0xFF9AB246),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 190,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: bannerOpacity <= 0.02,
                          child: Opacity(
                            opacity: bannerOpacity,
                            child: _buildBannerCard(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 370,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: featureOpacity <= 0.02,
                          child: Opacity(
                            opacity: featureOpacity,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 49,
                                  child: _featureCard(
                                    title: '需求定制',
                                    subtitle: '根据你的需求定制～',
                                    onTap: () => context.push('/demand/create'),
                                    large: true,
                                    illustration: _buildFeatureIllustration(
                                      'assets/home/feature_settle/Frame 5.png',
                                      width: 118,
                                      height: 118,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 51,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _featureCard(
                                        title: '入驻',
                                        subtitle: '',
                                        onTap: () => context.push('/apply/guide'),
                                        illustration: _buildFeatureIllustration(
                                          'assets/home/feature_map/Frame 6.png',
                                          width: 96,
                                          height: 78,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _featureCard(
                                        title: '联系我们',
                                        subtitle: '',
                                        onTap: () => ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('客服入口稍后接入'),
                                          ),
                                        ),
                                        illustration: _buildFeatureIllustration(
                                          'assets/home/feature_contact/Frame 5.png',
                                          width: 96,
                                          height: 78,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 538,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: tabOpacity <= 0.02,
                          child: Opacity(
                            opacity: tabOpacity,
                            child: _buildTabSelector(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: searchTop,
              child: _buildSearchRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandBlock() {
    return SizedBox(
      width: 190,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset(
              'assets/home/logo 1.png',
              width: 142,
              fit: BoxFit.contain,
            ),
          ),
          const Positioned(
            left: 46,
            top: 18,
            child: Text(
              '一点就陪伴',
              style: TextStyle(
                fontFamily: 'Wawati TC',
                fontFamilyFallback: [
                  'DFWaWaTC-W5',
                  '华文彩云',
                  '华文楷体',
                  'STKaiti',
                  'KaiTi',
                  '楷体',
                ],
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(139, 196, 41, 1),
                height: 1,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB7D640).withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 27,
                  color: Color(0xFFD5D5D5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchGuides(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '搜索内容',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD2D2D2),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: _pickCityWithLocationPicker,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB7D640).withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 78),
                  child: Text(
                    _selectedCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/home/banner/Rectangle 8.png',
                  fit: BoxFit.cover,
                ),
                Center(
                  child: Image.asset(
                    'assets/home/tab_mark/image 4.png',
                    width: 226,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    const labels = ['推荐', '最新', '关注'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _currentTab == index;
          return Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 24),
            child: GestureDetector(
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 0),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected && index == 0) ...[
                      Image.asset(
                        'assets/login/Group.png',
                        width: 18,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget illustration,
    bool large = false,
  }) {
    final cardHeight = large ? 150.0 : 72.0;
    final cardHorizontalPadding = large ? 18.0 : 14.0;
    final cardVerticalPadding = large ? 18.0 : 12.0;
    final titleSize = large ? 20.0 : 17.0;
    final subtitleSize = large ? 14.0 : 12.0;
    final arrowHeight = large ? 28.0 : 25.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: cardHeight,
        padding: EdgeInsets.symmetric(
          horizontal: cardHorizontalPadding,
          vertical: cardVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: large
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.05,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFAFAFA7),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    width: 50,
                    height: arrowHeight,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Align(
                alignment: large ? Alignment.bottomRight : Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: illustration,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIllustration(
    String assetPath, {
    required double width,
    required double height,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }

  Widget _buildGuideList({
    bool sortByHot = true,
    bool showFallbackAction = false,
  }) {
    return Consumer<GuideProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.guides.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final guides = List<Guide>.from(provider.filteredGuides);
        if (sortByHot) {
          guides.sort((a, b) {
            final scoreA = a.likes + a.fans + a.views;
            final scoreB = b.likes + b.fans + b.views;
            final scoreCompare = scoreB.compareTo(scoreA);
            if (scoreCompare != 0) return scoreCompare;
            return b.rating.compareTo(a.rating);
          });
        } else {
          guides.sort((a, b) {
            final verifiedCompare = (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0);
            if (verifiedCompare != 0) return verifiedCompare;
            final ratingCompare = b.rating.compareTo(a.rating);
            if (ratingCompare != 0) return ratingCompare;
            return b.likes.compareTo(a.likes);
          });
        }

        if (guides.isEmpty) {
          return _emptyState(
            icon: Icons.people_outline,
            title: '暂时没有地陪',
            subtitle: '可以切换城市或去服务页查看更多认证地陪',
            actionText: showFallbackAction ? '去服务页' : null,
            onAction: showFallbackAction ? () => MainScaffold.switchTo(1) : null,
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => provider.loadGuides(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            itemCount: guides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) => ServiceGuideCard(
              guide: guides[index],
              rankLabel: '${index + 1}',
              statusLabel: '最早可约 今天 14:00',
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 34, color: AppColors.textHint),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentHeight;
  final double maxExtentHeight;
  final Widget Function(BuildContext context, double collapseProgress) builder;

  const _HomeHeaderDelegate({
    required this.minExtentHeight,
    required this.maxExtentHeight,
    required this.builder,
  });

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final availableRange = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final collapseProgress = (shrinkOffset / availableRange).clamp(0.0, 1.0);
    return builder(context, collapseProgress);
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return minExtentHeight != oldDelegate.minExtentHeight ||
        maxExtentHeight != oldDelegate.maxExtentHeight ||
        builder != oldDelegate.builder;
  }
}
