import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../providers/guide_provider.dart';
import '../pages/main_scaffold.dart';
import '../pages/auth/login_page.dart';
import '../pages/home/post_detail_page.dart';
import '../pages/home/post_create_page.dart';
import '../pages/apply/apply_guide_page.dart';
import '../pages/admin/admin_audit_page.dart';
import '../pages/companion/guide_detail_page.dart';
import '../pages/profile/settings_page.dart';
import '../pages/travel_plan/travel_plan_create_page.dart';
import '../pages/profile/notification_settings_page.dart';
import '../pages/profile/security_settings_page.dart';
import '../pages/profile/wallet_page.dart';
import '../pages/profile/help_feedback_page.dart';
import '../pages/profile/coupons_page.dart';
import '../pages/profile/balance_page.dart';
import '../pages/profile/orders_page.dart';
import '../pages/order/order_create_page.dart';
import '../models/guide.dart';

class AppRouter {
  final UserProvider userProvider;
  final PostProvider postProvider;
  final GuideProvider guideProvider;

  AppRouter(this.userProvider, this.postProvider, this.guideProvider);

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: userProvider,
    redirect: (context, state) {
      final isLoggedIn = userProvider.isLoggedIn;
      final isGoingToLogin = state.uri.toString() == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/';
      
      return null; // Return null to stay on current route
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/post/create',
        builder: (context, state) => const PostCreatePage(),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          // Find the post from provider synchronously
          final post = postProvider.posts.firstWhere(
            (p) => p.id == id,
            // Fallback object to avoid exceptions if not found
            orElse: () => postProvider.posts.first, 
          );
          return PostDetailPage(post: post);
        },
      ),
      GoRoute(
        path: '/guide/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          final guide = guideProvider.guides.firstWhere(
            (g) => g.id == id,
            orElse: () => guideProvider.guides.first,
          );
          return GuideDetailPage(guide: guide);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => const SecuritySettingsPage(),
      ),
      GoRoute(
        path: '/settings/help',
        builder: (context, state) => const HelpFeedbackPage(),
      ),
      GoRoute(
        path: '/profile/coupons',
        builder: (context, state) => const CouponsPage(),
      ),
      GoRoute(
        path: '/profile/balance',
        builder: (context, state) => const BalancePage(),
      ),
      GoRoute(
        path: '/profile/orders',
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: '/travel_plan/create',
        builder: (context, state) => const TravelPlanCreatePage(),
      ),
      GoRoute(
        path: '/order_create',
        builder: (context, state) {
          final guide = state.extra as Guide?;
          if (guide == null) {
            return const Scaffold(body: Center(child: Text('Error: Guide data missing')));
          }
          return OrderCreatePage(guide: guide);
        },
      ),
      GoRoute(
        path: '/apply/guide',
        builder: (context, state) => const ApplyGuidePage(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (context, state) => const AdminAuditPage(),
      ),
    ],
  );
}
