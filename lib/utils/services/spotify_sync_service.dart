import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import '../app_error_mapper.dart';

/// ============================================================
///  SpotifySyncService — Gra (Logic/Data)
///  Trạm phát nhạc chung - Play/Pause Realtime (Phase 11)
///
///  Chức năng:
///  1. Giao tiếp với Spotify App (Qua MethodChannel hoặc API/SDK).
///  2. Bắt tín hiệu Play, Pause, Seek từ điện thoại NÀY
///     và cập nhật lên Firebase nhánh 'spotify_sync'.
///  3. Điện thoại KIA lắng nghe Firebase và tự kích hoạt Spotify y hệt.
/// ============================================================
class SpotifySyncService {
  static final SpotifySyncService _instance = SpotifySyncService._internal();
  factory SpotifySyncService() => _instance;
  SpotifySyncService._internal();

  final _db = FirebaseDatabase.instance;
  static const platform = MethodChannel('com.soullocket.app/spotify');

  // ignore: unused_field
  bool _isSyncing = false;

  /// Kích hoạt tính năng "Cùng Nhau Nghe Nhạc"
  Future<void> startSyncSession(String houseId, String trackId) async {
    _isSyncing = true;
    final sessionData = {
      'trackId': trackId,
      'isPlaying': true,
      'positionMs': 0,
      'lastUpdatedAt': ServerValue.timestamp,
    };

    // Tạo luồng chung trên Firebase
    await _db.ref('houses/$houseId/spotify_sync').set(sessionData);

    // Kích hoạt bài nhạc ở máy cục bộ (MethodChannel bắn lệnh sang Android/iOS chạy Spotify)
    try {
      await platform.invokeMethod('playTrack', {'trackUri': trackId});
    } catch (e) {
      debugPrint("Lỗi không mở được Spotify: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể mở Spotify.',
      ).message}");
    }
  }

  /// Trae sẽ dùng Stream này để vẽ Tình trạng Đĩa Than (Đang xoay hay dừng)
  Stream<Map<dynamic, dynamic>?> listenToPartnerMusic(String houseId) {
    return _db.ref('houses/$houseId/spotify_sync').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// Nút bấm Tạm dừng / Phát tiếp dùng chung
  Future<void> togglePlayPause(String houseId, bool isPlaying) async {
    await _db.ref('houses/$houseId/spotify_sync').update({
      'isPlaying': isPlaying,
      'lastUpdatedAt': ServerValue.timestamp,
    });

    try {
      if (isPlaying) {
        await platform.invokeMethod('resumePlayback');
      } else {
        await platform.invokeMethod('pausePlayback');
      }
    } catch (e) {
      debugPrint("Lỗi đài âm thanh: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể điều khiển phát nhạc.',
      ).message}");
    }
  }

  void stopSyncSession() {
    _isSyncing = false;
    platform.invokeMethod('pausePlayback');
  }
}
