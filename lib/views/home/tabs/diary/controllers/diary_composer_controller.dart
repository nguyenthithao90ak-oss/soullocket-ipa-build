import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/activity_history_service.dart';
import 'package:soullocket_app/utils/services/diary_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/home/tabs/diary/controllers/diary_feed_controller.dart';

class DiaryComposerController {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> isPostingVN = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedMoodVN = ValueNotifier<String>('😍');

  List<Map<String, dynamic>> get moods => <Map<String, dynamic>>[
        {
          'icon': '😍',
          'label': L10nService().translate('Vui vẻ'),
          'color': const Color(0xFFFF4B72),
        },
        {
          'icon': '💖',
          'label': L10nService().translate('Hạnh phúc'),
          'color': const Color(0xFFD81B60),
        },
        {
          'icon': '🤩',
          'label': L10nService().translate('Hứng khởi'),
          'color': const Color(0xFFFF8F00),
        },
        {
          'icon': '🤒',
          'label': L10nService().translate('Ốm'),
          'color': const Color(0xFF43A047),
        },
        {
          'icon': '🌧️',
          'label': L10nService().translate('Ư sầu'),
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
        L10nService().translate('Viết nội dung tâm sự trước đã!'),
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
              .translate('Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.'),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final houseId = await feedController.resolveHouseId();
      if (houseId == null) {
        showSnackBar(
          L10nService().translate('Chưa tìm thấy mã nhà để lưu bài viết.'),
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
            'Đã lưu nháp! Bài viết sẽ tự động đăng khi có mạng.',
          ),
          backgroundColor: const Color(0xFFF39C12),
        );
      } else {
        showSnackBar(L10nService().translate('Đã đăng tâm sự mới!'));
        ActivityHistoryService.instance.add(
          'đã viết một nhật ký mới',
          houseId: houseId,
          role: authorRole,
          isPrivate: false,
        );
      }
    } catch (e) {
      showSnackBar(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              L10nService().translate('Không thể đăng bài lúc này.'),
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
