import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/private_media_url_service.dart';
import '../../services/activity_history_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

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

class _VoiceScreenState extends State<VoiceScreen> with WidgetsBindingObserver {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
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
  Timer? _recordTicker;
  Timer? _recordLimitTimer;
  DateTime? _recordStartedAt;
  Duration _recordElapsed = Duration.zero;

  DatabaseReference get _voiceRef =>
      _dbRef.child('houses/${widget.houseId}/utilities/voices');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingKey = null);
    });
    unawaited(_restorePendingUploadStateIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTicker?.cancel();
    _recordLimitTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVoice() async {
    try {
      if (_isRecording) {
        _showMessage('Đang ghi âm, vui lòng dừng trước khi chọn file.');
        return;
      }

      final result = await AppLifecyclePresenceGuard.guard(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: false,
          withData: true,
          allowedExtensions: const ['mp3', 'm4a', 'aac', 'ogg'],
        ),
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Không đọc được file audio.');
      }
      if (bytes.length > _maxPickedVoiceBytes) {
        _showMessage('File audio này quá lớn, hãy chọn file khác nhỏ hơn.');
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
        throw Exception('Không đọc được thời lượng file audio.');
      }
      final remainingMs = await _remainingVoiceCapacityMs();
      if (remainingMs <= 0) {
        _showMessage('Kho ghi âm đã đạt giới hạn 5 phút.');
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

      if (mounted) {
        setState(() => _isUploading = true);
      }

      await _queueAndUploadVoiceFile(
        localPath: persistedPath,
        extension: safeExtension,
        fileName: file.name,
        mimeType: mimeType,
        durationMs: durationMs,
      );
      _showMessage('Đã gửi lời nhắn thoại lên nhà chung.');
    } catch (e) {
      _showMessage('Không thể tải file audio lúc này. Hãy thử lại sau.');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _toggleRecordAndUpload() async {
    if (_isUploading) return;

    if (_isRecording) {
      await _stopRecordingAndUpload();
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showMessage('Chưa có quyền microphone để ghi âm.');
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
        _showMessage('Kho ghi âm đã đạt giới hạn 5 phút.');
        return;
      }

      _recordLimitTimer = Timer(Duration(milliseconds: remainingMs), () async {
        if (!_isRecording) return;
        await _stopRecordingAndUpload(reachedLimit: true);
      });
    } catch (e) {
      _showMessage('Không thể bắt đầu ghi âm: $e');
    }
  }

  Future<void> _stopRecordingAndUpload({bool reachedLimit = false}) async {
    if (!_isRecording) return;

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
        _isUploading = true;
        _recordElapsed = safeElapsed;
      });
    }

    String? recordPath;
    try {
      recordPath = await _recorder.stop();
      _recordStartedAt = null;
      if (recordPath == null || recordPath.isEmpty) {
        throw Exception('Không tìm thấy file ghi âm.');
      }

      final durationMs = safeElapsed.inMilliseconds;
      if (durationMs <= 0) {
        throw Exception('Bản ghi quá ngắn, vui lòng thử lại.');
      }
      if (remainingMs <= 0 || durationMs > remainingMs) {
        _showMessage('Kho ghi âm không còn đủ dung lượng.');
        return;
      }

      final recordFile = File(recordPath);
      if (!await recordFile.exists()) {
        throw Exception('Không tìm thấy file ghi âm.');
      }

      final persistedPath = await _persistPendingUploadFile(
        bytes: await recordFile.readAsBytes(),
        extension: 'm4a',
      );
      await _queueAndUploadVoiceFile(
        localPath: persistedPath,
        extension: 'm4a',
        fileName: p.basename(recordPath),
        mimeType: _detectMimeType('m4a'),
        durationMs: durationMs,
      );

      _showMessage(
        reachedLimit
            ? 'Đã tự dừng ở mốc 5 phút và gửi bản ghi.'
            : 'Đã gửi bản ghi âm lên nhà chung.',
      );
    } catch (e) {
      _showMessage('Không thể gửi bản ghi âm: $e');
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
      if (mounted) {
        setState(() => _isUploading = false);
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
    final session = await _createVoiceUploadSession(
      fileName: fileName,
      contentType: mimeType,
    );
    final uploadUrl = session['uploadUrl']?.toString().trim() ?? '';
    final sessionId = session['sessionId']?.toString().trim() ?? '';
    final headers = Map<String, String>.from(
      ((session['headers'] as Map?) ?? const <String, dynamic>{}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
    if (uploadUrl.isEmpty || sessionId.isEmpty) {
      throw Exception('Thiếu phiên tải lời nhắn thoại.');
    }
    headers.putIfAbsent('Content-Type', () => mimeType);

    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: headers,
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception(
          'Tải audio lên máy chủ thất bại (${uploadResponse.statusCode}).');
    }

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
  }) async {
    try {
      final callable = _functions.httpsCallable('createVoiceUploadSession');
      final response = await callable.call(<String, dynamic>{
        'houseId': widget.houseId.trim(),
        'fileName': fileName.trim(),
        'contentType': contentType.trim(),
      });
      final data = response.data;
      if (data is! Map) {
        throw Exception('Voice upload session is invalid.');
      }
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Không thể tạo phiên tải lời nhắn thoại.');
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
      final callable = _functions.httpsCallable('finalizeVoiceUpload');
      await callable.call(<String, dynamic>{
        'houseId': widget.houseId.trim(),
        'sessionId': sessionId.trim(),
        'authorName': widget.myName.trim(),
        'fileName': fileName.trim(),
        'mimeType': mimeType.trim(),
        'durationMs': durationMs,
        'size': size,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Không thể hoàn tất lời nhắn thoại.');
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
    final key = item['key']?.toString() ?? '';
    if (_playingKey == key) {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingKey = null);
      return;
    }

    final url = await _resolveVoiceUrl(item);
    if (url.isEmpty) {
      _showMessage('Không mở được lời nhắn thoại này.');
      return;
    }

    await _player.stop();
    await _player.play(UrlSource(url));
    if (!mounted) return;
    setState(() => _playingKey = key);
  }

  Future<void> _deleteVoice(String key, String? url) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa ghi âm?'),
            content: const Text('Bạn có chắc muốn xóa bản ghi này không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Huỷ'),
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
        'đã xóa một bản ghi âm',
        houseId: widget.houseId,
        title: 'Đã xóa ghi âm',
        subtitle: data['name']?.toString() ?? data['a']?.toString() ?? '',
        action: 'delete',
        module: 'voice',
        entityType: 'voice',
        entityId: key,
        sourceLabel: 'Ghi âm',
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
    if (localPath.isEmpty || !await File(localPath).exists()) {
      await _clearPendingUpload();
      if (mounted) {
        setState(() => _pendingRetryUpload = null);
      }
      _showMessage('Không còn file ghi âm tạm để thử lại.');
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
      _showMessage('Đã gửi lại lời nhắn thoại lên nhà chung.');
    } catch (e) {
      _showMessage('Không thể thử lại ghi âm: $e');
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          'GHI ÂM LỜI NHẮN',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        ),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF009688), Color(0xFF80CBC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      margin: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.mic_rounded,
                  label: _isRecording
                      ? 'Dừng ${_formatDuration(_recordElapsed.inMilliseconds)}'
                      : 'Ghi âm',
                  onTap: _isUploading ? null : _toggleRecordAndUpload,
                  filled: _isRecording,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload file',
                  onTap: (_isUploading || _isRecording)
                      ? null
                      : _pickAndUploadVoice,
                  filled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.shrink(),
              if (_isUploading)
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRestoringUpload
                          ? 'Đang khôi phục upload'
                          : 'Đang upload',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_pendingRetryUpload != null && !_isUploading) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lần upload ghi âm trước đã bị gián đoạn. Bạn có thể thử lại.',
                      style: SLTheme.quicksand(
                        color: Colors.white,
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
                      'Thử lại',
                      style: SLTheme.quicksand(
                        color: Colors.white,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.white.withOpacity(0.08)
              : filled
                  ? Colors.redAccent
                  : Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceList() {
    return StreamBuilder(
      stream: _voiceRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final hasData =
            snapshot.hasData && snapshot.data?.snapshot.value != null;
        if (snapshot.connectionState == ConnectionState.waiting && !hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Lỗi tải dữ liệu: ${snapshot.error}',
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              'Chưa có lời nhắn thoại nào',
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          );
        }

        final rawValue = snapshot.data!.snapshot.value;
        if (rawValue is! Map) {
          return Center(
            child: Text(
              'Dữ liệu lời nhắn thoại không hợp lệ.',
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${items.length} bản ghi',
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_formatDuration(totalDurationMs)}/05:00',
                        style: SLTheme.quicksand(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: hasPlayableSource
                                      ? () => _togglePlay(item)
                                      : null,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _playingKey == key
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lời nhắn từ ${item['a']}',
                                        style: SLTheme.quicksand(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14),
                                      ),
                                      SLSpacing.h4,
                                      Text(
                                        '$timeStr • $durationStr',
                                        style: SLTheme.quicksand(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10.5),
                                      ),
                                      if ((item['name']?.toString() ?? '')
                                          .isNotEmpty) ...[
                                        SLSpacing.h4,
                                        Text(
                                          item['name'].toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SLTheme.quicksand(
                                              color: Colors.white54,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10.5),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white70, size: 20),
                                  onPressed: () => _deleteVoice(
                                      key, item['aud']?.toString()),
                                )
                              ],
                            ),
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
