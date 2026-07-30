import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bootstrap/app_bootstrap.dart';
import '../config/app_theme.dart';
import '../pages/auth/login_page.dart';
import '../providers/demand_provider.dart';
import '../providers/message_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import 'models/guide_app_models.dart';
import 'pages/guide_city_picker_page.dart';
import 'pages/guide_duty_mode_page.dart';
import 'pages/guide_duty_settings_page.dart';
import 'pages/guide_demand_hall_page.dart';
import 'pages/guide_messages_page.dart';
import 'pages/guide_order_center_page.dart';
import 'pages/guide_placeholder_pages.dart';
import 'pages/guide_profile_page.dart';
import 'pages/guide_route_page.dart';
import 'pages/guide_select_service_page.dart';
import 'pages/guide_service_location_page.dart';
import 'pages/guide_service_type_page.dart';
import 'pages/guide_workbench_page.dart';
import 'providers/guide_console_provider.dart';

class GuideApp extends StatelessWidget {
  const GuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionService = AppBootstrap.sessionService;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(sessionService: sessionService),
        ),
        ChangeNotifierProvider(
          create: (_) => DemandProvider(sessionService: sessionService)..loadDemands(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(sessionService: sessionService)..loadOrders(),
        ),
        ChangeNotifierProvider(
          create: (_) => MessageProvider(sessionService: sessionService)..loadRooms(),
        ),
        ChangeNotifierProvider(
          create: (_) => GuideConsoleProvider(),
        ),
      ],
      child: const _GuideAppBootstrapper(),
    );
  }
}

class _GuideAppBootstrapper extends StatefulWidget {
  const _GuideAppBootstrapper();

  @override
  State<_GuideAppBootstrapper> createState() => _GuideAppBootstrapperState();
}

class _GuideAppBootstrapperState extends State<_GuideAppBootstrapper> {
  bool _prepared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      final orderProvider = context.read<OrderProvider>();
      await context.read<GuideConsoleProvider>().syncFromProviders(
            userProvider: userProvider,
            orderProvider: orderProvider,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '伴一下地陪端',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _GuideAppGate(),
    );
  }
}

class _GuideAppGate extends StatelessWidget {
  const _GuideAppGate();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    if (!userProvider.isLoggedIn) {
      return const LoginPage();
    }
    if (!userProvider.user.isGuideApproved) {
      return GuideAccessGatePage(
        status: userProvider.user.guideApplicationStatus,
      );
    }

    return const _GuideMainShell();
  }
}

class GuideAccessGatePage extends StatelessWidget {
  final String? status;

  const GuideAccessGatePage({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final title = isPending
        ? '地陪认证审核中'
        : isRejected
            ? '地陪认证未通过'
            : '请先完成地陪认证';
    final message = isPending
        ? '你的地陪入驻资料已经提交，平台审核通过后才能进入地陪端接单。'
        : isRejected
            ? '你的地陪入驻资料暂未通过，请回到客户端补充或重新提交认证资料。'
            : '当前账号还不是认证地陪。请先在客户端提交地陪入驻申请，通过后再使用地陪端。';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRejected
                        ? Icons.error_outline_rounded
                        : isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.verified_user_outlined,
                    size: 68,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.read<UserProvider>().logout(),
                      child: const Text('退出当前账号'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideMainShell extends StatefulWidget {
  const _GuideMainShell();

  @override
  State<_GuideMainShell> createState() => _GuideMainShellState();
}

class _GuideMainShellState extends State<_GuideMainShell> {
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<GuideConsoleProvider>().syncFromProviders(
            userProvider: context.read<UserProvider>(),
            orderProvider: context.read<OrderProvider>(),
          );
      await context.read<MessageProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GuideOrderCenterPage(
        onOpenSettings: _openDutySettings,
        onOpenServiceOps: _openServiceOperations,
        onOpenRoute: _openRoute,
        onOpenChat: _openMessages,
      ),
      GuideWorkbenchPage(
        onOpenDutySettings: _openDutySettings,
        onOpenServiceOps: _openServiceOperations,
        onOpenPublish: _openPublish,
        onOpenDemandHall: _openDemandHall,
        onOpenEmergencyContacts: _openEmergencyContacts,
        onOpenServiceItems: _openSelectServicePage,
        onOpenAddressManager: _openServiceLocationPage,
        onOpenReviewCenter: _openReviewCenter,
        onOpenScheduleCenter: _openScheduleCenter,
        onOpenPromotionCenter: _openPromotionCenter,
        onOpenTaskCenter: _openTaskCenter,
        onOpenTrainingCenter: _openTrainingCenter,
      ),
      const SizedBox.shrink(),
      const GuideMessagesPage(),
      GuideProfilePage(
        onOpenDutySettings: _openDutySettings,
        onOpenAddressManager: _openServiceLocationPage,
        onOpenCityPicker: _openCityPage,
        onOpenCertification: _openCertificationPage,
        onOpenPlatformRules: _openPlatformRulesPage,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: InkWell(
        onTap: _openPublish,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 84,
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.add_rounded, size: 40, color: AppColors.textPrimary),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt_rounded,
                label: '订单中心',
                active: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: '工作台',
                active: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 86),
              _NavItem(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum_rounded,
                label: '消息',
                active: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: '我的',
                active: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMessages() {
    setState(() => _currentIndex = 3);
  }

  Future<void> _openPublish() async {
    await _openDemandHall();
  }

  Future<void> _openRoute([GuideOrderCardData? order]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuideRoutePage(order: order)),
    );
  }

  Future<void> _openDutySettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuideDutySettingsPage(
          onOpenMode: _openModePage,
          onOpenCity: _openCityPage,
          onOpenServiceTypes: _openServiceTypePage,
        ),
      ),
    );
  }

  Future<void> _openModePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideDutyModePage()),
    );
  }

  Future<void> _openCityPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideCityPickerPage()),
    );
  }

  Future<void> _openServiceTypePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideServiceTypePage()),
    );
  }

  Future<void> _openServiceLocationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideServiceLocationPage()),
    );
  }

  Future<void> _openSelectServicePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideSelectServicePage()),
    );
  }

  Future<void> _openDemandHall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuideDemandHallPage()),
    );
  }

  Future<void> _openServiceOperations() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '专属运营',
          message: '这里后续可以接运营工单、培训通知、活动权益和客服会话。',
          icon: Icons.support_agent_rounded,
        ),
      ),
    );
  }

  Future<void> _openEmergencyContacts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuidePlaceholderPage(
          title: '紧急联系人',
          message: '这里预留给地陪端配置紧急联系人、保险信息和应急流程。',
          icon: Icons.emergency_outlined,
        ),
      ),
    );
  }

  Future<void> _openReviewCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '客户评价',
          message: '这里后续可以接真实评价列表、评分申诉和服务口碑分析。',
          icon: Icons.reviews_outlined,
        ),
      ),
    );
  }

  Future<void> _openScheduleCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '时间管理',
          message: '这里后续可以接日历排班、请假、接单时段和黑名单时间段配置。',
          icon: Icons.calendar_month_outlined,
        ),
      ),
    );
  }

  Future<void> _openPromotionCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '拉新赚钱',
          message: '这里后续可以接邀请收益、分佣记录、邀请码和推广素材。',
          icon: Icons.campaign_outlined,
        ),
      ),
    );
  }

  Future<void> _openTaskCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '任务中心',
          message: '这里后续可以接签到任务、成长任务、奖励进度和任务明细。',
          icon: Icons.task_alt_rounded,
        ),
      ),
    );
  }

  Future<void> _openTrainingCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '培训中心',
          message: '这里后续可以接培训课程、考试记录、上岗指南和常见问题。',
          icon: Icons.school_outlined,
        ),
      ),
    );
  }

  Future<void> _openCertificationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '认证资料',
          message: '这里后续可以接实名认证、从业资料、审核进度和补件入口。',
          icon: Icons.badge_outlined,
        ),
      ),
    );
  }

  Future<void> _openPlatformRulesPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidePlaceholderPage(
          title: '平台规则',
          message: '这里后续可以接接单规则、服务规范、违规说明和申诉指引。',
          icon: Icons.policy_outlined,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 28,
                color: active ? AppColors.textPrimary : const Color(0xFFC8CBD3),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? AppColors.textPrimary : const Color(0xFFC8CBD3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
