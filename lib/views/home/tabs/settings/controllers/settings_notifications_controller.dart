import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotificationsDraft {
  final String? houseId;
  final bool notificationsEnabled;
  final bool notifAnniversary;
  final bool notifPost;
  final bool notifChat;
  final bool notifFriend;
  final bool notifHeart;
  final bool smartDiaryReminder;
  final bool smartCapsuleReminder;
  final bool smartLoveNoteReminder;
  final bool smartSleepReminder;
  final String goodMorningTime;
  final String goodNightTime;

  const SettingsNotificationsDraft({
    required this.houseId,
    required this.notificationsEnabled,
    required this.notifAnniversary,
    required this.notifPost,
    required this.notifChat,
    required this.notifFriend,
    required this.notifHeart,
    required this.smartDiaryReminder,
    required this.smartCapsuleReminder,
    required this.smartLoveNoteReminder,
    required this.smartSleepReminder,
    required this.goodMorningTime,
    required this.goodNightTime,
  });
}

class SettingsNotificationsController {
  const SettingsNotificationsController();

  Future<void> persistNotificationPrefs({
    required SharedPreferences prefs,
    required DatabaseReference dbRef,
    required SettingsNotificationsDraft draft,
  }) async {
    await prefs.setBool('il_notifications_enabled', draft.notificationsEnabled);
    await prefs.setBool('il_notif_anniversary', draft.notifAnniversary);
    await prefs.setBool('il_notif_post', draft.notifPost);
    await prefs.setBool('il_notif_chat', draft.notifChat);
    await prefs.setBool('il_notif_friend', draft.notifFriend);
    await prefs.setBool('il_notif_heart', draft.notifHeart);
    await prefs.setBool('il_smart_reminder_diary', draft.smartDiaryReminder);
    await prefs.setBool('il_smart_reminder_capsule', draft.smartCapsuleReminder);
    await prefs.setBool('il_smart_reminder_love_note', draft.smartLoveNoteReminder);
    await prefs.setBool('il_smart_reminder_sleep', draft.smartSleepReminder);
    await prefs.setString('il_good_morning_time', draft.goodMorningTime);
    await prefs.setString('il_good_night_time', draft.goodNightTime);

    final houseId = draft.houseId;
    if (houseId != null && houseId.trim().isNotEmpty) {
      await dbRef.child('houses/$houseId/settings').update({
        'notificationsEnabled': draft.notificationsEnabled,
        'notifAnniversary': draft.notifAnniversary,
        'notifPost': draft.notifPost,
        'notifChat': draft.notifChat,
        'notifFriend': draft.notifFriend,
        'notifHeart': draft.notifHeart,
        'smartReminderDiary': draft.smartDiaryReminder,
        'smartReminderCapsule': draft.smartCapsuleReminder,
        'smartReminderLoveNote': draft.smartLoveNoteReminder,
        'smartReminderSleep': draft.smartSleepReminder,
        'goodMorningTime': draft.goodMorningTime,
        'goodNightTime': draft.goodNightTime,
        'updatedAt': ServerValue.timestamp,
      });
    }
  }

  Future<void> syncNotificationTopics({
    required String? houseId,
    required bool enabled,
  }) async {
    if (enabled) {
      await FirebaseMessaging.instance.subscribeToTopic('soullocket_global');
      if (houseId != null && houseId.trim().isNotEmpty) {
        await FirebaseMessaging.instance.subscribeToTopic('house_$houseId');
      }
      return;
    }

    await FirebaseMessaging.instance.unsubscribeFromTopic('soullocket_global');
    if (houseId != null && houseId.trim().isNotEmpty) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('house_$houseId');
    }
  }
}
