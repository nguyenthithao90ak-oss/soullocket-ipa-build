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
import '../utils/diary_notification_key.dart';
import 'diary_feed_controller.dart';

class DiaryComposerController {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> isPostingVN = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedMoodVN = ValueNotifier<String>('📝');
  final ValueNotifier<DiaryQuota?> quotaVN = ValueNotifier<DiaryQuota?>(null);
  String? _quotaHouseId;
  bool _disposed = false;

  String? get quotaStatus {
    final quota = quotaVN.value;
    if (quota == null) return null;
    return L10nService().format('diary_quota_status', {
      'dailyRemaining': quota.dailyRemaining,
      'dailyLimit': quota.dailyLimit,
      'totalRemaining': quota.totalRemaining,
      'totalLimit': quota.totalLimit,
    });
  }

  Future<void> refreshQuota(String houseId, {bool force = false}) async {
    final normalized = houseId.trim();
    if (normalized.isEmpty || (!force && _quotaHouseId == normalized)) return;
    _quotaHouseId = normalized;
    try {
      final quota = await DiaryService().fetchDiaryQuota(normalized);
      if (!_disposed) quotaVN.value = quota;
    } catch (error) {
      debugPrint('[DiaryQuota] Không tải được trạng thái quota: $error');
    }
  }

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
      unawaited(refreshQuota(houseId, force: true));

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
        NotificationService()
            .sendPartnerNotification(
              houseId: houseId,
              title: L10nService().format(
                'ui_home_value1_value2_just_wrote_a_confession_f3dc57',
                {'value1': authorName, 'value2': mood},
              ),
              // Không đưa nội dung tâm sự lên lock screen; người nhận sẽ xem
              // đầy đủ sau khi mở app và qua luồng khóa riêng tư.
              body: L10nService().format('diary_partner_new_diary', {
                'author': authorName,
              }),
              data: const {'screen': 'diary', 'type': 'diary_post'},
              idempotencyKey: diaryPostNotificationIdempotencyKey(tempId),
            )
            .ignore();
      }
    } catch (e) {
      if (e is DiaryQuotaException) {
        final quota = e.quota;
        final message = e.isDailyLimit
            ? L10nService().format('diary_quota_daily_reached', {
                'limit': quota?.dailyLimit ?? 50,
              })
            : e.isTotalLimit
            ? L10nService().format('diary_quota_total_reached', {
                'limit': quota?.totalLimit ?? 500,
              })
            : L10nService().translate('diary_quota_reached');
        showSnackBar(message, backgroundColor: const Color(0xFFE07A2D));
        return;
      }
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
    _disposed = true;
    textController.dispose();
    isPostingVN.dispose();
    selectedMoodVN.dispose();
    quotaVN.dispose();
  }
}
