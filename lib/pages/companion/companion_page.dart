import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/guide_provider.dart';
import '../../providers/application_provider.dart';
import '../../models/guide_application.dart';
import '../../widgets/guide_card.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  int _activeTabIndex = 0; // 0 for Guide list, 1 for Contact Us
  GuideApplication? _myApp;
  bool _isCheckingStatus = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuideProvider>().loadGuides();
      _loadApplicationStatus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplicationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final app = await context.read<ApplicationProvider>().getMyApplication();
      setState(() => _myApp = app);
    } catch (e) {
      debugPrint('Error loading app status: $e');
    } finally {
      setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_activeTabIndex == 0) ...[
              _buildFilterBar(context),
              Expanded(child: _buildGuideList()),
            ] else ...[
              Expanded(child: _buildContactInfo()),
            ],
            _buildPublishBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // 搜索栏
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.tagBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<GuideProvider>().setSearchQuery(value);
                    },
                    decoration: const InputDecoration(
                      hintText: '搜索地陪姓名/城市/介绍',
                      hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      context.read<GuideProvider>().setSearchQuery('');
                    },
                    child: const Icon(Icons.clear, size: 18, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 三个矩形按钮
          Row(
            children: [
              _buildTopBlock(
                _isCheckingStatus 
                    ? '检查中...' 
                    : (_myApp == null 
                        ? '浅伴入驻' 
                        : (_myApp!.status == 'pending' 
                            ? '审核中' 
                            : (_myApp!.status == 'approved' ? '已入驻' : '重新入驻'))), 
                () {
                  if (_myApp == null || _myApp!.status == 'rejected') {
                    context.push('/apply/guide');
                  } else if (_myApp!.status == 'pending') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请正在审核中，请耐心等待')));
                  } else if (_myApp!.status == 'approved') {
                    context.push('/guide/${_myApp!.userId}');
                  }
                },
                isActive: _myApp?.status == 'approved',
              ),
              const SizedBox(width: 8),
              _buildTopBlock('联系我们', () => setState(() => _activeTabIndex = 1), isActive: _activeTabIndex == 1),
              const SizedBox(width: 8),
              _buildTopBlock('伴一下', () => setState(() => _activeTabIndex = 0), isActive: _activeTabIndex == 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBlock(String title, VoidCallback onTap, {bool isActive = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFFF9A3E),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.topLeft,
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Consumer<GuideProvider>(
      builder: (context, guideProvider, child) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showCityPicker(context, guideProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.tagBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(guideProvider.selectedCity, style: AppTextStyles.tag),
                      const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showFilterModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('筛选', style: AppTextStyles.subtitle),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCityPicker(BuildContext context, GuideProvider provider) {
    final cities = ['全国', '北京', '苏州', '杭州', '成都', '西安', '长沙'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择城市', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cities.map((city) {
                  final isSelected = city == provider.selectedCity;
                  return GestureDetector(
                    onTap: () {
                      provider.setCity(city);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.tagBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showFilterModal(BuildContext context) {
    final provider = context.read<GuideProvider>();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('筛选条件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          provider.clearFilters();
                          setModalState(() {});
                        },
                        child: const Text('重置', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('性别要求', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFilterChip('不限', provider.filterGender == null, () {
                        setModalState(() => provider.setGenderFilter(null));
                      }),
                      const SizedBox(width: 10),
                      _buildFilterChip('只看女生', provider.filterGender == '女', () {
                        setModalState(() => provider.setGenderFilter('女'));
                      }),
                      const SizedBox(width: 10),
                      _buildFilterChip('只看男生', provider.filterGender == '男', () {
                        setModalState(() => provider.setGenderFilter('男'));
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('特色标签', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildFilterChip('今天来过', provider.filterTag == '今天来过', () {
                        setModalState(() => provider.setTagFilter(provider.filterTag == '今天来过' ? null : '今天来过'));
                      }),
                      _buildFilterChip('本地通', provider.filterTag == '本地通', () {
                        setModalState(() => provider.setTagFilter(provider.filterTag == '本地通' ? null : '本地通'));
                      }),
                      _buildFilterChip('摄影达人', provider.filterTag == '摄影达人', () {
                        setModalState(() => provider.setTagFilter(provider.filterTag == '摄影达人' ? null : '摄影达人'));
                      }),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('显示结果'),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.tagBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 从 GuideProvider 获取数据
  Widget _buildGuideList() {
    return Consumer<GuideProvider>(
      builder: (context, guideProvider, child) {
        if (guideProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final guides = guideProvider.filteredGuides;
        if (guides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('该城市暂无地陪', style: AppTextStyles.subtitle),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => guideProvider.loadGuides(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: guides.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return GuideCard(guide: guides[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildPublishBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/post/create'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('发布你的浅伴通告', style: AppTextStyles.caption),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/post/create'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('发布', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('联系方式', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              '如果您有任何问题或合作意向，可以通过以下方式联系我们的客服团队。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildContactItem(Icons.wechat, '官方微信', 'BanYixia_Official'),
            const SizedBox(height: 16),
            _buildContactItem(Icons.email, '合作邮箱', 'partner@banyixia.com'),
            const SizedBox(height: 16),
            _buildContactItem(Icons.phone, '客服热线', '400-888-8888'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
