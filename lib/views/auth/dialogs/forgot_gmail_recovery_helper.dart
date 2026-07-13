import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/auth_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import 'auth_feedback_dialogs.dart';
import 'password_reset_otp_dialog.dart';

class ForgotGmailRecoveryHelper {
  const ForgotGmailRecoveryHelper._();

  static Future<void> launch({
    required BuildContext context,
    required AuthService authService,
    required Future<bool> Function() onGuardPasswordReset,
  }) async {
    final houseId = await _promptHouseId(context);
    if (houseId == null || houseId.isEmpty) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10nService().translate('Đang kiểm tra...'))),
    );

    final secData = await authService.getHouseSecurityData(houseId);
    if (!context.mounted) return;

    if (secData == null) {
      AuthFeedbackDialogs.showError(
        context,
        L10nService().translate('auth_err_missing_house_code'),
      );
      return;
    }

    final recovery = secData['recovery'] is Map
        ? Map<String, dynamic>.from(secData['recovery'] as Map)
        : <String, dynamic>{};
    final question =
        (recovery['question'] ?? secData['question'] ?? '').toString().trim();
    final storedAnswer =
        (recovery['answerHash'] ?? secData['answerHash'] ?? secData['answer'])
            ?.toString();
    final fullEmail = secData['email']?.toString().trim().toLowerCase() ?? '';

    if (question.isEmpty) {
      AuthFeedbackDialogs.showError(
        context,
        L10nService().translate('auth_err_no_security_q'),
      );
      return;
    }

    final answer = await _promptSecurityAnswer(context, question);
    if (answer == null || answer.isEmpty) return;

    final isCorrect = authService.matchesRecoveryAnswer(
      storedAnswer,
      answer,
    );

    if (!context.mounted) return;
    if (!isCorrect) {
      AuthFeedbackDialogs.showError(
        context,
        L10nService().translate('auth_err_wrong_security_a'),
      );
      return;
    }

    final maskedEmail = authService.maskEmail(fullEmail);
    if (!context.mounted) return;
    await _promptMaskedEmail(
      context: context,
      authService: authService,
      fullEmail: fullEmail,
      maskedEmail: maskedEmail,
      houseId: houseId,
      pin: secData['pin'] as String?,
      onGuardPasswordReset: onGuardPasswordReset,
    );
  }

  static Future<String?> _promptHouseId(BuildContext context) {
    final houseIdController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'QUÊN GMAIL',
          style: SLTheme.quicksand(
            color: SLColors.primaryActive,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L10nService().translate('Vui lòng nhập mã nhà của bạn:'),
                style: SLTheme.quicksand(fontSize: 14),
              ),
              SLSpacing.h16,
              TextField(
                controller: houseIdController,
                autofocus: true,
                style: SLTheme.quicksand(),
                decoration: InputDecoration(
                  hintText: 'VD: NH_...',
                  border: OutlineInputBorder(borderRadius: SLRadius.mdAll),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              L10nService().translate('Hủy'),
              style: SLTheme.quicksand(),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, houseIdController.text.trim()),
            child: Text(
              L10nService().translate('Tiếp theo'),
              style: SLTheme.quicksand(),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        houseIdController.dispose();
      });
    });
  }

  static Future<String?> _promptSecurityAnswer(
    BuildContext context,
    String question,
  ) {
    final answerController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'CÂU HỎI BẢO MẬT',
          style: SLTheme.quicksand(
            color: SLColors.primaryActive,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10nService().format('auth_security_question_label', {
                  'question': question,
                }),
                style: SLTheme.quicksand(fontWeight: FontWeight.bold),
              ),
              SLSpacing.h16,
              TextField(
                controller: answerController,
                autofocus: true,
                style: SLTheme.quicksand(),
                decoration: InputDecoration(
                  hintText: L10nService().translate('Nhập câu trả lời...'),
                  border: OutlineInputBorder(borderRadius: SLRadius.mdAll),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              L10nService().translate('Hủy'),
              style: SLTheme.quicksand(),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, answerController.text.trim()),
            child: Text(
              L10nService().translate('Xác Minh'),
              style: SLTheme.quicksand(),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        answerController.dispose();
      });
    });
  }

  static Future<void> _promptMaskedEmail({
    required BuildContext context,
    required AuthService authService,
    required String fullEmail,
    required String maskedEmail,
    required String houseId,
    required String? pin,
    required Future<bool> Function() onGuardPasswordReset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    final isFamiliarDevice = prefs.getString('il_house_id') == houseId;
    var promptMessage = L10nService().format('auth_recovery_email_prompt', {
      'email': maskedEmail,
    });
    if (isFamiliarDevice) {
      promptMessage += L10nService().translate(
        '\\n\\n[Thiết bị quen] Nếu bạn quên cả mã PIN, nhập "RESET" để yêu cầu đổi mới (xử lý sau 3 ngày).',
      );
    }

    final inputController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          L10nService().translate('auth_verify_email_title'),
          style: SLTheme.quicksand(
            color: SLColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10nService().format('auth_recovery_email_hint', {
                  'email': maskedEmail,
                }),
                style: SLTheme.quicksand(fontWeight: FontWeight.bold),
              ),
              SLSpacing.h8,
              Text(promptMessage, style: SLTheme.quicksand(fontSize: 13)),
              SLSpacing.h16,
              TextField(
                controller: inputController,
                autofocus: true,
                style: SLTheme.quicksand(),
                decoration: InputDecoration(
                  hintText: L10nService().translate('Vui lòng nhập...'),
                  border: OutlineInputBorder(borderRadius: SLRadius.mdAll),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              L10nService().translate('Hủy'),
              style: SLTheme.quicksand(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              inputController.text.trim().toLowerCase(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SLColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: SLRadius.smAll),
            ),
            child: Text(
              L10nService().translate('Xác nhận'),
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      inputController.dispose();
    });

    if (result == null || result.isEmpty) return;
    if (!context.mounted) return;

    if (result == fullEmail || (pin != null && result == pin.toLowerCase())) {
      await _sendPasswordResetOtp(
        context: context,
        authService: authService,
        fullEmail: fullEmail,
        maskedEmail: maskedEmail,
        onGuardPasswordReset: onGuardPasswordReset,
      );
      return;
    }

    if (isFamiliarDevice && result == 'reset') {
      AuthFeedbackDialogs.showError(
        context,
        L10nService().translate('auth_msg_recovery_requested'),
      );
      await FirebaseDatabase.instance.ref('reset_requests/$houseId').set({
        'requestTs': ServerValue.timestamp,
        'platform': 'flutter',
        'status': 'pending',
      });
      return;
    }

    AuthFeedbackDialogs.showError(
      context,
      L10nService().translate('Email hoặc Mã bảo mật không chính xác.'),
    );
  }

  static Future<void> _sendPasswordResetOtp({
    required BuildContext context,
    required AuthService authService,
    required String fullEmail,
    required String maskedEmail,
    required Future<bool> Function() onGuardPasswordReset,
  }) async {
    final success = await PasswordResetOtpDialog.show(
      context: context,
      fullEmail: fullEmail,
      maskedEmail: maskedEmail,
      onGuard: onGuardPasswordReset,
      sendOtpEmail: authService.sendOtpEmail,
      verifyCode: (otp, newPassword) async {
        final token = await authService.verifyOtpAndGetToken(fullEmail, otp);
        await authService.signInWithCustomTokenAndSetPassword(
          token,
          newPassword,
        );
      },
    );
    if (!success || !context.mounted) return;

    SLNotice.showSuccess(
      context,
      L10nService().translate('auth_password_reset_success_login'),
    );
  }
}
