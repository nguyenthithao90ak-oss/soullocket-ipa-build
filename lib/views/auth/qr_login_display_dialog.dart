import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/sl_theme.dart';
import '../../services/qr_login_service.dart';
import '../../services/qr_payload_codec.dart';
import '../../services/security_flow_guard.dart';
import '../../widgets/sensitive_content_guard.dart';

class QRLoginDisplayDialog extends StatefulWidget {
  const QRLoginDisplayDialog({super.key});

  @override
  State<QRLoginDisplayDialog> createState() => _QRLoginDisplayDialogState();
}

class _QRLoginDisplayDialogState extends State<QRLoginDisplayDialog> {
  static const int _ttlSeconds = QRLoginService.tokenTtlSeconds;

  final _qrSvc = QRLoginService();
  final _securityFlowGuard = SecurityFlowGuard.instance;

  String _token = '';
  StreamSubscription? _sub;
  Timer? _countdownTimer;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isSecurityReady = false;
  int _secondsLeft = _ttlSeconds;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.qrLoginDisplay,
      continueLabel: 'Mở QR đăng nhập',
    );
    if (!mounted) return;
    if (!canContinue) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSecurityReady = true);
    await _startQR();
  }

  Future<void> _startQR({bool refresh = false}) async {
    if (refresh && _token.isNotEmpty) {
      await _clearActiveToken();
    } else {
      await _sub?.cancel();
      _countdownTimer?.cancel();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isExpired = false;
      _secondsLeft = _ttlSeconds;
    });

    _token = _qrSvc.generateToken();
    await _qrSvc.initTokenNode(_token);
    if (!mounted) return;

    _sub = _qrSvc.watchToken(_token).listen((event) async {
      final raw = event.snapshot.value;
      if (raw is! Map) return;

      final data = Map<String, dynamic>.from(raw);
      if (data['status'] != 'authorized') return;

      final houseId = data['houseId'] as String?;
      final authUid = data['auth_uid'] as String?;
      if (houseId == null || authUid == null) return;

      _countdownTimer?.cancel();
      await _sub?.cancel();
      await _qrSvc.consumeToken(_token);
      _token = '';

      if (!mounted) return;
      Navigator.pop(context, {
        'houseId': houseId,
        'authUid': authUid,
      });
    });

    _startCountdown();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = _ttlSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _isExpired = true;
        });
        unawaited(_clearActiveToken());
        return;
      }

      setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _clearActiveToken() async {
    _countdownTimer?.cancel();
    await _sub?.cancel();
    if (_token.isNotEmpty) {
      await _qrSvc.disposeToken(_token);
      _token = '';
    }
  }

  Color get _statusColor {
    if (!_isSecurityReady || _isLoading) return const Color(0xFFB57A90);
    if (_isExpired) return const Color(0xFFD81B60);
    return const Color(0xFF2E7D32);
  }

  String get _statusText {
    if (!_isSecurityReady) return 'Đang kiểm tra an toàn đăng nhập...';
    if (_isLoading) return 'Đang tạo mã đăng nhập an toàn...';
    if (_isExpired) {
      return 'QR đã hết hạn. Hãy làm mới để tạo mã đăng nhập mới.';
    }
    return 'QR đăng nhập đang hoạt động';
  }

  String get _countdownText {
    if (!_isSecurityReady) return 'Đang chờ kiểm tra bảo mật';
    if (_isExpired) return 'QR còn lại: 0 giây (00:00)';
    final ss = _secondsLeft.toString().padLeft(2, '0');
    return 'QR còn lại: $_secondsLeft giây (00:$ss)';
  }

  @override
  void dispose() {
    unawaited(_clearActiveToken());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final textScale = mediaQuery.textScaler.scale(1);
    final compact = SLResponsive.isCompactWidth(screenWidth);
    final stackedActions = compact || textScale > 1.2;
    final horizontalInset = SLResponsive.horizontalPaddingForWidth(
      screenWidth,
      compactPadding: 14,
      handsetPadding: 20,
      tabletPadding: 24,
      desktopPadding: 24,
    );
    final verticalInset = compact ? 14.0 : 24.0;
    final contentPadding = compact ? 16.0 : 22.0;
    final maxDialogHeight =
        (screenHeight - mediaQuery.viewInsets.vertical - (verticalInset * 2))
            .clamp(320.0, screenHeight)
            .toDouble();
    final maxDialogWidth = SLResponsive.clampPanelWidth(
      screenWidth,
      max: 420,
      compactGutter: horizontalInset * 2,
      gutter: horizontalInset * 2,
    );
    final availableWidth = screenWidth - (horizontalInset * 2);
    var qrBoxSize = (availableWidth - (compact ? 34 : 44))
        .clamp(compact ? 164.0 : 176.0, compact ? 220.0 : 248.0)
        .toDouble();
    final heightLimitedQrBox = (maxDialogHeight * (compact ? 0.26 : 0.30))
        .clamp(compact ? 164.0 : 176.0, compact ? 220.0 : 248.0)
        .toDouble();
    if (heightLimitedQrBox < qrBoxSize) {
      qrBoxSize = heightLimitedQrBox;
    }
    final qrSize = (qrBoxSize - (compact ? 36 : 48))
        .clamp(148.0, compact ? 184.0 : 200.0)
        .toDouble();

    return SensitiveContentGuard(
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: verticalInset,
        ),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 24 : 30),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7FA), Color(0xFFFFE9F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                contentPadding,
                contentPadding,
                compact ? 14 : 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 50 : 56,
                    height: compact ? 50 : 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD81B60),
                    ),
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: Colors.white,
                      size: compact ? 26 : 30,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Text(
                    'ĐĂNG NHẬP BẰNG QR',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 19 : 22,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    'Mở SoulLocket trên thiết bị đã đăng nhập, vào phần quét QR đăng nhập rồi đưa camera quét mã bên dưới.',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: compact ? 12.2 : 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6D5C63),
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                      vertical: compact ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: _statusColor.withValues(alpha: 0.28)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 13.2 : 14,
                            color: _statusColor,
                          ),
                        ),
                        SLSpacing.h4,
                        Text(
                          _countdownText,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7A6B73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SLSpacing.h16,
                  Container(
                    width: qrBoxSize,
                    height: qrBoxSize,
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: SLRadius.xlAll,
                      border: Border.all(color: const Color(0x22D81B60)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD81B60),
                            ),
                          )
                        : _isExpired
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_off_rounded,
                                    size: compact ? 40 : 48,
                                    color: const Color(
                                      0xFFD81B60,
                                    ).withValues(alpha: 0.9),
                                  ),
                                  SLSpacing.h12,
                                  Text(
                                    'Mã QR này đã hết hạn',
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: compact ? 15.2 : 17,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  Text(
                                    'Bấm "Làm mới QR" để tạo mã đăng nhập mới trong $_ttlSeconds giây.',
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF7A6B73),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              )
                            : QrImageView(
                                data: QRPayloadCodec.encodeLoginToken(_token),
                                version: QrVersions.auto,
                                size: qrSize,
                                eyeStyle: const QrEyeStyle(
                                  color: Color(0xFFD81B60),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  color: Color(0xFFD81B60),
                                ),
                              ),
                  ),
                  SLSpacing.h12,
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: const Color(0x1FD81B60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lưu ý bảo mật',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF8A1E46),
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          'Đây là QR đăng nhập, không dùng để ghép đôi hay vào nhà cộng đồng. Mã sẽ tự hủy sau khi dùng, khi hết $_ttlSeconds giây hoặc khi bạn đóng cửa sổ này.',
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6D5C63),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SLSpacing.h16,
                  Builder(
                    builder: (context) {
                      final closeButton = OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8C7B84),
                          side: const BorderSide(color: Color(0x2FD81B60)),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 12 : 13,
                          ),
                        ),
                        child: Text(
                          'Đóng',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                      final refreshButton = ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => unawaited(_startQR(refresh: true)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 12 : 13,
                          ),
                        ),
                        child: Text(
                          'Làm mới QR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      );

                      if (stackedActions) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            closeButton,
                            SLSpacing.h8,
                            refreshButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: closeButton),
                          SLSpacing.w8,
                          Expanded(child: refreshButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
