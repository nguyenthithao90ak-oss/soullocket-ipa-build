import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'core/cloud_functions_helper.dart';
import 'storage/storage_signed_audio_upload.dart';
import 'pending_upload_service.dart';

class CreativeDiaryService {
  static final CreativeDiaryService _instance =
      CreativeDiaryService._internal();
  factory CreativeDiaryService() => _instance;
  CreativeDiaryService._internal();

  final _db = FirebaseDatabase.instance;

  String _voicePendingKey(String houseId) =>
      'creative_diary_voice_${houseId.trim()}';

  Future<void> saveCreativePage({
    required String houseId,
    required String content,
    required Map<String, dynamic> metadata,
    XFile? voiceNote,
  }) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    void guard() {
      if (ownerUid == null ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid) {
        throw FirebaseAuthException(code: 'user-token-expired');
      }
    }

    guard();
    if (voiceNote == null) {
      await _db.ref('houses/$houseId/creative_diary').push().set({
        'content': content,
        'metadata': metadata,
        'voiceUrl': null,
        'timestamp': ServerValue.timestamp,
      });
      return;
    }

    final originalFileName = voiceNote.name.isNotEmpty
        ? voiceNote.name
        : voiceNote.path;
    final extension = p.extension(originalFileName).toLowerCase();
    final safeExtension = extension.isNotEmpty ? extension : '.m4a';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$safeExtension';
    final mimeType = _detectMimeType(safeExtension);
    final bytes = await _readVoiceBytes(voiceNote);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Không đọc được dữ liệu ghi âm để lưu sổ tay.');
    }

    final pendingKey = _voicePendingKey(houseId);
    await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
      'content': content,
      'metadata': metadata,
      'fileName': fileName,
      'mimeType': mimeType,
    }, category: 'creative_diary_voice');

    try {
      guard();
      final session = await _createCreativeDiaryVoiceUploadSession(
        houseId: houseId,
        fileName: fileName,
        contentType: mimeType,
      );
      guard();
      final sessionId = session['sessionId']?.toString().trim() ?? '';
      final client = http.Client();
      try {
        await StorageSignedAudioUpload.put(
          session: session,
          bytes: bytes,
          contentType: mimeType,
          client: client,
        );
      } finally {
        client.close();
      }
      guard();
      await _finalizeCreativeDiaryVoiceUpload(
        houseId: houseId,
        sessionId: sessionId,
        content: content,
        metadata: metadata,
        fileName: fileName,
        mimeType: mimeType,
      );
      guard();
      try {
        await PendingUploadService.instance.clear(pendingKey);
      } catch (_) {}
    } catch (error) {
      await PendingUploadService.instance.markFailed(pendingKey, error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _createCreativeDiaryVoiceUploadSession({
    required String houseId,
    required String fileName,
    required String contentType,
  }) async {
    final response =
        await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
          'createCreativeDiaryVoiceUploadSession',
          requireAppCheck: true,
          throwOriginalException: true,
          timeout: const Duration(seconds: 30),
          payload: {
            'houseId': houseId.trim(),
            'fileName': fileName.trim(),
            'contentType': contentType.trim(),
          },
        );
    return response.data;
  }

  Future<void> _finalizeCreativeDiaryVoiceUpload({
    required String houseId,
    required String sessionId,
    required String content,
    required Map<String, dynamic> metadata,
    required String fileName,
    required String mimeType,
  }) async {
    final response =
        await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
          'finalizeCreativeDiaryVoiceUpload',
          requireAppCheck: true,
          throwOriginalException: true,
          timeout: const Duration(seconds: 30),
          payload: {
            'houseId': houseId.trim(),
            'sessionId': sessionId.trim(),
            'content': content,
            'metadata': metadata,
            'fileName': fileName.trim(),
            'mimeType': mimeType.trim(),
          },
        );
    if (response.data['ok'] != true) {
      throw StateError('Creative diary finalize was not confirmed');
    }
  }

  Future<Uint8List?> _readVoiceBytes(XFile file) async {
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String _detectMimeType(String extension) {
    switch (extension.replaceFirst('.', '').toLowerCase()) {
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

  Stream<List<Map<dynamic, dynamic>>> listenToDiaryPages(String houseId) {
    return _db
        .ref('houses/$houseId/creative_diary')
        .orderByChild('timestamp')
        .limitToLast(20)
        .onValue
        .map((event) {
          if (!event.snapshot.exists) return [];
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          return data.entries.map((e) {
            final item = Map<dynamic, dynamic>.from(e.value as Map);
            item['id'] = e.key;
            return item;
          }).toList()..sort(
            (a, b) => (b['timestamp'] as int? ?? 0).compareTo(
              a['timestamp'] as int? ?? 0,
            ),
          );
        });
  }
}
