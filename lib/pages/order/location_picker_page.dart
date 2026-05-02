import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';

class LocationPickerPage extends StatefulWidget {
  final String? initialAddress;
  final String? initialCity;
  final String title;

  const LocationPickerPage({
    super.key,
    this.initialAddress,
    this.initialCity,
    this.title = '服务地点',
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late String _selectedAddress;
  late String _selectedCity;
  final Map<String, GlobalKey> _sectionKeys = {};

  final List<_LocationEntry> _entries = const [
    _LocationEntry('A', '安吉余村', '浙江湖州'),
    _LocationEntry('A', '澳门大三巴', '澳门'),
    _LocationEntry('B', '北京三里屯', '北京'),
    _LocationEntry('B', '北海银滩', '广西北海'),
    _LocationEntry('C', '成都春熙路', '四川成都'),
    _LocationEntry('C', '重庆洪崖洞', '重庆'),
    _LocationEntry('D', '东极岛', '浙江舟山'),
    _LocationEntry('D', '大理古城', '云南大理'),
    _LocationEntry('E', '恩施大峡谷', '湖北恩施'),
    _LocationEntry('F', '福建土楼', '福建龙岩'),
    _LocationEntry('F', '凤凰古城', '湖南湘西'),
    _LocationEntry('G', '广州塔', '广东广州'),
    _LocationEntry('G', '桂林阳朔', '广西桂林'),
    _LocationEntry('H', '杭州西湖', '浙江杭州'),
    _LocationEntry('H', '黄山风景区', '安徽黄山'),
    _LocationEntry('J', '金鸡湖', '江苏苏州'),
    _LocationEntry('J', '九寨沟', '四川阿坝'),
    _LocationEntry('K', '昆明滇池', '云南昆明'),
    _LocationEntry('L', '丽江古城', '云南丽江'),
    _LocationEntry('L', '拉萨布达拉宫', '西藏拉萨'),
    _LocationEntry('M', '梅里雪山', '云南迪庆'),
    _LocationEntry('N', '南京夫子庙', '江苏南京'),
    _LocationEntry('N', '宁波老外滩', '浙江宁波'),
    _LocationEntry('Q', '青岛栈桥', '山东青岛'),
    _LocationEntry('S', '苏州拙政园', '江苏苏州'),
    _LocationEntry('S', '上海外滩', '上海'),
    _LocationEntry('T', '天津五大道', '天津'),
    _LocationEntry('W', '武汉东湖', '湖北武汉'),
    _LocationEntry('X', '西安大雁塔', '陕西西安'),
    _LocationEntry('X', '厦门鼓浪屿', '福建厦门'),
    _LocationEntry('Y', '云南洱海', '云南大理'),
    _LocationEntry('Z', '珠海情侣路', '广东珠海'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _selectedAddress = widget.initialAddress ?? _entries.first.name;
    _selectedCity = widget.initialCity ?? '苏州';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_LocationEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries.where((entry) {
      return entry.name.toLowerCase().contains(query) ||
          entry.city.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final grouped = <String, List<_LocationEntry>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.letter, () => []).add(item);
    }
    final letters = grouped.keys.toList()..sort();
    for (final letter in letters) {
      _sectionKeys.putIfAbsent(letter, () => GlobalKey());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showApiPlaceholder('地图选点 API 待接入'),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('地图选点'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Row(
                children: [
                  const Text(
                    '当前位置',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showApiPlaceholder('重新定位 API 待接入'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '重新定位',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: '江苏省苏州市姑苏区...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          TextSpan(
                            text: '（自动定位在城市中的具体位置）',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: _buildQuickChips(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Row(
                children: [
                  const Text(
                    'A-Z',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '地点列表',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showApiPlaceholder('地图/定位 API 待接入'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '地图定位',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  _searchController.text.trim().isNotEmpty
                      ? _buildSearchResults(filtered)
                      : _buildGroupedList(grouped, letters),
                  Positioned(
                    right: 8,
                    top: 8,
                    bottom: 8,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.tagBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '顶部',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        for (final letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: GestureDetector(
                              onTap: () => _jumpToLetter(letter, grouped),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: grouped.containsKey(letter)
                                          ? AppColors.textSecondary
                                          : AppColors.textHint,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.pop(_selectedAddress),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('选择此地点'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(21),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: '城市/区县/商务等地点',
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final recommendedCities = ['苏州', '北京', '上海', '深圳', '广州', '成都', '武汉', '杭州', '西安', '重庆'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              '苏州',
              selected: true,
              onTap: () => setState(() {
                _selectedCity = '苏州';
                _selectedAddress = '苏州';
              }),
            ),
            _chip(
              '全国',
              onTap: () => setState(() {
                _selectedCity = '全国';
                _selectedAddress = '全国';
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '推荐城市',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: recommendedCities.map((city) {
            return _chip(
              city,
              onTap: () => setState(() {
                _selectedCity = city;
                _selectedAddress = city;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          '历史访问',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              _selectedCity,
              selected: true,
              onTap: () => setState(() {
                _selectedAddress = _selectedCity;
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(
    String text, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFD7D7D7) : const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }

  Widget _buildSearchResults(List<_LocationEntry> items) {
    if (items.isEmpty) {
      return const Center(child: Text('没有找到匹配地点'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.name == _selectedAddress;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined, color: AppColors.textHint),
          title: Text(item.name),
          subtitle: Text(item.city),
          selected: selected,
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : null,
          onTap: () => setState(() => _selectedAddress = item.name),
        );
      },
    );
  }

  Widget _buildGroupedList(
    Map<String, List<_LocationEntry>> grouped,
    List<String> letters,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 28, 16),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final items = grouped[letter] ?? const [];
        return Padding(
          key: _sectionKeys[letter],
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tagBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _buildLocationTile(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationTile(_LocationEntry item) {
    final selected = item.name == _selectedAddress;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined, color: AppColors.textHint),
      title: Text(item.name),
      subtitle: Text(item.city),
      selected: selected,
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () => setState(() => _selectedAddress = item.name),
    );
  }

  void _jumpToLetter(String letter, Map<String, List<_LocationEntry>> grouped) {
    if (!grouped.containsKey(letter)) {
      _showApiPlaceholder('$letter 类地点暂未接入');
      return;
    }
    final key = _sectionKeys[letter];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    }
  }

  void _showApiPlaceholder(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMapArea() {
    return Container(
      height: 290,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF1FF), Color(0xFFF7FAFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          Positioned(
            left: 18,
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_selectedCity | 搜索服务地点',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showApiPlaceholder('定位 API 待接入'),
                    child: const Text(
                      '定位',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.location_pin, size: 54, color: Color(0xFF3D6CF5)),
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: Column(
              children: [
                _mapAction(
                  Icons.map_outlined,
                  '地图',
                  () => _showApiPlaceholder('地图 API 待接入'),
                ),
                const SizedBox(height: 10),
                _mapAction(
                  Icons.my_location,
                  '定位',
                  () => _showApiPlaceholder('定位 API 待接入'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationEntry {
  final String letter;
  final String name;
  final String city;

  const _LocationEntry(this.letter, this.name, this.city);
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
