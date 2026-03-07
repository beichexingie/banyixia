import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_router.dart';
import 'providers/user_provider.dart';
import 'providers/post_provider.dart';
import 'providers/guide_provider.dart';
import 'providers/order_provider.dart';
import 'providers/message_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()..loadPosts()),
        ChangeNotifierProvider(create: (_) => GuideProvider()..loadGuides()),
        ChangeNotifierProvider(create: (_) => OrderProvider()..loadOrders()),
        ChangeNotifierProvider(create: (_) => MessageProvider()..loadMessages()),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter(
            context.read<UserProvider>(),
            context.read<PostProvider>(),
            context.read<GuideProvider>(),
          ).router;

          return MaterialApp.router(
            title: '伴一下',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
