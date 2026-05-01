part of 'notification_screen.dart';

// Badge counter để stream số về HomeScreen
class NotificationBadgeNotifier extends ChangeNotifier {
  static final NotificationBadgeNotifier _instance =
      NotificationBadgeNotifier._internal();
  factory NotificationBadgeNotifier() => _instance;
  NotificationBadgeNotifier._internal();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  void update(int count) {
    if (_unreadCount != count) {
      _unreadCount = count;
      notifyListeners();
    }
  }
}

enum NotifFilter { all, friend, like, comment, system }
