import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/app_router.dart';
import '../config/app_theme.dart';
import '../providers/application_provider.dart';
import '../providers/demand_provider.dart';
import '../providers/guide_provider.dart';
import '../providers/message_provider.dart';
import '../providers/order_provider.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../services/payment_service.dart';
import '../services/phone_auth_service.dart';

class BanyixiaApp extends StatelessWidget {
  final PhoneAuthService? phoneAuthService;
  final PaymentService? paymentService;

  const BanyixiaApp({
    super.key,
    this.phoneAuthService,
    this.paymentService,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPhoneAuthService =
        phoneAuthService ?? SupabasePhoneAuthService();
    final resolvedPaymentService =
        paymentService ?? const AlipayPaymentService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            phoneAuthService: resolvedPhoneAuthService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => PostProvider()..loadPosts()),
        ChangeNotifierProvider(create: (_) => GuideProvider()..loadGuides()),
        ChangeNotifierProvider(create: (_) => DemandProvider()..loadDemands()),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(
            paymentService: resolvedPaymentService,
          )..loadOrders(),
        ),
        ChangeNotifierProvider(create: (_) => MessageProvider()..loadRooms()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter(
            context.read<UserProvider>(),
            context.read<PostProvider>(),
            context.read<GuideProvider>(),
          ).router;

          return MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
