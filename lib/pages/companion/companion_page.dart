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

  // Do not hide guides whose city has not been completed in the admin data.
  // Users can still choose a specific city from the picker when needed.
  String _selectedCity = '全国';
  bool _sortByTime = true;

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

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.loadGuides(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildTopSection(),
                  _buildBottomSection(provider, guides),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection() {
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
        child: Column(children: [_buildSearchBar()]),
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
    // HomePage and CompanionPage share one GuideProvider, but they have
    // independent city selections. Do not use provider.filteredGuides here,
    // otherwise the home page can silently filter this list to its city.
    final query = provider.searchQuery.trim().toLowerCase();
    final baseList = provider.guides.where((guide) {
      if (query.isNotEmpty) {
        final matches =
            guide.name.toLowerCase().contains(query) ||
            guide.city.toLowerCase().contains(query) ||
            guide.description.toLowerCase().contains(query) ||
            guide.tags.join(' ').toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_selectedCity != '全国' &&
          _normalizeCityName(guide.city) != _normalizeCityName(_selectedCity)) {
        return false;
      }
      if (provider.filterGender != null &&
          guide.gender != provider.filterGender) {
        return false;
      }
      if (provider.filterTag != null &&
          !guide.tags.contains(provider.filterTag)) {
        return false;
      }
      return true;
    }).toList();
    if (baseList.isEmpty) {
      return const <Guide>[];
    }

    final list = baseList;
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
