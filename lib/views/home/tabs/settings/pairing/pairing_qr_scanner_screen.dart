import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_invite_qr_codec.dart';

/// Máy quét QR dành riêng cho lời mời ghép nối.
///
/// Màn hình này chỉ trả lại mã mời đã được kiểm tra định dạng. Việc gửi yêu
/// cầu vẫn diễn ra ở màn trước để người dùng có thời gian xem lại lựa chọn.
class PairingQrScannerScreen extends StatefulWidget {
  const PairingQrScannerScreen({super.key});

  @override
  State<PairingQrScannerScreen> createState() => _PairingQrScannerScreenState();
}

class _PairingQrScannerScreenState extends State<PairingQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _isCompleting = false;
  String? _feedback;

  String _t(String key) => context.tr(key);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isCompleting || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    final code = PairingInviteQrCodec.decode(rawValue);
    if (code == null) {
      if (mounted) {
        setState(() => _feedback = _t('pairing_ui_scan_invalid'));
      }
      return;
    }

    setState(() {
      _isCompleting = true;
      _feedback = null;
    });
    try {
      await _controller.stop();
    } catch (_) {
      // Máy quét đã có thể dừng khi điều hướng; vẫn trả mã đã kiểm tra.
    }
    if (mounted) {
      Navigator.of(context).pop(code);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = _t('pairing_ui_scan_flash_unavailable'));
      }
    }
  }

  String _cameraErrorText(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return _t('pairing_ui_scan_camera_denied');
      case MobileScannerErrorCode.unsupported:
        return _t('pairing_ui_scan_camera_unsupported');
      default:
        return _t('pairing_ui_scan_camera_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151018),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const SizedBox.shrink(),
          ),
          const _ScannerScrim(),
          SafeArea(
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, camera, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final frameSize = (constraints.maxWidth - 64)
                      .clamp(160.0, 272.0)
                      .toDouble();
                  // Cho phép cuộn khi màn hình thấp hoặc người dùng tăng cỡ chữ.
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildScannerHeader(camera),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: camera.error != null
                                ? _buildCameraError(camera.error!)
                                : Column(
                                    children: [
                                      _ScanFrame(size: frameSize),
                                      const SizedBox(height: 20),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                        ),
                                        child: Semantics(
                                          liveRegion: _feedback != null,
                                          child: Text(
                                            _feedback ??
                                                _t('pairing_ui_scan_hint'),
                                            textAlign: TextAlign.center,
                                            style: SLTheme.quicksand(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          _buildPrivacyNote(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isCompleting)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerHeader(MobileScannerState camera) {
    final torchOn = camera.torchState == TorchState.on;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleAction(
            icon: Icons.arrow_back_rounded,
            label: _t('pairing_ui_back'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('pairing_ui_scan_title'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('pairing_ui_scan_subtitle'),
                    style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleAction(
            icon: torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            label: _t('pairing_ui_scan_flash'),
            onTap:
                camera.isRunning &&
                    camera.error == null &&
                    camera.torchState != TorchState.unavailable
                ? _toggleTorch
                : null,
            active: torchOn,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                color: Color(0xFFF4B2C1),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                _cameraErrorText(error),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard_outlined, size: 20),
              label: Text(
                _t('pairing_ui_enter_title'),
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB9516D),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                textStyle: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFFF4B2C1),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t('pairing_ui_scan_private_note'),
              style: SLTheme.quicksand(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Material(
        color: active
            ? const Color(0xFFB9516D)
            : Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: onTap == null ? Colors.white38 : Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFF4B2C1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const _ScanCorner(top: 0, left: 0, rotation: 0, color: borderColor),
          const _ScanCorner(
            top: 0,
            right: 0,
            rotation: 1.5708,
            color: borderColor,
          ),
          const _ScanCorner(
            bottom: 0,
            right: 0,
            rotation: 3.14159,
            color: borderColor,
          ),
          const _ScanCorner(
            bottom: 0,
            left: 0,
            rotation: 4.71239,
            color: borderColor,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: size * 0.48,
              height: 1,
              color: borderColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.rotation,
    required this.color,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double rotation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 4),
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _ScannerScrim extends StatelessWidget {
  const _ScannerScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.72),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.80),
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
      ),
    );
  }
}
