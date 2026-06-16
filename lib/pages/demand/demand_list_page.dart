import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/demand_request.dart';
import '../../providers/demand_provider.dart';
import '../../widgets/demand_card.dart';

class DemandListPage extends StatefulWidget {
  const DemandListPage({super.key});

  @override
  State<DemandListPage> createState() => _DemandListPageState();
}

class _DemandListPageState extends State<DemandListPage> {
  int _activeChip = 0;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DemandProvider>().loadDemands();
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
      appBar: AppBar(
        title: const Text('需求列表'),
        actions: [
          IconButton(
            onPressed: () => context.push('/demand/create'),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 10),
                    _buildCitySelector(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildChip('推荐', 0),
                    const SizedBox(width: 10),
                    _buildChip('最新', 1),
                    const SizedBox(width: 10),
                    _buildChip('附近', 2),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<DemandProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final demands = _filteredDemands(provider.filteredDemands);
                if (demands.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => provider.loadDemands(
                    query: _searchController.text.trim(),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemBuilder: (context, index) =>
                        DemandCard(demand: demands[index]),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemCount: demands.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/demand/create'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text(
          '发布',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<DemandRequest> _filteredDemands(List<DemandRequest> demands) {
    if (_activeChip == 1) {
      return demands.reversed.toList();
    }
    if (_activeChip == 2) {
      return demands.where((item) => item.city.isNotEmpty).toList();
    }
    return demands;
  }

  Future<void> _pickCity() async {
    final currentCity = context.read<DemandProvider>().selectedCity;
    final seedCity = currentCity == '全国' ? '苏州' : currentCity;

    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {
        'city': seedCity,
        'address': seedCity,
      },
    );
    if (result == null || !mounted) return;

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) return;

    context.read<DemandProvider>().setCity(city);
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  context.read<DemandProvider>().setSearchQuery(value),
              decoration: const InputDecoration(
                hintText: '搜索地点、时间或需求内容',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                context.read<DemandProvider>().setSearchQuery('');
                setState(() {});
              },
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textHint,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    final selectedCity = context.watch<DemandProvider>().selectedCity;
    return GestureDetector(
      onTap: selectedCity == '全国' ? _pickCity : null,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              selectedCity,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            if (selectedCity == '全国')
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppColors.primary,
              )
            else
              GestureDetector(
                onTap: () => context.read<DemandProvider>().setCity('全国'),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int index) {
    final selected = _activeChip == index;
    return GestureDetector(
      onTap: () => setState(() => _activeChip = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: selected ? 0 : 0.2),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tagBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有匹配到需求',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '可以先去发布自己的需求试试',
            style: TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) return '';

    const suffixes = ['特别行政区', '自治州', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }
}
