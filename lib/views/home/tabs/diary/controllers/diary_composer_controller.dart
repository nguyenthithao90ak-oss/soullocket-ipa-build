import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/activity_history_service.dart';
import '../../../../../utils/services/custom_mood_sticker_service.dart';
import '../../../../../utils/services/diary_service.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/notification_service.dart';
import '../../../../../utils/services/sound_service.dart';
import '../models/diary_mood_catalog.dart';
import 'diary_feed_controller.dart';

class DiaryComposerController {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> isPostingVN = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedMoodVN = ValueNotifier<String>('📝');

  List<Map<String, dynamic>> getMoodsWithCustom(String? customUrl) =>
      DiaryMoodCatalog.withCustom(customUrl);

  List<Map<String, dynamic>> get moods => getMoodsWithCustom(null).sublist(1);

  void setMood(String mood) {
    selectedMoodVN.value = mood;
  }

  Future<void> submit({
    required DiaryFeedController feedController,
    required Future<User?> Function() resolveCurrentUser,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    if (isPostingVN.value || CustomMoodStickerService.instance.isBusyVN.value) {
      return;
    }
    final content = textController.text.trim();
    final mood = selectedMoodVN.value;

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
      final customUrl =
          CustomMoodStickerService.instance.customStickerUrlVN.value;
      if (mood == '📷' && (customUrl == null || customUrl.isEmpty)) {
        showSnackBar(
          L10nService().translate('diary_custom_sticker_add'),
          backgroundColor: const Color(0xFFEF6C57),
        );
        return;
      }
      final tempId = await DiaryService().addDiaryPost(
        houseId: houseId,
        content: content,
        mood: mood,
        authorId: user.uid,
        authorName: authorName,
        authorEmail: user.email?.trim().toLowerCase() ?? '',
        authorRole: authorRole,
        imageUrl: '',
        customMoodUrl: mood == '📷' ? customUrl : null,
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
        // Chỉ báo âm thanh sau khi lưu xong, không báo cho bản chờ đồng bộ.
        unawaited(SoundService().playSaved());
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
