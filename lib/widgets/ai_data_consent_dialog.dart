import 'package:flutter/material.dart';
import '../utils/ai_data_consent.dart';
import '../utils/services/l10n_service.dart';
import 'sl_dialog.dart';

Future<bool> requestAiDataConsent(
  BuildContext context, {
  required String uid,
  required bool Function() isCurrent,
  bool manage = false,
}) async {
  if (uid.isEmpty || !isCurrent()) return false;
  final bool accepted;
  try {
    accepted = await AiDataConsent.hasConsent(uid);
  } catch (_) {
    return false;
  }
  if (!context.mounted || !isCurrent()) return false;
  if (accepted && !manage) return true;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => SLAlertDialog(
      title: Text(context.tr(
        accepted && manage ? 'ai_data_consent_manage' : 'ai_data_consent_title',
      )),
      content: Text(context.tr('ai_data_consent_body')),
      actions: [
        SLDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            context.tr(accepted ? 'ai_data_consent_revoke' : 'p3_cancel'),
          ),
        ),
        SLDialogAction(
          primary: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.tr('ai_data_consent_accept')),
        ),
      ],
    ),
  );
  if (!isCurrent()) return false;
  // Đóng hộp thoại không thay lựa chọn đã lưu; chỉ nút đồng ý mới cấp consent.
  if (result == null) return accepted && manage;
  try {
    await AiDataConsent.setConsent(uid, result);
  } catch (_) {
    return false;
  }
  return result && isCurrent();
}
