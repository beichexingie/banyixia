import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/demand_request.dart';
import '../main_scaffold.dart';
import '../../providers/demand_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/demand_card.dart';

class DemandListPage extends StatefulWidget {
  const DemandListPage({super.key});

  @override
  State<DemandListPage> createState() => _DemandListPageState();
}

class _DemandListPageState extends State<DemandListPage> {
  int _activeChip = 0;

  Future<void> _openCustomerService() async {
    try {
      final roomId = await context.read<MessageProvider>().openCustomerService();
      if (!mounted) return;
      context.push(
        '/chat/$roomId?name=${Uri.encodeComponent('在线客服')}&avatar=',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开客服失败：$error')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DemandProvider>().loadDemands();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton(
          onPressed: () => context.push('/demand/create'),
          backgroundColor: const Color(0xFF181818),
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: Consumer<DemandProvider>(
        builder: (context, provider, _) {
          final demands = _filteredDemands(provider.filteredDemands);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadDemands(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                if (provider.isLoading && demands.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (demands.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 126),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == demands.length - 1 ? 0 : 14,
                          ),
                          child: DemandCard(
                            demand: demands[index],
                            compact: false,
                          ),
                        );
                      }, childCount: demands.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9FFA0), Color(0xFFF2FFD0), Color(0xFFF7F7F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.72, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '需求列表',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTopCard(
                        title: '需求定制',
                        subtitle: '根据你的需求定制~',
                        image: 'assets/home/feature_settle/Frame 5.png',
                        big: true,
                        onTap: () => context.push('/demand/create'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildTopCard(
                            title: '入驻',
                            subtitle: '',
                            image: 'assets/home/feature_map/Frame 6.png',
                            big: false,
                            onTap: () => context.push('/apply/guide'),
                          ),
                          const SizedBox(height: 10),
                          _buildTopCard(
                            title: '联系我们',
                            subtitle: '',
                            image: 'assets/home/feature_contact/Frame 5.png',
                            big: false,
                            onTap: _openCustomerService,
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
      ),
    );
  }

  Widget _buildTopCard({
    required String title,
    required String subtitle,
    required String image,
    required bool big,
    required VoidCallback onTap,
  }) {
    final height = big ? 142.0 : 72.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        padding: EdgeInsets.fromLTRB(big ? 16 : 14, big ? 14 : 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: big ? 120 : 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: big ? 20 : 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    width: 52,
                    height: 24,
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
            Positioned(
              right: big ? 8 : 0,
              bottom: big ? 0 : -4,
              child: Image.asset(
                image,
                width: big ? 112 : 62,
                height: big ? 112 : 62,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 74,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              label: '广场',
              icon: Icons.public_outlined,
              onTap: () {
                MainScaffold.switchTo(0);
                context.go('/');
              },
            ),
            _navItem(
              label: '服务',
              icon: Icons.favorite_border,
              onTap: () {
                MainScaffold.switchTo(1);
                context.go('/');
              },
            ),
            GestureDetector(
              onTap: () => context.push('/demand/create'),
              child: SizedBox(
                width: 66,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/login/Group.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _navItem(
              label: '消息',
              icon: Icons.chat_bubble_outline,
              onTap: () {
                MainScaffold.switchTo(3);
                context.go('/');
              },
            ),
            _navItem(
              label: '我的',
              icon: Icons.person_outline,
              onTap: () {
                MainScaffold.switchTo(4);
                context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFFD0D5E2)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFD0D5E2),
              ),
            ),
          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.explore_outlined,
                size: 40,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无需求内容',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '可以先发布自己的需求，等合适的人来接单。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
