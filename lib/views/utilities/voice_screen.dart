import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/app_lifecycle_presence_guard.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/private_media_url_service.dart';
import 'package:soullocket_app/utils/services/activity_history_service.dart';
import 'package:soullocket_app/utils/services/cloudflare_r2_service.dart';

class VoiceScreen extends StatefulWidget {
  final String houseId;
  final String myName;
  final bool embedded;

  const VoiceScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.embedded = false,
  });

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon:
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Ghi âm giọng nói',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('Tính năng:'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  '- Ghi lại các lời chúc, giọng hát, hoặc tiếng ngáy của người ấy để lưu giữ.\n- Lưu trữ trên mây, không lo mất file khi đổi điện thoại.'),
              const SizedBox(height: 12),
              Text(context.tr('Cách sử dụng:'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  '- Bấm và giữ biểu tượng Micro để bắt đầu ghi âm.\n- Đặt tên cho bản ghi và lưu lại.\n- Bấm nút Phát để nghe lại bất cứ lúc nào, âm thanh sẽ đồng bộ sang máy người kia.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Đã hiểu')),
          ),
        ],
      ),
    );
  }

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final PrivateMediaUrlService _privateMediaUrlService =
      PrivateMediaUrlService();
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  static const Duration _maxVoiceStorageDuration = Duration(minutes: 5);
  static const int _maxPickedVoiceBytes = 6 * 1024 * 1024;
  static const String _pendingUploadPrefsKey = 'voice_pending_upload_v1';
  bool _isUploading = false;
  bool _isRecording = false;
  bool _isRestoringUpload = false;
  Map<String, dynamic>? _pendingRetryUpload;
  String? _playingKey;
  String? _loadingKey;
  StreamSubscription? _playerCompleteSub;
  Timer? _recordTicker;
  Timer? _recordLimitTimer;
  DateTime? _recordStartedAt;
  Duration _recordElapsed = Duration.zero;
  late final AnimationController _bounceController;

  late final Stream<DatabaseEvent> _voiceStream;

  DatabaseReference get _voiceRef =>
      _dbRef.child('houses/${widget.houseId}/utilities/voices');

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _voiceStream = _voiceRef.onValue;
    WidgetsBinding.instance.addObserver(this);
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingKey = null;
        _loadingKey = null;
      });
    });
    unawaited(_restorePendingUploadStateIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerCompleteSub?.cancel();
    _recordTicker?.cancel();
    _recordLimitTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVoice() async {
    final errInvalidHouse = context.tr('util_chatmthynh_c77d9c');
    final errRecordingInProgress = context.tr('util_angghimvui_cd6c6e');
    final errNoFileBytes = context.tr('util_khngccfile_e69550');
    final errFileTooBig = context.tr('util_fileaudion_98a287');
    final errNoDuration = context.tr('util_khngccthil_ff2924');
    final errNoCapacity = context.tr('util_khoghimtgi_e908da');
    final successMsg = context.tr('util_gilinhntho_f7601a');
    final fallbackErrMsg = context.tr('util_khngthchnf_d2beb2');

    try {
      if (_isUploading) return;

      if (widget.houseId.trim().isEmpty) {
        _showMessage(errInvalidHouse);
        return;
      }

      if (_isRecording) {
        _showMessage(errRecordingInProgress);
        return;
      }

      final file = await AppLifecyclePresenceGuard.guard(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['mp3', 'm4a', 'aac', 'ogg'],
        ),
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception(errNoFileBytes);
      }
      if (bytes.length > _maxPickedVoiceBytes) {
        _showMessage(errFileTooBig);
        return;
      }

      final extension =
          p.extension(file.name).replaceFirst('.', '').toLowerCase();
      final safeExtension = extension.isEmpty ? 'mp3' : extension;
      final mimeType = _detectMimeType(safeExtension);
      final durationMs = await _resolveAudioDurationMs(
        path: file.path,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (durationMs == null) {
        throw Exception(errNoDuration);
      }
      final remainingMs = await _remainingVoiceCapacityMs();
      if (remainingMs <= 0) {
        _showMessage(errNoCapacity);
        return;
      }
      if (durationMs > remainingMs) {
        _showMessage(
          'Kho ghi âm còn ${_formatDuration(remainingMs)} nên không đủ cho file này.',
        );
        return;
      }

      final persistedPath = await _persistPendingUploadFile(
        bytes: bytes,
        extension: safeExtension,
      );

      // Bỏ block UI: chạy ngầm
      unawaited(_queueAndUploadVoiceFile(
        localPath: persistedPath,
        extension: safeExtension,
        fileName: file.name,
        mimeType: mimeType,
        durationMs: durationMs,
      ).then((_) {
        _showMessage(successMsg);
      }).catchError((e, stackTrace) {
        debugPrint('[VoiceScreen] _pickAndUploadVoice async catchError: $e');
        unawaited(ErrorLoggerService.instance.logError(
            e, stackTrace as StackTrace?,
            reason: 'pickAndUploadVoice_async_error'));
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackErrMsg,
        );
        _showMessage(errorInfo.message);
      }));
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _pickAndUploadVoice catch: $e');
      unawaited(ErrorLoggerService.instance
          .logError(e, stackTrace, reason: 'pickAndUploadVoice_sync_error'));
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: fallbackErrMsg,
      );
      _showMessage(errorInfo.message);
    }
  }

  Future<void> _toggleRecordAndUpload() async {
    if (_isUploading) return;

    final errInvalidHouse = context.tr('util_chatmthynh_c77d9c');
    final errNoPermission = context.tr('util_chacquynmi_786856');
    final errNoCapacity = context.tr('util_khoghimtgi_e908da');
    final fallbackErrMsg = context.tr('util_khngthbtug_2c71cb');

    if (widget.houseId.trim().isEmpty) {
      _showMessage(errInvalidHouse);
      return;
    }

    if (_isRecording) {
      await _stopRecordingAndUpload();
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showMessage(errNoPermission);
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final recordPath = p.join(
        tmpDir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: recordPath,
      );

      _recordTicker?.cancel();
      _recordLimitTimer?.cancel();
      _recordStartedAt = DateTime.now();

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordElapsed = Duration.zero;
      });

      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;
        final startedAt = _recordStartedAt;
        if (startedAt == null) return;
        final elapsed = DateTime.now().difference(startedAt);
        setState(() {
          _recordElapsed = elapsed;
        });
      });

      final remainingMs = await _remainingVoiceCapacityMs();
      if (remainingMs <= 0) {
        await _recorder.stop();
        _recordTicker?.cancel();
        _recordStartedAt = null;
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordElapsed = Duration.zero;
          });
        }
        _showMessage(errNoCapacity);
        return;
      }

      _recordLimitTimer = Timer(Duration(milliseconds: remainingMs), () async {
        if (!_isRecording) return;
        await _stopRecordingAndUpload(reachedLimit: true);
      });
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _toggleRecordAndUpload catch: $e');
      unawaited(ErrorLoggerService.instance
          .logError(e, stackTrace, reason: 'toggleRecordAndUpload_error'));
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: fallbackErrMsg,
      );
      _showMessage(errorInfo.message);
    }
  }

  Future<void> _stopRecordingAndUpload({bool reachedLimit = false}) async {
    if (!_isRecording) return;

    final errNoFile = context.tr('util_khngtmthyf_96836b');
    final errTooShort = context.tr('util_bnghiqungn_019531');
    final errNoCapacity = context.tr('util_khoghimkhn_25536a');
    final limitReachedMsg = context.tr('util_tdngmc5pht_4e5f44');
    final successMsg = context.tr('util_gibnghimln_67b0fd');
    final fallbackErrMsg = context.tr('util_khngthgibn_953e06');

    _recordTicker?.cancel();
    _recordLimitTimer?.cancel();
    _recordTicker = null;
    _recordLimitTimer = null;

    final startedAt = _recordStartedAt;
    final elapsed = startedAt == null
        ? _recordElapsed
        : DateTime.now().difference(startedAt);
    final remainingMs = await _remainingVoiceCapacityMs();
    final safeElapsed = elapsed > Duration(milliseconds: remainingMs)
        ? Duration(milliseconds: remainingMs)
        : elapsed;

    if (mounted) {
      setState(() {
        _isRecording = false;
        // Bỏ khóa UI khi upload
        _recordElapsed = safeElapsed;
      });
    }

    String? recordPath;
    try {
      recordPath = await _recorder.stop();
      _recordStartedAt = null;
      if (recordPath == null || recordPath.isEmpty) {
        throw Exception(errNoFile);
      }

      final durationMs = safeElapsed.inMilliseconds;
      if (durationMs <= 0) {
        throw Exception(errTooShort);
      }
      if (remainingMs <= 0 || durationMs > remainingMs) {
        _showMessage(errNoCapacity);
        return;
      }

      final recordFile = File(recordPath);
      if (!await recordFile.exists()) {
        throw Exception(errNoFile);
      }

      final persistedPath = await _persistPendingUploadFile(
        bytes: await recordFile.readAsBytes(),
        extension: 'm4a',
      );
      unawaited(_queueAndUploadVoiceFile(
        localPath: persistedPath,
        extension: 'm4a',
        fileName: p.basename(recordPath),
        mimeType: _detectMimeType('m4a'),
        durationMs: durationMs,
      ).then((_) {
        _showMessage(
          reachedLimit ? limitReachedMsg : successMsg,
        );
      }).catchError((e, stackTrace) {
        debugPrint(
            '[VoiceScreen] _stopRecordingAndUpload async catchError: $e');
        unawaited(ErrorLoggerService.instance.logError(
            e, stackTrace as StackTrace?,
            reason: 'stopRecordingAndUpload_async_error'));
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackErrMsg,
        );
        _showMessage(errorInfo.message);
      }));
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _stopRecordingAndUpload catch: $e');
      unawaited(ErrorLoggerService.instance.logError(e, stackTrace,
          reason: 'stopRecordingAndUpload_sync_error'));
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: fallbackErrMsg,
      );
      _showMessage(errorInfo.message);
    } finally {
      _recordStartedAt = null;
      if (recordPath != null && recordPath.isNotEmpty) {
        try {
          final recordFile = File(recordPath);
          if (await recordFile.exists()) {
            await recordFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _uploadVoiceBytes({
    required Uint8List bytes,
    required String extension,
    required String fileName,
    required String mimeType,
    required int durationMs,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(
      tempDir.path,
      'voice_upload_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes);

    try {
      final folder = 'houses/${widget.houseId}/utilities/voices';
      String? publicUrl = await CloudflareR2Service.instance.uploadFile(
        tempFile,
        folderPath: folder,
        contentTypeOverride: mimeType,
      );

      // Fallback 1: Thử upload base64 nếu upload file trực tiếp gặp sự cố
      if (publicUrl == null || publicUrl.isEmpty) {
        final cleanBase64 = base64Encode(bytes);
        publicUrl = await CloudflareR2Service.instance.uploadBase64(
          cleanBase64,
          folderPath: folder,
          extension: extension.replaceAll('.', ''),
        );
      }

      // Fallback 2: Lưu trữ dạng Data URI âm thanh trực tiếp để không bao giờ bị mất file
      if (publicUrl == null || publicUrl.isEmpty) {
        publicUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final newVoiceRef = _voiceRef.push();
      final newKey = newVoiceRef.key ?? '${now}_voice';

      final voicePayload = <String, dynamic>{
        'aud': publicUrl,
        'name': widget.myName.trim(),
        'a': widget.myName.trim(),
        'duration': durationMs,
        'dur': (durationMs / 1000).round(),
        'durationMs': durationMs,
        'size': bytes.length,
        'ts': now,
        'createdAt': now,
      };

      await newVoiceRef.set(voicePayload);

      unawaited(ActivityHistoryService.instance.add(
        'Đã gửi một lời nhắn thoại mới',
        houseId: widget.houseId,
        title: 'Ghi âm lời nhắn',
        subtitle: widget.myName.trim(),
        action: 'create',
        module: 'voice',
        entityType: 'voice',
        entityId: newKey,
        previewUrl: publicUrl,
        previewType: 'audio',
      ));
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] Upload voice error: $e');
      unawaited(ErrorLoggerService.instance.logError(e, stackTrace,
          reason: 'voice_upload_direct_error'));
      rethrow;
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<int?> _resolveAudioDurationMs({
    String? path,
    Uint8List? bytes,
    required String mimeType,
  }) async {
    final probePlayer = AudioPlayer();
    try {
      if (path != null && path.trim().isNotEmpty) {
        await probePlayer.setSourceDeviceFile(path, mimeType: mimeType);
      } else if (bytes != null && bytes.isNotEmpty) {
        await probePlayer.setSourceBytes(bytes, mimeType: mimeType);
      } else {
        return null;
      }

      var duration = await probePlayer.getDuration();
      if (duration != null && duration > Duration.zero) {
        return duration.inMilliseconds;
      }

      duration = await probePlayer.onDurationChanged.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => Duration.zero,
      );
      if (duration > Duration.zero) {
        return duration.inMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await probePlayer.dispose();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isSignedUrlExpired(Map<String, dynamic> item) {
    if (item['privateMedia'] != true && item['storageAccess'] != 'signed') {
      return false;
    }
    final expiresAt = (item['audExpiresAt'] as num?)?.toInt() ?? 0;
    return expiresAt <= DateTime.now().millisecondsSinceEpoch + 60000;
  }

  Future<String> _resolveVoiceUrl(Map<String, dynamic> item) async {
    final existingUrl = item['aud']?.toString().trim() ?? '';
    final key = item['key']?.toString().trim() ?? '';
    final hasStoragePath =
        (item['storagePath']?.toString().trim().isNotEmpty ?? false) ||
            (item['storageKey']?.toString().trim().isNotEmpty ?? false);
    if (existingUrl.isNotEmpty && !_isSignedUrlExpired(item)) {
      return existingUrl;
    }
    if (key.isEmpty || !hasStoragePath) {
      return existingUrl;
    }
    final result = await _privateMediaUrlService.resolve(
      houseId: widget.houseId,
      mediaId: key,
      kind: 'voice',
    );
    item['aud'] = result.url;
    item['audExpiresAt'] = result.expiresAt;
    return result.url;
  }

  Future<void> _togglePlay(Map<String, dynamic> item) async {
    final errNoUrl = context.tr('util_khngmclinh_37686c');
    final key = item['key']?.toString() ?? '';
    if (_playingKey == key) {
      await _player.stop();
      if (!mounted) return;
      setState(() {
        _playingKey = null;
        _loadingKey = null;
      });
      return;
    }

    setState(() {
      _loadingKey = key;
    });

    try {
      final url = await _resolveVoiceUrl(item);
      if (url.isEmpty) {
        _showMessage(errNoUrl);
        setState(() => _loadingKey = null);
        return;
      }

      await _player.stop();
      await _player.play(UrlSource(url));
      if (!mounted) return;
      setState(() {
        _playingKey = key;
        _loadingKey = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingKey = null);
      }
    }
  }

  Future<void> _deleteVoice(String key, String? url) async {
    final title = context.tr('util_xaghim_fd8c5c');
    final content = context.tr('util_bncchcmunx_ff38b5');
    final cancel = context.tr('util_hu_9daba0');
    final logText = context.tr('util_xamtbnghim_453273');
    final logTitle = context.tr('util_xaghim_9013be');
    final sourceLabel = context.tr('util_ghim_f8ac88');

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OK'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final snapshot = await _voiceRef.child(key).get();
    if (snapshot.exists && snapshot.value is Map) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      await ActivityHistoryService.instance.add(
        logText,
        houseId: widget.houseId,
        title: logTitle,
        subtitle: data['name']?.toString() ?? data['a']?.toString() ?? '',
        action: 'delete',
        module: 'voice',
        entityType: 'voice',
        entityId: key,
        sourceLabel: sourceLabel,
        previewUrl: data['aud']?.toString() ?? '',
        previewType: 'audio',
        restorePath: 'houses/${widget.houseId}/voice/$key',
        restorePayload: data,
      );
    }
    await _voiceRef.child(key).remove();
    if (_playingKey == key) {
      await _player.stop();
      if (mounted) {
        if (!mounted) return;
        setState(() => _playingKey = null);
      }
    }
  }

  String _detectMimeType(String extension) {
    switch (extension) {
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  String _formatDuration(int ms) {
    int seconds = (ms / 1000).round();
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<int> _remainingVoiceCapacityMs() async {
    final snapshot = await _voiceRef.get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      return _maxVoiceStorageDuration.inMilliseconds;
    }
    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    var totalMs = 0;
    for (final value in data.values) {
      if (value is Map) {
        totalMs += ((value['duration'] as num?)?.toInt() ?? 0);
      }
    }
    final remaining = _maxVoiceStorageDuration.inMilliseconds - totalMs;
    return remaining < 0 ? 0 : remaining;
  }

  Future<String> _persistPendingUploadFile({
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
      p.join(
        dir.path,
        'voice_pending_${DateTime.now().millisecondsSinceEpoch}.$extension',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _savePendingUpload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUploadPrefsKey, jsonEncode(payload));
  }

  Future<void> _clearPendingUpload({bool deleteLocalFile = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadPrefsKey);
    if (deleteLocalFile && raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map &&
            (decoded['localPath']?.toString().isNotEmpty ?? false)) {
          final file = File(decoded['localPath'].toString());
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}
    }
    await prefs.remove(_pendingUploadPrefsKey);
  }

  Future<void> _restorePendingUploadStateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadPrefsKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted || _pendingRetryUpload == null) {
        return;
      }
      setState(() => _pendingRetryUpload = null);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _clearPendingUpload();
        return;
      }
      final localPath = decoded['localPath']?.toString() ?? '';
      if (localPath.isEmpty || !await File(localPath).exists()) {
        await _clearPendingUpload();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingRetryUpload = Map<String, dynamic>.from(decoded);
      });
    } catch (_) {
      await _clearPendingUpload();
    }
  }

  Future<void> _retryPendingUpload() async {
    final payload = _pendingRetryUpload;
    if (payload == null || _isUploading) {
      return;
    }
    final localPath = payload['localPath']?.toString() ?? '';
    final errNoFile = context.tr('util_khngcnfile_2c41f4');
    final successMsg = context.tr('util_gililinhnt_d1cbf0');
    final errRetryFailed = context.tr('util_khngththli_8551ac');

    if (localPath.isEmpty || !await File(localPath).exists()) {
      await _clearPendingUpload();
      if (mounted) {
        setState(() => _pendingRetryUpload = null);
      }
      _showMessage(errNoFile);
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
        _isRestoringUpload = true;
      });
    }
    try {
      await _queueAndUploadVoiceFile(
        localPath: localPath,
        extension: payload['extension']?.toString() ?? 'm4a',
        fileName: payload['fileName']?.toString() ?? p.basename(localPath),
        mimeType: payload['mimeType']?.toString() ?? _detectMimeType('m4a'),
        durationMs: (payload['durationMs'] as num?)?.toInt() ?? 0,
      );
      if (mounted) {
        setState(() => _pendingRetryUpload = null);
      }
      _showMessage(successMsg);
    } catch (e) {
      _showMessage(errRetryFailed);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isRestoringUpload = false;
        });
      }
    }
  }

  Future<void> _queueAndUploadVoiceFile({
    required String localPath,
    required String extension,
    required String fileName,
    required String mimeType,
    required int durationMs,
  }) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }
    try {
      await _savePendingUpload(<String, dynamic>{
        'localPath': localPath,
        'extension': extension,
        'fileName': fileName,
        'mimeType': mimeType,
        'durationMs': durationMs,
      });
      final bytes = await File(localPath).readAsBytes();
      await _uploadVoiceBytes(
        bytes: bytes,
        extension: extension,
        fileName: fileName,
        mimeType: mimeType,
        durationMs: durationMs,
      );
      await _clearPendingUpload(deleteLocalFile: true);
      _pendingRetryUpload = null;
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _queueAndUploadVoiceFile error: $e');
      unawaited(ErrorLoggerService.instance
          .logError(e, stackTrace, reason: 'queueAndUploadVoiceFile_failed'));
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(
        context,
        context.tr('util_ghimlinhn_7761df'),
        actions: [_buildInfoIcon(context)],
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.bgMain,
        accentColor: const Color(0xFF00B4DB),
        secondaryAccent: const Color(0xFF0083B0),
        motif: SLCanvasBackdropMotif.sparkles,
        child: SafeArea(
          child: Column(
            children: [
              _buildRecordArea(),
              Expanded(child: _buildVoiceList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: SLColors.borderLight),
        boxShadow: SLShadow.subtle,
      ),
      child: Column(
        children: [
          // Walkie-Talkie Retro Layout
          Container(
            width: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECEFF1), // Retro plastic gray
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFCFD8DC), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Antenna
                Container(
                  width: 12,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF455A64),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SLSpacing.h8,
                // Retro Screen
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isRecording
                          ? Colors.red.shade200
                          : Colors.teal.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isRecording ? 'TRANSMITTING...' : 'STANDBY 📻',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _isRecording
                              ? Colors.red.shade900
                              : Colors.teal.shade900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SLSpacing.h4,
                      if (_isRecording)
                        Text(
                          _formatDuration(_recordElapsed.inMilliseconds),
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        )
                      else
                        Text(
                          '00:00',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
                SLSpacing.h16,
                // Mic / PTT Button
                GestureDetector(
                  onTap: _isUploading ? null : _toggleRecordAndUpload,
                  child: ScaleTransition(
                    scale: _isRecording
                        ? Tween<double>(begin: 0.94, end: 1.06).animate(
                            CurvedAnimation(
                                parent: _bounceController,
                                curve: Curves.easeInOut),
                          )
                        : const AlwaysStoppedAnimation(1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isRecording
                            ? const LinearGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? Colors.red
                                    : const Color(0xFF00B4DB))
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                SLSpacing.h6,
                Text(
                  _isRecording ? 'BẤM ĐỂ DỪNG' : 'PTT BUTTON',
                  style: SLTheme.quicksand(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textSecond,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h12,
          // Action controls
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SLColors.borderLight),
                    boxShadow: SLShadow.subtle,
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.upload_file_rounded,
                        color: SLColors.primary, size: 18),
                    label: Text(
                      'Tải lên file audio',
                      style: SLTheme.quicksand(
                        color: SLColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: (_isUploading || _isRecording)
                        ? null
                        : _pickAndUploadVoice,
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading) ...[
            SLSpacing.h10,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SLColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isRestoringUpload
                      ? context.tr('util_angkhiphcu_076cd4')
                      : context.tr('util_angupload_7ded4c'),
                  style: SLTheme.quicksand(
                    color: SLColors.textSecond,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (_pendingRetryUpload != null && !_isUploading) ...[
            SLSpacing.h10,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SLColors.dangerLight,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: SLColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: SLColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('util_lnuploadgh_c94950'),
                      style: SLTheme.quicksand(
                        color: SLColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _retryPendingUpload,
                    child: Text(
                      context.tr('util_thli_4dffdf'),
                      style: SLTheme.quicksand(
                        color: SLColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceList() {
    return StreamBuilder(
      stream: _voiceStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final hasData =
            snapshot.hasData && snapshot.data?.snapshot.value != null;
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('util_khngticlin_a510e1'),
              style: SLTheme.quicksand(
                  color: SLColors.textSecond, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              context.tr('util_chaclinhnt_9864b0'),
              style: SLTheme.quicksand(
                  color: SLColors.textSecond, fontWeight: FontWeight.w600),
            ),
          );
        }

        final rawValue = snapshot.data!.snapshot.value;
        if (rawValue is! Map) {
          return Center(
            child: Text(
              context.tr('util_dliulinhnt_f7fe04'),
              style: SLTheme.quicksand(
                  color: SLColors.textSecond, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = Map<dynamic, dynamic>.from(rawValue);
        final items = data.entries
            .map((e) {
              final value = e.value;
              if (value is! Map) {
                return null;
              }
              return {
                'key': e.key,
                ...Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value)),
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();
        items.sort(
            (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));

        final totalDurationMs = items.fold<int>(
          0,
          (sum, item) => sum + ((item['duration'] as num?)?.toInt() ?? 0),
        );

        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00B4DB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF00B4DB)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          L10nService().translateRecordsCount(items.length),
                          style: SLTheme.quicksand(
                            color: const Color(0xFF00B4DB),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: SLColors.borderLight),
                        ),
                        child: Text(
                          '${_formatDuration(totalDurationMs)}/05:00',
                          style: SLTheme.quicksand(
                            color: SLColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final key = item['key']?.toString() ?? '';
                      final audioUrl = item['aud']?.toString() ?? '';
                      final hasPlayableSource = audioUrl.isNotEmpty ||
                          (item['storagePath']?.toString().isNotEmpty ?? false);
                      final date = DateTime.fromMillisecondsSinceEpoch(
                          item['ts'] as int? ?? 0);
                      final timeStr = DateFormat('dd/MM HH:mm').format(date);
                      final durationStr =
                          _formatDuration(item['duration'] as int? ?? 0);
                      final isPlaying = _playingKey == key;
                      final isLoading = _loadingKey == key;

                      return _AnimatedPressButton(
                        onTap:
                            hasPlayableSource ? () => _togglePlay(item) : null,
                        borderRadius: 18,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isPlaying
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF00B4DB)
                                          .withValues(alpha: 0.12),
                                      const Color(0xFF0083B0)
                                          .withValues(alpha: 0.06),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.55),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPlaying
                                  ? const Color(0xFF00B4DB)
                                      .withValues(alpha: 0.5)
                                  : SLColors.borderLight,
                              width: isPlaying ? 1.5 : 1.0,
                            ),
                            boxShadow: SLShadow.subtle,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: isPlaying
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF00B4DB),
                                            Color(0xFF0083B0)
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [
                                            SLColors.primaryLight,
                                            SLColors.primaryLight
                                                .withValues(alpha: 0.5),
                                          ],
                                        ),
                                  shape: BoxShape.circle,
                                  boxShadow: isPlaying ? SLShadow.primary : [],
                                ),
                                child: Center(
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: isPlaying
                                              ? Colors.white
                                              : SLColors.primary,
                                          size: 26,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      L10nService().translatePartnerMessage(
                                          item['a']?.toString() ?? ''),
                                      style: SLTheme.quicksand(
                                          color: SLColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5),
                                    ),
                                    SLSpacing.h4,
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          color: SLColors.textSecond,
                                          size: 11,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$timeStr  •  $durationStr',
                                          style: SLTheme.quicksand(
                                              color: SLColors.textSecond,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    if ((item['name']?.toString() ?? '')
                                        .isNotEmpty) ...[
                                      SLSpacing.h4,
                                      Text(
                                        item['name'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                            color: SLColors.textSecond
                                                .withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (isPlaying) ...[
                                const _VoiceVisualizer(),
                                const SizedBox(width: 12),
                              ],
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: SLColors.textSecond, size: 20),
                                onPressed: () =>
                                    _deleteVoice(key, item['aud']?.toString()),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting && hasData)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }
}

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    this.borderRadius = 0,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _VoiceVisualizer extends StatefulWidget {
  const _VoiceVisualizer();

  @override
  State<_VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<_VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final double value =
                math.sin((_controller.value * 2 * math.pi) + (index * 1.5)) *
                        0.5 +
                    0.5;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 4 + (value * 14),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final IconData icon;

  const _PulseIcon({required this.icon});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: Colors.white, size: 18),
    );
  }
}
