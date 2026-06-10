import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/image_picker_recovery_service.dart';
import '../../utils/services/qr_payload_codec.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/sl_notice.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../visitors/visitor_profile_screen.dart';

class HouseQRScreen extends StatefulWidget {
  final String houseId;

  const HouseQRScreen({super.key, required this.houseId});

  @override
  State<HouseQRScreen> createState() => _HouseQRScreenState();
}

class _HouseQRScreenState extends State<HouseQRScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _lookupController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final FriendsService _friendsService = FriendsService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isProcessing = false;
  bool _isAnalyzingImage = false;
  bool _isSearching = false;
  String? _scannerInfoText;
  List<Map<String, dynamic>> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentIndex != 1) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(_startScanner(silent: true));
      return;
    }

    unawaited(_stopScanner());
  }

  Future<void> _copyHouseId() async {
    await Clipboard.setData(ClipboardData(text: widget.houseId));
    if (!mounted) return;
    SLNotice.showSuccess(context, context.tr('comm_saochpidnh_81b785'));
  }

  Future<void> _setTab(int index) async {
    if (_currentIndex == index) return;

    await _stopScanner();
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
      _scannerInfoText = null;
      _isProcessing = false;
    });

    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentIndex != 1) return;
        unawaited(_startScanner());
      });
    }
  }

  Future<void> _startScanner({bool silent = false}) async {
    if (!mounted || _currentIndex != 1) return;

    try {
      await _scannerController.start();
      if (!mounted) return;
      setState(() => _scannerInfoText = null);
    } on MobileScannerException catch (error) {
      final text = _scannerErrorText(error);
      if (!mounted) return;
      setState(() => _scannerInfoText = text);
      if (!silent && mounted) {
        if (mounted) {
          SLNotice.showError(context, text);
        }
      }
    } catch (error) {
      if (!mounted) return;
      final text =
          context.tr('comm_khngthmcam_c28e15');
      setState(() => _scannerInfoText = text);
      if (!silent && mounted) {
        SLNotice.showError(context, text);
      }
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
  }

  Future<void> _restartScanner() async {
    await _stopScanner();
    if (!mounted || _currentIndex != 1) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _startScanner();
  }

  String _scannerErrorText(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return context.tr('comm_cameraangb_4bacfe');
      case MobileScannerErrorCode.unsupported:
        return context.tr('comm_thitbhocem_8c72ee');
      case MobileScannerErrorCode.controllerUninitialized:
        return context.tr('comm_camerachak_81d30f');
      case MobileScannerErrorCode.controllerAlreadyInitialized:
        return context.tr('comm_cameraangc_b3ff08');
      default:
        return context.tr('comm_cameraqran_f00350');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isAnalyzingImage) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        unawaited(_handleDetectedValue(raw, sourceLabel: 'camera'));
        return;
      }
    }
  }

  Future<void> _handleDetectedValue(
    String raw, {
    required String sourceLabel,
  }) async {
    if (_isProcessing) return;

    final value = raw.trim();
    if (value.isEmpty) return;

    if (value.toUpperCase().startsWith('SOULLOCKET:LOGIN:')) {
      if (!mounted) return;
      setState(() {
        _scannerInfoText =
            context.tr('comm_mnylqrngnh_78e9de');
      });
      SLNotice.showError(
        context,
        context.tr('comm_ylqrngnhpk_2b21fa'),
      );
      await _startScanner(silent: true);
      return;
    }

    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() => _isProcessing = true);
    }
    await _stopScanner();

    try {
      final resolvedHouseId = await _resolveHouseId(value);
      if (!mounted) return;

      if (resolvedHouseId == null) {
        final text =
            'Không đọc ra mã nhà từ $sourceLabel. Bạn có thể thử ảnh khác hoặc nhập ID nhà bên dưới.';
        setState(() {
          _isProcessing = false;
          _scannerInfoText = text;
        });
        if (mounted) {
          SLNotice.showError(context, text);
        }
        await _startScanner(silent: true);
        return;
      }

      await _openVisitorProfile(resolvedHouseId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _scannerInfoText =
            context.tr('comm_clikhixlmq_54b191');
      });
      SLNotice.showError(
        context,
        context.tr('comm_chathxlmqr_edb285'),
      );
      await _startScanner(silent: true);
    }
  }

  Future<void> _pickQrImageFromGallery() async {
    if (_isAnalyzingImage || _isProcessing) return;

    FocusScope.of(context).unfocus();
    setState(() => _isAnalyzingImage = true);

    try {
      final XFile? image = await AppLifecyclePresenceGuard.guard(
        () => ImagePickerRecoveryService.instance.pickImage(
          picker: _imagePicker,
          source: ImageSource.gallery,
        ),
      );

      if (image == null) return;

      await _stopScanner();

      final BarcodeCapture? capture =
          await _scannerController.analyzeImage(image.path);

      if (!mounted) return;

      final codes = capture?.barcodes ?? const <Barcode>[];
      final raw = codes
          .map((item) => item.rawValue?.trim() ?? '')
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');

      if (raw.isEmpty) {
        setState(() {
          _scannerInfoText =
              context.tr('comm_nhnychacra_368948');
        });
        SLNotice.showError(
          context,
          context.tr('comm_khngccqrtn_f5aefc'),
        );
        return;
      }

      await _handleDetectedValue(raw, sourceLabel: context.tr('comm_nhqr_288f50'));
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      final text = _scannerErrorText(error);
      setState(() => _scannerInfoText = text);
      if (mounted) {
        SLNotice.showError(context, text);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scannerInfoText =
            context.tr('comm_khngthcnhq_d71d1f');
      });
      SLNotice.showError(
        context,
        context.tr('comm_chathcnhqr_14b91e'),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }

    if (!mounted) return;
    if (_currentIndex == 1 && !_isProcessing) {
      await _startScanner(silent: true);
    }
  }

  Future<void> _searchHouseManually() async {
    if (_isSearching || _isProcessing) return;

    final query = _lookupController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        SLNotice.showError(
            context, context.tr('comm_bnnhpidnhu_f2499d'));
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    try {
      final exactHouseId = await _resolveHouseId(query);
      if (exactHouseId != null) {
        if (!mounted) return;
        setState(() => _searchResults = const []);
        await _openVisitorProfile(exactHouseId);
        return;
      }

      final results = await _friendsService
          .searchHouses(query, limit: 10)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      setState(() => _searchResults = results);

      if (results.isEmpty) {
        SLNotice.showError(
          context,
          context.tr('comm_khngtmthyn_3d95f0'),
        );
      } else {
        SLNotice.showSuccess(context, 'Đã tìm thấy ${results.length} kết quả.');
      }
    } catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('comm_chathtmnhl_88938a'),
      );
      SLNotice.showError(
        context,
        errorInfo.message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (!mounted) return;
      if (mounted) {
        SLNotice.showError(context, context.tr('comm_thitbnykhn_df24cd'));
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {
      if (!mounted) return;
      if (mounted) {
        SLNotice.showError(context, context.tr('comm_khngthicam_8bf16f'));
      }
    }
  }

  Future<String?> _resolveHouseId(String raw) async {
    final directCandidates = _extractDirectCandidates(raw);
    for (final candidate in directCandidates) {
      if (await _houseExists(candidate)) {
        return candidate;
      }
    }

    final normalizedQuery = _normalizeLookupQuery(raw);
    if (normalizedQuery.isEmpty) return null;

    final results = await _friendsService
        .searchHouses(
          normalizedQuery,
          limit: 8,
        )
        .timeout(const Duration(seconds: 10));

    for (final item in results) {
      final id = item['id']?.toString().trim() ?? '';
      final username = item['username']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty) continue;

      if (id.toLowerCase() == normalizedQuery.toLowerCase() ||
          username == normalizedQuery.toLowerCase()) {
        return id;
      }
    }

    return null;
  }

  List<String> _extractDirectCandidates(String raw) {
    final candidates = <String>{};

    void add(String value) {
      final normalized = value.trim().replaceAll('"', '').replaceAll("'", '');
      if (normalized.isEmpty) return;
      if (normalized.toUpperCase().startsWith('SOULLOCKET:LOGIN:')) return;
      candidates.add(normalized);
    }

    final trimmed = raw.trim();
    add(trimmed);
    add(trimmed.replaceAll(RegExp(r'\s+'), ''));

    final upper = trimmed.toUpperCase();
    const prefixes = <String>[
      'SOULLOCKET:HOUSE:',
      'SOULLOCKET:COMMUNITY:',
      'HOUSE:',
      'HOUSE_ID:',
    ];

    for (final prefix in prefixes) {
      if (upper.startsWith(prefix)) {
        add(trimmed.substring(prefix.length));
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      for (final key in [
        'houseId',
        'house_id',
        'id',
        'hid',
        'targetHouseId',
        'target',
      ]) {
        final value = uri.queryParameters[key];
        if (value != null && value.isNotEmpty) {
          add(value);
        }
      }

      final segments =
          uri.pathSegments.where((item) => item.trim().isNotEmpty).toList();
      if (segments.isNotEmpty) {
        add(segments.last);
      }
    }

    return candidates.toList();
  }

  String _normalizeLookupQuery(String raw) {
    var value = raw.trim();

    if (value.toUpperCase().startsWith('SOULLOCKET:LOGIN:')) {
      return '';
    }

    if (value.startsWith('@')) {
      value = value.substring(1);
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      for (final key in [
        'houseId',
        'house_id',
        'id',
        'hid',
        'targetHouseId',
        'target',
      ]) {
        final qp = uri.queryParameters[key];
        if (qp != null && qp.trim().isNotEmpty) {
          value = qp.trim();
          break;
        }
      }

      if (value == raw.trim() && uri.pathSegments.isNotEmpty) {
        value = uri.pathSegments.last.trim();
      }
    }

    final knownWebHosts = <String>{
      if (AppConfig.webHost.isNotEmpty) AppConfig.webHost,
      'soullockket.web.app',
      'soullocket.com',
    };
    final lowerValue = value.toLowerCase();
    if (knownWebHosts.any(lowerValue.contains)) {
      final hostUri =
          Uri.tryParse(value.contains('://') ? value : 'https://$value');
      if (hostUri != null && hostUri.pathSegments.isNotEmpty) {
        value = hostUri.pathSegments.last.trim();
      }
    }

    const prefixes = <String>[
      'SOULLOCKET:HOUSE:',
      'SOULLOCKET:COMMUNITY:',
      'HOUSE:',
      'HOUSE_ID:',
    ];
    for (final prefix in prefixes) {
      if (value.toUpperCase().startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }

    return value.replaceAll('@', '').trim();
  }

  Future<bool> _houseExists(String houseId) async {
    final normalized = houseId.trim();
    if (normalized.isEmpty) return false;

    final profileSnap = await _dbRef
        .child('house_profiles/$normalized')
        .get()
        .timeout(const Duration(seconds: 8));
    if (profileSnap.exists) return true;

    final publicSnap = await _dbRef
        .child('houses_public/$normalized')
        .get()
        .timeout(const Duration(seconds: 8));
    if (publicSnap.exists) return true;

    final houseSnap = await _dbRef
        .child('houses/$normalized')
        .get()
        .timeout(const Duration(seconds: 8));
    return houseSnap.exists;
  }

  Future<void> _openVisitorProfile(String houseId) async {
    if (houseId == widget.houseId) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (mounted) {
        SLNotice.showError(context, context.tr('comm_ylnhcabnri_7f664c'));
      }
      await _startScanner(silent: true);
      return;
    }

    if (!await _houseExists(houseId)) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (mounted) {
        SLNotice.showError(context, context.tr('comm_idnhnyhink_79555a'));
      }
      await _startScanner(silent: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _searchResults = const [];
      _scannerInfoText = null;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorProfileScreen(targetHouseId: houseId),
      ),
    );

    if (!mounted) return;
    if (_currentIndex == 1) {
      await _startScanner(silent: true);
    }
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: SLRadius.xlAll,
      border: Border.all(color: const Color(0xFFF3D8E4)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lookupController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          context.tr('comm_mqrnh_4cc87e'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('👁️ Xem QR', 0),
                ),
                Expanded(
                  child: _buildTabButton(context.tr('comm_quttm_2c34c5'), 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _currentIndex == 0 ? _buildViewQR() : _buildScanQR(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => unawaited(_setTab(index)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFD81B60) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: isActive ? const Color(0xFFD81B60) : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildViewQR() {
    return SingleChildScrollView(
      padding: SLSpacing.all24,
      child: Column(
        children: [
          Container(
            padding: SLSpacing.all24,
            decoration: _panelDecoration(),
            child: Column(
              children: [
                Text(
                  context.tr('comm_mnhcabn_de776a'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                    fontSize: 16,
                  ),
                ),
                SLSpacing.h12,
                Text(
                  widget.houseId,
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                  textAlign: TextAlign.center,
                ),
                SLSpacing.h24,
                Container(
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFD81B60), width: 3),
                    borderRadius: SLRadius.lgAll,
                  ),
                  child: QrImageView(
                    data: QRPayloadCodec.encodeHouseId(widget.houseId),
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFFD81B60),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                SLSpacing.h16,
                Text(
                  context.tr('comm_chiasqrhoc_a6ff48'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h24,
          ElevatedButton.icon(
            onPressed: _copyHouseId,
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.tr('comm_saochpidnh_7d7eb8')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: SLRadius.lgAll,
              ),
              textStyle: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          SLSpacing.h12,
          OutlinedButton.icon(
            onPressed: () => unawaited(_setTab(1)),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(context.tr('comm_mqutupload_1174a7')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD81B60),
              side: const BorderSide(color: Color(0xFFD81B60)),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: SLRadius.lgAll,
              ),
              textStyle: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanQR() {
    final previewHeight =
        (MediaQuery.of(context).size.height * 0.38).clamp(300.0, 420.0);

    return SingleChildScrollView(
      padding: SLSpacing.all20,
      child: Column(
        children: [
          Container(
            height: previewHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: SLRadius.xlAll,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: SLRadius.xlAll,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scanFrameSize = math
                      .min(
                        constraints.maxWidth - 56,
                        constraints.maxHeight - 56,
                      )
                      .clamp(180.0, 240.0)
                      .toDouble();

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        placeholderBuilder: (context) => Container(
                          color: const Color(0xFF111827),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD81B60),
                            ),
                          ),
                        ),
                        errorBuilder: (context, error) {
                          return Container(
                            color: const Color(0xFF111827),
                            padding: SLSpacing.all20,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white,
                                    size: 54,
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
                              Colors.black.withValues(alpha: 0.28),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.34),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: scanFrameSize,
                          height: scanFrameSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD81B60), width: 3),
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                      if (_isProcessing || _isAnalyzingImage)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFFD81B60),
                                ),
                                SLSpacing.h12,
                                Text(
                                  _isAnalyzingImage
                                      ? context.tr('comm_angcnhqr_0cfc4a')
                                      : context.tr('comm_angmnhtngn_619c3d'),
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
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
          ),
          SLSpacing.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _panelDecoration(),
            child: Text(
              context.tr('comm_nucamerakh_4d4199'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
          if ((_scannerInfoText ?? '').isNotEmpty) ...[
            SLSpacing.h12,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _panelDecoration().copyWith(
                color: const Color(0xFFFFF4F8),
                border: Border.all(color: const Color(0xFFFFC2D7)),
              ),
              child: Text(
                _scannerInfoText!,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFFD81B60),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          SLSpacing.h16,
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('comm_qutuploadh_289c9c'),
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                  ),
                ),
                SLSpacing.h8,
                Text(
                  context.tr('comm_phnnygipbn_57adec'),
                  style: SLTheme.quicksand(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                SLSpacing.h16,
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scannerController,
                  builder: (context, state, _) {
                    final canSwitchCamera = (state.availableCameras ?? 0) > 1;
                    final torchUnavailable =
                        state.torchState == TorchState.unavailable;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildActionChip(
                          icon: Icons.photo_library_rounded,
                          label: _isAnalyzingImage
                              ? context.tr('comm_angcnh_ee1b76')
                              : context.tr('comm_uploadnhqr_5cba41'),
                          onTap: _isAnalyzingImage
                              ? null
                              : _pickQrImageFromGallery,
                        ),
                        _buildActionChip(
                          icon: Icons.refresh_rounded,
                          label: context.tr('comm_qutlicamer_1828af'),
                          onTap: _restartScanner,
                        ),
                        if (!torchUnavailable)
                          _buildActionChip(
                            icon: state.torchState == TorchState.on
                                ? Icons.flash_off_rounded
                                : Icons.flash_on_rounded,
                            label: state.torchState == TorchState.on
                                ? context.tr('comm_ttn_1854c0')
                                : context.tr('comm_btn_fb6cc2'),
                            onTap: _toggleTorch,
                          ),
                        if (canSwitchCamera)
                          _buildActionChip(
                            icon: Icons.cameraswitch_rounded,
                            label: context.tr('comm_icamera_039618'),
                            onTap: _switchCamera,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          SLSpacing.h16,
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('comm_tmbngiduse_23a776'),
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                  ),
                ),
                SLSpacing.h8,
                Text(
                  context.tr('comm_dnidnhuser_ce315c'),
                  style: SLTheme.quicksand(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                SLSpacing.h16,
                TextField(
                  controller: _lookupController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_searchHouseManually()),
                  decoration: InputDecoration(
                    hintText: context.tr('comm_vdabc123xy_310a2c'),
                    hintStyle: SLTheme.quicksand(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFFF7FA),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _lookupController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _lookupController.clear();
                              setState(() => _searchResults = const []);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFF1D0DF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFF1D0DF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD81B60)),
                    ),
                  ),
                ),
                SLSpacing.h12,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching
                        ? null
                        : () => unawaited(_searchHouseManually()),
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: Text(
                      _isSearching ? context.tr('comm_angtm_6c56d7') : context.tr('comm_tmnhngay_9f1329'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty) ...[
            SLSpacing.h16,
            Container(
              width: double.infinity,
              padding: SLSpacing.all16,
              decoration: _panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('comm_ktqutmthy_216f37'),
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  SLSpacing.h12,
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      return _buildSearchResultTile(_searchResults[index]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              onTap == null ? const Color(0xFFF3F4F6) : const Color(0xFFFFF5F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: onTap == null
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFF1D0DF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFD81B60)),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: onTap == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim() ?? '';
    final houseName = item['houseName']?.toString().trim() ?? '';
    final username = item['username']?.toString().trim() ?? '';
    final avatar = item['houseAvatar']?.toString().trim() ?? '';

    return InkWell(
      onTap: id.isEmpty ? null : () => unawaited(_openVisitorProfile(id)),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFE4EC),
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(
                      Icons.home_rounded,
                      color: Color(0xFFD81B60),
                    )
                  : null,
            ),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    houseName.isNotEmpty ? houseName : context.tr('comm_nhchattn_36b406'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    SLSpacing.gapH(2),
                    Text(
                      '@$username',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                  ],
                  SLSpacing.gapH(2),
                  Text(
                    'ID: $id',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
