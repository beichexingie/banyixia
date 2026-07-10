import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideCityPickerPage extends StatefulWidget {
  const GuideCityPickerPage({super.key});

  @override
  State<GuideCityPickerPage> createState() => _GuideCityPickerPageState();
}

class _GuideCityPickerPageState extends State<GuideCityPickerPage> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _allCities = [
    '阿坝藏族羌族自治州',
    '阿克苏地区',
    '阿拉善盟',
    '阿勒泰地区',
    '安庆',
    '安阳',
    '鞍山',
    '北京',
    '重庆',
    '成都',
    '长沙',
    '大连',
    '东莞',
    '福州',
    '广州',
    '贵阳',
    '杭州',
    '合肥',
    '昆明',
    '南京',
    '宁波',
    '青岛',
    '上海',
    '深圳',
    '苏州',
    '天津',
    '武汉',
    '无锡',
    '西安',
    '厦门',
    '郑州',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final query = _searchController.text.trim();
    final filtered = _allCities.where((item) {
      if (query.isEmpty) return true;
      return item.contains(query);
    }).toList();

    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                    hintText: '城市/区县/商场等地点',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GuidePillButton(
              label: '地图选点',
              icon: Icons.map_outlined,
              onTap: () => Navigator.of(context).maybePop(),
              color: const Color(0xFFF5F5F7),
              foregroundColor: AppColors.textPrimary,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const Text(
            '当前位置',
            style: TextStyle(fontSize: 18, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.location_on_rounded, color: AppColors.primaryDark, size: 26),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${console.currentLocation.city}${console.currentLocation.title}... ${console.currentLocation.detail}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  context.read<GuideConsoleProvider>().cycleMockCurrentLocation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已切换到新的模拟定位点')),
                  );
                },
                icon: const Icon(Icons.gps_fixed, color: AppColors.textPrimary),
                label: const Text(
                  '重新定位',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CityChip(
                label: console.selectedCity,
                active: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('当前接单城市：${console.selectedCity}')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('全国', style: TextStyle(fontSize: 18, color: AppColors.textHint)),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CityChip(label: '全国', active: false),
            ],
          ),
          const SizedBox(height: 24),
          const Text('推荐城市', style: TextStyle(fontSize: 18, color: AppColors.textHint)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: ['苏州', '北京', '上海', '深圳', '杭州', '成都', '重庆', '武汉']
                .map(
                  (city) => _CityChip(
                    label: city,
                    active: city == console.selectedCity,
                    onTap: () async {
                      await console.setSelectedCity(city);
                      if (!mounted) return;
                      Navigator.of(context).maybePop();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text('历史访问', style: TextStyle(fontSize: 18, color: AppColors.textHint)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: console.historyCities
                .map(
                  (city) => _HistoryCityChip(
                    label: city,
                    onTap: () async {
                      await console.setSelectedCity(city);
                      if (!mounted) return;
                      Navigator.of(context).maybePop();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 30),
          const Text(
            'A',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          ...filtered.map(
            (city) => InkWell(
              onTap: () async {
                await console.setSelectedCity(city);
                if (!mounted) return;
                Navigator.of(context).maybePop();
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  city,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _CityChip({
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _HistoryCityChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HistoryCityChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
