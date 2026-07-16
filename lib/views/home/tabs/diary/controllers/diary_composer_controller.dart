import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/activity_history_service.dart';
import '../../../../../utils/services/diary_service.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/notification_service.dart';
import 'diary_feed_controller.dart';

class DiaryComposerController {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> isPostingVN = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedMoodVN = ValueNotifier<String>('😍');

  List<Map<String, dynamic>> get moods => <Map<String, dynamic>>[
        {
          'icon': '😍',
          'label': L10nService()
              .translate(L10nService().translate('home_vuiv_2d8b13')),
          'color': const Color(0xFFFF4B72),
        },
        {
          'icon': '💖',
          'label': L10nService()
              .translate(L10nService().translate('home_hnhphc_2a902f')),
          'color': const Color(0xFFD81B60),
        },
        {
          'icon': '🤩',
          'label': L10nService()
              .translate(L10nService().translate('home_hngkhi_eef2c4')),
          'color': const Color(0xFFFF8F00),
        },
        {
          'icon': '🤒',
          'label':
              L10nService().translate(L10nService().translate('home_m_6872a7')),
          'color': const Color(0xFF43A047),
        },
        {
          'icon': '🌧️',
          'label': L10nService()
              .translate(L10nService().translate('home_su_9a7d8d')),
          'color': const Color(0xFF546E7A),
        },
      ];

  void setMood(String mood) {
    selectedMoodVN.value = mood;
  }

  Future<void> submit({
    required DiaryFeedController feedController,
    required Future<User?> Function() resolveCurrentUser,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    final content = textController.text.trim();

    if (content.isEmpty) {
      showSnackBar(
        L10nService()
            .translate(L10nService().translate('home_vitnidungt_62c71e')),
        backgroundColor: const Color(0xFFEF6C57),
      );
      return;
    }

    isPostingVN.value = true;
    try {
      final user = await resolveCurrentUser();
      if (user == null) {
        showSnackBar(
          L10nService()
              .translate(L10nService().translate('home_phinngnhpc_f6ac90')),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final houseId = await feedController.resolveHouseId();
      if (houseId == null) {
        showSnackBar(
          L10nService()
              .translate(L10nService().translate('home_chatmthymn_54ac3c')),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final authorName = await feedController.resolveCurrentAuthorName(user);
      final authorRole = feedController.currentAuthorRole;
      final tempId = await DiaryService().addDiaryPost(
        houseId: houseId,
        content: content,
        mood: selectedMoodVN.value,
        authorId: user.uid,
        authorName: authorName,
        authorEmail: user.email?.trim().toLowerCase() ?? '',
        authorRole: authorRole,
        imageUrl: '',
      );

      textController.clear();
      if (tempId.startsWith('offline_')) {
        showSnackBar(
          L10nService().translate(
            L10nService().translate('home_lunhpbivit_aa16c6'),
          ),
          backgroundColor: const Color(0xFFF39C12),
        );
      } else {
        showSnackBar(L10nService()
            .translate(L10nService().translate('home_ngtmsmi_f60808')));
        ActivityHistoryService.instance.add(
          L10nService().translate('home_vitmtnhtkm_2ae1bc'),
          houseId: houseId,
          role: authorRole,
          isPrivate: false,
        ).catchError((_) => null);
        // Gửi push notification tới người bên kia kèm nội dung nhật ký
        final mood = selectedMoodVN.value;
        final preview =
            content.length > 60 ? '${content.substring(0, 60)}...' : content;
        NotificationService().sendPartnerNotification(
          houseId: houseId,
          title: '$authorName $mood vừa viết tâm sự!',
          body: preview,
          data: const {'screen': 'diary', 'type': 'diary_post'},
        ).ignore();
      }
    } catch (e) {
      showSnackBar(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService()
              .translate(L10nService().translate('home_khngthngbi_6d6c5a')),
        ).message,
        backgroundColor: const Color(0xFFE53935),
      );
    } finally {
      isPostingVN.value = false;
    }
  }

  void dispose() {
    textController.dispose();
    isPostingVN.dispose();
    selectedMoodVN.dispose();
  }
}
