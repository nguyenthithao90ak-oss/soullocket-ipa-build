import 'package:soullocket_app/utils/services/l10n_service.dart';

class PresenceStatusFormatter {
  const PresenceStatusFormatter();

  String onlineLabel() => L10nService().translate('core_presence_online');

  String neverConnectedLabel() =>
      L10nService().translate('core_presence_never_connected');

  String disconnectedLabel() =>
      L10nService().translate('core_presence_disconnected');

  String justDisconnectedLabel() =>
      L10nService().translate('core_presence_just_disconnected');

  String formatLastSeen(int? lastSeenMs) {
    if (lastSeenMs == null) return neverConnectedLabel();
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
    );

    if (diff.inSeconds < 60) {
      return L10nService()
          .format('core_presence_minutes_ago', {'count': 1});
    }
    if (diff.inMinutes < 60) {
      return L10nService()
          .format('core_presence_minutes_ago', {'count': diff.inMinutes});
    }
    if (diff.inHours < 24) {
      return L10nService()
          .format('core_presence_hours_ago', {'count': diff.inHours});
    }
    if (diff.inDays == 1) {
      return L10nService().translate('core_presence_yesterday');
    }
    if (diff.inDays < 30) {
      return L10nService()
          .format('core_presence_days_ago', {'count': diff.inDays});
    }
    return L10nService().translate('core_presence_long_ago');
  }
}
