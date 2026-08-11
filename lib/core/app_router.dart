import 'package:go_router/go_router.dart';
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/widget_action_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AppRouter {
  static final router = GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: '/',
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppEntry(),
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
