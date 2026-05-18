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
  int _activeCategory = -1;

  final List<_CategoryItem> _categories = const [
    _CategoryItem(Icons.menu_book_outlined, '文化讲解', '讲解'),
    _CategoryItem(Icons.self_improvement_outlined, '情绪充电宝', '陪聊'),
    _CategoryItem(Icons.mic_none_outlined, '文娱活动', '活动'),
    _CategoryItem(Icons.terrain_outlined, '爬山户外', '户外'),
    _CategoryItem(Icons.work_outline, '商务活动', '商务'),
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
        child: Consumer<GuideProvider>(
          builder: (context, provider, child) {
            final guides = _filteredGuides(provider);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.loadGuides(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _buildTopActions(),
                  const SizedBox(height: 18),
                  _buildCategoryRow(),
                  const SizedBox(height: 18),
                  _buildSearchCityRow(),
                  const SizedBox(height: 14),
                  if (provider.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (guides.isEmpty)
                    _buildEmptyState()
                  else
                    ...guides.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ServiceGuideCard(
                          guide: entry.value,
                          statusLabel: _statusLabel(entry.key),
                        ),
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

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(child: _topButton('入驻', () => context.push('/apply/guide'))),
        const SizedBox(width: 12),
        Expanded(
          child: _topButton('需求定制', () => context.push('/demand/create')),
        ),
        const SizedBox(width: 12),
        Expanded(child: _topButton('需求列表', () => context.push('/demands'))),
      ],
    );
  }

  Widget _topButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE1E1E1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = _categories[index];
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = index),
            child: SizedBox(
              width: 84,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 24, color: AppColors.textHint),
                  const SizedBox(height: 5),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemCount: _categories.length,
      ),
    );
  }

  Widget _buildSearchCityRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickCityWithLocationPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedCity,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '请输入内容',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const Icon(Icons.search, size: 18, color: AppColors.textHint),
              ],
            ),
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
        final text = '${guide.name}${guide.description}${guide.tags.join('')}';
        return text.contains(category.keyword);
      }).toList();
    }
    return list;
  }

  String _statusLabel(int index) {
    const labels = ['最早可约今晚14:00', '正在服务中', '最早可约今晚14:00', '待约中'];
    return labels[index % labels.length];
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.tagBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.search_off_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '暂无匹配服务',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '换个城市或关键词试试',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final IconData icon;
  final String label;
  final String keyword;

  const _CategoryItem(this.icon, this.label, this.keyword);
}
