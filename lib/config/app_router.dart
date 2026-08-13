import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../providers/guide_provider.dart';
import '../pages/main_scaffold.dart';
import '../pages/auth/login_page.dart';
import '../pages/apply/apply_guide_page.dart';
import '../pages/messages/chat_room_page.dart';
import '../pages/profile/settings_page.dart';
import '../pages/travel_plan/travel_plan_create_page.dart';
import '../pages/profile/notification_settings_page.dart';
import '../pages/profile/security_settings_page.dart';
import '../pages/profile/password_change_page.dart';
import '../pages/profile/wallet_page.dart';
import '../pages/profile/help_feedback_page.dart';
import '../pages/profile/coupons_page.dart';
import '../pages/profile/balance_page.dart';
import '../pages/profile/orders_page.dart';
import '../pages/profile/following_page.dart';
import '../pages/order/order_create_page.dart';
import '../pages/order/location_picker_page.dart';
import '../pages/admin/audit_list_page.dart';
import '../pages/profile/user_profile_page.dart';
import '../pages/demand/demand_list_page.dart';
import '../pages/demand/demand_create_page.dart';
import '../pages/demand/demand_detail_page.dart';
import '../pages/demand/my_demand_list_page.dart';
import '../pages/common/state_notice_page.dart';
import '../models/guide.dart';
import '../pages/profile/order_detail_page.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/profile/order_review_page.dart';
import '../services/push_notification_service.dart';

class AppRouter {
  final UserProvider userProvider;
  final GuideProvider guideProvider;

  AppRouter(this.userProvider, this.guideProvider);

  late final GoRouter router = GoRouter(
    navigatorKey: pushNavigatorKey,
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
      GoRoute(path: '/', builder: (context, state) => const MainScaffold()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/guide/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserProfilePage(userId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const EditProfilePage(),
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
        path: '/settings/password',
        builder: (context, state) => const PasswordChangePage(),
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
        builder: (context, state) {
          final initialTab =
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return OrdersPage(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: '/following',
        builder: (context, state) => const FollowingPage(),
      ),
      GoRoute(
        path: '/profile/orders/:id',
        builder: (context, state) {
          return OrderDetailPage(orderId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/profile/orders/:id/review',
        builder: (context, state) =>
            OrderReviewPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/travel_plan/create',
        builder: (context, state) => const TravelPlanCreatePage(),
      ),
      GoRoute(
        path: '/order/create',
        builder: (context, state) {
          final guideId = state.uri.queryParameters['guideId'];
          Guide? guide = state.extra is Guide ? state.extra as Guide : null;
          if (guideId != null && guideId.trim().isNotEmpty) {
            try {
              guide ??= guideProvider.guides.firstWhere((g) => g.id == guideId);
            } catch (_) {
              // 保留 extra 里带来的地陪信息
            }
          }
          if (guide == null || !guide.verified) {
            return const StateNoticePage(
              title: '地陪不可下单',
              message: '当前地陪不存在、未通过审核，或页面信息已经过期，请返回服务页重新选择。',
              icon: Icons.person_off_outlined,
            );
          }
          return OrderCreatePage(guide: guide);
        },
      ),
      GoRoute(
        path: '/order/location',
        builder: (context, state) {
          final extra = state.extra;
          String? address;
          String? city;
          if (extra is Map) {
            address = extra['address']?.toString();
            city = extra['city']?.toString();
          } else if (extra is String) {
            address = extra;
          }
          return LocationPickerPage(initialAddress: address, initialCity: city);
        },
      ),
      GoRoute(
        path: '/demand/location',
        builder: (context, state) {
          final extra = state.extra;
          String? address;
          String? city;
          if (extra is Map) {
            address = extra['address']?.toString();
            city = extra['city']?.toString();
          } else if (extra is String) {
            address = extra;
          }
          return LocationPickerPage(
            title: '服务地点',
            initialAddress: address,
            initialCity: city,
          );
        },
      ),
      GoRoute(
        path: '/demands',
        builder: (context, state) => const DemandListPage(),
      ),
      GoRoute(
        path: '/demands/me',
        builder: (context, state) => const MyDemandListPage(),
      ),
      GoRoute(
        path: '/demand/create',
        builder: (context, state) => const DemandCreatePage(),
      ),
      GoRoute(
        path: '/demand/:id',
        builder: (context, state) =>
            DemandDetailPage(demandId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/apply/guide',
        builder: (context, state) {
          if (userProvider.isBanned) {
            return const StateNoticePage(
              title: '账号受限',
              message: '当前账号处于限制状态，暂时不能提交地陪入驻申请，请联系客服处理。',
              icon: Icons.gpp_bad_outlined,
            );
          }
          return const ApplyGuidePage();
        },
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserProfilePage(userId: id);
        },
      ),
      GoRoute(path: '/wallet', builder: (context, state) => const WalletPage()),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final name = state.uri.queryParameters['name'] ?? '用户';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          return ChatRoomPage(
            roomId: roomId,
            otherUserName: name,
            otherUserAvatar: avatar,
          );
        },
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (context, state) {
          if (!userProvider.isAdmin) {
            return const StateNoticePage(
              title: '无权限访问',
              message: '这个页面仅对管理员开放，当前账号不能查看审核后台。',
              icon: Icons.lock_outline,
            );
          }
          return const AuditListPage();
        },
      ),
    ],
  );
}
