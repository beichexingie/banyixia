import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'home/home_page.dart';
import 'companion/companion_page.dart';
import 'messages/messages_page.dart';
import 'profile/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  /// 全局 key，用于从其他页面切换 Tab
  static final GlobalKey<State<MainScaffold>> mainKey = GlobalKey<State<MainScaffold>>();

  /// 从外部切换到指定 Tab
  static void switchTo(int index) {
    final state = mainKey.currentState;
    if (state is _MainScaffoldState) {
      state.switchToTab(index);
    }
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    if (index == 2) return; // + 号不是真正的 tab
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _pages = const [
    HomePage(),
    CompanionPage(),
    SizedBox(),
    MessagesPage(),
    ProfilePage(),
  ];

  void _onTabTapped(int index) {
    if (index == 2) {
      _showPublishSheet();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showPublishSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('发布内容', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              _buildPublishOption(Icons.article_outlined, '分享游玩瞬间', '发布旅行笔记和攻略', route: '/post/create'),
              const Divider(),
              _buildPublishOption(Icons.map_outlined, '创建旅行计划', '规划你的行程路线', route: '/travel_plan/create'),
              const Divider(),
              _buildPublishOption(Icons.person_add_outlined, '申请成为地陪', '入驻成为本地向导', route: '/apply/guide'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublishOption(IconData icon, String title, String subtitle, {String? route}) {
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        Navigator.pop(context); // close the bottom sheet
        if (route != null) {
          context.push(route);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「$title」功能即将上线'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: MainScaffold.mainKey,
      body: IndexedStack(
        index: _currentIndex > 2 ? _currentIndex - 1 : _currentIndex,
        children: [
          _pages[0],
          _pages[1],
          _pages[3],
          _pages[4],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, '首页'),
                _buildNavItem(1, Icons.people_outline, Icons.people, '搭子'),
                _buildCenterButton(),
                Consumer<MessageProvider>(
                  builder: (context, msgProvider, _) {
                    return _buildNavItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, '消息', badge: msgProvider.totalUnread);
                  },
                ),
                _buildNavItem(4, Icons.person_outline, Icons.person, '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {int badge = 0}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  size: 24,
                ),
                if (badge > 0)
                  Positioned(
                    top: -2, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      alignment: Alignment.center,
                      child: Text(badge > 99 ? '..' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
