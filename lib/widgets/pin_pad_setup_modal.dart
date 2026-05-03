import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/sl_theme.dart';
import 'sensitive_content_guard.dart';

part 'pin_pad_setup/pin_pad_background_part.dart';

class PinPadSetupModal extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool isConfirming;
  final String? firstPin;
  final bool isUnlock;
  final String? correctPin;
  final Future<PinUnlockResult> Function(String pin)? unlockValidator;
  final int? unlockPinLength;
  final int initialLockSeconds;
  final bool enableForgotPin;
  final String? forgotPinHint;
  final Future<bool> Function()? onForgotPin;
  final Function(String pin) onCompleted;

  const PinPadSetupModal({
    super.key,
    this.title = 'Thiết lập mã PIN',
    this.subtitle,
    this.isConfirming = false,
    this.firstPin,
    this.isUnlock = false,
    this.correctPin,
    this.unlockValidator,
    this.unlockPinLength,
    this.initialLockSeconds = 0,
    this.enableForgotPin = false,
    this.forgotPinHint,
    this.onForgotPin,
    required this.onCompleted,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'Thiết lập mã PIN',
    String? subtitle,
    bool isConfirming = false,
    String? firstPin,
    bool isUnlock = false,
    String? correctPin,
    Future<PinUnlockResult> Function(String pin)? unlockValidator,
    int? unlockPinLength,
    int initialLockSeconds = 0,
    bool enableForgotPin = false,
    String? forgotPinHint,
    Future<bool> Function()? onForgotPin,
  }) async {
    return Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 110),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PinPadSetupModal(
            title: title,
            subtitle: subtitle,
            isConfirming: isConfirming,
            firstPin: firstPin,
            isUnlock: isUnlock,
            correctPin: correctPin,
            unlockValidator: unlockValidator,
            unlockPinLength: unlockPinLength,
            initialLockSeconds: initialLockSeconds,
            enableForgotPin: enableForgotPin,
            forgotPinHint: forgotPinHint,
            onForgotPin: onForgotPin,
            onCompleted: (pin) => Navigator.of(context).pop(pin),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.996,
                end: 1,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<PinPadSetupModal> createState() => _PinPadSetupModalState();
}

class _PinPadSetupModalState extends State<PinPadSetupModal> {
  String _currentPin = '';
  final int _minPinLength = 4;
  final int _maxPinLength = 8;
  bool _hasError = false;
  String? _errorMessage;
  int _remainingLockSeconds = 0;
  bool _isSubmitting = false;
  bool _isRecoveringPin = false;
  bool _canUseForgotPin = false;
  Timer? _lockTimer;

  bool get _isInputLocked =>
      _remainingLockSeconds > 0 || _isSubmitting || _isRecoveringPin;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  int _localFailCount = 0;

  @override
  void initState() {
    super.initState();
    _remainingLockSeconds = widget.initialLockSeconds;
    _canUseForgotPin = widget.enableForgotPin;
    if (_remainingLockSeconds > 0) {
      _startLockCountdown(_remainingLockSeconds);
    } else if (widget.isUnlock && widget.correctPin != null) {
      _checkLocalLockout();
    }
  }

  Future<void> _checkLocalLockout() async {
    final failStr = await _secureStorage.read(key: 'pinpad_fail_count');
    final lockUntilStr = await _secureStorage.read(key: 'pinpad_lock_until');
    _localFailCount = int.tryParse(failStr ?? '0') ?? 0;
    final lockUntil = int.tryParse(lockUntilStr ?? '0') ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntil > now) {
      if (mounted) {
        _startLockCountdown(((lockUntil - now) / 1000).ceil());
      }
    } else if (lockUntil > 0) {
      await _secureStorage.delete(key: 'pinpad_lock_until');
    }
  }

  Future<void> _recordLocalFail() async {
    _localFailCount++;
    await _secureStorage.write(
        key: 'pinpad_fail_count', value: _localFailCount.toString());

    int lockSeconds = 0;
    if (_localFailCount >= 10) {
      lockSeconds = 300;
    } else if (_localFailCount >= 5) {
      lockSeconds = 30;
    }

    if (lockSeconds > 0) {
      final lockUntil =
          DateTime.now().millisecondsSinceEpoch + (lockSeconds * 1000);
      await _secureStorage.write(
          key: 'pinpad_lock_until', value: lockUntil.toString());
      _startLockCountdown(lockSeconds);
    } else {
      _showLocalError();
    }
  }

  Future<void> _clearLocalFail() async {
    _localFailCount = 0;
    await _secureStorage.delete(key: 'pinpad_fail_count');
    await _secureStorage.delete(key: 'pinpad_lock_until');
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _onNumberPressed(String number) async {
    if (_isInputLocked || _currentPin.length >= _pinSlotCount) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _currentPin += number;
      _hasError = false;
      _errorMessage = null;
    });

    final validator = widget.unlockValidator;
    final targetLength = widget.correctPin?.length ?? widget.unlockPinLength;

    if (widget.isUnlock &&
        validator != null &&
        targetLength != null &&
        _currentPin.length == targetLength) {
      await _submitUnlockAttempt(_currentPin);
      return;
    }

    if (widget.isUnlock && widget.correctPin != null) {
      if (_currentPin.length == widget.correctPin!.length) {
        if (_currentPin == widget.correctPin) {
          HapticFeedback.heavyImpact();
          await _clearLocalFail();
          widget.onCompleted(_currentPin);
        } else {
          await _recordLocalFail();
        }
      }
    }

    if (widget.isConfirming &&
        widget.firstPin != null &&
        _currentPin.length == widget.firstPin!.length) {
      await _onSubmit();
    }
  }

  void _onDeletePressed() {
    if (_isInputLocked) {
      return;
    }

    if (_currentPin.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_isInputLocked) {
      return;
    }

    if (_currentPin.length < _minimumSubmitLength) {
      setState(() {
        _hasError = true;
        _errorMessage = _defaultHintText;
      });
      HapticFeedback.vibrate();
      return;
    }

    if (widget.isConfirming &&
        widget.firstPin != null &&
        _currentPin != widget.firstPin) {
      HapticFeedback.vibrate();
      setState(() {
        _hasError = true;
        _currentPin = '';
        _errorMessage = 'Hai lần nhập chưa khớp nhau. Mình nhập lại nhé.';
      });
      return;
    }

    if (widget.isUnlock && widget.unlockValidator != null) {
      await _submitUnlockAttempt(_currentPin);
      return;
    }

    if (widget.isUnlock &&
        widget.correctPin != null &&
        _currentPin != widget.correctPin) {
      await _recordLocalFail();
      return;
    }

    if (widget.isUnlock && widget.correctPin != null) {
      await _clearLocalFail();
    }

    widget.onCompleted(_currentPin);
  }

  Future<void> _submitUnlockAttempt(String pin) async {
    final validator = widget.unlockValidator;
    if (validator == null) {
      widget.onCompleted(pin);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await validator(pin);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (result.status == PinUnlockStatus.success) {
      HapticFeedback.heavyImpact();
      widget.onCompleted(pin);
      return;
    }

    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
      _currentPin = '';
      _errorMessage = result.message;
      _canUseForgotPin = _canUseForgotPin || result.canRecoverWithEmail;
    });

    if (result.status == PinUnlockStatus.blocked &&
        result.remainingLockSeconds > 0) {
      _startLockCountdown(result.remainingLockSeconds);
    }
  }

  Future<void> _handleForgotPin() async {
    final onForgotPin = widget.onForgotPin;
    if (onForgotPin == null || _isRecoveringPin || !_canUseForgotPin) {
      return;
    }

    setState(() {
      _isRecoveringPin = true;
      _hasError = false;
      _errorMessage = null;
    });

    bool recovered = false;
    try {
      recovered = await onForgotPin();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _isRecoveringPin = false;
    });

    if (recovered) {
      widget.onCompleted('');
    }
  }

  void _showLocalError() {
    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
      _currentPin = '';
      _errorMessage = 'Mã PIN chưa đúng. Hãy thử lại.';
    });
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() {
      _remainingLockSeconds = seconds;
      _currentPin = '';
      _hasError = true;
      _errorMessage =
          'Bạn đã nhập sai quá nhiều lần. Thử lại sau $_remainingLockSeconds giây.';
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingLockSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingLockSeconds = 0;
          _hasError = false;
          _errorMessage = null;
        });
        return;
      }

      setState(() {
        _remainingLockSeconds -= 1;
        _errorMessage =
            'Bạn đã nhập sai quá nhiều lần. Thử lại sau $_remainingLockSeconds giây.';
      });
    });
  }

  String _cleanUiText(String raw, {String fallback = ''}) {
    if (raw.trim().isEmpty) {
      return fallback;
    }

    final value = raw.replaceAll('Quên mã pin?', 'Quên mã PIN?').replaceAll(
          'Quên mã pin sau khi nhập sai 5 lần',
          'Quên mã PIN sau khi nhập sai 5 lần',
        );

    const mojibakeMarkers = <String>[
      '\u00C3',
      '\u00C6',
      '\u00E1\u00BA',
      '\u00E1\u00BB',
    ];

    if (mojibakeMarkers.any(value.contains)) {
      return fallback.isNotEmpty ? fallback : value;
    }
    return value;
  }

  String get _resolvedTitle =>
      _cleanUiText(widget.title, fallback: 'Thiết lập mã PIN');

  String get _resolvedSubtitle {
    final fallback = widget.isUnlock
        ? 'Nhập mã PIN để mở khóa ứng dụng.'
        : widget.isConfirming
            ? 'Nhập lại đúng mã PIN vừa rồi để xác nhận.'
            : 'Nhập 4-8 chữ số để khóa ứng dụng.';
    final raw = (widget.subtitle ?? _defaultSubtitle).trim();
    return raw.isEmpty ? fallback : _cleanUiText(raw, fallback: fallback);
  }

  String get _resolvedCuteMessage {
    final fallback = widget.isUnlock
        ? 'Mở cánh cửa riêng tư của hai bạn thôi nào 💖'
        : widget.isConfirming
            ? 'Xác nhận lại chiếc chìa khóa nhỏ xinh này nhé ✨'
            : 'Tạo một chiếc chìa khóa đáng yêu để giữ mọi điều riêng tư thật an toàn.';
    return _cleanUiText(_cuteMessage, fallback: fallback);
  }

  String get _resolvedHintText {
    final fallback = _pinSlotCount == _maxPinLength
        ? 'Nhập từ 4 đến 8 số.'
        : 'Nhập đủ $_pinSlotCount số để tiếp tục.';
    return _cleanUiText(_defaultHintText, fallback: fallback);
  }

  String get _resolvedProgressText {
    final fallback = _pinSlotCount == _maxPinLength
        ? '${_currentPin.length}/8 số · tối thiểu 4 số'
        : '${_currentPin.length}/$_pinSlotCount số';
    return _cleanUiText(_pinProgressText, fallback: fallback);
  }

  String get _forgotPinActionLabel {
    if (_isRecoveringPin) {
      return 'Đang khôi phục mã PIN...';
    }
    return 'Quên mã PIN?';
  }

  String get _forgotPinDisabledLabel => 'Quên mã PIN sau khi nhập sai 5 lần';

  String get _confirmDeliveryHint =>
      'Mã xác nhận sẽ chỉ gửi tới ${widget.forgotPinHint}.';

  String get _primaryActionLabel =>
      widget.isConfirming ? 'XÁC NHẬN' : 'TIẾP TỤC';

  double _keypadButtonSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= SLResponsive.tablet) return 84;
    if (width < 360) return 68;
    return 76;
  }

  double _dotSpacing(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 360 ? 5 : 8;
  }

  Widget _buildFullscreenBody(BuildContext context, String displayedError) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxPanelWidth = screenWidth >= SLResponsive.tablet ? 560.0 : 520.0;
    final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
      screenWidth,
      compactPadding: 18,
      handsetPadding: 22,
      tabletPadding: 28,
    );

    return PopScope(
      canPop: !widget.isUnlock,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8EEF4),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF8FB),
                      Color(0xFFFBEFF5),
                      Color(0xFFF6EAF0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            _buildAmbientOrb(
              alignment: const Alignment(-1.12, -0.82),
              color: const Color(0x14D81B60),
              size: 180,
            ),
            _buildAmbientOrb(
              alignment: const Alignment(1.08, -0.18),
              color: const Color(0x12FFB6C9),
              size: 220,
            ),
            _buildAmbientOrb(
              alignment: const Alignment(0.82, 1.06),
              color: const Color(0x108E6BE8),
              size: 200,
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  18,
                  horizontalPadding,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxPanelWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.isUnlock)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: SLColors.textSecond,
                              tooltip: 'Đóng',
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                        const SizedBox(height: 8),
                        _buildFullscreenHeader(displayedError, context),
                        const SizedBox(height: 28),
                        _buildFullscreenKeypadSection(context),
                        if (widget.isUnlock) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _canUseForgotPin && !_isRecoveringPin
                                ? _handleForgotPin
                                : null,
                            child: Text(
                              _canUseForgotPin
                                  ? _forgotPinActionLabel
                                  : _forgotPinDisabledLabel,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _canUseForgotPin
                                    ? SLColors.primary
                                    : SLColors.primary.withOpacity(0.45),
                              ),
                            ),
                          ),
                          if ((widget.forgotPinHint ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Text(
                                _confirmDeliveryHint,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textSecond,
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                        if (!widget.isUnlock) ...[
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: SLColors.textSecond,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: BorderSide(
                                      color: SLColors.primary.withOpacity(0.18),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text(
                                    'Hủy bỏ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              SLSpacing.w12,
                              Expanded(
                                flex: 2,
                                child: SLTheme.primaryButton(
                                  text: _primaryActionLabel,
                                  onPressed: _currentPin.length >=
                                              _minimumSubmitLength &&
                                          !_isInputLocked
                                      ? _onSubmit
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientOrb({
    required Alignment alignment,
    required Color color,
    required double size,
  }) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenHeader(
    String displayedError,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
              border: Border.all(
                color: SLColors.primary.withOpacity(0.12),
              ),
            ),
            child: Icon(
              widget.isUnlock
                  ? Icons.lock_open_rounded
                  : Icons.lock_person_rounded,
              color: SLColors.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _resolvedTitle,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: SLColors.primaryActive,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _resolvedSubtitle,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: SLColors.textPrimary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _resolvedCuteMessage,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SLColors.textSecond,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _buildPinDots(context),
        const SizedBox(height: 12),
        Text(
          _resolvedProgressText,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _hasError ? SLColors.danger : SLColors.textSecond,
          ),
        ),
        if (_hasError) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: SLColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SLColors.danger.withOpacity(0.16),
              ),
            ),
            child: Text(
              displayedError,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SLColors.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFullscreenKeypadSection(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.7)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 24, 6, 0),
        child: RepaintBoundary(
          child: _buildKeypad(context),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyPolishedBody(BuildContext context, String displayedError) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxPanelWidth = screenWidth >= SLResponsive.tablet ? 560.0 : 520.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SLColors.bgMain,
                    Color(0xFFFFEFE8),
                    SLColors.secondarySoft,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: FloatingBackgroundIcons(
                emojis: ['💖', '✨', '☁️', '🌸', '🎀', '💌', '🌷'],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: SLResponsive.horizontalPaddingForWidth(
                    screenWidth,
                    compactPadding: 14,
                    handsetPadding: 18,
                    tabletPadding: 24,
                  ),
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: SLResponsive.clampPanelWidth(
                      screenWidth,
                      max: maxPanelWidth,
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SLColors.bgElevated.withOpacity(0.96),
                          SLColors.surfaceWarm.withOpacity(0.94),
                          SLColors.secondarySoft.withOpacity(0.90),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SLColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: SLColors.primary.withOpacity(0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: SLColors.secondary.withOpacity(0.08),
                          blurRadius: 36,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SLSpacing.h12,
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SLColors.bgElevated,
                            boxShadow: [
                              BoxShadow(
                                color: SLColors.primary.withOpacity(0.14),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.isUnlock
                                ? Icons.lock_open_rounded
                                : Icons.lock_person_rounded,
                            color: SLColors.primary,
                            size: 32,
                          ),
                        ),
                        SLSpacing.h16,
                        Text(
                          _resolvedTitle,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: SLColors.primaryActive,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SLSpacing.h12,
                        Text(
                          _resolvedSubtitle,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          _resolvedCuteMessage,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textSecond,
                            height: 1.4,
                          ),
                        ),
                        SLSpacing.h20,
                        _buildPinDots(context),
                        SLSpacing.h12,
                        Text(
                          _resolvedProgressText,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _hasError
                                ? SLColors.danger
                                : SLColors.textSecond,
                          ),
                        ),
                        if (_hasError) ...[
                          SLSpacing.h12,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: SLColors.danger.withOpacity(0.10),
                              borderRadius: SLRadius.mdAll,
                              border: Border.all(
                                color: SLColors.danger.withOpacity(0.20),
                              ),
                            ),
                            child: Text(
                              displayedError,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: SLColors.danger,
                              ),
                            ),
                          ),
                        ],
                        SLSpacing.h24,
                        _buildKeypad(context),
                        if (widget.isUnlock) ...[
                          SLSpacing.h12,
                          TextButton(
                            onPressed: _canUseForgotPin && !_isRecoveringPin
                                ? _handleForgotPin
                                : null,
                            child: Text(
                              _canUseForgotPin
                                  ? _forgotPinActionLabel
                                  : _forgotPinDisabledLabel,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _canUseForgotPin
                                    ? SLColors.primary
                                    : SLColors.primary.withOpacity(0.45),
                              ),
                            ),
                          ),
                          if ((widget.forgotPinHint ?? '').trim().isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _confirmDeliveryHint,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textSecond,
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                        SLSpacing.h12,
                        if (!widget.isUnlock) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    foregroundColor: SLColors.textSecond,
                                  ),
                                  child: const Text(
                                    'Hủy bỏ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              SLSpacing.w16,
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            SLColors.primary.withOpacity(0.24),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: SLTheme.primaryButton(
                                    text: _primaryActionLabel,
                                    onPressed: _currentPin.length >=
                                                _minimumSubmitLength &&
                                            !_isInputLocked
                                        ? _onSubmit
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots(BuildContext context) {
    final dotSpacing = _dotSpacing(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinSlotCount, (index) {
        bool isActive = index < _currentPin.length;
        bool isNext = index == _currentPin.length;
        final isRequiredSlot = index < _requiredPinLength;
        final inactiveRequiredSize =
            MediaQuery.sizeOf(context).width < 360 ? 12.0 : 14.0;
        final inactiveOptionalSize =
            MediaQuery.sizeOf(context).width < 360 ? 9.0 : 10.0;
        final activeSize =
            MediaQuery.sizeOf(context).width >= SLResponsive.tablet
                ? 22.0
                : 20.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: dotSpacing),
          width: isActive
              ? activeSize
              : (isRequiredSlot ? inactiveRequiredSize : inactiveOptionalSize),
          height: isActive
              ? activeSize
              : (isRequiredSlot ? inactiveRequiredSize : inactiveOptionalSize),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? SLColors.primary
                : (isRequiredSlot
                    ? SLColors.bgElevated.withOpacity(0.72)
                    : SLColors.bgElevated.withOpacity(0.34)),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: SLColors.primary.withOpacity(0.36),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : null,
            border: isNext && index < _pinSlotCount
                ? Border.all(color: SLColors.primary, width: 2.2)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(BuildContext context) {
    final buttonSize = _keypadButtonSize(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var j = 1; j <= 3; j++)
                  _buildKeypadButton(
                    (i * 3 + j).toString(),
                    context: context,
                    size: buttonSize,
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: buttonSize, height: buttonSize),
            _buildKeypadButton('0', context: context, size: buttonSize),
            _buildKeypadButton(
              'delete',
              context: context,
              size: buttonSize,
              icon: Icons.backspace_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(
    String value, {
    required BuildContext context,
    required double size,
    IconData? icon,
  }) {
    bool isDelete = value == 'delete';
    final onTap = _isInputLocked
        ? null
        : (isDelete ? _onDeletePressed : () => _onNumberPressed(value));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: SLColors.primary.withOpacity(0.15),
        highlightColor: SLColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDelete
                ? Colors.transparent
                : SLColors.bgElevated.withOpacity(0.78),
            border: Border.all(
              color: isDelete
                  ? Colors.transparent
                  : SLColors.bgElevated.withOpacity(0.86),
              width: 1.5,
            ),
            boxShadow: isDelete
                ? null
                : [
                    BoxShadow(
                      color: SLColors.primary.withOpacity(0.08),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  color: _isInputLocked
                      ? SLColors.primary.withOpacity(0.4)
                      : SLColors.primary,
                  size: size * 0.42,
                )
              : Text(
                  value,
                  style: SLTheme.quicksand(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: _isInputLocked
                        ? SLColors.primary.withOpacity(0.4)
                        : SLColors.primary,
                  ),
                ),
        ),
      ),
    );
  }

  int get _resolvedPinLength {
    final unlockLength = widget.unlockPinLength;
    if (unlockLength != null &&
        unlockLength >= _minPinLength &&
        unlockLength <= _maxPinLength) {
      return unlockLength;
    }
    final firstPinLength = widget.firstPin?.trim().length;
    if (firstPinLength != null &&
        firstPinLength >= _minPinLength &&
        firstPinLength <= _maxPinLength) {
      return firstPinLength;
    }
    final correctPinLength = widget.correctPin?.trim().length;
    if (correctPinLength != null &&
        correctPinLength >= _minPinLength &&
        correctPinLength <= _maxPinLength) {
      return correctPinLength;
    }
    return _maxPinLength;
  }

  int get _requiredPinLength {
    return _resolvedPinLength == _maxPinLength
        ? _minPinLength
        : _resolvedPinLength;
  }

  int get _minimumSubmitLength {
    return _resolvedPinLength == _maxPinLength
        ? _minPinLength
        : _resolvedPinLength;
  }

  int get _pinSlotCount {
    return _resolvedPinLength;
  }

  String get _defaultSubtitle {
    if (widget.isUnlock) {
      return 'Nhập mã PIN để mở khóa ứng dụng.';
    }
    if (widget.isConfirming) {
      return 'Nhập lại đúng mã PIN vừa rồi để xác nhận.';
    }
    return 'Nhập 4-8 chữ số để khóa ứng dụng.';
  }

  String get _cuteMessage {
    if (widget.isUnlock) {
      return 'Mở cánh cửa riêng tư của hai bạn thôi nào 💖';
    }
    if (widget.isConfirming) {
      return 'Xác nhận lại chiếc chìa khóa nhỏ xinh này nhé ✨';
    }
    return 'Tạo một chiếc chìa khóa đáng yêu để giữ mọi điều riêng tư thật an toàn.';
  }

  String get _defaultHintText {
    if (_pinSlotCount == _maxPinLength) {
      return 'Nhập từ 4 đến 8 số.';
    }
    return 'Nhập đủ $_pinSlotCount số để tiếp tục.';
  }

  String get _pinProgressText {
    if (_pinSlotCount == _maxPinLength) {
      return '${_currentPin.length}/8 số · tối thiểu 4 số';
    }
    return '${_currentPin.length}/$_pinSlotCount số';
  }

  @override
  Widget build(BuildContext context) {
    final displayedError = _cleanUiText(
      _errorMessage ?? _resolvedHintText,
      fallback: _resolvedHintText,
    );
    return SensitiveContentGuard(
      child: _buildFullscreenBody(context, displayedError),
    );
    // ignore: dead_code
    return SensitiveContentGuard(
      child: Scaffold(
        backgroundColor:
            const Color(0xFFFCE4EC), // Màu nền hồng pastel dễ thương
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SLColors.bgMain,
                      Color(0xFFFFEFE8),
                      SLColors.secondarySoft,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Hiệu ứng icon rơi
            const Positioned.fill(
              child: IgnorePointer(
                child: FloatingBackgroundIcons(
                  emojis: ['💖', '✨', '☁️', '🌸', '🎀', '💌', '🌷'],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: SLResponsive.horizontalPaddingForWidth(
                      MediaQuery.sizeOf(context).width,
                      compactPadding: 14,
                      handsetPadding: 18,
                      tabletPadding: 24,
                    ),
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: SLResponsive.clampPanelWidth(
                        MediaQuery.sizeOf(context).width,
                        max: MediaQuery.sizeOf(context).width >=
                                SLResponsive.tablet
                            ? 560
                            : 520,
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SLColors.bgElevated.withOpacity(0.96),
                            SLColors.surfaceWarm.withOpacity(0.94),
                            SLColors.secondarySoft.withOpacity(0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SLColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: SLColors.primary.withOpacity(0.10),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                          BoxShadow(
                            color: SLColors.secondary.withOpacity(0.08),
                            blurRadius: 36,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SLSpacing.h12,
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: SLColors.primary.withOpacity(0.14),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.isUnlock
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_person_rounded,
                              color: SLColors.primary,
                              size: 32,
                            ),
                          ),
                          SLSpacing.h16,
                          Text(
                            _resolvedTitle,
                            style: SLTheme.quicksand(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: SLColors.primaryActive,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SLSpacing.h12,
                          Text(
                            _resolvedSubtitle,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: SLColors.textPrimary,
                            ),
                          ),
                          SLSpacing.h8,
                          Text(
                            _resolvedCuteMessage,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SLColors.textSecond,
                              height: 1.35,
                            ),
                          ),
                          SLSpacing.h20,
                          _buildPinDots(context),
                          SLSpacing.h12,
                          Text(
                            _resolvedProgressText,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _hasError
                                  ? SLColors.danger
                                  : SLColors.textSecond,
                            ),
                          ),
                          if (_hasError) ...[
                            SLSpacing.h12,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: SLColors.danger.withOpacity(0.1),
                                borderRadius: SLRadius.mdAll,
                                border: Border.all(
                                    color: SLColors.danger.withOpacity(0.2)),
                              ),
                              child: Text(
                                displayedError,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: SLColors.danger,
                                ),
                              ),
                            ),
                          ],
                          SLSpacing.h24,
                          _buildKeypad(context),
                          if (widget.isUnlock) ...[
                            SLSpacing.h12,
                            TextButton(
                              onPressed: _canUseForgotPin && !_isRecoveringPin
                                  ? _handleForgotPin
                                  : null,
                              child: Text(
                                _canUseForgotPin
                                    ? (_isRecoveringPin
                                        ? 'Đang khôi phục mã PIN...'
                                        : 'Quên mã pin?')
                                    : 'Quên mã pin sau khi nhập sai 5 lần',
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _canUseForgotPin
                                      ? const Color(0xFFD81B60)
                                      : const Color(0xFFD81B60)
                                          .withOpacity(0.45),
                                ),
                              ),
                            ),
                            if ((widget.forgotPinHint ?? '').trim().isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Mã xác nhận sẽ chỉ gửi tới ${widget.forgotPinHint}.',
                                  textAlign: TextAlign.center,
                                  style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                          SLSpacing.h12,
                          if (!widget.isUnlock) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      foregroundColor: Colors.black54,
                                    ),
                                    child: const Text('Hủy bỏ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            letterSpacing: 1.1)),
                                  ),
                                ),
                                SLSpacing.w16,
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD81B60)
                                              .withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: SLTheme.primaryButton(
                                      text: widget.isConfirming
                                          ? 'XÁC NHẬN'
                                          : 'TIẾP TỤC',
                                      onPressed: _currentPin.length >=
                                                  _minimumSubmitLength &&
                                              !_isInputLocked
                                          ? _onSubmit
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
