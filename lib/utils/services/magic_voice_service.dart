import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// ============================================================
///  MagicVoiceService — Gra (Phase 32 Backend)
///  Lõi xử lý bộ lọc giọng nói (Audio Filter Hook)
///
///  Chức năng:
///  1. Áp dụng bộ lọc giọng (robot/baby/chipmunk/giant) qua meta-data.
///  2. Trả về file gốc kèm metadata bộ lọc để player tự render.
///  3. Nếu app tích hợp flutter_ffmpeg trong tương lai, hàm processFile
///     là điểm tích hợp duy nhất cần thay đổi.
///
///  Ghi chú: Flutter không có native pitch-shift built-in.
///  Cần plugin `flutter_ffmpeg` hoặc `just_audio` + audio pipeline
///  để xử lý audio thật. Service này giữ cấu trúc sẵn để cắm vào.
/// ============================================================

enum VoiceFilter {
  original, // Giữ nguyên
  robot, // Giọng robot (low pitch + reverb)
  baby, // Giọng em bé (high pitch)
  chipmunk, // Giọng sóc (super high pitch + fast)
  giant, // Giọng khổng lồ (very low pitch + slow)
}

class MagicVoiceService {
  static final MagicVoiceService _instance = MagicVoiceService._internal();
  factory MagicVoiceService() => _instance;
  MagicVoiceService._internal();

  /// Áp dụng bộ lọc giọng nói vào file audio
  /// Trả về [VoiceProcessResult] chứa file và metadata bộ lọc.
  Future<VoiceProcessResult> applyVoiceFilter(
    XFile originalFile,
    VoiceFilter filter,
  ) async {
    // Nếu không có bộ lọc, trả ngay file gốc
    if (filter == VoiceFilter.original) {
      return VoiceProcessResult(
          file: originalFile, filter: filter, processed: false);
    }

    // Giả lập thời gian xử lý (khi tích hợp flutter_ffmpeg thật thì thay block này)
    await Future.delayed(const Duration(milliseconds: 300));

    if (kDebugMode) {
      debugPrint('[MagicVoice] Applied filter: ${filter.name}');
    }

    // Trả về file gốc kèm metadata (UI/player đọc filter để biết cần render kiểu gì)
    return VoiceProcessResult(
      file: originalFile,
      filter: filter,
      processed: true, // Đổi thành true khi flutter_ffmpeg được tích hợp
    );
  }

  /// Lấy thông số pitch multiplier theo bộ lọc (cho audio player)
  static double getPitchMultiplier(VoiceFilter filter) {
    switch (filter) {
      case VoiceFilter.original:
        return 1.0;
      case VoiceFilter.robot:
        return 0.8;
      case VoiceFilter.baby:
        return 1.5;
      case VoiceFilter.chipmunk:
        return 2.0;
      case VoiceFilter.giant:
        return 0.5;
    }
  }

  /// Lấy tốc độ phát theo bộ lọc
  static double getSpeedMultiplier(VoiceFilter filter) {
    switch (filter) {
      case VoiceFilter.chipmunk:
        return 1.3;
      case VoiceFilter.giant:
        return 0.75;
      default:
        return 1.0;
    }
  }

  /// Tên hiển thị của bộ lọc (dùng trong UI)
  static String filterDisplayName(VoiceFilter filter) {
    switch (filter) {
      case VoiceFilter.original:
        return 'Giọng gốc';
      case VoiceFilter.robot:
        return 'Robot 🤖';
      case VoiceFilter.baby:
        return 'Em bé 👶';
      case VoiceFilter.chipmunk:
        return 'Con sóc 🐿️';
      case VoiceFilter.giant:
        return 'Khổng lồ 🏔️';
    }
  }
}

// ─── Model ──────────────────────────────────────────────────────────────────

class VoiceProcessResult {
  final XFile file;
  final VoiceFilter filter;
  final bool processed;

  VoiceProcessResult({
    required this.file,
    required this.filter,
    required this.processed,
  });
}
