import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_page_physics.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/couple_service.dart';
import '../../utils/services/image_picker_recovery_service.dart';
import '../../utils/services/qr_payload_codec.dart';
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
        return context.tr('relationship_cameraangb_10b95e');
      case MobileScannerErrorCode.unsupported:
        return context.tr('relationship_thitbnykhn_8e3b31');
      default:
        return context.tr('relationship_cameraqran_130dfd');
    }
  }

  Future<void> _startScanner({bool silent = false}) async {
    if (!mounted || _tabController.index != 1) return;
    final msgCameraFail = context.tr('relationship_khngthmcam_f1b8b3');
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
      final text = msgCameraFail;
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
      _setError(context.tr('relationship_bncnnhpidn_2e0bbf'));
      return;
    }

    final payloadKind = QRPayloadCodec.detectKind(value);
    if (payloadKind == QRPayloadKind.login) {
      _setError(
        context.tr('relationship_ylqrngnhpk_40b3b8'),
        scannedValue: value,
      );
      return;
    }

    if (payloadKind == QRPayloadKind.community) {
      _setError(
        context.tr('relationship_ylqrcngngg_af5cca'),
        scannedValue: value,
      );
      return;
    }

    final targetHouseId = QRPayloadCodec.extractHouseId(value);
    if (targetHouseId == null || targetHouseId.isEmpty) {
      _setError(
        context.tr('relationship_mnychacrac_e7b941'),
        scannedValue: value,
      );
      return;
    }

    if (targetHouseId == widget.houseId.trim()) {
      _setError(
        context.tr('relationship_ylchnhnhca_0a8067'),
        scannedValue: targetHouseId,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _scanned = targetHouseId;
      _joinError = null;
      _statusText = source == 'camera'
          ? context.tr('relationship_ccqrnhngdn_a2faca')
          : 'Đã nhận ID nhà từ $source. Ứng dụng đang thử ghép đôi.';
      _isJoining = true;
    });

    try {
      final result = await _coupleService.joinHouse(targetHouseId);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _statusText = context.tr('relationship_ghpithnhcn_835245');
          _isJoining = false;
        });
        _showSnack(
          context.tr('relationship_ghpithnhcn_767848'),
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
          fallbackMessage: context.tr('relationship_khngghpich_72dc50'),
        ).message,
        scannedValue: targetHouseId,
      );
    }
  }

  Future<void> _pickQrImageFromGallery() async {
    if (_isJoining || _isAnalyzingImage) return;
    FocusScope.of(context).unfocus();
    final msgAnalyzing = context.tr('relationship_angcnhqrtt_a50fdb');
    final msgNoQr = context.tr('relationship_nhnychacra_b77482');
    final msgQrSource = context.tr('relationship_nhqr_288f50');
    final msgAnalyzeFail = context.tr('relationship_khngccnhqr_dc8453');
    setState(() {
      _isAnalyzingImage = true;
      _joinError = null;
      _statusText = msgAnalyzing;
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
        _setError(msgNoQr);
        return;
      }
      await _handleValue(raw, source: msgQrSource);
    } on MobileScannerException catch (error) {
      _setError(_scannerErrorText(error));
    } catch (error) {
      _setError(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: msgAnalyzeFail,
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
          context.tr('relationship_ktnivingiy_5bb8af'),
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
          tabs: [
            Tab(text: context.tr('relationship_mqrnh_99a331')),
            Tab(text: context.tr('relationship_qutmqr_5c2829')),
          ],
        ),
      ),
      body: TabBarView(
        physics: const SLPagePhysics(),
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
                  context.tr('relationship_amqrnychon_0cffa8'),
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
                  context.tr('relationship_ylqrnhghpi_3b13c4'),
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
                    context.tr('relationship_saochpmnh_039efa'),
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
              context.tr('relationship_ngiycthqut_f245e2'),
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
                errorBuilder: (context, error) {
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
                        final msgSwitchFail =
                            context.tr('relationship_khngthicam_8bf16f');
                        try {
                          await _scannerCtrl.switchCamera();
                        } catch (_) {
                          _setError(msgSwitchFail);
                        }
                      },
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () async {
                        final msgTorchFail =
                            context.tr('relationship_thitbnykhn_df24cd');
                        try {
                          await _scannerCtrl.toggleTorch();
                          if (mounted) {
                            setState(() => _isTorchOn = !_isTorchOn);
                          }
                        } catch (_) {
                          _setError(msgTorchFail);
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
                    label: Text(context.tr('relationship_uploadnhqr_5cba41')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_restartScanner()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('relationship_qutlicamer_1828af')),
                  ),
                ],
              ),
              SLSpacing.h8,
              TextField(
                controller: _manualCtrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(_handleValue(_manualCtrl.text,
                    source: context.tr('relationship_nhptay_d6a84b'))),
                decoration: InputDecoration(
                  hintText: context.tr('relationship_vdabc123xy_28686a'),
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
                          _handleValue(_manualCtrl.text,
                              source: context.tr('relationship_nhptay_d6a84b')),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                ),
                child: Text(
                  _isJoining
                      ? context.tr('relationship_angghpi_3711a2')
                      : context.tr('relationship_xcnhnghpi_e13bce'),
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
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('relationship_mvanhn_170b30'),
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          SLSpacing.h8,
          Text(
            _scanned ?? context.tr('relationship_chaqutcmno_22f72b'),
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
