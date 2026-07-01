import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/message_provider.dart';
import 'companion/companion_page.dart';
import 'home/home_page.dart';
import 'messages/messages_page.dart';
import 'profile/profile_page.dart';

final ValueNotifier<int> appTabNotifier = ValueNotifier<int>(0);

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  static void switchTo(int index) {
    appTabNotifier.value = index;
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    CompanionPage(),
    SizedBox(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    appTabNotifier.addListener(_onTabNotifierChanged);
  }

  @override
  void dispose() {
    appTabNotifier.removeListener(_onTabNotifierChanged);
    super.dispose();
  }

  void _onTabNotifierChanged() {
    if (appTabNotifier.value == 2) return;
    if (_currentIndex != appTabNotifier.value) {
      setState(() {
        _currentIndex = appTabNotifier.value;
      });
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      _showPublishSheet();
      return;
    }
    appTabNotifier.value = index;
  }

  void _showPublishSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 40),
                    const Expanded(
                      child: Text(
                        '发布内容',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildPublishOption(
                  icon: Icons.image_outlined,
                  title: '发布动态',
                  subtitle: '记录图片、活动和旅行灵感',
                  route: '/post/create',
                ),
                const Divider(height: 18),
                _buildPublishOption(
                  icon: Icons.campaign_outlined,
                  title: '发布招募/自荐',
                  subtitle: '发起招募帖或展示自己的地陪服务',
                  route: '/post/create?mode=recruit',
                ),
                const Divider(height: 18),
                _buildPublishOption(
                  icon: Icons.edit_note_outlined,
                  title: '发布需求',
                  subtitle: '快速发起地陪体验和定制需求',
                  route: '/demand/create',
                ),
                const Divider(height: 18),
                _buildPublishOption(
                  icon: Icons.storefront_outlined,
                  title: '申请成为地陪',
                  subtitle: '入驻成为本地服务提供者',
                  route: '/apply/guide',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPublishOption({
    required IconData icon,
    required String title,
    required String subtitle,
    String? route,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: () {
        Navigator.pop(context);
        if (route != null) {
          context.push(route);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex > 2 ? _currentIndex - 1 : _currentIndex,
        children: [_pages[0], _pages[1], _pages[3], _pages[4]],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          height: 86,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.public_outlined, Icons.public, '广场'),
              _buildNavItem(1, Icons.favorite_border, Icons.favorite, '服务'),
              _buildCenterButton(),
              Consumer<MessageProvider>(
                builder: (context, msgProvider, _) {
                  return _buildNavItem(
                    3,
                    Icons.chat_bubble_outline,
                    Icons.chat_bubble,
                    '消息',
                    badge: msgProvider.totalUnread,
                  );
                },
              ),
              _buildNavItem(4, Icons.person_outline, Icons.person, '我的'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    int badge = 0,
  }) {
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
                  color: isActive ? AppColors.textPrimary : AppColors.textHint,
                  size: 28,
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '..' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppColors.textPrimary : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          size: 34,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
