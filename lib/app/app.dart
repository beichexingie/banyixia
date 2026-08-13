import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../providers/application_provider.dart';
import '../providers/call_provider.dart';
import '../providers/demand_provider.dart';
import '../providers/guide_provider.dart';
import '../providers/message_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../pages/main_scaffold.dart';
import '../services/payment_service.dart';
import '../services/push_notification_service.dart';
import '../bootstrap/app_bootstrap.dart';

class BanyixiaApp extends StatelessWidget {
  final PaymentService? paymentService;

  const BanyixiaApp({super.key, this.paymentService});

  @override
  Widget build(BuildContext context) {
    final sessionService = AppBootstrap.sessionService;
    final resolvedPaymentService =
        paymentService ?? const AlipayPaymentService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(sessionService: sessionService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              GuideProvider(sessionService: sessionService)..loadGuides(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              DemandProvider(sessionService: sessionService)..loadDemands(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(
            paymentService: resolvedPaymentService,
            sessionService: sessionService,
          )..loadOrders(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MessageProvider(sessionService: sessionService)..loadRooms(),
        ),
        ChangeNotifierProvider(
          create: (_) => ApplicationProvider(sessionService: sessionService),
        ),
        ChangeNotifierProvider(
          create: (_) => CallProvider(sessionService: sessionService),
        ),
      ],
      child: const _AppRouterHost(),
    );
  }
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      context.read<UserProvider>(),
      context.read<GuideProvider>(),
    );
    AppBootstrap.pushNotificationService?.attachRouteHandler(
      _handlePushRoute,
    );
  }

  void _handlePushRoute(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null) return;

    if (uri.path == '/messages') {
      MainScaffold.switchTo(3);
      _appRouter.router.go('/');
      return;
    }

    _appRouter.router.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: _appRouter.router,
    );
  }
}
