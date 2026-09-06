import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login/auth_visual_style.dart';
import 'login/auth_recovery_layout.dart';
import 'login/aurora_form_widgets.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/security_flow_guard.dart';
import '../../core/sl_theme.dart';
import '../../utils/flexible_date_input.dart';
import '../../utils/app_error_mapper.dart';
import '../../widgets/sensitive_content_guard.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
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
  bool isObscure = true;
  String question = '';
  String answerHash = '';
  String fullEmail = '';
  String maskedEmail = '';
  String houseId = '';
  String linkSentEmail = '';
  String houseUser1Name = '';
  String houseUser2Name = '';

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
        backgroundColor: _style.surface,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('forgot_pwd_dialog_error_title'),
          style: _style.text(size: 19, weight: FontWeight.w700),
        ),
        content: Text(msg, style: _style.text(color: _style.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.tr('forgot_pwd_dialog_close'),
              style: _style.text(color: _style.accent),
            ),
          ),
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
          houseUser1Name = n1.isNotEmpty
              ? n1
              : context.tr('forgot_pwd_member_default_1');
          houseUser2Name = n2.isNotEmpty
              ? n2
              : context.tr('forgot_pwd_member_default_2');
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
      final resolvedAnswerHash =
          (recovery['answerHash'] ??
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
            backgroundColor: _style.surface,
            scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
            title: Text(
              context.tr('forgot_pwd_success_title'),
              style: _style.text(size: 20, weight: FontWeight.w700),
            ),
            content: Text(
              context.tr('forgot_pwd_success_message'),
              style: _style.text(color: _style.muted),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _style.button,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.smAll),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  context.tr('forgot_pwd_btn_home'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
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

  AuthVisualStyle get _style => AuthVisualStyle.of(context);

  Widget _buildRecoveryInfoCard({
    required String eyebrow,
    required String title,
    required String description,
    required IconData icon,
  }) => AuthRecoveryIntro(
    eyebrow: eyebrow,
    title: title,
    description: description,
    icon: icon,
  );

  Widget _buildSectionLabel(String text, {String? trailing}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text, style: _style.text(size: 13, weight: FontWeight.w600)),
      if (trailing != null) ...[
        const SizedBox(height: 4),
        Text(trailing, style: _style.text(size: 12, color: _style.muted)),
      ],
    ],
  );

  InputDecoration _recoveryInputDecoration({
    required String hintText,
    required IconData icon,
    String? helperText,
  }) => InputDecoration(
    hintText: hintText,
    helperText: helperText,
    helperMaxLines: 3,
    hintStyle: _style.text(size: 14, color: _style.muted),
    helperStyle: _style.text(size: 11, color: _style.muted),
    prefixIcon: Padding(
      padding: const EdgeInsets.all(9),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _style.accentFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: _style.accent),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 52),
    filled: true,
    fillColor: _style.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _style.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _style.accent, width: 1.4),
    ),
  );

  Widget _buildRecoveryActionButton({
    required String label,
    required VoidCallback? onTap,
    required bool busy,
    required IconData icon,
  }) => AuroraPrimaryButton(
    label: label,
    onPressed: onTap,
    isLoading: busy,
    enabled: onTap != null,
    icon: icon,
  );

  Widget _buildStep4OtpAndNewPassword() {
    final sentTo = maskedEmail.isNotEmpty ? maskedEmail : linkSentEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecoveryInfoCard(
          eyebrow: context.tr('auth_cute_recovery_password'),
          title: isSendingRecoveryCode
              ? context.tr('forgot_pwd_step4_title_sending')
              : context.tr('forgot_pwd_step4_title_enter'),
          description: isSendingRecoveryCode
              ? L10nService().format('forgot_pwd_step4_desc_sending', {
                  'email': sentTo,
                })
              : L10nService().format('forgot_pwd_step4_desc_sent', {
                  'email': sentTo,
                }),
          icon: Icons.mark_email_unread_rounded,
        ),
        SLSpacing.h24,
        _buildSectionLabel(context.tr('forgot_pwd_label_otp')),
        SLSpacing.h8,
        TextField(
          controller: otpCtrl,
          key: const ValueKey('auth_recovery_otp'),
          autofocus: true,
          enabled: !isBusy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          maxLength: 6,
          style: _style
              .text(size: 20, weight: FontWeight.w700)
              .copyWith(letterSpacing: 6),
          textAlign: TextAlign.center,
          decoration: _recoveryInputDecoration(
            hintText: context.tr('auth_cute_recovery_otp_hint'),
            icon: Icons.pin_rounded,
          ).copyWith(counterText: ''),
        ),
        SLSpacing.h24,
        _buildSectionLabel(context.tr('forgot_pwd_label_new_password')),
        SLSpacing.h8,
        TextField(
          controller: newPwdCtrl,
          key: const ValueKey('auth_recovery_new_password'),
          enabled: !isBusy,
          obscureText: isObscure,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) =>
              isBusy ? null : handleVerifyOtpAndCreatePassword(),
          style: _style.text(size: 15),
          decoration:
              _recoveryInputDecoration(
                hintText: context.tr('forgot_pwd_hint_new_password'),
                icon: Icons.lock_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: context.tr(
                    isObscure
                        ? 'auth_cute_show_password'
                        : 'auth_cute_hide_password',
                  ),
                  icon: Icon(
                    isObscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: _style.muted,
                  ),
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
                            content: Text(
                              context.tr('forgot_pwd_snack_otp_resent'),
                              style: SLTheme.quicksand(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        _showErrorDialog(
                          context.tr('forgot_pwd_err_resend_otp_failed'),
                        );
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
            child: Text(
              context.tr('forgot_pwd_btn_resend_otp'),
              style: _style.text(color: _style.accent, weight: FontWeight.w600),
            ),
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
              eyebrow: context.tr('auth_cute_recovery_security'),
              title: question,
              description: context.tr('forgot_pwd_step2_desc'),
              icon: Icons.help_rounded,
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
              style: _style.text(size: 15),
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
              label: isBusy
                  ? context.tr('forgot_pwd_btn_checking')
                  : context.tr('forgot_pwd_btn_check_answer'),
              onTap: isBusy ? null : handleAnswerVerify,
              busy: isBusy,
              icon: Icons.verified_user_rounded,
            ),
          ],
        );
      case 3:
        final description = maskedEmail.isNotEmpty
            ? L10nService().format('forgot_pwd_step3_desc_with_hint', {
                'masked': maskedEmail,
              })
            : context.tr('forgot_pwd_step3_desc_no_hint');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecoveryInfoCard(
              eyebrow: context.tr('auth_cute_recovery_email'),
              title: context.tr('forgot_pwd_step3_title'),
              description: description,
              icon: Icons.mark_email_read_rounded,
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
              style: _style.text(size: 15),
              onSubmitted: (_) => isBusy ? null : handleResetLinkSend(),
              decoration: _recoveryInputDecoration(
                hintText: context.tr('forgot_pwd_hint_full_email'),
                icon: Icons.alternate_email_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy
                  ? context.tr('forgot_pwd_btn_send_code_busy')
                  : context.tr('forgot_pwd_btn_send_code'),
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
              eyebrow: context.tr('auth_cute_recovery_identify'),
              title: context.tr('auth_cute_recovery_start_title'),
              description: context.tr('auth_cute_recovery_start_description'),
              icon: Icons.home_rounded,
            ),
            SLSpacing.h20,
            _buildSectionLabel(context.tr('forgot_pwd_label_house_or_email')),
            SLSpacing.h8,
            TextField(
              key: const ValueKey('auth_recovery_identifier'),
              controller: houseCtrl,
              autofocus: false,
              enabled: !isBusy,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              style: _style.text(size: 15),
              onSubmitted: (_) => isBusy ? null : handleHouseLookup(),
              decoration: _recoveryInputDecoration(
                hintText: context.tr('forgot_pwd_hint_house_or_email'),
                icon: Icons.vpn_key_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy
                  ? context.tr('forgot_pwd_btn_processing')
                  : context.tr('forgot_pwd_btn_continue'),
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
    return SensitiveContentGuard(
      child: AuthRecoveryLayout(
        busy: isBusy,
        onBack: () => Navigator.of(context).pop(),
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(step), child: buildStepBody()),
        ),
        footer: TextButton.icon(
          key: const ValueKey('auth_recovery_previous'),
          onPressed: isBusy
              ? null
              : () {
                  if (step == 1) {
                    Navigator.of(context).pop();
                    return;
                  }
                  setState(() {
                    if (step == 4) {
                      step = 1;
                      linkSentEmail = '';
                    } else if (step == 3 && question.isNotEmpty) {
                      step = 2;
                    } else {
                      step = 1;
                    }
                  });
                },
          style: TextButton.styleFrom(
            foregroundColor: _style.accent,
            textStyle: _style.text(size: 13, weight: FontWeight.w600),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(
            context.tr(
              step == 1
                  ? 'auth_cute_back_login'
                  : step == 4
                  ? 'forgot_pwd_btn_restart'
                  : 'forgot_pwd_btn_back_step',
            ),
          ),
        ),
      ),
    );
  }
}
