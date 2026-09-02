import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/activity_history_service.dart';
import '../../../../../utils/services/diary_service.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/notification_service.dart';
import '../../../../../widgets/soullocket_animated_sticker.dart';
import 'diary_feed_controller.dart';

class DiaryComposerController {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> isPostingVN = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedMoodVN = ValueNotifier<String>('📝');

  List<Map<String, dynamic>> get moods => <Map<String, dynamic>>[
    {
      'icon': '📝',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_reflective'),
      'label': L10nService().translate('home_bnhyn_325c26'),
      'color': const Color(0xFF8D6E63),
    },
    {
      'icon': '🙈',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_shy'),
      'label': L10nService().translate('community_mood_gentle'),
      'color': const Color(0xFFF06292),
    },
    {
      'icon': '💌',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_missing'),
      'label': L10nService().translate('home_nh_dbe2a3'),
      'color': const Color(0xFFE91E63),
    },
    {
      'icon': '⭐',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_proud'),
      'label': L10nService().translate('home_tho_ebaeb2'),
      'color': const Color(0xFFFFB300),
    },
    {
      'icon': '🌙',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_sleepy'),
      'label': L10nService().translate('community_mood_tired'),
      'color': const Color(0xFF7E57C2),
    },
    {
      'icon': '🥺',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_anxious'),
      'label': L10nService().translate('home_cmtchicman_356344'),
      'color': const Color(0xFF9575CD),
    },
    {
      'icon': '😤',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_grumpy'),
      'label': L10nService().translate('home_hidibnmtxu_6797cf'),
      'color': const Color(0xFFEF5350),
    },
    {
      'icon': '😉',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_playful'),
      'label': L10nService().translate('util_tinhqui_51118a'),
      'color': const Color(0xFF42A5F5),
    },
    {
      'icon': '❤️‍🩹',
      'asset': SoulLocketStickerCatalog.referenceFor('diary_healing'),
      'label': L10nService().translate('home_timchalnh_0adb4b'),
      'color': const Color(0xFF66BB6A),
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
        L10nService().translate(
          L10nService().translate('home_vitnidungt_62c71e'),
        ),
        backgroundColor: const Color(0xFFEF6C57),
      );
      return;
    }

    isPostingVN.value = true;
    try {
      final user = await resolveCurrentUser();
      if (user == null) {
        showSnackBar(
          L10nService().translate(
            L10nService().translate('home_phinngnhpc_f6ac90'),
          ),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final houseId = await feedController.resolveHouseId();
      if (houseId == null) {
        showSnackBar(
          L10nService().translate(
            L10nService().translate('home_chatmthymn_54ac3c'),
          ),
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
        showSnackBar(
          L10nService().translate(
            L10nService().translate('home_ngtmsmi_f60808'),
          ),
        );
        ActivityHistoryService.instance
            .add(
              L10nService().translate('home_vitmtnhtkm_2ae1bc'),
              houseId: houseId,
              role: authorRole,
              isPrivate: false,
            )
            .catchError((_) => null);
        // Gửi push notification tới người bên kia kèm nội dung nhật ký
        final mood = selectedMoodVN.value;
        final preview = content.length > 60
            ? '${content.substring(0, 60)}...'
            : content;
        NotificationService()
            .sendPartnerNotification(
              houseId: houseId,
              title: '$authorName $mood vừa viết tâm sự!',
              body: preview,
              data: const {'screen': 'diary', 'type': 'diary_post'},
            )
            .ignore();
      }
    } catch (e) {
      showSnackBar(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService().translate(
            L10nService().translate('home_khngthngbi_6d6c5a'),
          ),
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
