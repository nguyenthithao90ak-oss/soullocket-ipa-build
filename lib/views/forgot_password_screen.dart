import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
  static const List<String> _recoveryStepLabels = [
    'Nhà / Email',
    'Bảo mật',
    'Gửi mã',
    'Đổi mật khẩu',
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
        title: Text('Lỗi',
            style: SLTheme.quicksand(
                color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(msg, style: SLTheme.quicksand()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Đóng', style: SLTheme.quicksand()),
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
          houseUser1Name = n1.isNotEmpty ? n1 : 'Thành viên 1';
          houseUser2Name = n2.isNotEmpty ? n2 : 'Thành viên 2';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          houseUser1Name = 'Thành viên 1';
          houseUser2Name = 'Thành viên 2';
        });
      }
    }
  }

  Future<void> handleHouseLookup() async {
    final input = houseCtrl.text.trim();
    if (input.isEmpty) {
      _showErrorDialog('Vui lòng nhập mã nhà hoặc Email trước.');
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
        if (mounted) {
          setState(() {
            isSendingRecoveryCode = false;
            linkSentEmail = '';
            step = 1;
          });
        }
        if (resolvedMessage.contains('không tìm thấy') ||
            resolvedMessage.contains('user-not-found') ||
            resolvedMessage.contains('không tồn tại')) {
          _showErrorDialog(
              'Email này không tồn tại trong hệ thống. Vui lòng kiểm tra lại.');
        } else {
          _showErrorDialog(
              'Chưa thể gửi mã khôi phục lúc này. Vui lòng thử lại sau.');
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
        _showErrorDialog(
          'Không tìm thấy mã nhà này hoặc nhà chưa có dữ liệu khôi phục.',
        );
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

      _showErrorDialog(
        'Nhà này chưa có đủ dữ liệu khôi phục. Vui lòng liên hệ hỗ trợ.',
      );
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  Future<void> handleAnswerVerify() async {
    final rawAnswer = answerCtrl.text.trim();
    if (rawAnswer.isEmpty) {
      _showErrorDialog('Vui lòng nhập câu trả lời bảo mật.');
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
      _showErrorDialog('Câu trả lời bảo mật không chính xác.');
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
      _showErrorDialog('Vui lòng nhập email đăng ký hợp lệ.');
      return;
    }

    if (fullEmail.isNotEmpty &&
        enteredEmail != _normalizeRecoveryEmail(fullEmail)) {
      _showErrorDialog(
        'Email bạn nhập chưa khớp với email bảo mật của nhà.',
      );
      return;
    }

    if (fullEmail.isEmpty &&
        maskedEmail.isNotEmpty &&
        !_emailMatchesMaskedHint(enteredEmail, maskedEmail)) {
      _showErrorDialog(
        'Email bạn nhập chưa khớp với gợi ý bảo mật của nhà.',
      );
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
      if (mounted) {
        setState(() {
          isBusy = false;
          isSendingRecoveryCode = false;
          linkSentEmail = '';
          step = 3;
        });
      }
      if (resolvedMessage.contains('không tìm thấy') ||
          resolvedMessage.contains('user-not-found') ||
          resolvedMessage.contains('không tồn tại')) {
        _showErrorDialog(
            'Email này không tồn tại trong hệ thống. Vui lòng kiểm tra lại.');
      } else {
        _showErrorDialog('Lỗi gửi mã khôi phục: $resolvedMessage');
      }
    }
  }

  Future<void> handleVerifyOtpAndCreatePassword() async {
    final otp = otpCtrl.text.trim();
    final newPwd = newPwdCtrl.text;
    if (otp.length != 6) {
      _showErrorDialog('Vui lòng nhập đủ 6 số mã xác nhận.');
      return;
    }
    if (newPwd.length < 6) {
      _showErrorDialog('Mật khẩu mới phải có ít nhất 6 ký tự.');
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
            title: Text('Thành công',
                style: SLTheme.quicksand(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            content: Text('Mật khẩu đã được cập nhật thành công.',
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
                child: const Text('VỀ TRANG CHỦ',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(
          'Chưa thể đặt lại mật khẩu lúc này. Vui lòng thử lại sau.');
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: SLTheme.quicksand(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: accent.withValues(alpha: 0.88),
                    letterSpacing: 0.5,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2F2A2E),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    color: const Color(0xFF6F6670),
                    height: 1.4,
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
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: Colors.grey[600],
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
      hintStyle: SLTheme.quicksand(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: const Color(0xFFD81B60)),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      isDense: true,
      filled: true,
      fillColor: _recoveryAccentSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF2C8D7), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.5),
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
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: isEnabled ? _recoveryButtonColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(18),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: _recoveryButtonColor.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SLSpacing.w8,
                      Icon(icon, color: Colors.white, size: 20),
                    ],
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
                      _recoveryStepLabels[currentIndex],
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
                      'Thành viên trong nhà',
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
                  'Đang chờ bạn nhập mã xác nhận trong email.\nMã có hiệu lực trong thời gian ngắn, hãy dùng mã mới nhất.',
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
                '💡 Lưu ý:',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _recoveryAccentDark,
                ),
              ),
              SLSpacing.h4,
              _buildTip('Kiểm tra thư mục Spam/Junk nếu không thấy email.'),
              _buildTip('Mã có hiệu lực trong thời gian ngắn.'),
              _buildTip(
                  'Nhập mã 6 số trong email để đặt lại mật khẩu trực tiếp trong app.'),
            ],
          ),
        ),
        SLSpacing.gapH(28),
        // ── Resend button ────────────────────────────────────────────
        _buildRecoveryActionButton(
          label: 'Gửi lại mã khôi phục',
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
                            'Đã gửi lại mã khôi phục.',
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
                    _showErrorDialog(
                        'Chưa thể gửi lại mã khôi phục lúc này. Vui lòng thử lại sau.');
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
          eyebrow: 'BƯỚC 4 • ĐẶT LẠI MẬT KHẨU',
          title: isSendingRecoveryCode
              ? 'Đang gửi mã xác nhận'
              : 'Nhập mã xác nhận',
          description: isSendingRecoveryCode
              ? 'Đang gửi mã xác nhận 6 số đến:\n$sentTo\nMàn hình nhập mã đã sẵn sàng, bạn chỉ cần chờ email gửi tới.'
              : 'Mã xác nhận 6 số vừa được gửi đến:\n$sentTo',
          icon: Icons.mark_email_unread_rounded,
          accent: const Color(0xFFD81B60),
        ),
        SLSpacing.h24,
        _buildSectionLabel('Mã xác nhận (6 số)'),
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
        _buildSectionLabel('Mật khẩu mới'),
        SLSpacing.h8,
        TextField(
          controller: newPwdCtrl,
          enabled: !isBusy,
          obscureText: isObscure,
          style: SLTheme.quicksand(),
          decoration: _recoveryInputDecoration(
            hintText: 'Nhập mật khẩu mới (ít nhất 6 ký tự)',
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
              ? 'Đang gửi mã xác nhận...'
              : isBusy
                  ? 'Đang xử lý...'
                  : 'Xác nhận & Đổi mật khẩu',
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
                            content: Text('Đã gửi lại mã xác nhận.',
                                style: SLTheme.quicksand()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      _showErrorDialog(
                          'Chưa thể gửi lại mã xác nhận lúc này. Vui lòng thử lại sau.');
                    } finally {
                      if (mounted) {
                        setState(() {
                          isBusy = false;
                          isSendingRecoveryCode = false;
                        });
                      }
                    }
                  },
            child: Text('Chưa nhận được mã? Gửi lại',
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
              eyebrow: 'BƯỚC 2 • CÂU HỎI BẢO MẬT',
              title: question,
              description:
                  'Trả lời đúng để mở bước gửi mã khôi phục đến email đã đăng ký.',
              icon: Icons.help_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel('Câu trả lời của bạn'),
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
                    ? 'ngày/tháng/năm'
                    : 'Nhập câu trả lời...',
                icon: _isBirthRecoveryQuestion
                    ? Icons.calendar_month_rounded
                    : Icons.key_rounded,
                helperText: _isBirthRecoveryQuestion
                    ? 'Đang nhập ngày/tháng/năm'
                    : null,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label:
                  isBusy ? 'Đang kiểm tra câu trả lời...' : 'Kiểm tra đáp án',
              onTap: isBusy ? null : handleAnswerVerify,
              busy: isBusy,
              icon: Icons.verified_user_rounded,
            ),
          ],
        );
      case 3:
        final description = maskedEmail.isNotEmpty
            ? 'Gợi ý email bảo mật: $maskedEmail\nNhập đầy đủ email đăng ký để hệ thống gửi mã khôi phục.'
            : 'Nhập email đăng ký đầy đủ để hệ thống gửi mã khôi phục.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecoveryInfoCard(
              eyebrow: 'BƯỚC 3 • GỬI MÃ KHÔI PHỤC',
              title: 'Xác minh thành công',
              description: description,
              icon: Icons.mark_email_read_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel(
              'Email đăng ký đầy đủ',
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
                hintText: 'Nhập email đăng ký đầy đủ...',
                icon: Icons.alternate_email_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy ? 'Đang gửi mã khôi phục...' : 'Gửi mã khôi phục',
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
              eyebrow: 'BƯỚC 1 • XÁC MINH NHÀ / EMAIL',
              title: 'Nhập mã nhà hoặc Email',
              description:
                  'Hệ thống sẽ tự động phân tích. Nhập Email để nhận mã khôi phục, hoặc mã nhà để trả lời câu hỏi bảo mật.',
              icon: Icons.home_rounded,
              accent: const Color(0xFFD81B60),
            ),
            SLSpacing.h20,
            _buildSectionLabel('Mã nhà hoặc Email'),
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
                hintText: 'VD: NH_K2L9... hoặc abc@gmail.com',
                icon: Icons.vpn_key_rounded,
              ),
            ),
            SLSpacing.h24,
            _buildRecoveryActionButton(
              label: isBusy ? 'Đang xử lý...' : 'Tiếp tục',
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
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF8FB),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87),
            onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Khôi phục mật khẩu',
            style: SLTheme.quicksand(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: _recoveryButtonColor.withValues(alpha: 0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: _recoveryButtonColor.withValues(alpha: 0.06),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        // From step 4 go back to start
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
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text(
                              step == 4 ? 'Bắt đầu lại' : 'Quay lại bước trước',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD81B60),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
