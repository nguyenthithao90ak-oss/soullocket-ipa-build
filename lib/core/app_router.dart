import 'package:go_router/go_router.dart';
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';

class AppRouter {
  static final router = GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppEntry(),
      ),
    ],
  );
}
