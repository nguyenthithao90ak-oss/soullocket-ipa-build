import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/sl_theme.dart';
import '../../services/couple_service.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../services/qr_payload_codec.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';

class CoupleConnectScreen extends StatefulWidget {
  final String houseId;

  const CoupleConnectScreen({super.key, required this.houseId});

  @override
  State<CoupleConnectScreen> createState() => _CoupleConnectScreenState();
}

class _CoupleConnectScreenState extends State<CoupleConnectScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _manualCtrl = TextEditingController();
  final _scannerCtrl = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _imagePicker = ImagePicker();
  final _coupleService = CoupleService();
  late final TabController _tabController;

  String? _scanned;
  String? _statusText;
  String? _joinError;
  bool _isTorchOn = false;
  bool _isJoining = false;
  bool _isAnalyzingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 1) return;
      unawaited(_startScanner());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tabController.index != 1) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(_startScanner(silent: true));
      return;
    }

    unawaited(_stopScanner());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _manualCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      unawaited(_startScanner());
      return;
    }
    unawaited(_stopScanner());
  }

  void _showSnack(String text, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: backgroundColor),
    );
  }

  void _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Đã sao chép mã nhà: $text');
  }

  String _scannerErrorText(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera đang bị từ chối quyền. Hãy cấp quyền camera hoặc dùng Upload ảnh QR / nhập ID nhà.';
      case MobileScannerErrorCode.unsupported:
        return 'Thiết bị này không hỗ trợ camera quét QR. Bạn vẫn có thể upload ảnh QR hoặc nhập ID nhà.';
      default:
        return 'Camera QR đang gặp lỗi. Bạn vẫn có thể upload ảnh QR hoặc nhập ID nhà ở dưới.';
    }
  }

  Future<void> _startScanner({bool silent = false}) async {
    if (!mounted || _tabController.index != 1) return;
    try {
      await _scannerCtrl.start();
    } on MobileScannerException catch (error) {
      final text = _scannerErrorText(error);
      if (!mounted) return;
      setState(() {
        _joinError = text;
        _statusText = text;
        _isJoining = false;
      });
      if (!silent) {
        _showSnack(text, backgroundColor: const Color(0xFFD81B60));
      }
    } catch (_) {
      const text =
          'Không thể mở camera quét QR lúc này. Bạn vẫn có thể upload ảnh QR hoặc nhập ID nhà ở dưới.';
      if (!mounted) return;
      setState(() {
        _joinError = text;
        _statusText = text;
        _isJoining = false;
      });
      if (!silent) {
        _showSnack(text, backgroundColor: const Color(0xFFD81B60));
      }
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerCtrl.stop();
    } catch (_) {}
  }

  Future<void> _restartScanner() async {
    await _stopScanner();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _startScanner(silent: true);
  }

  void _setError(String text, {String? scannedValue}) {
    if (!mounted) return;
    setState(() {
      _scanned = scannedValue;
      _joinError = text;
      _statusText = text;
      _isJoining = false;
    });
    _showSnack(text, backgroundColor: const Color(0xFFD81B60));
  }

  Future<void> _handleValue(String raw, {required String source}) async {
    final value = raw.trim();
    if (value.isEmpty) {
      _setError('Bạn cần nhập ID nhà hoặc chọn một ảnh QR hợp lệ trước đã.');
      return;
    }

    final payloadKind = QRPayloadCodec.detectKind(value);
    if (payloadKind == QRPayloadKind.login) {
      _setError(
        'Đây là QR đăng nhập, không phải QR ghép đôi. Hãy nhờ người ấy mở đúng QR nhà để quét.',
        scannedValue: value,
      );
      return;
    }

    if (payloadKind == QRPayloadKind.community) {
      _setError(
        'Đây là QR cộng đồng để ghé thăm, không phải QR ghép đôi. Hãy nhờ người ấy mở đúng QR nhà để quét.',
        scannedValue: value,
      );
      return;
    }

    final targetHouseId = QRPayloadCodec.extractHouseId(value);
    if (targetHouseId == null || targetHouseId.isEmpty) {
      _setError(
        'Mã này chưa đọc ra được ID nhà hợp lệ. Bạn thử quét lại, upload ảnh QR khác hoặc nhập ID nhà ở dưới.',
        scannedValue: value,
      );
      return;
    }

    if (targetHouseId == widget.houseId.trim()) {
      _setError(
        'Đây là chính nhà của bạn rồi. Hãy dùng QR hoặc ID của người ấy.',
        scannedValue: targetHouseId,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _scanned = targetHouseId;
      _joinError = null;
      _statusText = source == 'camera'
          ? 'Đã đọc được QR nhà. Ứng dụng đang thử ghép đôi.'
          : 'Đã nhận ID nhà từ $source. Ứng dụng đang thử ghép đôi.';
      _isJoining = true;
    });

    try {
      final result = await _coupleService.joinHouse(targetHouseId);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _statusText = 'Ghép đôi thành công. Hai bạn đã vào cùng một nhà.';
          _isJoining = false;
        });
        _showSnack(
          '❤️ Ghép đôi thành công! Hai bạn đã vào cùng một nhà.',
          backgroundColor: const Color(0xFFD81B60),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      _setError(
        result.errorMessage.trim(),
        scannedValue: targetHouseId,
      );
    } catch (error) {
      _setError(
        AppErrorMapper.resolve(
          error,
          fallbackMessage:
              'Không ghép đôi được: hãy kiểm tra mã nhà, trạng thái ghép đôi hoặc kết nối mạng.',
        ).message,
        scannedValue: targetHouseId,
      );
    }
  }

  Future<void> _pickQrImageFromGallery() async {
    if (_isJoining || _isAnalyzingImage) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzingImage = true;
      _joinError = null;
      _statusText = 'Đang đọc ảnh QR từ thư viện...';
    });

    try {
      final image = await AppLifecyclePresenceGuard.guard(
        () => ImagePickerRecoveryService.instance.pickImage(
          picker: _imagePicker,
          source: ImageSource.gallery,
        ),
      );
      if (image == null) return;
      await _scannerCtrl.stop();
      final capture = await _scannerCtrl.analyzeImage(image.path);
      final raw = capture?.barcodes
              .map((item) => item.rawValue?.trim() ?? '')
              .firstWhere((item) => item.isNotEmpty, orElse: () => '') ??
          '';
      if (raw.isEmpty) {
        _setError(
          'Ảnh này chưa đọc ra được mã QR hợp lệ. Bạn thử ảnh khác hoặc nhập ID nhà ở dưới.',
        );
        return;
      }
      await _handleValue(raw, source: 'ảnh QR');
    } on MobileScannerException catch (error) {
      _setError(_scannerErrorText(error));
    } catch (error) {
      _setError(
        AppErrorMapper.resolve(
          error,
          fallbackMessage:
              'Không đọc được ảnh QR: hãy thử ảnh rõ hơn hoặc nhập ID nhà bên dưới.',
        ).message,
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingImage = false);
      if (mounted) await _restartScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseId = widget.houseId.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F8),
        elevation: 0,
        title: Text(
          'KẾT NỐI VỚI NGƯỜI ẤY',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD81B60)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w900),
          indicatorColor: const Color(0xFFD81B60),
          labelColor: const Color(0xFFD81B60),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Mã QR nhà'),
            Tab(text: 'Quét mã QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildViewTab(houseId),
          _buildScanTab(),
        ],
      ),
    );
  }

  Widget _buildViewTab(String houseId) {
    return SingleChildScrollView(
      padding: SLSpacing.all16,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: SLRadius.xlAll,
              border: Border.all(color: const Color(0x26D81B60)),
            ),
            child: Column(
              children: [
                Text(
                  'Đưa mã QR này cho người ấy quét',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                SLSpacing.h12,
                QrImageView(
                  data: QRPayloadCodec.encodeHouseId(houseId),
                  size: 240,
                  backgroundColor: Colors.white,
                ),
                SLSpacing.h12,
                SelectableText(
                  houseId,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  'Đây là QR nhà để ghép đôi, không phải QR đăng nhập.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF9B5B71),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SLSpacing.h12,
                ElevatedButton(
                  onPressed: () => _copy(houseId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                  ),
                  child: Text(
                    'Sao chép mã nhà',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h16,
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: SLRadius.xlAll,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Người ấy có thể quét QR, upload ảnh QR hoặc nhập tay mã nhà này để ghép đôi.',
              style: SLTheme.quicksand(
                color: const Color(0xFF6B4450),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerCtrl,
                onDetect: (capture) {
                  if (_isJoining || _isAnalyzingImage) return;
                  if (capture.barcodes.isEmpty) return;
                  final raw = capture.barcodes.first.rawValue?.trim();
                  if (raw == null || raw.isEmpty) return;
                  unawaited(_handleValue(raw, source: 'camera'));
                },
                errorBuilder: (context, error, child) {
                  return Container(
                    color: const Color(0xFF111827),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        _scannerErrorText(error),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        try {
                          await _scannerCtrl.switchCamera();
                        } catch (_) {
                          _setError('Không thể đổi camera trên thiết bị này.');
                        }
                      },
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () async {
                        try {
                          await _scannerCtrl.toggleTorch();
                          if (mounted) {
                            setState(() => _isTorchOn = !_isTorchOn);
                          }
                        } catch (_) {
                          _setError('Thiết bị này không hỗ trợ đèn flash.');
                        }
                      },
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: _buildResultCard(),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: const Color(0xFFFFF5F8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isAnalyzingImage
                        ? null
                        : () => unawaited(_pickQrImageFromGallery()),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Upload ảnh QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_restartScanner()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Quét lại camera'),
                  ),
                ],
              ),
              SLSpacing.h8,
              TextField(
                controller: _manualCtrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(
                    _handleValue(_manualCtrl.text, source: 'nhập tay')),
                decoration: InputDecoration(
                  hintText: 'VD: abc123xyz hoặc QR nhà đã copy',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.house_rounded),
                  suffixIcon: _manualCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _manualCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: SLRadius.mdAll,
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              SLSpacing.h8,
              ElevatedButton(
                onPressed: _isJoining
                    ? null
                    : () => unawaited(
                          _handleValue(_manualCtrl.text, source: 'nhập tay'),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                ),
                child: Text(
                  _isJoining ? 'Đang ghép đôi...' : 'Xác nhận ghép đôi',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mã vừa nhận',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          SLSpacing.h8,
          Text(
            _scanned ?? 'Chưa quét được mã nào',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((_statusText ?? '').isNotEmpty) ...[
            SLSpacing.h8,
            Text(
              _statusText!,
              style: SLTheme.quicksand(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if ((_joinError ?? '').isNotEmpty) ...[
            SLSpacing.h8,
            Text(
              _joinError!,
              style: SLTheme.quicksand(
                color: const Color(0xFFFFB4C8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
