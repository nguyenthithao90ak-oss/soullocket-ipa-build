import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/widget_action_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:soullocket_app/views/utilities/love_card_public_link_screen.dart';
import 'package:soullocket_app/utils/services/love_card_link_service.dart';

import 'constants/app_config.dart';
import 'routing/external_link_startup.dart';

class AppRouter {
  static final _startupUri = Uri.base;

  static final router = GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: kIsWeb ? externalLinkInitialLocation(_startupUri) : '/',
    // Thiệp công khai mở trực tiếp, không phụ thuộc đăng nhập hoặc tải Home.
    overridePlatformDefaultLocation:
        kIsWeb && shouldStartAtAppEntry(_startupUri),
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AppEntry()),
      GoRoute(
        path: LoveCardLinkService.viewerPath,
        builder: (context, state) => LoveCardPublicLinkScreen(
          sourceUri: AppConfig.webUri(
            LoveCardLinkService.viewerPath,
          ).replace(query: state.uri.query, fragment: state.uri.fragment),
          onBack: () => context.go('/'),
        ),
      ),
      GoRoute(
        path: '/diary',
        redirect: (context, state) {
          SLTheme.globalTabRequest.value = 1;
          return '/';
        },
      ),
      GoRoute(
        path: '/apps',
        redirect: (context, state) {
          SLTheme.globalTabRequest.value = 2;
          return '/';
        },
      ),
      GoRoute(
        path: '/fun',
        redirect: (context, state) {
          SLTheme.globalTabRequest.value = 3;
          return '/';
        },
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) {
          SLTheme.globalTabRequest.value = -1;
          return '/';
        },
      ),
      GoRoute(
        path: '/health',
        redirect: (context, state) {
          WidgetActionService().triggerAction(WidgetLaunchAction.cycle);
          return '/';
        },
      ),
      GoRoute(
        path: '/love-insights',
        redirect: (context, state) {
          WidgetActionService().triggerAction(WidgetLaunchAction.love);
          return '/';
        },
      ),
      GoRoute(
        path: '/calendar',
        redirect: (context, state) {
          WidgetActionService().triggerAction(WidgetLaunchAction.calendar);
          return '/';
        },
      ),
      GoRoute(
        path: '/events',
        redirect: (context, state) {
          WidgetActionService().triggerAction(WidgetLaunchAction.soul_events);
          return '/';
        },
      ),
    ],
  );
}
