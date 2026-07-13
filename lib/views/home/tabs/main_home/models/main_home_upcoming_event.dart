part of '../../main_home_tab.dart';

class HomeUpcomingEvent {
  final String title;
  final DateTime date;
  final String type; // 'calendar' | 'anniversary' | 'birthday' | 'holiday'

  HomeUpcomingEvent({
    required this.title,
    required this.date,
    required this.type,
  });
}
