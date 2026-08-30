import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/amap_config.dart';
import '../../config/guide_sort.dart';
import '../../config/guide_service_catalog.dart';
import '../../models/guide.dart';
import '../../providers/guide_provider.dart';
import '../../widgets/service_guide_card.dart';
import '../../widgets/guide_sort_menu_button.dart';
import '../../widgets/design_icon.dart';
import '../../services/map_service.dart';

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
  String? _selectedPlaceAddress;
  double? _selectedPlaceLatitude;
  double? _selectedPlaceLongitude;
  GuideSortMode _guideSortMode = GuideSortMode.time;
  String? _selectedCategory;
  double? _viewerLatitude;
  double? _viewerLongitude;
  final MapService _mapService = const AmapMapService(
    apiKey: AmapConfig.webServiceKey,
  );

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
              onRefresh: () => provider.loadGuides(
                latitude: _viewerLatitude,
                longitude: _viewerLongitude,
                sort: _guideSortMode == GuideSortMode.distance
                    ? 'distance'
                    : null,
              ),
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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildCategoryCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCards() {
    const categories = [('休闲游玩', '休闲游玩'), ('户外运动', '户外运动'), ('公务随行', '公务随行')];

    return Row(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildCategoryCard(
              title: categories[index].$1,
              iconAsset: categories[index].$2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String iconAsset,
  }) {
    final selected = _selectedCategory == title;
    return InkWell(
      onTap: () => setState(() {
        _selectedCategory = selected ? null : title;
      }),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 74,
        padding: const EdgeInsets.fromLTRB(9, 9, 7, 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC9FF70) : const Color(0xFFEFFFCE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: DesignIcon(iconAsset, size: 34),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
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
          const Icon(Icons.search_rounded, size: 21, color: Color(0xFFD0D0D0)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索内容',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFD0D0D0)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 13,
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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
        child: Column(
          children: [
            _buildListHeader(),
            const SizedBox(height: 10),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: ServiceGuideCard(
                    guide: guides[index],
                    listCompact: true,
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
        GuideSortMenuButton(mode: _guideSortMode, onSelected: _selectGuideSort),
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
      final categoryTypes = _selectedCategory == null
          ? null
          : guideServiceCategories[_selectedCategory];
      if (categoryTypes != null &&
          !_guideServiceTypes(guide).any(categoryTypes.contains)) {
        return false;
      }
      return true;
    }).toList();
    if (baseList.isEmpty) {
      return const <Guide>[];
    }

    final list = baseList..sort((a, b) => compareGuides(a, b, _guideSortMode));
    return list;
  }

  Future<void> _selectGuideSort(GuideSortMode mode) async {
    if (mode == GuideSortMode.distance) {
      try {
        var latitude = _selectedPlaceLatitude;
        var longitude = _selectedPlaceLongitude;
        if (latitude == null || longitude == null) {
          final position = await _mapService.currentPosition();
          if (!mounted) return;
          latitude = position?.latitude;
          longitude = position?.longitude;
          if (latitude == null || longitude == null) {
            _showSortMessage('暂时无法获取当前位置，无法按距离排序');
            return;
          }
        }
        setState(() {
          _guideSortMode = mode;
          _viewerLatitude = latitude;
          _viewerLongitude = longitude;
        });
        await context.read<GuideProvider>().loadGuides(
          latitude: _viewerLatitude,
          longitude: _viewerLongitude,
          sort: 'distance',
        );
        return;
      } on AmapApiException catch (error) {
        if (!mounted) return;
        if (error.code == 'LOCATION_SERVICE_DISABLED') {
          await _promptToEnableLocationService();
        } else {
          _showSortMessage('定位失败：${error.info}');
        }
        return;
      } catch (error) {
        if (mounted) _showSortMessage('获取当前位置失败：$error');
        return;
      }
    }
    setState(() => _guideSortMode = mode);
  }

  void _showSortMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _promptToEnableLocationService() async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('系统定位未开启'),
        content: const Text('请先打开手机系统定位服务，开启后再使用距离排序。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去开启定位'),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await Geolocator.openLocationSettings();
    }
  }

  Iterable<String> _guideServiceTypes(Guide guide) sync* {
    yield* guide.tags;
    for (final item in guide.serviceItems) {
      final type = item['service_type'] ?? item['serviceType'] ?? item['name'];
      if (type != null && type.toString().trim().isNotEmpty) {
        yield type.toString().trim();
      }
    }
  }

  Future<void> _pickCityWithLocationPicker() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {
        'city': _selectedCity,
        'address': _selectedPlaceAddress ?? _selectedCity,
      },
    );
    if (result == null || !mounted) {
      return;
    }

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) {
      return;
    }

    final isSpecificPlace = result['isSpecificPlace'] == true;
    final latitude = _toDouble(result['latitude']);
    final longitude = _toDouble(result['longitude']);
    final summary = (result['summary'] ?? result['address'] ?? '')
        .toString()
        .trim();

    setState(() {
      _selectedCity = city;
      _selectedPlaceAddress = isSpecificPlace ? summary : null;
      _selectedPlaceLatitude = isSpecificPlace ? latitude : null;
      _selectedPlaceLongitude = isSpecificPlace ? longitude : null;
    });
    final provider = context.read<GuideProvider>();
    provider.setCity(city);
    if (_guideSortMode == GuideSortMode.distance) {
      await provider.loadGuides(
        latitude: _selectedPlaceLatitude,
        longitude: _selectedPlaceLongitude,
        sort: 'distance',
      );
    }
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

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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
