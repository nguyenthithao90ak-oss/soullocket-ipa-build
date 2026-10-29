import 'package:soullocket_app/utils/services/breakup_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/ui_copy.dart';

/// Nội dung dùng chung để Home và Cài đặt giải thích cùng một thời hạn.
abstract final class BreakupNoticeCopy {
  static String title(BreakupRequestData request) => L10nService().translate(
    request.isProcessing
        ? 'home_angxlxadli_9bb5cf'
        : request.isScheduled
        ? 'home_lnlchxadli_6e8028'
        : 'home_angchxlchi_6eafab',
  );

  static String dateTime(int timestamp) {
    if (timestamp <= 0) {
      return L10nService().translate('home_khngxcnh_fb806e');
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return UiCopy.text('copy_03dc788a1b2c', {
      'value1': date.day.toString().padLeft(2, '0'),
      'value2': date.month.toString().padLeft(2, '0'),
      'value3': date.year,
      'value4': date.hour.toString().padLeft(2, '0'),
      'value5': date.minute.toString().padLeft(2, '0'),
    });
  }

  static String status(
    BreakupRequestData request, {
    int? now,
    bool compact = false,
  }) {
    final l10n = L10nService();
    if (!request.isActive) return '';
    if (request.isProcessing) {
      return l10n.translate(
        compact
            ? 'breakup_notice_processing_short'
            : 'breakup_notice_processing',
      );
    }
    final deadline = request.isScheduled ? request.deleteAt : request.expireAt;
    final isDue =
        deadline > 0 &&
        deadline <= (now ?? DateTime.now().millisecondsSinceEpoch);
    final key = isDue
        ? (compact ? 'breakup_notice_due_short' : 'breakup_notice_due')
        : request.isScheduled
        ? (compact
              ? 'breakup_notice_scheduled_short'
              : 'breakup_notice_scheduled')
        : (compact ? 'breakup_notice_pending_short' : 'breakup_notice_pending');
    return l10n.format(key, {'deadline': dateTime(deadline)});
  }

  static String details(BreakupRequestData request) => [
    status(request),
    L10nService().translate('breakup_notice_scope'),
    if (!request.isProcessing)
      L10nService().translate('breakup_notice_withdraw'),
  ].join('\n\n');

  static String requestConfirmation({required bool isSingle}) => [
    L10nService().translate(
      isSingle ? 'breakup_single_confirm' : 'breakup_request_confirm',
    ),
    L10nService().translate('breakup_notice_scope'),
    L10nService().translate('breakup_notice_withdraw'),
  ].join('\n\n');

  static String get approveConfirmation => [
    L10nService().translate('breakup_approve_confirm'),
    L10nService().translate('breakup_notice_scope'),
  ].join('\n\n');
}
