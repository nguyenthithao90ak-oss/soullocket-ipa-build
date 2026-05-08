import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/sl_theme.dart';
import '../../services/house_service.dart';
import '../../services/qr_login_service.dart';
import '../../services/qr_payload_codec.dart';
import '../../services/security_flow_guard.dart';
import '../../widgets/sensitive_content_guard.dart';

class QRAuthorizeScannerScreen extends StatefulWidget {
  const QRAuthorizeScannerScreen({super.key});

  @override
  State<QRAuthorizeScannerScreen> createState() =>
      _QRAuthorizeScannerScreenState();
}

class _QRAuthorizeScannerScreenState extends State<QRAuthorizeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _qrSvc = QRLoginService();
  final _securityFlowGuard = SecurityFlowGuard.instance;

  bool _isProcessing = false;
  bool _isSecurityReady = false;
  bool _isTorchOn = false;
  bool _isUsingFrontCamera = false;
  String? _scannerInfoText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSecurityGate();
    });
  }

  Future<void> _runSecurityGate() async {
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.qrLoginAuthorize,
      continueLabel: 'Mở máy quét',
    );
    if (!mounted) return;
    if (!canContinue) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSecurityReady = true);
  }

  Future<void> _showSnack(String text, {Color? backgroundColor}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: backgroundColor,
      ),
    );
  }

  String _scannerErrorText(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera đang bị từ chối quyền. Hãy cấp quyền camera rồi mở lại màn quét QR đăng nhập.';
      case MobileScannerErrorCode.unsupported:
        return 'Thiết bị hoặc emulator này không hỗ trợ camera quét QR đăng nhập.';
      case MobileScannerErrorCode.controllerUninitialized:
        return 'Camera chưa khởi tạo xong. Bạn hãy mở lại màn quét QR đăng nhập.';
      case MobileScannerErrorCode.controllerAlreadyInitialized:
        return 'Camera đang được giữ bởi phiên khác. Hãy quay lại rồi mở màn quét lại.';
      default:
        return 'Camera QR đang gặp lỗi. Bạn thử mở lại màn quét hoặc kiểm tra quyền camera.';
    }
  }

  Future<void> _restartScanner() async {
    try {
      await _controller.stop();
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _showScannerInfo(
    String text, {
    bool showSnack = true,
  }) async {
    if (mounted) {
      setState(() => _scannerInfoText = text);
    } else {
      _scannerInfoText = text;
    }

    if (showSnack) {
      await _showSnack(
        text,
        backgroundColor: const Color(0xFFD81B60),
      );
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {
      await _showSnack(
        'Thiết bị này không hỗ trợ đèn flash để quét QR.',
        backgroundColor: const Color(0xFFD81B60),
      );
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
      if (!mounted) return;
      setState(() => _isUsingFrontCamera = !_isUsingFrontCamera);
    } catch (_) {
      await _showSnack(
        'Không thể đổi camera trên thiết bị này.',
        backgroundColor: const Color(0xFFD81B60),
      );
    }
  }

  Future<void> _handleMissingSession() async {
    if (mounted) {
      setState(() => _isProcessing = false);
    } else {
      _isProcessing = false;
    }

    await _restartScanner();
    await _showScannerInfo(
      'Thiết bị này chưa có đủ thông tin nhà để cấp quyền đăng nhập.',
    );
  }

  Future<bool?> _showConfirmDialog({
    required String houseId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD81B60),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  'CẤP QUYỀN ĐĂNG NHẬP',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thiết bị mới sẽ được phép đăng nhập vào đúng ngôi nhà của bạn sau khi bạn xác nhận.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6D5C63),
                  height: 1.4,
                ),
              ),
              SLSpacing.h12,
              _buildInfoRow(Icons.home_rounded, 'Mã nhà', houseId),
              SLSpacing.h12,
              Text(
                'Chỉ xác nhận nếu bạn đang tự đăng nhập trên thiết bị mới của mình hoặc của người ấy.',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A1E46),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Để sau',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF85757D),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
              ),
              child: Text(
                'Cấp quyền',
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0x22D81B60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD81B60), size: 18),
          SLSpacing.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9E8790),
                  ),
                ),
                SLSpacing.gapH(2),
                Text(
                  value,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4F3F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isSecurityReady) return;
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    final token = QRPayloadCodec.extractLoginToken(code);
    if (token == null) {
      final kind = QRPayloadCodec.detectKind(code);
      final text = kind == QRPayloadKind.house ||
              kind == QRPayloadKind.community
          ? 'Đây là QR nhà hoặc QR cộng đồng, không phải QR đăng nhập. Hãy mở đúng QR đăng nhập trên thiết bị mới rồi quét lại.'
          : 'Mã vừa quét không phải QR đăng nhập hợp lệ.';
      await _showScannerInfo(text);
      return;
    }

    setState(() {
      _isProcessing = true;
      _scannerInfoText = null;
    });

    try {
      final houseId =
          (await HouseService().getCurrentHouseId(preferFresh: true))?.trim() ??
              '';

      if (houseId.isEmpty) {
        await _handleMissingSession();
        return;
      }

      await _controller.stop();
      if (!mounted) return;

      final confirmed = await _showConfirmDialog(houseId: houseId);

      if (confirmed == true) {
        await _qrSvc.authorizeToken(token, houseId);
        await _showSnack(
          'Đã cấp quyền đăng nhập cho thiết bị mới.',
          backgroundColor: const Color(0xFFD81B60),
        );
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
        } else {
          _isProcessing = false;
        }
        await _restartScanner();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isProcessing = false);
      } else {
        _isProcessing = false;
      }
      await _restartScanner();
      await _showSnack(
        error.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFD81B60),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSecurityReady) {
      return SensitiveContentGuard(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  SLSpacing.h16,
                  Text(
                    'Đang kiểm tra an toàn trước khi mở màn quét QR...',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SensitiveContentGuard(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Container(
                  color: const Color(0xFF0B0B0D),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                        SLSpacing.h12,
                        Text(
                          _scannerErrorText(error),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.68),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactHeight = constraints.maxHeight < 760;
                  final minFrameSize = isCompactHeight ? 188.0 : 208.0;
                  final maxByWidth = (constraints.maxWidth - 72)
                      .clamp(minFrameSize, 270.0)
                      .toDouble();
                  final maxByHeight = (constraints.maxHeight * 0.34)
                      .clamp(minFrameSize, 270.0)
                      .toDouble();
                  final scanFrameSize =
                      maxByWidth < maxByHeight ? maxByWidth : maxByHeight;
                  final frameInset =
                      (scanFrameSize * 0.052).clamp(12.0, 16.0).toDouble();
                  final contentGap = isCompactHeight ? 12.0 : 18.0;
                  final infoPadding = isCompactHeight ? 14.0 : 16.0;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            _buildCircleButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            SLSpacing.w8,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QUÉT QR ĐĂNG NHẬP',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Xác nhận đăng nhập cho thiết bị mới',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildCircleButton(
                              icon: _isUsingFrontCamera
                                  ? Icons.camera_front_rounded
                                  : Icons.camera_rear_rounded,
                              onTap: _switchCamera,
                            ),
                            SLSpacing.w8,
                            _buildCircleButton(
                              icon: _isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              onTap: _toggleTorch,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: contentGap),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(infoPadding),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: SLRadius.xlAll,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đưa mã QR trên thiết bị mới vào khung quét để cấp quyền đăng nhập đúng ngôi nhà hiện tại.',
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                              SLSpacing.h8,
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildHintChip(
                                    Icons.security_rounded,
                                    'Cấp quyền một lần',
                                  ),
                                  _buildHintChip(
                                    Icons.timer_rounded,
                                    'Quét càng sớm càng tốt',
                                  ),
                                  _buildHintChip(
                                    Icons.favorite_rounded,
                                    'Chỉ cho đúng thiết bị cần dùng',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if ((_scannerInfoText ?? '').isNotEmpty) ...[
                        SizedBox(height: contentGap),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(infoPadding),
                            decoration: BoxDecoration(
                              color: const Color(0xFF401722).withValues(alpha: 0.86),
                              borderRadius: SLRadius.xlAll,
                              border: Border.all(
                                color: const Color(0x66FF8DB4),
                              ),
                            ),
                            child: Text(
                              _scannerInfoText!,
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: contentGap),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: scanFrameSize,
                            height: scanFrameSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      SLColors.primaryActive.withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: frameInset,
                                  left: frameInset,
                                  child: _buildCornerMarker(),
                                ),
                                Positioned(
                                  top: frameInset,
                                  right: frameInset,
                                  child: Transform.rotate(
                                    angle: 1.57,
                                    child: _buildCornerMarker(),
                                  ),
                                ),
                                Positioned(
                                  bottom: frameInset,
                                  left: frameInset,
                                  child: Transform.rotate(
                                    angle: -1.57,
                                    child: _buildCornerMarker(),
                                  ),
                                ),
                                Positioned(
                                  bottom: frameInset,
                                  right: frameInset,
                                  child: Transform.rotate(
                                    angle: 3.14,
                                    child: _buildCornerMarker(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(infoPadding),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: SLRadius.xlAll,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cách dùng nhanh',
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SLSpacing.h8,
                              Text(
                                '1) Mở màn đăng nhập trên thiết bị mới',
                                style: SLTheme.quicksand(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '2) Chọn đăng nhập bằng QR để hiện đúng QR đăng nhập',
                                style: SLTheme.quicksand(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '3) Dùng máy hiện tại quét mã và xác nhận cấp quyền',
                                style: SLTheme.quicksand(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: SLSpacing.all20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1A1D),
                      borderRadius: SLRadius.xlAll,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFFD81B60)),
                        SLSpacing.h12,
                        Text(
                          'Đang kiểm tra QR đăng nhập...',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHintChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: SLRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFFC1D3)),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerMarker() {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _CornerPainter(),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width, 6)
      ..lineTo(6, 6)
      ..lineTo(6, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
