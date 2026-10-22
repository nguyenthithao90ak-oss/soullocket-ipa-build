import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/sl_route.dart';
import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';
import 'sensitive_content_guard.dart';
import 'sl_settings_kit.dart';

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
  final bool enableBiometrics;
  final VoidCallback? onBiometricPressed;
  final Function(String pin) onCompleted;

  const PinPadSetupModal({
    super.key,
    this.title = '',
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
    this.enableBiometrics = false,
    this.onBiometricPressed,
    required this.onCompleted,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = '',
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
    bool enableBiometrics = false,
    VoidCallback? onBiometricPressed,
  }) async {
    return slPushRoute<String>(
      context,
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
            enableBiometrics: enableBiometrics,
            onBiometricPressed: onBiometricPressed,
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
      identity: PinPadSetupModal,
      rootNavigator: true,
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
        _errorMessage = L10nService().translate('pin_mismatch');
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
        _errorMessage = L10nService().translate('pin_recover_failed');
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
      _errorMessage = L10nService().translate('pin_incorrect');
    });
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() {
      _remainingLockSeconds = seconds;
      _currentPin = '';
      _hasError = true;
      _errorMessage = L10nService().format(
          'pin_too_many_attempts_retry_seconds',
          {'seconds': _remainingLockSeconds});
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
        _errorMessage = L10nService().format(
            'pin_too_many_attempts_retry_seconds',
            {'seconds': _remainingLockSeconds});
      });
    });
  }

  String _cleanUiText(String raw, {String fallback = ''}) {
    if (raw.trim().isEmpty) {
      return fallback;
    }

    final value = raw
        .replaceAll('Quên mã pin?', L10nService().translate('pin_forgot'))
        .replaceAll(
          'Quên mã pin sau khi nhập sai 5 lần',
          L10nService().translate('pin_forgot_after_5'),
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

  String get _resolvedTitle => _cleanUiText(widget.title,
      fallback: L10nService().translate('pin_setup_title'));

  String get _resolvedSubtitle {
    final fallback = widget.isUnlock
        ? L10nService().translate('pin_unlock_subtitle')
        : widget.isConfirming
            ? L10nService().translate('pin_confirm_subtitle')
            : L10nService().translate('pin_setup_subtitle');
    final raw = (widget.subtitle ?? _defaultSubtitle).trim();
    return raw.isEmpty ? fallback : _cleanUiText(raw, fallback: fallback);
  }

  String get _resolvedCuteMessage {
    final fallback = widget.isUnlock
        ? L10nService().translate('pin_cute_unlock')
        : widget.isConfirming
            ? L10nService().translate('pin_cute_confirm')
            : L10nService().translate('pin_cute_setup');
    return _cleanUiText(_cuteMessage, fallback: fallback);
  }

  String get _resolvedHintText {
    final fallback = _pinSlotCount == _maxPinLength
        ? L10nService().translate('pin_hint_4_8')
        : L10nService()
            .format('pin_hint_exact_count', {'count': _pinSlotCount});
    return _cleanUiText(_defaultHintText, fallback: fallback);
  }

  String get _resolvedProgressText {
    final fallback = _pinSlotCount == _maxPinLength
        ? L10nService()
            .format('pin_progress_min', {'current': _currentPin.length})
        : L10nService().format('pin_progress_exact',
            {'current': _currentPin.length, 'count': _pinSlotCount});
    return _cleanUiText(_pinProgressText, fallback: fallback);
  }

  String get _forgotPinActionLabel {
    if (_isRecoveringPin) {
      return L10nService().translate('pin_recovering');
    }
    return L10nService().translate('pin_forgot');
  }

  String get _forgotPinDisabledLabel =>
      L10nService().translate('pin_forgot_after_5');

  String get _confirmDeliveryHint => L10nService().format(
      'pin_confirm_delivery_hint', {'target': widget.forgotPinHint ?? ''});

  String get _primaryActionLabel => widget.isConfirming
      ? L10nService().translate('core_confirm_upper')
      : L10nService().translate('core_continue_upper');

  double _keypadButtonSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical;
    if (width >= SLResponsive.tablet) return 84;
    if (width < 360 || height < 700) return 64;
    return 72;
  }

  SLSettingsPalette _pinPalette(BuildContext context) =>
      SLSettingsPalette.resolve(
        Theme.of(context).brightness == Brightness.dark,
      );

  Widget _buildFullscreenBody(BuildContext context, String displayedError) {
    final palette = _pinPalette(context);
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
        backgroundColor: palette.isDark
            ? palette.canvas
            : const Color(0xFFFFF4F8),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: palette.isDark
                        ? [palette.canvasTop, palette.canvas, palette.surface]
                        : const [
                            Color(0xFFFFFBFD),
                            Color(0xFFFFF0F6),
                            Color(0xFFF8F0FC),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            _buildAmbientOrb(
              alignment: const Alignment(-1.12, -0.82),
              color: const Color(0x16E65372),
              size: 190,
            ),
            _buildAmbientOrb(
              alignment: const Alignment(1.08, -0.18),
              color: const Color(0x16FFB6C9),
              size: 220,
            ),
            _buildAmbientOrb(
              alignment: const Alignment(0.82, 1.06),
              color: const Color(0x148E6BE8),
              size: 214,
            ),
            _buildAmbientOrb(
              alignment: const Alignment(-0.92, 0.92),
              color: const Color(0x10F4A37A),
              size: 142,
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        12,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxPanelWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFullscreenHeader(displayedError, context),
                              const SizedBox(height: 16),
                              _buildFullscreenKeypadSection(context),
                              if (widget.isUnlock) ...[
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed:
                                      _canUseForgotPin && !_isRecoveringPin
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
                                          ? palette.accent
                                          : palette.inkTertiary,
                                    ),
                                  ),
                                ),
                                if ((widget.forgotPinHint ?? '')
                                    .trim()
                                    .isNotEmpty)
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
                                        color: palette.inkSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isUnlock)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10,
                        horizontalPadding,
                        12,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxPanelWidth),
                          child: _buildSetupActions(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupActions(BuildContext context) {
    final palette = _pinPalette(context);
    final canSubmit =
        _currentPin.length >= _minimumSubmitLength && !_isInputLocked;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    final cancel = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.inkSecondary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.22)),
        shape: shape,
        textStyle: SLTheme.quicksand(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: Text(
        L10nService().translate('core_cancel'),
        textAlign: TextAlign.center,
      ),
    );
    final primary = DecoratedBox(
      decoration: BoxDecoration(
        gradient: canSubmit
            ? const LinearGradient(
                colors: [SLColors.primaryActive, SLSettingsColors.accentStrong],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: canSubmit ? null : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        boxShadow: canSubmit
            ? [
                BoxShadow(
                  color: SLColors.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: canSubmit ? _onSubmit : null,
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: palette.inkSecondary,
          disabledBackgroundColor: Colors.transparent,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: shape,
          textStyle: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Text(_primaryActionLabel, textAlign: TextAlign.center),
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 8), cancel],
      );
    }
    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: primary),
      ],
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
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }

  Widget _buildFullscreenHeader(String displayedError, BuildContext context) {
    final palette = _pinPalette(context);
    final errorColor = palette.isDark
        ? Theme.of(context).colorScheme.error
        : SLColors.danger;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.isDark
                  ? [palette.surface, palette.surfaceMuted]
                  : [
                      Colors.white.withValues(alpha: 0.82),
                      const Color(0xFFFFF4F8).withValues(alpha: 0.74),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: palette.isDark
                  ? palette.border
                  : Colors.white.withValues(alpha: 0.92),
            ),
            boxShadow: [
              BoxShadow(
                color: SLColors.primary.withValues(alpha: 0.08),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: SLColors.accentPurple.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SLColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: SLColors.primary.withValues(alpha: 0.24),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.isDark
                              ? palette.surface
                              : SLColors.paper,
                          border: Border.all(
                            color: palette.isDark
                                ? palette.border
                                : Colors.white.withValues(alpha: 0.96),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          widget.isUnlock
                              ? Icons.lock_open_rounded
                              : Icons.lock_person_rounded,
                          color: palette.accent,
                          size: 30,
                        ),
                      ),
                      const Positioned(
                        top: -1,
                        right: 2,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: SLColors.warningGold,
                          size: 17,
                        ),
                      ),
                      const Positioned(
                        bottom: 1,
                        left: 0,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: SLColors.primary,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _resolvedTitle,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: palette.accent,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _resolvedSubtitle,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _resolvedCuteMessage,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.inkSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _buildPinDots(context),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _hasError
                        ? errorColor.withValues(alpha: 0.10)
                        : palette.isDark
                        ? palette.surface
                        : Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: (_hasError ? errorColor : palette.accent)
                          .withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    _resolvedProgressText,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _hasError ? errorColor : palette.inkSecondary,
                    ),
                  ),
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: errorColor.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    displayedError,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: errorColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!widget.isUnlock)
          PositionedDirectional(
            top: 6,
            end: 6,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: palette.inkSecondary,
              tooltip: L10nService().translate('core_close'),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              style: IconButton.styleFrom(
                backgroundColor: palette.surface.withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullscreenKeypadSection(BuildContext context) {
    final palette = _pinPalette(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.isDark
            ? palette.surface.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: palette.isDark
              ? palette.border
              : Colors.white.withValues(alpha: 0.62),
        ),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: RepaintBoundary(child: _buildKeypad(context)),
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
                          SLColors.bgElevated.withValues(alpha: 0.96),
                          SLColors.surfaceWarm.withValues(alpha: 0.94),
                          SLColors.secondarySoft.withValues(alpha: 0.90),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SLColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: SLColors.primary.withValues(alpha: 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: SLColors.secondary.withValues(alpha: 0.08),
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
                                color: SLColors.primary.withValues(alpha: 0.14),
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
                              color: SLColors.danger.withValues(alpha: 0.10),
                              borderRadius: SLRadius.mdAll,
                              border: Border.all(
                                color: SLColors.danger.withValues(alpha: 0.20),
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
                                    : SLColors.primary.withValues(alpha: 0.45),
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
                                  child: Text(
                                    L10nService().translate('core_cancel'),
                                    style: const TextStyle(
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
                                        color: SLColors.primary
                                            .withValues(alpha: 0.24),
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
    final palette = _pinPalette(context);
    final activeSize = MediaQuery.sizeOf(context).width >= SLResponsive.tablet
        ? 22.0
        : 20.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Giữ từng ô cố định để đủ tám số vẫn vừa thẻ và không xô các ô còn lại.
        final spacing = min(
          12.0,
          max(
            0.0,
            (constraints.maxWidth - activeSize * _pinSlotCount) /
                (_pinSlotCount - 1),
          ),
        );
        return ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < _pinSlotCount; index++) ...[
                if (index > 0) SizedBox(width: spacing),
                SizedBox(
                  width: activeSize,
                  height: activeSize,
                  child: Center(
                    child: _buildPinDot(index, activeSize, palette),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinDot(int index, double activeSize, SLSettingsPalette palette) {
    final isActive = index < _currentPin.length;
    final isNext = index == _currentPin.length;
    final isRequiredSlot = index < _requiredPinLength;
    const inactiveRequiredSize = 14.0;
    const inactiveOptionalSize = 10.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: isActive
          ? activeSize
          : (isRequiredSlot ? inactiveRequiredSize : inactiveOptionalSize),
      height: isActive
          ? activeSize
          : (isRequiredSlot ? inactiveRequiredSize : inactiveOptionalSize),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive ? SLColors.primaryGradient : null,
        color: isActive
            ? null
            : (isRequiredSlot
                  ? palette.accent.withValues(alpha: 0.14)
                  : palette.accent.withValues(alpha: 0.06)),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: SLColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: isNext && index < _pinSlotCount
            ? Border.all(color: palette.accent, width: 2.2)
            : isActive
            ? null
            : Border.all(
                color: palette.accent.withValues(
                  alpha: isRequiredSlot ? 0.28 : 0.15,
                ),
              ),
      ),
      alignment: Alignment.center,
      child: isActive
          ? const Icon(Icons.favorite_rounded, color: Colors.white, size: 10)
          : null,
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
            if (widget.enableBiometrics && widget.onBiometricPressed != null)
              _buildKeypadButton(
                'bio',
                context: context,
                size: buttonSize,
                icon: defaultTargetPlatform == TargetPlatform.iOS
                    ? Icons.face_retouching_natural_rounded
                    : Icons.fingerprint_rounded,
                onTapOverride: widget.onBiometricPressed,
              )
            else
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
    VoidCallback? onTapOverride,
  }) {
    final palette = _pinPalette(context);
    final isDelete = value == 'delete';
    final isBiometric = value == 'bio';
    final onTap = _isInputLocked
        ? null
        : (onTapOverride ??
              (isDelete ? _onDeletePressed : () => _onNumberPressed(value)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: SLColors.primary.withValues(alpha: 0.15),
        highlightColor: SLColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: palette.isDark
                ? LinearGradient(
                    colors: [
                      isDelete
                          ? palette.accentSoft
                          : isBiometric
                          ? SLColors.accentPurple.withValues(alpha: 0.20)
                          : palette.surfaceMuted,
                      palette.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isDelete
                ? LinearGradient(
                    colors: [
                      SLColors.primarySoft.withValues(alpha: 0.92),
                      Colors.white.withValues(alpha: 0.72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isBiometric
                ? LinearGradient(
                    colors: [
                      SLColors.tertiarySoft.withValues(alpha: 0.92),
                      Colors.white.withValues(alpha: 0.80),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      const Color(0xFFFFF2F6).withValues(alpha: 0.84),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: palette.isDark
                  ? palette.border
                  : isDelete
                  ? SLColors.primary.withValues(alpha: 0.18)
                  : isBiometric
                  ? SLColors.accentPurple.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.94),
              width: 1.25,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isDelete
                            ? SLColors.primary
                            : isBiometric
                            ? SLColors.accentPurple
                            : SLColors.primary)
                        .withValues(alpha: 0.10),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  color: _isInputLocked
                      ? palette.inkTertiary
                      : isBiometric
                      ? palette.tint(SLColors.accentPurpleDark)
                      : palette.accent,
                  size: size * 0.42,
                )
              : Text(
                  value,
                  style: SLTheme.quicksand(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                    color: _isInputLocked
                        ? palette.inkTertiary
                        : palette.accent,
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
      return L10nService().translate('pin_unlock_subtitle');
    }
    if (widget.isConfirming) {
      return L10nService().translate('pin_confirm_subtitle');
    }
    return L10nService().translate('pin_setup_subtitle');
  }

  String get _cuteMessage {
    if (widget.isUnlock) {
      return L10nService().translate('pin_cute_unlock');
    }
    if (widget.isConfirming) {
      return L10nService().translate('pin_cute_confirm');
    }
    return L10nService().translate('pin_cute_setup');
  }

  String get _defaultHintText {
    if (_pinSlotCount == _maxPinLength) {
      return L10nService().translate('pin_hint_4_8');
    }
    return L10nService().format(
      'pin_hint_exact_count',
      {'count': _pinSlotCount},
    );
  }

  String get _pinProgressText {
    if (_pinSlotCount == _maxPinLength) {
      return L10nService().format(
        'pin_progress_min',
        {'current': _currentPin.length},
      );
    }
    return L10nService().format(
      'pin_progress_exact',
      {'current': _currentPin.length, 'count': _pinSlotCount},
    );
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
                            SLColors.bgElevated.withValues(alpha: 0.96),
                            SLColors.surfaceWarm.withValues(alpha: 0.94),
                            SLColors.secondarySoft.withValues(alpha: 0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SLColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: SLColors.primary.withValues(alpha: 0.10),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                          BoxShadow(
                            color: SLColors.secondary.withValues(alpha: 0.08),
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
                                  color:
                                      SLColors.primary.withValues(alpha: 0.14),
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
                                color: SLColors.danger.withValues(alpha: 0.1),
                                borderRadius: SLRadius.mdAll,
                                border: Border.all(
                                    color:
                                        SLColors.danger.withValues(alpha: 0.2)),
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
                                        ? context.tr('ui_common_restoring_pin_962cd6')
                                        : context.tr('security_pin_forgot_title'))
                                    : context.tr('ui_common_enter_an_incorrect_pin_5_times_to_a60a17'),
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _canUseForgotPin
                                      ? const Color(0xFFD81B60)
                                      : const Color(0xFFD81B60)
                                          .withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            if ((widget.forgotPinHint ?? '').trim().isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  L10nService().format(
                                      'pin_confirm_delivery_hint',
                                      {'target': widget.forgotPinHint ?? ''}),
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
                                    child: Text(context.tr('ui_common_cancel_247d4b'),
                                        style: const TextStyle(
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
                                              .withValues(alpha: 0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: SLTheme.primaryButton(
                                      text: widget.isConfirming
                                          ? context.tr('core_confirm_upper')
                                          : context.tr('core_continue_upper'),
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
