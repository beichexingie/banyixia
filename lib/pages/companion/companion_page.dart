import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../providers/guide_provider.dart';
import '../../widgets/service_guide_card.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  late final TextEditingController _searchController;

  String _selectedCity = '苏州';
  int _activeCategory = 0;
  bool _sortByTime = true;

  final List<_ServiceCategory> _categories = const [
    _ServiceCategory(
      title: '休闲游玩',
      subtitle: '这是文案哦\n这是文案哦',
      keyword: '休闲',
      heroIcon: Icons.weekend_outlined,
      items: [
        _ServiceItem(Icons.restaurant_outlined, '老吃家'),
        _ServiceItem(Icons.directions_walk, '城市漫步'),
        _ServiceItem(Icons.storefront_outlined, '打卡探店'),
        _ServiceItem(Icons.map_outlined, '本地陪玩'),
        _ServiceItem(Icons.palette_outlined, '观影赏剧'),
        _ServiceItem(Icons.directions_car_outlined, '露营自驾'),
        _ServiceItem(Icons.attractions_outlined, '游乐园'),
        _ServiceItem(Icons.dashboard_customize_outlined, '桌游娱乐'),
        _ServiceItem(Icons.rocket_launch_outlined, '剧本密室'),
        _ServiceItem(Icons.sports_baseball_outlined, '桌球陪练'),
        _ServiceItem(Icons.sports_esports_outlined, '开黑搭子'),
        _ServiceItem(Icons.shopping_bag_outlined, '代排购物'),
      ],
    ),
    _ServiceCategory(
      title: '户外运动',
      subtitle: '这是文案哦\n这是文案哦',
      keyword: '户外',
      heroIcon: Icons.terrain_outlined,
      items: [
        _ServiceItem(Icons.hiking_outlined, '徒步爬山'),
        _ServiceItem(Icons.directions_run, '轻氧慢跑'),
        _ServiceItem(Icons.fitness_center, '健身陪同'),
        _ServiceItem(Icons.self_improvement_outlined, '养生气功'),
        _ServiceItem(Icons.pedal_bike_outlined, '骑行竞走'),
        _ServiceItem(Icons.surfing_outlined, '滑板冲浪'),
        _ServiceItem(Icons.sports_tennis_outlined, '羽毛球'),
        _ServiceItem(Icons.sports_baseball_outlined, '网球'),
        _ServiceItem(Icons.golf_course_outlined, '高尔夫'),
        _ServiceItem(Icons.pool_outlined, '游泳'),
        _ServiceItem(Icons.ads_click_outlined, '射箭击靶'),
        _ServiceItem(Icons.filter_hdr_outlined, '攀岩登壁'),
      ],
    ),
    _ServiceCategory(
      title: '公务随行',
      subtitle: '这是文案哦\n这是文案哦',
      keyword: '商务',
      heroIcon: Icons.business_center_outlined,
      items: [
        _ServiceItem(Icons.sports_bar_outlined, '微醺小酌'),
        _ServiceItem(Icons.mic_external_on_outlined, '欢乐K歌'),
        _ServiceItem(Icons.record_voice_over_outlined, '商务接待'),
        _ServiceItem(Icons.music_note_outlined, '乐器表演'),
        _ServiceItem(Icons.apartment_outlined, '礼仪展会'),
        _ServiceItem(Icons.favorite_border, '树洞倾诉'),
        _ServiceItem(Icons.support_agent_outlined, '会务主持'),
        _ServiceItem(Icons.translate_outlined, '专业翻译'),
        _ServiceItem(Icons.local_hospital_outlined, '医疗陪同'),
        _ServiceItem(Icons.spa_outlined, '茶艺师'),
        _ServiceItem(Icons.badge_outlined, '秘书助理'),
        _ServiceItem(Icons.local_taxi_outlined, '商务司机'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (!mounted) {
        return;
      }
      context.read<GuideProvider>().setSearchQuery(
        _searchController.text.trim(),
      );
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GuideProvider>();
      provider.setCity(_selectedCity);
      provider.loadGuides();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F2),
      body: SafeArea(
        child: Consumer<GuideProvider>(
          builder: (context, provider, _) {
            final guides = _filteredGuides(provider);
            final category = _categories[_activeCategory];

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.loadGuides(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildTopSection(category),
                  _buildBottomSection(provider, guides),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection(_ServiceCategory category) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE5FFD1), Color(0xFFF6FBEF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.42, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 18),
            _buildCategoryRow(),
            const SizedBox(height: 22),
            _buildItemGrid(category.items),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 26, color: Color(0xFFD0D0D0)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索内容',
                hintStyle: TextStyle(fontSize: 15, color: Color(0xFFD0D0D0)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_categories.length, (index) {
        final active = index == _activeCategory;
        return Expanded(
          flex: active ? 118 : 94,
          child: Padding(
            padding: EdgeInsets.only(
              right: index == _categories.length - 1 ? 0 : 10,
            ),
            child: _buildCategoryCard(_categories[index], index, active),
          ),
        );
      }),
    );
  }

  Widget _buildCategoryCard(_ServiceCategory category, int index, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: active ? 156 : 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: active
                ? const [Color(0xFFD9FF57), Color(0xFFF0FFC0)]
                : const [Color(0xFFF2FFD7), Color(0xFFF8FCEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFCBF55C,
              ).withValues(alpha: active ? 0.22 : 0.08),
              blurRadius: active ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                active ? 14 : 12,
                active ? 18 : 14,
                active ? 52 : 42,
                active ? 12 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.title,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: active ? 22 : 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: active ? 14 : 12,
                      height: 1.2,
                      color: const Color(0xFF727272),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: active ? 12 : 10,
              bottom: active ? 10 : 8,
              child: Icon(
                category.heroIcon,
                size: active ? 50 : 40,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(List<_ServiceItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const runSpacing = 16.0;
        final crossAxisCount = constraints.maxWidth >= 340 ? 6 : 5;
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        final iconBoxSize = itemWidth >= 52
            ? 48.0
            : (itemWidth <= 42 ? 40.0 : itemWidth - 4);

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.icon,
                      size: iconBoxSize * 0.62,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBottomSection(GuideProvider provider, List<Guide> guides) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFF4F4F2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        child: Column(
          children: [
            _buildListHeader(),
            const SizedBox(height: 14),
            if (provider.isLoading && guides.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 56),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (guides.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(guides.length, (index) {
                final guide = guides[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ServiceGuideCard(
                    guide: guide,
                    rankLabel: '${index + 1}',
                    statusLabel: '最早可约 今14:00',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        InkWell(
          onTap: _pickCityWithLocationPicker,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Text(
                _selectedCity,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => setState(() => _sortByTime = !_sortByTime),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  _sortByTime ? '时间升序' : '热门排序',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Guide> _filteredGuides(GuideProvider provider) {
    final baseList = List<Guide>.of(provider.filteredGuides);
    if (baseList.isEmpty) {
      return const <Guide>[];
    }

    final keyword = _categories[_activeCategory].keyword.trim().toLowerCase();
    final matched = keyword.isEmpty
        ? baseList
        : baseList.where((guide) {
            final fullText =
                '${guide.name} ${guide.city} ${guide.description} ${guide.tags.join(' ')}'
                    .toLowerCase();
            return fullText.contains(keyword);
          }).toList();

    final list = matched.isNotEmpty ? matched : baseList;
    if (_sortByTime) {
      list.sort((a, b) {
        final verifiedCompare = (b.verified ? 1 : 0).compareTo(
          a.verified ? 1 : 0,
        );
        if (verifiedCompare != 0) {
          return verifiedCompare;
        }
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) {
          return ratingCompare;
        }
        return b.likes.compareTo(a.likes);
      });
    } else {
      list.sort((a, b) {
        final scoreA = a.likes + a.fans + a.views;
        final scoreB = b.likes + b.fans + b.views;
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return b.rating.compareTo(a.rating);
      });
    }
    return list;
  }

  Future<void> _pickCityWithLocationPicker() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {'city': _selectedCity, 'address': _selectedCity},
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
    const suffixes = ['特别行政区', '自治州', '自治县', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.travel_explore_outlined,
            size: 44,
            color: AppColors.textHint,
          ),
          SizedBox(height: 12),
          Text(
            '当前分类还没有匹配服务',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '可以切换城市、分类，或者搜索关键词试试',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ServiceCategory {
  final String title;
  final String subtitle;
  final String keyword;
  final IconData heroIcon;
  final List<_ServiceItem> items;

  const _ServiceCategory({
    required this.title,
    required this.subtitle,
    required this.keyword,
    required this.heroIcon,
    required this.items,
  });
}

class _ServiceItem {
  final IconData icon;
  final String label;

  const _ServiceItem(this.icon, this.label);
}
