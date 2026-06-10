import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/l10n_service.dart';
import '../services/security_flow_guard.dart';
import '../core/sl_theme.dart';
import '../utils/flexible_date_input.dart';
import '../utils/app_error_mapper.dart';
import '../widgets/sensitive_content_guard.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _recoveryButtonColor = Color(0xFFD81B60);
  static const Color _recoveryAccentDark = Color(0xFFAD1457);
  static const Color _recoveryAccentSoft = Color(0xFFFFE1EC);
  static const List<IconData> _recoveryStepIcons = [
    Icons.home_rounded,
    Icons.quiz_rounded,
    Icons.mail_rounded,
    Icons.password_rounded,
  ];
  static List<String> recoveryStepLabels(BuildContext context) => [
    context.tr('forgot_pwd_step_home_email'),
    context.tr('forgot_pwd_step_security'),
    context.tr('forgot_pwd_step_send_code'),
    context.tr('forgot_pwd_step_change_password'),
  ];

  final _authService = AuthService();
  final SecurityFlowGuard _securityFlowGuard = SecurityFlowGuard.instance;
  final houseCtrl = TextEditingController();
  final answerCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final newPwdCtrl = TextEditingController();

  int step = 1;
  bool isBusy = false;
  bool isSendingRecoveryCode = false;
  bool isObscure = false;
  String question = '';
  String answerHash = '';
  String fullEmail = '';
  String maskedEmail = '';
  String houseId = '';
  String linkSentEmail = '';
  String houseUser1Name = '';
  String houseUser2Name = '';

  int get _displayRecoveryStep => step == 4 ? 4 : step;

  @override
  void dispose() {
    houseCtrl.dispose();
    answerCtrl.dispose();
    emailCtrl.dispose();
    otpCtrl.dispose();
    newPwdCtrl.dispose();
    super.dispose();
  }

  void _showErrorDialog(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('forgot_pwd_dialog_error_title'),
            style: SLTheme.quicksand(
                color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(msg, style: SLTheme.quicksand()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('forgot_pwd_dialog_close'), style: SLTheme.quicksand()),
          )
        ],
      ),
    );
  }

  String _normalizeRecoveryEmail(String email) {
    return email.trim().toLowerCase();
  }

  bool get _isBirthRecoveryQuestion {
    return DateInputUtils.looksLikeBirthQuestion(question);
  }

  void _normalizeAnswerIfDate() {
    if (!_isBirthRecoveryQuestion) return;
    final normalized = DateInputUtils.normalizeForDisplay(
      answerCtrl.text,
      firstYear: 1900,
      lastYear: DateTime.now().year,
      allowMissingYear: true,
    );
    answerCtrl.text = normalized;
    answerCtrl.selection = TextSelection.collapsed(offset: normalized.length);
  }

  bool _isValidRecoveryEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool _emailMatchesMaskedHint(String email, String masked) {
    if (masked.isEmpty || email.isEmpty) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final name = parts[0];
    final domain = parts[1];

    final maskedParts = masked.split('@');
    if (maskedParts.length != 2) return false;
    final maskedName = maskedParts[0];
    final maskedDomain = maskedParts[1];

    if (domain != maskedDomain) return false;
    if (name.length < 2) return false;

    if (!maskedName.startsWith(name[0])) return false;
    if (!maskedName.endsWith(name[name.length - 1])) return false;

    return true;
  }

  Future<String> _loadPublicRecoveryHint(String resolvedHouseId) async {
    final email = await _authService.findEmailByHouseId(resolvedHouseId);
    if (email != null && email.isNotEmpty) {
      return _authService.maskEmail(email);
    }
    return '';
  }

  Future<void> _loadHouseMemberNames(String resolvedHouseId) async {
    if (resolvedHouseId.isEmpty) return;
    try {
      final dbRef = _authService.getDatabaseRef();
      final snap = await dbRef.child('houses/$resolvedHouseId/settings').get();
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map? ?? {});
      final n1 = (data['nameU1'] ?? data['user1Name'] ?? data['name1'] ?? '')
          .toString()
          .trim();
      final n2 = (data['nameU2'] ?? data['user2Name'] ?? data['name2'] ?? '')
          .toString()
          .trim();
      if (mounted) {
        setState(() {
          houseUser1Name = n1.isNotEmpty ? n1 : context.tr('forgot_pwd_member_default_1');
          houseUser2Name = n2.isNotEmpty ? n2 : context.tr('forgot_pwd_member_default_2');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          houseUser1Name = context.tr('forgot_pwd_member_default_1');
          houseUser2Name = context.tr('forgot_pwd_member_default_2');
        });
      }
    }
  }

  Future<void> handleHouseLookup() async {
    final input = houseCtrl.text.trim();
    if (input.isEmpty) {
      _showErrorDialog(context.tr('forgot_pwd_err_enter_house_or_email'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isBusy = true);

    if (_isValidRecoveryEmail(input)) {
      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SensitiveActionType.forgotPasswordSendOtp,
      );
      if (!canContinue) {
        if (mounted) {
          setState(() => isBusy = false);
        }
        return;
      }

      // Direct email entry opens the OTP screen immediately while the code is sent.
      final normalizedEmail = _normalizeRecoveryEmail(input);
      setState(() {
        linkSentEmail = normalizedEmail;
        houseId = '';
        houseUser1Name = '';
        houseUser2Name = '';
        step = 4;
        isSendingRecoveryCode = true;
      });
      try {
        await _authService.sendOtpEmail(normalizedEmail);
        if (mounted) {
          setState(() => isSendingRecoveryCode = false);
        }
      } catch (e) {
        final resolvedMessage = AppErrorMapper.resolve(e).message;
        if (!mounted) return;
        setState(() {
          isSendingRecoveryCode = false;
          linkSentEmail = '';
          step = 1;
        });
        if (resolvedMessage.contains('không tìm thấy') ||
            resolvedMessage.contains('user-not-found') ||
            resolvedMessage.contains('không tồn tại')) {
          _showErrorDialog(context.tr('forgot_pwd_err_email_not_found'));
        } else {
          _showErrorDialog(context.tr('forgot_pwd_err_send_code_failed'));
        }
      } finally {
        if (mounted) setState(() => isBusy = false);
      }
      return;
    }

    final resolvedHouseId = input.toUpperCase();
    try {
      final secData = await _authService.getHouseSecurityData(resolvedHouseId);
      final publicHint = await _loadPublicRecoveryHint(resolvedHouseId);
      if (!mounted) return;
      final recovery = secData?['recovery'] is Map
          ? Map<String, dynamic>.from(secData!['recovery'] as Map)
          : <String, dynamic>{};

      final resolvedQuestion =
          (recovery['question'] ?? secData?['question'] ?? '')
              .toString()
              .trim();
      final resolvedAnswerHash = (recovery['answerHash'] ??
              secData?['answerHash'] ??
              secData?['answer'] ??
              '')
          .toString()
          .trim();
      final resolvedFullEmail = _normalizeRecoveryEmail(
        (secData?['email'] ?? '').toString(),
      );
      final resolvedMaskedEmail = resolvedFullEmail.isNotEmpty
          ? _authService.maskEmail(resolvedFullEmail)
          : publicHint;

      if (secData == null && resolvedMaskedEmail.isEmpty) {
        _showErrorDialog(context.tr('forgot_pwd_err_house_not_found'));
        return;
      }

      houseId = resolvedHouseId;
      question = resolvedQuestion;
      answerHash = resolvedAnswerHash;
      fullEmail = resolvedFullEmail;
      maskedEmail = resolvedMaskedEmail;
      answerCtrl.clear();
      emailCtrl.clear();

      // Load names in parallel (non-blocking UI)
      unawaited(_loadHouseMemberNames(resolvedHouseId));

      if (question.isNotEmpty && answerHash.isNotEmpty) {
        setState(() => step = 2);
        return;
      }

      if (maskedEmail.isNotEmpty || fullEmail.isNotEmpty) {
        setState(() => step = 3);
        return;
      }

      _showErrorDialog(context.tr('forgot_pwd_err_no_recovery_data'));
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  Future<void> handleAnswerVerify() async {
    final rawAnswer = answerCtrl.text.trim();
    if (rawAnswer.isEmpty) {
      _showErrorDialog(context.tr('forgot_pwd_err_enter_answer'));
      return;
    }
    if (_isBirthRecoveryQuestion) {
      final validationError = DateInputUtils.validationError(
        rawAnswer,
        firstYear: 1900,
        lastYear: DateTime.now().year,
        allowMissingYear: true,
      );
      if (validationError != null) {
        _showErrorDialog(validationError);
        return;
      }
    }
    _normalizeAnswerIfDate();
    final answer = answerCtrl.text.trim();

    FocusScope.of(context).unfocus();
    final ok = _authService.matchesRecoveryAnswer(answerHash, answer);
    if (!ok) {
      _showErrorDialog(context.tr('forgot_pwd_err_wrong_answer'));
      return;
    }

    if (fullEmail.isNotEmpty && emailCtrl.text.trim().isEmpty) {
      emailCtrl.text = fullEmail;
    }
    setState(() => step = 3);
  }

  Future<void> handleResetLinkSend() async {
    final enteredEmail = _normalizeRecoveryEmail(emailCtrl.text.trim());
    if (!_isValidRecoveryEmail(enteredEmail)) {
      _showErrorDialog(context.tr('forgot_pwd_err_enter_valid_email'));
      return;
    }

    if (fullEmail.isNotEmpty &&
        enteredEmail != _normalizeRecoveryEmail(fullEmail)) {
      _showErrorDialog(context.tr('forgot_pwd_err_email_mismatch_security'));
      return;
    }

    if (fullEmail.isEmpty &&
        maskedEmail.isNotEmpty &&
        !_emailMatchesMaskedHint(enteredEmail, maskedEmail)) {
      _showErrorDialog(context.tr('forgot_pwd_err_email_mismatch_hint'));
      return;
    }

    FocusScope.of(context).unfocus();
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.forgotPasswordSendOtp,
    );
    if (!canContinue) {
      return;
    }
    if (!mounted) return;
    setState(() {
      linkSentEmail = enteredEmail;
      step = 4;
      isBusy = true;
      isSendingRecoveryCode = true;
    });
    try {
      await _authService.sendOtpEmail(enteredEmail);
      // Load member names if not loaded yet
      if (houseId.isNotEmpty &&
          houseUser1Name.isEmpty &&
          houseUser2Name.isEmpty) {
        await _loadHouseMemberNames(houseId);
      }
      if (mounted) {
        setState(() {
          isBusy = false;
          isSendingRecoveryCode = false;
        });
      }
    } catch (e) {
      final resolvedMessage = AppErrorMapper.resolve(e).message;
      if (!mounted) return;
      setState(() {
        isBusy = false;
        isSendingRecoveryCode = false;
        linkSentEmail = '';
        step = 3;
      });
      if (resolvedMessage.contains('không tìm thấy') ||
          resolvedMessage.contains('user-not-found') ||
          resolvedMessage.contains('không tồn tại')) {
        _showErrorDialog(context.tr('forgot_pwd_err_email_not_found'));
      } else {
        _showErrorDialog('Lỗi gửi mã khôi phục: $resolvedMessage');
      }
    }
  }

  Future<void> handleVerifyOtpAndCreatePassword() async {
    final otp = otpCtrl.text.trim();
    final newPwd = newPwdCtrl.text;
    if (otp.length != 6) {
      _showErrorDialog(context.tr('forgot_pwd_err_enter_otp'));
      return;
    }
    if (newPwd.length < 6) {
      _showErrorDialog(context.tr('forgot_pwd_err_password_too_short'));
      return;
    }

    FocusScope.of(context).unfocus();
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.forgotPasswordReset,
    );
    if (!canContinue) {
      return;
    }
    if (!mounted) return;
    setState(() => isBusy = true);

    try {
      final token = await _authService.verifyOtpAndGetToken(linkSentEmail, otp);
      await _authService.signInWithCustomTokenAndSetPassword(token, newPwd);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
            title: Text(context.tr('forgot_pwd_success_title'),
                style: SLTheme.quicksand(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            content: Text(context.tr('forgot_pwd_success_message'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w600)),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.smAll),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(context.tr('forgot_pwd_btn_home'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context.tr('forgot_pwd_err_reset_failed'));
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Widget _buildRecoveryInfoCard({
    required String eyebrow,
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8FD), Color(0xFFFDF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFB6D3).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE080BB).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    color: SLColors.textSecond,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: SLTheme.quicksand(
            fontSize: 13,
            color: SLColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: SLColors.primary,
            ),
          ),
      ],
    );
  }

  InputDecoration _recoveryInputDecoration({
    required String hintText,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      hintStyle: SLTheme.quicksand(
        color: SLColors.textSecond.withValues(alpha: 0.70),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: SLTheme.quicksand(
        fontSize: 11,
        color: SLColors.textSecond,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFD81B60), size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFFF8F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE8DDD6), width: 1.25),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: SLColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: SLColors.danger, width: 1.6),
      ),
    );
  }

  Widget _buildRecoveryActionButton({
    required String label,
    required VoidCallback? onTap,
    required bool busy,
    required IconData icon,
  }) {
    final isEnabled = onTap != null;
    final colors = isEnabled
        ? const [Color(0xFFD81B60), Color(0xFFFF5293), Color(0xFFFF8FB8)]
        : const [Color(0xFFE8AFC4), Color(0xFFF1C3D3)];

    return Opacity(
      opacity: isEnabled ? 1 : 0.62,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.38),
            width: 1.4,
          ),
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: colors.last.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(icon, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecoveryProgressHeader() {
    final currentStep = _displayRecoveryStep;
    final currentIndex = currentStep - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_recoveryButtonColor, _recoveryAccentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
        boxShadow: [
          BoxShadow(
            color: _recoveryButtonColor.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _recoveryStepIcons[currentIndex],
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bước $currentStep/4',
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.82),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recoveryStepLabels(context)[currentIndex],
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(currentStep / 4 * 100).round()}%',
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: currentStep / 4,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Kept for the OTP recovery flow if this pending screen is re-enabled later.
  // ignore: unused_element
  Widget _buildStep4PendingConfirmation() {
    final sentTo = maskedEmail.isNotEmpty ? maskedEmail : linkSentEmail;
    final hasNames = houseUser1Name.isNotEmpty || houseUser2Name.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top success banner ──────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_recoveryButtonColor, _recoveryAccentDark],
            ),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              SLSpacing.h12,
              Text(
                'Mã khôi phục đã được gửi! 💌',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SLSpacing.h4,
              Text(
                sentTo.isNotEmpty
                    ? 'Đã gửi đến: $sentTo'
                    : 'Kiểm tra hộp thư email của bạn',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
        SLSpacing.h20,
        // ── House members ───────────────────────────────────────────
        if (hasNames) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: SLRadius.lgAll,
              border: Border.all(color: Colors.pink.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.home_rounded,
                        color: Color(0xFFD81B60), size: 18),
                    SLSpacing.w8,
                    Text(
                      context.tr('forgot_pwd_members_label'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                  ],
                ),
                SLSpacing.h12,
                Row(
                  children: [
                    _buildMemberChip(
                      name: houseUser1Name,
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFD81B60),
                    ),
                    SLSpacing.w12,
                    _buildMemberChip(
                      name: houseUser2Name,
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFF8F86FF),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SLSpacing.h16,
        ],
        // ── Pending badge ────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _recoveryAccentSoft,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _recoveryButtonColor.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _recoveryButtonColor,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  context.tr('forgot_pwd_pending_waiting'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    color: _recoveryAccentDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        SLSpacing.h16,
        // ── Tips ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _recoveryAccentSoft,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _recoveryButtonColor.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 ${context.tr('forgot_pwd_tips_note')}',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _recoveryAccentDark,
                ),
              ),
              SLSpacing.h4,
              _buildTip(context.tr('forgot_pwd_tip_check_spam')),
              _buildTip(context.tr('forgot_pwd_tip_code_expires')),
              _buildTip(context.tr('forgot_pwd_tip_enter_otp_in_app')),
            ],
          ),
        ),
        SLSpacing.gapH(28),
        // ── Resend button ────────────────────────────────────────────
        _buildRecoveryActionButton(
          label: context.tr('forgot_pwd_btn_resend'),
          onTap: isBusy
              ? null
              : () async {
                  if (linkSentEmail.isEmpty) return;
                  setState(() => isBusy = true);
                  try {
                    await _authService.sendOtpEmail(linkSentEmail);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr('forgot_pwd_snack_resent'),
                            style: SLTheme.quicksand(color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _showErrorDialog(context.tr('forgot_pwd_err_resend_failed'));
                    }
                  } finally {
                    if (mounted) setState(() => isBusy = false);
                  }
                },
          busy: isBusy,
          icon: Icons.refresh_rounded,
        ),
      ],
    );
  }

  Widget _buildMemberChip({
    required String name,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            SLSpacing.w4,
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style:
                  SLTheme.quicksand(fontSize: 12, color: _recoveryAccentDark)),
          Expanded(
            child: Text(
              text,
              style: SLTheme.quicksand(
                  fontSize: 12, color: _recoveryAccentDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4OtpAndNewPassword() {
    final sentTo = maskedEmail.isNotEmpty ? maskedEmail : linkSentEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecoveryInfoCard(
          eyebrow: context.tr('forgot_pwd_step4_eyebrow'),
          title: isSendingRecoveryCode
              ? context.tr('forgot_pwd_step4_title_sending')
              : context.tr('forgot_pwd_step4_title_enter'),
          description: isSendingRecoveryCode
              ? L10nService().format('forgot_pwd_step4_desc_sending', {'email': sentTo})
              : L10nService().format('forgot_pwd_step4_desc_sent', {'email': sentTo}),
          icon: Icons.mark_email_unread_rounded,
          accent: const Color(0xFFD81B60),
        ),
        SLSpacing.h24,
        _buildSectionLabel(context.tr('forgot_pwd_label_otp')),
        SLSpacing.h8,
        TextField(
          controller: otpCtrl,
          autofocus: true,
          enabled: !isBusy,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style:
              SLTheme.quicksand(letterSpacing: 4, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: _recoveryInputDecoration(
            hintText: '000000',
            icon: Icons.pin_rounded,
          ).copyWith(counterText: ''),
        ),
        SLSpacing.h24,
        _buildSectionLabel(context.tr('forgot_pwd_label_new_password')),
        SLSpacing.h8,
        TextField(
          controller: newPwdCtrl,
          enabled: !isBusy,
          obscureText: isObscure,
          style: SLTheme.quicksand(),
          decoration: _recoveryInputDecoration(
            hintText: context.tr('forgot_pwd_hint_new_password'),
            icon: Icons.lock_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                  isObscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.grey),
              onPressed: () => setState(() => isObscure = !isObscure),
            ),
          ),
        ),
        SLSpacing.gapH(32),
        _buildRecoveryActionButton(
          label: isSendingRecoveryCode
              ? context.tr('forgot_pwd_btn_sending')
              : isBusy
                  ? context.tr('forgot_pwd_btn_processing')
                  : context.tr('forgot_pwd_btn_confirm_change'),
          onTap: isBusy ? null : handleVerifyOtpAndCreatePassword,
          busy: isBusy,
          icon: Icons.check_circle_outline_rounded,
        ),
        SLSpacing.h20,
        Center(
          child: TextButton(
            onPressed: isBusy
                ? null
                : () async {
                    if (linkSentEmail.isEmpty) return;
                    if (!mounted) return;
                    setState(() {
                      isBusy = true;
                      isSendingRecoveryCode = true;
                    });
                    try {
                      await _authService.sendOtpEmail(linkSentEmail);
                      if (mounted) {
                        setState(() => isSendingRecoveryCode = false);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('forgot_pwd_snack_otp_resent'),
                                style: SLTheme.quicksand()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        _showErrorDialog(context.tr('forgot_pwd_err_resend_otp_failed'));
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isBusy = false;
                          isSendingRecoveryCode = false;
                        });
                      }
                    }
                  },
            child: Text(context.tr('forgot_pwd_btn_resend_otp'),
                style: SLTheme.quicksand(
                    color: const Color(0xFFD81B60),
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget buildStepBody() {
    switch (step) {
      case 4:
        return _buildStep4OtpAndNewPassword();
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecoveryInfoCard(
              eyebrow: context.tr('forgot_pwd_step2_eyebrow'),
              title: question,
              description: context.tr('forgot_pwd_step2_desc'),
              icon: Icons.help_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel(context.tr('forgot_pwd_label_your_answer')),
            SLSpacing.h8,
            TextField(
              controller: answerCtrl,
              autofocus: true,
              enabled: !isBusy,
              keyboardType: _isBirthRecoveryQuestion
                  ? TextInputType.datetime
                  : TextInputType.text,
              inputFormatters: _isBirthRecoveryQuestion
                  ? const [FlexibleDateInputFormatter()]
                  : null,
              style: SLTheme.quicksand(),
              textInputAction: TextInputAction.done,
              onEditingComplete: _normalizeAnswerIfDate,
              onSubmitted: (_) => isBusy ? null : handleAnswerVerify(),
              decoration: _recoveryInputDecoration(
                hintText: _isBirthRecoveryQuestion
                    ? context.tr('forgot_pwd_hint_date')
                    : context.tr('forgot_pwd_hint_answer'),
                icon: _isBirthRecoveryQuestion
                    ? Icons.calendar_month_rounded
                    : Icons.key_rounded,
                helperText: _isBirthRecoveryQuestion
                    ? context.tr('forgot_pwd_helper_date')
                    : null,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy ? context.tr('forgot_pwd_btn_checking') : context.tr('forgot_pwd_btn_check_answer'),
              onTap: isBusy ? null : handleAnswerVerify,
              busy: isBusy,
              icon: Icons.verified_user_rounded,
            ),
          ],
        );
      case 3:
        final description = maskedEmail.isNotEmpty
            ? L10nService().format('forgot_pwd_step3_desc_with_hint', {'masked': maskedEmail})
            : context.tr('forgot_pwd_step3_desc_no_hint');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecoveryInfoCard(
              eyebrow: context.tr('forgot_pwd_step3_eyebrow'),
              title: context.tr('forgot_pwd_step3_title'),
              description: description,
              icon: Icons.mark_email_read_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel(
              context.tr('forgot_pwd_label_full_email'),
              trailing: maskedEmail.isNotEmpty ? maskedEmail : null,
            ),
            SLSpacing.h8,
            TextField(
              controller: emailCtrl,
              autofocus: true,
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autocorrect: false,
              enableSuggestions: false,
              style: SLTheme.quicksand(),
              onSubmitted: (_) => isBusy ? null : handleResetLinkSend(),
              decoration: _recoveryInputDecoration(
                hintText: context.tr('forgot_pwd_hint_full_email'),
                icon: Icons.alternate_email_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy ? context.tr('forgot_pwd_btn_send_code_busy') : context.tr('forgot_pwd_btn_send_code'),
              onTap: isBusy ? null : handleResetLinkSend,
              busy: isBusy,
              icon: Icons.send_rounded,
            ),
          ],
        );
      case 1:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecoveryInfoCard(
              eyebrow: context.tr('forgot_pwd_step1_eyebrow'),
              title: context.tr('forgot_pwd_step1_title'),
              description: context.tr('forgot_pwd_step1_desc'),
              icon: Icons.home_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel(context.tr('forgot_pwd_label_house_or_email')),
            SLSpacing.h8,
            TextField(
              controller: houseCtrl,
              autofocus: true,
              enabled: !isBusy,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
              ),
              onSubmitted: (_) => isBusy ? null : handleHouseLookup(),
              decoration: _recoveryInputDecoration(
                hintText: context.tr('forgot_pwd_hint_house_or_email'),
                icon: Icons.vpn_key_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy ? context.tr('forgot_pwd_btn_processing') : context.tr('forgot_pwd_btn_continue'),
              onTap: isBusy ? null : handleHouseLookup,
              busy: isBusy,
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColors = const [
      Color(0xFFFFF0F5),
      Color(0xFFFFD6E7),
      Color(0xFFFCEEF7),
      Color(0xFFEEDDF8),
    ];

    return SensitiveContentGuard(
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: backgroundColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // --- top-left large blush orb ---
              Positioned(
                top: -80,
                left: -80,
                child: IgnorePointer(
                  child: _AuthGlowOrb(
                    size: 260,
                    colors: const [Color(0xFFFFB6D3), Color(0xFFFF8FB8)],
                    opacity: 0.38,
                  ),
                ),
              ),
              // --- right mid rose orb ---
              Positioned(
                top: 100,
                right: -90,
                child: IgnorePointer(
                  child: _AuthGlowOrb(
                    size: 220,
                    colors: const [Color(0xFFFFC2DC), Color(0xFFFF85B3)],
                    opacity: 0.44,
                  ),
                ),
              ),
              // --- bottom-right lavender orb ---
              Positioned(
                bottom: -30,
                right: 20,
                child: IgnorePointer(
                  child: _AuthGlowOrb(
                    size: 180,
                    colors: const [Color(0xFFE0BBFF), Color(0xFFC49CFF)],
                    opacity: 0.32,
                  ),
                ),
              ),
              // --- decorative sparkle icons ---
              Positioned(
                bottom: 100,
                left: 12,
                child: IgnorePointer(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: SLColors.primary.withValues(alpha: 0.22),
                    size: 52,
                  ),
                ),
              ),
              Positioned(
                top: 160,
                left: 30,
                child: IgnorePointer(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: SLColors.primary.withValues(alpha: 0.12),
                    size: 36,
                  ),
                ),
              ),

              // --- Main Content ---
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: SLColors.primary),
                    onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    context.tr('forgot_pwd_appbar_title').toUpperCase(),
                    style: SLTheme.quicksand(
                      color: SLColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  centerTitle: true,
                ),
                body: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isCompact = width < 380;
                      final isTablet = width >= 600;
                      final horizontalPadding = isCompact ? 14.0 : 18.0;
                      final maxContentWidth = isTablet ? 520.0 : 420.0;

                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxContentWidth),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBFD).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: const Color(0xFFFFB6D3).withValues(alpha: 0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF85B3).withValues(alpha: 0.16),
                                    blurRadius: 40,
                                    spreadRadius: -4,
                                    offset: const Offset(0, 20),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    blurRadius: 0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Brand Header Logo
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [SLColors.primary, Color(0xFFE060B0)],
                                          ).createShader(bounds),
                                          child: const Icon(
                                            Icons.favorite_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [Color(0xFFE0609A), Color(0xFFA044C0)],
                                          ).createShader(bounds),
                                          child: Text(
                                            'soullocket',
                                            style: SLTheme.quicksand(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [Color(0xFFE060B0), SLColors.primary],
                                          ).createShader(bounds),
                                          child: const Icon(
                                            Icons.favorite_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: KeyedSubtree(
                                      key: ValueKey(step),
                                      child: buildStepBody(),
                                    ),
                                  ),
                                  if (step > 1) ...[
                                    SLSpacing.h20,
                                    Center(
                                      child: TextButton.icon(
                                        onPressed: isBusy
                                            ? null
                                            : () {
                                                setState(() {
                                                  if (step == 4) {
                                                    step = 1;
                                                    linkSentEmail = '';
                                                  } else if (step == 3 &&
                                                      question.isNotEmpty) {
                                                    step = 2;
                                                  } else {
                                                    step = 1;
                                                  }
                                                });
                                              },
                                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                        label: Text(
                                          step == 4
                                              ? context.tr('forgot_pwd_btn_restart')
                                              : context.tr('forgot_pwd_btn_back_step'),
                                          style: SLTheme.quicksand(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFFD81B60),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthGlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final double opacity;

  const _AuthGlowOrb({
    required this.size,
    required this.colors,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: opacity),
            colors.last.withValues(alpha: opacity * 0.58),
            colors.last.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
