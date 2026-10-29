import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/app_lifecycle_presence_guard.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/private_media_url_service.dart';
import 'package:soullocket_app/utils/services/activity_history_service.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_signed_audio_upload.dart';
import 'package:soullocket_app/utils/services/storage/voice_upload_scope.dart';
import 'package:soullocket_app/utils/voice_storage_capacity.dart';
import 'package:soullocket_app/utils/services/pro_feature_limits.dart';
import 'package:soullocket_app/widgets/pro_upsell_dialog.dart';
import 'package:soullocket_app/utils/screen_activity_mixin.dart';
import 'package:soullocket_app/views/utilities/widgets/voice_message_studio.dart';

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
    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        ScreenActivityMixin {
  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_voice_recording_74d3a2')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('vault_features_label'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(context.tr('voice_help_features')),
              const SizedBox(height: 12),
              Text(
                context.tr('p3_help_how_to_label'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(context.tr('voice_help_steps')),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

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
  VoidCallback? _releaseRecordingQuiet;
  VoidCallback? _releasePlaybackQuiet;
  StreamSubscription<PlayerState>? _playbackStateSub;
  StreamSubscription<void>? _playbackCompleteSub;
  bool _startingPlayback = false;
  bool _startingRecording = false;

  void _releaseVoicePlaybackQuiet() {
    _releasePlaybackQuiet?.call();
    _releasePlaybackQuiet = null;
  }

  void _releaseVoiceRecordingQuiet() {
    _releaseRecordingQuiet?.call();
    _releaseRecordingQuiet = null;
  }

  static const int _maxPickedVoiceBytes = 6 * 1024 * 1024;
  late final String? _uploadOwnerUid;
  late final String _uploadHouseId;
  late final VoiceUploadScope _uploadScope;
  String get _pendingUploadPrefsKey =>
      'voice_pending_upload_v2_${_uploadOwnerUid}_$_uploadHouseId';
  bool get _uploadScopeIsCurrent => _uploadScope.matches(
    currentUid: FirebaseAuth.instance.currentUser?.uid,
    currentHouseId: widget.houseId,
  );

  void _requireUploadScope() {
    if (!_uploadScopeIsCurrent) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
  }

  bool _isUploading = false;
  bool _isRecording = false;
  bool _isRestoringUpload = false;
  Map<String, dynamic>? _pendingRetryUpload;
  String? _playingKey;
  String? _loadingKey;
  Timer? _recordTicker;
  Timer? _recordLimitTimer;
  DateTime? _recordStartedAt;
  Duration _recordElapsed = Duration.zero;
  late final AnimationController _bounceController;

  late final Stream<DatabaseEvent> _voiceStream;
  // Bản mới nhất từ listener danh sách; dùng để tính dung lượng thay vì tải lại cả danh sách.
  Object? _latestVoicesValue;
  bool _hasVoicesSnapshot = false;

  DatabaseReference get _voiceRef =>
      _dbRef.child('houses/${widget.houseId}/utilities/voices');

  DatabaseEvent _rememberVoicesSnapshot(DatabaseEvent event) {
    _latestVoicesValue = event.snapshot.value;
    _hasVoicesSnapshot = true;
    return event;
  }

  @override
  void initState() {
    super.initState();
    _uploadOwnerUid = FirebaseAuth.instance.currentUser?.uid;
    _uploadHouseId = widget.houseId.trim();
    _uploadScope = VoiceUploadScope(
      ownerUid: _uploadOwnerUid,
      houseId: _uploadHouseId,
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _voiceStream = _voiceRef.onValue.map(_rememberVoicesSnapshot);
    WidgetsBinding.instance.addObserver(this);
    _playbackStateSub = _player.onPlayerStateChanged.listen((state) {
      if (!_startingPlayback && state != PlayerState.playing) {
        _releaseVoicePlaybackQuiet();
      }
    });
    _playbackCompleteSub = _player.onPlayerComplete.listen((_) {
      _releaseVoicePlaybackQuiet();
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
    _privateMediaUrlService.dispose();
    _playbackStateSub?.cancel();
    _playbackCompleteSub?.cancel();
    _releaseVoicePlaybackQuiet();
    _releaseVoiceRecordingQuiet();
    _recordTicker?.cancel();
    _recordLimitTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      _privateMediaUrlService.clear();
    }
  }

  @override
  void onScreenActivityChanged(bool active) => _syncRecordingMotion();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRecordingMotion();
  }

  void _syncRecordingMotion() {
    if (isScreenActive &&
        _isRecording &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_bounceController.isAnimating) {
        _bounceController.repeat(reverse: true);
      }
    } else {
      _bounceController.stop();
    }
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

      final extension = p
          .extension(file.name)
          .replaceFirst('.', '')
          .toLowerCase();
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
        if (!mounted) return;
        _showMessage(
          L10nScope.of(context).format(
            'ui_utilities_the_recording_store_still_has_value1_so_c10203',
            {'value1': _formatDuration(remainingMs)},
          ),
        );
        return;
      }

      final persistedPath = await _persistPendingUploadFile(
        bytes: bytes,
        extension: safeExtension,
      );

      // Bỏ block UI: chạy ngầm
      unawaited(
        _queueAndUploadVoiceFile(
              localPath: persistedPath,
              extension: safeExtension,
              fileName: file.name,
              mimeType: mimeType,
              durationMs: durationMs,
            )
            .then((_) {
              _showMessage(successMsg);
            })
            .catchError((e, stackTrace) {
              debugPrint(
                '[VoiceScreen] _pickAndUploadVoice async catchError: $e',
              );
              unawaited(
                ErrorLoggerService.instance.logError(
                  e,
                  stackTrace as StackTrace?,
                  reason: 'pickAndUploadVoice_async_error',
                ),
              );
              final errorInfo = AppErrorMapper.resolve(
                e,
                fallbackMessage: fallbackErrMsg,
              );
              _showMessage(errorInfo.message);
            }),
      );
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _pickAndUploadVoice catch: $e');
      unawaited(
        ErrorLoggerService.instance.logError(
          e,
          stackTrace,
          reason: 'pickAndUploadVoice_sync_error',
        ),
      );
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

    if (_startingRecording) return;
    if (_isRecording) {
      await _stopRecordingAndUpload();
      return;
    }

    _startingRecording = true;
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
      if (!mounted) return;
      // Giữ yên trước khi mở micro để tiếng xác nhận không lọt vào bản ghi.
      _releaseRecordingQuiet ??= SoundService().holdQuiet();
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

      if (!mounted) {
        await _recorder.stop();
        _releaseVoiceRecordingQuiet();
        return;
      }
      setState(() {
        _isRecording = true;
        _recordElapsed = Duration.zero;
      });
      _syncRecordingMotion();

      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isScreenActive || !_isRecording) return;
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
        _releaseVoiceRecordingQuiet();
        _recordTicker?.cancel();
        _recordStartedAt = null;
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordElapsed = Duration.zero;
          });
          _syncRecordingMotion();
        }
        _showMessage(errNoCapacity);
        return;
      }

      // Tài khoản thường ghi tối đa 60 giây mỗi tin; PRO ghi tới hết dung lượng nhà.
      final freeCapMs = ProFeatureLimits.freeVoiceMessage.inMilliseconds;
      final freeCapped = remainingMs > freeCapMs && !await checkProAccess();
      // Trừ phần đã ghi trong lúc chờ kiểm tra PRO để không vượt 60 giây.
      final startedAt = _recordStartedAt;
      final spentMs = freeCapped && startedAt != null
          ? DateTime.now().difference(startedAt).inMilliseconds
          : 0;
      final limitMs = freeCapped
          ? (freeCapMs - spentMs).clamp(0, freeCapMs).toInt()
          : remainingMs;
      _recordLimitTimer = Timer(Duration(milliseconds: limitMs), () async {
        if (!_isRecording) return;
        await _stopRecordingAndUpload(reachedLimit: !freeCapped);
        if (freeCapped && mounted) {
          unawaited(
            showProUpsell(
              context,
              houseId: widget.houseId,
              message: L10nService().format('pro_limit_voice_length', {
                'seconds': ProFeatureLimits.freeVoiceMessage.inSeconds,
                'minutes': VoiceStorageCapacity.capacityMs ~/ 60000,
              }),
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      if (!_isRecording) _releaseVoiceRecordingQuiet();
      debugPrint('[VoiceScreen] _toggleRecordAndUpload catch: $e');
      unawaited(
        ErrorLoggerService.instance.logError(
          e,
          stackTrace,
          reason: 'toggleRecordAndUpload_error',
        ),
      );
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: fallbackErrMsg,
      );
      _showMessage(errorInfo.message);
    } finally {
      _startingRecording = false;
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
      _syncRecordingMotion();
    }

    String? recordPath;
    try {
      recordPath = await _recorder.stop();
      _releaseVoiceRecordingQuiet();
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
      unawaited(
        _queueAndUploadVoiceFile(
              localPath: persistedPath,
              extension: 'm4a',
              fileName: p.basename(recordPath),
              mimeType: _detectMimeType('m4a'),
              durationMs: durationMs,
            )
            .then((_) {
              _showMessage(reachedLimit ? limitReachedMsg : successMsg);
            })
            .catchError((e, stackTrace) {
              debugPrint(
                '[VoiceScreen] _stopRecordingAndUpload async catchError: $e',
              );
              unawaited(
                ErrorLoggerService.instance.logError(
                  e,
                  stackTrace as StackTrace?,
                  reason: 'stopRecordingAndUpload_async_error',
                ),
              );
              final errorInfo = AppErrorMapper.resolve(
                e,
                fallbackMessage: fallbackErrMsg,
              );
              _showMessage(errorInfo.message);
            }),
      );
    } catch (e, stackTrace) {
      debugPrint('[VoiceScreen] _stopRecordingAndUpload catch: $e');
      unawaited(
        ErrorLoggerService.instance.logError(
          e,
          stackTrace,
          reason: 'stopRecordingAndUpload_sync_error',
        ),
      );
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
        } catch (error) {
          debugPrint(
            '[SuppressedError] lib/views/utilities/voice_screen.dart: $error',
          );
        }
      }
    }
  }

  Future<void> _uploadVoiceBytes({
    required Uint8List bytes,
    required String extension,
    required String fileName,
    required String mimeType,
    required int durationMs,
    required Future<void> Function(String sessionId, int size) onSession,
  }) async {
    _requireUploadScope();
    final session = await _createVoiceUploadSession(
      fileName: fileName,
      contentType: mimeType,
      size: bytes.length,
      md5Hex: md5.convert(bytes).toString(),
    );
    _requireUploadScope();
    final sessionId = session['sessionId']?.toString().trim() ?? '';
    if (sessionId.isEmpty) throw StateError('Missing voice upload session');
    await onSession(sessionId, bytes.length);
    _requireUploadScope();
    final client = http.Client();
    try {
      await StorageSignedAudioUpload.put(
        session: session,
        bytes: bytes,
        contentType: mimeType,
        client: client,
        houseId: _uploadHouseId,
        ownerUid: _uploadOwnerUid,
      );
    } catch (e, stackTrace) {
      // ClientException có thể chứa URL ký; chỉ chuyển lỗi đã bỏ thông tin nhạy cảm.
      final safeError = e is TimeoutException
          ? TimeoutException('Voice upload timed out.', e.duration)
          : http.ClientException('Voice upload failed (${e.runtimeType}).');
      debugPrint('[VoiceScreen] Signed audio upload failed: $safeError');
      unawaited(
        ErrorLoggerService.instance.logError(
          safeError,
          stackTrace,
          reason: 'r2_upload_put_error',
        ),
      );
      Error.throwWithStackTrace(safeError, stackTrace);
    } finally {
      client.close();
    }
    _requireUploadScope();
    await _finalizeVoiceUpload(
      sessionId: sessionId,
      fileName: fileName,
      mimeType: mimeType,
      durationMs: durationMs,
      size: bytes.length,
    );
  }

  Future<Map<String, dynamic>> _createVoiceUploadSession({
    required String fileName,
    required String contentType,
    required int size,
    required String md5Hex,
  }) async {
    try {
      final response =
          await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
            'createVoiceUploadSession',
            payload: <String, dynamic>{
              'houseId': _uploadHouseId,
              'fileName': fileName.trim(),
              'contentType': contentType.trim(),
              // Server mới cấp phiên R2 riêng tư, khóa cứng kích thước + MD5;
              // server cũ bỏ qua các trường này và trả phiên Firebase Storage.
              'transport': 'r2',
              'size': size,
              'uploadProtocolVersion': 2,
              'md5': md5Hex,
            },
            timeout: const Duration(seconds: 15),
            requireAppCheck: true,
            throwOriginalException: true,
          );
      return response.data;
    } catch (error, stackTrace) {
      debugPrint('[VoiceScreen] createVoiceUploadSession error: $error');
      unawaited(
        ErrorLoggerService.instance.logError(
          error,
          stackTrace,
          reason: 'createVoiceUploadSession_unknown_error',
        ),
      );
      rethrow;
    }
  }

  Future<void> _finalizeVoiceUpload({
    required String sessionId,
    required String fileName,
    required String mimeType,
    required int durationMs,
    required int size,
  }) async {
    try {
      final result =
          await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
            'finalizeVoiceUpload',
            payload: <String, dynamic>{
              'houseId': _uploadHouseId,
              'sessionId': sessionId.trim(),
              'authorName': widget.myName.trim(),
              'fileName': fileName.trim(),
              'mimeType': mimeType.trim(),
              'durationMs': durationMs,
              'size': size,
            },
            timeout: const Duration(seconds: 15),
            requireAppCheck: true,
            throwOriginalException: true,
          );
      if (result.data['ok'] != true) {
        throw StateError('Voice upload finalize was not confirmed');
      }
    } catch (error, stackTrace) {
      debugPrint('[VoiceScreen] finalizeVoiceUpload error: $error');
      unawaited(
        ErrorLoggerService.instance.logError(
          error,
          stackTrace,
          reason: 'finalizeVoiceUpload_unknown_error',
        ),
      );
      rethrow;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SLSnackBar(content: Text(message)));
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
    if (_startingPlayback) return;
    final errNoUrl = context.tr('util_khngmclinh_37686c');
    final key = item['key']?.toString() ?? '';
    if (_playingKey == key) {
      await _player.stop();
      _releaseVoicePlaybackQuiet();
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

    _startingPlayback = true;
    _releasePlaybackQuiet ??= SoundService().holdQuiet();
    try {
      final url = await _resolveVoiceUrl(item);
      if (!mounted) return;
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
      _releaseVoicePlaybackQuiet();
      if (mounted) {
        setState(() => _loadingKey = null);
      }
    } finally {
      _startingPlayback = false;
      if (!mounted || _player.state != PlayerState.playing) {
        _releaseVoicePlaybackQuiet();
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

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => SLAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              SLDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancel),
              ),
              SLDialogAction(
                primary: true,

                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.tr('OK')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    _requireUploadScope();
    final snapshot = await _voiceRef.child(key).get();
    _requireUploadScope();
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'deleteVoiceMessage',
      payload: {'houseId': _uploadHouseId, 'voiceId': key},
      requireAppCheck: true,
      throwOriginalException: true,
    );
    if (result.data['ok'] != true) {
      throw StateError('Voice deletion was not confirmed');
    }
    _privateMediaUrlService.clear();
    if (snapshot.exists && snapshot.value is Map) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      try {
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
        );
      } catch (_) {}
    }
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
    if (_hasVoicesSnapshot) {
      return VoiceStorageCapacity.remainingMs(_latestVoicesValue);
    }
    final snapshot = await _voiceRef.get();
    return VoiceStorageCapacity.remainingMs(snapshot.value);
  }

  bool _isVoiceCapacityRejection(Object error) {
    if (error is! FirebaseFunctionsException ||
        error.code != 'failed-precondition') {
      return false;
    }
    final details = error.details;
    return details is Map &&
        details['reason'] == VoiceStorageCapacity.rejectionReason;
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
    _requireUploadScope();
    final saved = await prefs.setString(
      _pendingUploadPrefsKey,
      jsonEncode({
        ...payload,
        'ownerUid': _uploadOwnerUid,
        'houseId': _uploadHouseId,
      }),
    );
    if (!saved) throw StateError('Cannot persist pending voice upload');
    if (mounted && _uploadScopeIsCurrent) {
      _pendingRetryUpload = {
        ...payload,
        'ownerUid': _uploadOwnerUid,
        'houseId': _uploadHouseId,
      };
    }
  }

  Future<void> _clearPendingUpload({bool deleteLocalFile = false}) async {
    if (!_uploadScopeIsCurrent) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_uploadScopeIsCurrent) return;
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
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/utilities/voice_screen.dart: $error',
        );
      }
    }
    await prefs.remove(_pendingUploadPrefsKey);
  }

  Future<void> _restorePendingUploadStateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_uploadScopeIsCurrent) return;
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
      if (decoded['ownerUid'] != _uploadOwnerUid ||
          decoded['houseId'] != _uploadHouseId) {
        return;
      }
      final localPath = decoded['localPath']?.toString() ?? '';
      if ((decoded['sessionId']?.toString().isEmpty ?? true) &&
          (localPath.isEmpty || !await File(localPath).exists())) {
        return;
      }
      if (!_uploadScopeIsCurrent || !mounted) {
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
    if (payload == null ||
        _isUploading ||
        !_uploadScopeIsCurrent ||
        payload['ownerUid'] != _uploadOwnerUid ||
        payload['houseId'] != _uploadHouseId) {
      return;
    }
    final localPath = payload['localPath']?.toString() ?? '';
    final errNoFile = context.tr('util_khngcnfile_2c41f4');
    final successMsg = context.tr('util_gililinhnt_d1cbf0');
    final errRetryFailed = context.tr('util_khngththli_8551ac');

    if ((payload['sessionId']?.toString().isEmpty ?? true) &&
        (localPath.isEmpty || !await File(localPath).exists())) {
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
        retryPayload: payload,
      );
      if (mounted) {
        setState(() => _pendingRetryUpload = null);
      }
      _showMessage(successMsg);
    } catch (e) {
      _showMessage(e is AppErrorInfo ? e.message : errRetryFailed);
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
    Map<String, dynamic>? retryPayload,
  }) async {
    _requireUploadScope();
    final errNoCapacity = context.tr('util_khoghimkhn_25536a');
    if (retryPayload == null && _pendingRetryUpload != null) {
      throw StateError('Retry the pending voice upload first');
    }
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }
    try {
      final payload = <String, dynamic>{
        ...?retryPayload,
        'localPath': localPath,
        'extension': extension,
        'fileName': fileName,
        'mimeType': mimeType,
        'durationMs': durationMs,
      };
      await _savePendingUpload(payload);
      final previousSessionId = payload['sessionId']?.toString() ?? '';
      if (previousSessionId.isNotEmpty) {
        try {
          await _finalizeVoiceUpload(
            sessionId: previousSessionId,
            fileName: fileName,
            mimeType: mimeType,
            durationMs: durationMs,
            size: (payload['size'] as num?)?.toInt() ?? 0,
          );
          await _clearPendingUpload(deleteLocalFile: true);
          _pendingRetryUpload = null;
          return;
        } on FirebaseFunctionsException catch (error) {
          if (error.code != 'failed-precondition' ||
              error.details is! Map ||
              error.details['reason'] != 'upload-not-found') {
            rethrow;
          }
        }
      }
      _requireUploadScope();
      final bytes = await File(localPath).readAsBytes();
      await _uploadVoiceBytes(
        bytes: bytes,
        extension: extension,
        fileName: fileName,
        mimeType: mimeType,
        durationMs: durationMs,
        onSession: (sessionId, size) async {
          payload['sessionId'] = sessionId;
          payload['size'] = size;
          await _savePendingUpload(payload);
        },
      );
      await _clearPendingUpload(deleteLocalFile: true);
      _pendingRetryUpload = null;
    } catch (e, stackTrace) {
      if (_isVoiceCapacityRejection(e)) {
        // Server đã từ chối và xóa tệp; giữ bản chờ chỉ khiến người dùng kẹt ở nút thử lại.
        await _clearPendingUpload(deleteLocalFile: true);
        _pendingRetryUpload = null;
        throw AppErrorInfo(kind: AppErrorKind.user, message: errNoCapacity);
      }
      debugPrint('[VoiceScreen] _queueAndUploadVoiceFile error: $e');
      unawaited(
        ErrorLoggerService.instance.logError(
          e,
          stackTrace,
          reason: 'queueAndUploadVoiceFile_failed',
        ),
      );
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
    return StreamBuilder(
      stream: _voiceStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final libraryState =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData
            ? VoiceLibraryState.loading
            : snapshot.hasError
            ? VoiceLibraryState.error
            : !snapshot.hasData || snapshot.data?.snapshot.value == null
            ? VoiceLibraryState.empty
            : snapshot.data!.snapshot.value is Map
            ? VoiceLibraryState.ready
            : VoiceLibraryState.invalid;
        final rawValue = snapshot.data?.snapshot.value;
        final rawMap = rawValue is Map
            ? Map<dynamic, dynamic>.from(rawValue)
            : <dynamic, dynamic>{};
        final dataItems =
            rawMap.entries
                .map((e) {
                  final value = e.value;
                  if (value is! Map) return null;
                  return {
                    'key': e.key,
                    ...Map<String, dynamic>.from(
                      Map<dynamic, dynamic>.from(value),
                    ),
                  };
                })
                .whereType<Map<String, dynamic>>()
                .toList()
              ..sort(
                (a, b) =>
                    (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0),
              );
        final totalDurationMs = VoiceStorageCapacity.storedDurationMs(rawValue);
        final remainingCapacity = VoiceStorageCapacity.capacityMs == 0
            ? 0.0
            : totalDurationMs / VoiceStorageCapacity.capacityMs;

        return VoiceStudioView(
          messages: dataItems.map((item) {
            final key = item['key']?.toString() ?? '';
            final date = DateTime.fromMillisecondsSinceEpoch(
              item['ts'] as int? ?? 0,
            );
            return VoiceMessagePresentation(
              id: key,
              title: L10nService().translatePartnerMessage(
                item['a']?.toString() ?? '',
              ),
              dateLabel:
                  '${LocaleDateFormat.dayMonthTime(date)}  •  ${_formatDuration(item['duration'] as int? ?? 0)}',
              durationLabel: _formatDuration(item['duration'] as int? ?? 0),
              fileName: item['name']?.toString() ?? '',
              playable:
                  item['aud']?.toString().isNotEmpty == true ||
                  item['storagePath']?.toString().isNotEmpty == true,
            );
          }).toList(),
          libraryState: libraryState,
          elapsedLabel: _isRecording
              ? _formatDuration(_recordElapsed.inMilliseconds)
              : '00:00',
          storedLabel: _formatDuration(totalDurationMs),
          capacityLabel: _formatDuration(VoiceStorageCapacity.capacityMs),
          capacityFraction: remainingCapacity,
          recordingAnimation: _bounceController,
          recording: _isRecording,
          uploading: _isUploading,
          restoringUpload: _isRestoringUpload,
          pendingUpload: _pendingRetryUpload != null,
          refreshing:
              snapshot.connectionState == ConnectionState.waiting &&
              snapshot.hasData,
          playingId: _playingKey,
          loadingId: _loadingKey,
          onRecord: _toggleRecordAndUpload,
          onUpload: _pickAndUploadVoice,
          onPlay: (key) {
            final item = dataItems.firstWhere(
              (entry) => entry['key']?.toString() == key,
            );
            unawaited(_togglePlay(item));
          },
          onDelete: (key) {
            final item = dataItems.firstWhere(
              (entry) => entry['key']?.toString() == key,
            );
            unawaited(_deleteVoice(key, item['aud']?.toString()));
          },
          onBack: () => Navigator.of(context).maybePop(),
          onInfo: () => _showInfoDialog(context),
          onRetryUpload: _retryPendingUpload,
        );
      },
    );
  }
}
