import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/call_provider.dart';
import '../providers/message_provider.dart';
import '../providers/user_provider.dart';
import 'companion/companion_page.dart';
import 'home/home_page.dart';
import 'messages/messages_page.dart';
import 'order/incoming_voice_call_dialog.dart';
import 'order/voice_call_page.dart';
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

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _incomingCallTimer;
  bool _checkingIncomingCall = false;
  bool _showingIncomingCall = false;

  static const List<Widget> _pages = [
    HomePage(),
    CompanionPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appTabNotifier.addListener(_handleExternalTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncomingCalls();
      _incomingCallTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkIncomingCalls(),
      );
    });
  }

  @override
  void dispose() {
    _incomingCallTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    appTabNotifier.removeListener(_handleExternalTabChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIncomingCalls();
    }
  }

  void _handleExternalTabChange() {
    if (appTabNotifier.value == 2 || _currentIndex == appTabNotifier.value) {
      return;
    }
    setState(() {
      _currentIndex = appTabNotifier.value.clamp(0, 4);
    });
  }

  void _onTap(int index) {
    if (index == 2) {
      _showPublishSheet();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    appTabNotifier.value = index;
  }

  void _showPublishSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '发布内容',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _publishItem(
                    icon: Icons.assignment_outlined,
                    title: '发布需求',
                    subtitle: '填写时间地点，快速发单',
                    route: '/demand/create',
                  ),
                  const SizedBox(height: 10),
                  _publishItem(
                    icon: Icons.verified_user_outlined,
                    title: '申请入驻',
                    subtitle: '成为平台认证向导',
                    route: '/apply/guide',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkIncomingCalls() async {
    if (!mounted || _checkingIncomingCall || _showingIncomingCall) return;
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn) return;

    _checkingIncomingCall = true;
    try {
      final calls = await context
          .read<CallProvider>()
          .fetchIncomingVoiceCalls();
      if (!mounted || calls.isEmpty || _showingIncomingCall) return;
      await _showIncomingCallSheet(calls.first);
    } catch (_) {
      // Keep polling quiet; order pages will show explicit call errors.
    } finally {
      _checkingIncomingCall = false;
    }
  }

  Future<void> _showIncomingCallSheet(Map<String, dynamic> call) async {
    _showingIncomingCall = true;
    final callId = call['id']?.toString() ?? call['call_id']?.toString() ?? '';
    final callProvider = context.read<CallProvider>();
    try {
      if (callId.isEmpty) return;
      final action = await showIncomingVoiceCallDialog(
        context,
        call: call,
        callProvider: callProvider,
        fallbackPeerName: '地陪',
      );
      if (!mounted ||
          action == null ||
          action == IncomingCallAction.cancelled) {
        return;
      }
      if (action == IncomingCallAction.reject) {
        await callProvider.endVoiceCall(callId, reason: 'customer_rejected');
        return;
      }
      final payload = await callProvider.joinVoiceCall(callId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VoiceCallPage(
            callPayload: payload,
            peerName: '地陪',
            incoming: true,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理来电失败：$error')));
      }
    } finally {
      _showingIncomingCall = false;
    }
  }

  Widget _publishItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.push(route);
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = _pageIndexForNav(_currentIndex);

    return Scaffold(
      body: IndexedStack(index: pageIndex, children: _pages),
      bottomNavigationBar: Container(
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
                index: 0,
                label: '广场',
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
              ),
              _navItem(
                index: 1,
                label: '服务',
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
              ),
              _centerButton(),
              Consumer<MessageProvider>(
                builder: (context, provider, _) => _navItem(
                  index: 3,
                  label: '消息',
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  badge: provider.totalUnread,
                ),
              ),
              _navItem(
                index: 4,
                label: '我的',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badge = 0,
  }) {
    final active = _currentIndex == index;

    return InkWell(
      onTap: () => _onTap(index),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 24,
                  color: active
                      ? AppColors.textPrimary
                      : const Color(0xFFD0D5E2),
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6E6B),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.textPrimary : const Color(0xFFD0D5E2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerButton() {
    return GestureDetector(
      onTap: () => _onTap(2),
      child: Container(
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
        child: const Icon(Icons.add, size: 30, color: AppColors.textPrimary),
      ),
    );
  }

  int _pageIndexForNav(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }
}
