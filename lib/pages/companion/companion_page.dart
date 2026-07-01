import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../models/travel_post.dart';
import '../../providers/guide_provider.dart';
import '../../providers/post_provider.dart';
import '../../widgets/service_guide_card.dart';
import '../../widgets/travel_card.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  late final TextEditingController _searchController;
  String _selectedCity = '苏州';
  int _activeCategory = -1;

  final List<_TopServiceCard> _topCards = const [
    _TopServiceCard(
      title: '休闲游玩',
      subtitle: '这是一段文案哦\n这是文案哦',
      icon: Icons.deck_outlined,
    ),
    _TopServiceCard(
      title: '户外运动',
      subtitle: '这是文案哦\n这是文案哦',
      icon: Icons.landscape_outlined,
    ),
    _TopServiceCard(
      title: '公务随行',
      subtitle: '这是文案哦\n这是文案哦',
      icon: Icons.luggage_outlined,
    ),
  ];

  final List<_CategoryItem> _categories = const [
    _CategoryItem(Icons.restaurant_outlined, '老吃家', '美食'),
    _CategoryItem(Icons.hiking_outlined, '城市漫步', '陪游'),
    _CategoryItem(Icons.storefront_outlined, '打卡探店', '探店'),
    _CategoryItem(Icons.map_outlined, '本地陪玩', '地陪'),
    _CategoryItem(Icons.movie_filter_outlined, '观影赏剧', '观影'),
    _CategoryItem(Icons.directions_car_outlined, '露营自驾', '露营'),
    _CategoryItem(Icons.roller_skating_outlined, '游乐园', '游乐'),
    _CategoryItem(Icons.style_outlined, '桌游娱乐', '桌游'),
    _CategoryItem(Icons.theater_comedy_outlined, '剧本密室', '剧本'),
    _CategoryItem(Icons.sports_baseball_outlined, '桌球陪练', '桌球'),
    _CategoryItem(Icons.sports_esports_outlined, '开黑搭子', '开黑'),
    _CategoryItem(Icons.shopping_bag_outlined, '代排购物', '购物'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (!mounted) return;
      context.read<GuideProvider>().setSearchQuery(_searchController.text);
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GuideProvider>();
      provider.setCity(_selectedCity);
      provider.setSearchQuery('');
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer2<GuideProvider, PostProvider>(
          builder: (context, guideProvider, postProvider, child) {
            final guides = _filteredGuides(guideProvider);
            final recruitPosts = _filteredRecruitPosts(postProvider);

            return RefreshIndicator(
              color: AppColors.primaryDark,
              onRefresh: () async {
                await Future.wait([
                  guideProvider.loadGuides(),
                  postProvider.loadPosts(),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildTopServiceCards(),
                  const SizedBox(height: 18),
                  _buildCategoryGrid(),
                  const SizedBox(height: 18),
                  _buildSortHeader(),
                  const SizedBox(height: 12),
                  if (guideProvider.isLoading && guides.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    )
                  else if (guides.isNotEmpty)
                    ...guides.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ServiceGuideCard(
                          guide: entry.value,
                          statusLabel: _statusLabel(entry.key),
                          compact: true,
                        ),
                      ),
                    )
                  else
                    _buildGuideEmptyHint(),
                  if (recruitPosts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildRecruitSection(recruitPosts),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE4FFD0), Color(0xFFF7F9F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(29),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 26, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
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
    );
  }

  Widget _buildTopServiceCards() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(_topCards[0], large: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildFeatureCard(_topCards[1]),
              const SizedBox(height: 12),
              _buildFeatureCard(_topCards[2]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_TopServiceCard card, {bool large = false}) {
    return GestureDetector(
      onTap: () {
        final index = _topCards.indexOf(card);
        setState(() {
          _activeCategory = index == 0 ? 0 : index == 1 ? 6 : 2;
        });
      },
      child: Container(
        height: large ? 168 : 78,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDAFF6A), Color(0xFFF5F9E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: TextStyle(
                    fontSize: large ? 28 : 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                card.icon,
                size: large ? 72 : 48,
                color: AppColors.textPrimary.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 18,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final item = _categories[index];
        final isActive = _activeCategory == index;
        return GestureDetector(
          onTap: () => setState(() => _activeCategory = index),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.textPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickCityWithLocationPicker,
          child: Row(
            children: [
              Text(
                _selectedCity,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Text(
                '时间升序',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.unfold_more, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ],
    );
  }

  List<Guide> _filteredGuides(GuideProvider provider) {
    var list = provider.filteredGuides;
    if (_activeCategory >= 0) {
      final category = _categories[_activeCategory];
      list = list.where((guide) {
        final text =
            '${guide.name}${guide.city}${guide.description}${guide.tags.join('')}';
        return text.contains(category.keyword);
      }).toList();
    }
    return list;
  }

  String _statusLabel(int index) {
    const labels = ['最早可约 今14:00', '在线接单', '最早可约 今14:00', '极速回复'];
    return labels[index % labels.length];
  }

  List<TravelPost> _filteredRecruitPosts(PostProvider provider) {
    final keyword = _searchController.text.trim().toLowerCase();
    final city = _selectedCity.trim();

    return provider.posts.where((post) {
      final fullText =
          '${post.title} ${post.subtitle ?? ''} ${post.content ?? ''} ${post.tag} ${post.authorName}'
              .toLowerCase();
      final isRecruitLike =
          post.tag.contains('招募') ||
          fullText.contains('招募') ||
          fullText.contains('自荐') ||
          fullText.contains('地陪') ||
          fullText.contains('陪游');
      if (!isRecruitLike) return false;

      if (keyword.isNotEmpty && !fullText.contains(keyword)) {
        return false;
      }

      if (city.isNotEmpty && city != '全国') {
        final cityMatched =
            fullText.contains(city.toLowerCase()) ||
            post.tag.toLowerCase().contains(city.toLowerCase());
        if (!cityMatched) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _pickCityWithLocationPicker() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {
        'city': _selectedCity,
        'address': _selectedCity == '全国' ? '苏州' : _selectedCity,
      },
    );
    if (result == null || !mounted) return;

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) return;

    setState(() => _selectedCity = city);
    context.read<GuideProvider>().setCity(city);
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

  Widget _buildGuideEmptyHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        '当前城市暂时没有匹配到地陪服务，先看看地陪招募和自荐内容，或者切换城市再试。',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildRecruitSection(List<TravelPost> recruitPosts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '地陪招募 / 自荐',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/post/create?mode=recruit'),
              child: const Text('去发布'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recruitPosts.length > 4 ? 4 : recruitPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final post = recruitPosts[index];
            return TravelCard(
              post: post,
              cityLabel: _selectedCity == '全国' ? null : _selectedCity,
            );
          },
        ),
      ],
    );
  }
}

class _TopServiceCard {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TopServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _CategoryItem {
  final IconData icon;
  final String label;
  final String keyword;

  const _CategoryItem(this.icon, this.label, this.keyword);
}
