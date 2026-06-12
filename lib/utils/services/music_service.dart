import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../views/ui_prefs.dart';
import '../app_error_mapper.dart';
import 'offline_cache_service.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();

  factory MusicService() => _instance;

  MusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isVisibleNotifier = ValueNotifier<bool>(false);

  String? _currentUrl;
  String _currentType = 'audio';

  static String _normalizedMediaPath(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('\\', '/').trim().toLowerCase();
  }

  static bool _hasSupportedAudioExtension(String path) {
    return path.endsWith('.mp3') ||
        path.endsWith('.mp4') ||
        path.endsWith('.m4a') ||
        path.endsWith('.wav') ||
        path.endsWith('.ogg') ||
        path.endsWith('.aac') ||
        path.endsWith('.flac');
  }

  static bool isLocalAudioPath(String path) {
    if (kIsWeb) {
      return false;
    }

    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return false;
    }

    final normalizedPath = _normalizedMediaPath(trimmed);
    if (normalizedPath.isEmpty) {
      return false;
    }

    return _hasSupportedAudioExtension(normalizedPath);
  }

  static bool isSupportedMusicUrl(String url) {
    return isLocalAudioPath(url);
  }

  static String inferMediaType(String url) {
    final path = _normalizedMediaPath(url);
    if (path.endsWith('.mp4')) {
      return 'video';
    }
    return 'audio';
  }

  Future<void> init() async {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      isPlayingNotifier.value = state == PlayerState.playing;
    });

    UiPrefs.notifier.addListener(_handleUiPrefsChanged);

    unawaited(_applyResolvedMusic());
  }

  void _handleUiPrefsChanged() {
    final state = UiPrefs.notifier.value;
    if (!state.musicAutoplay) {
      if (isPlayingNotifier.value) {
        stop(keepCurrentUrl: true);
      }
    } else {
      if (!isPlayingNotifier.value && _currentUrl != null) {
        play(_currentUrl!, type: _currentType);
      }
    }
  }

  Future<void> _applyResolvedMusic() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final localMusicData = _readLocalMusicData(prefs);
    final data = localMusicData;
    final url = _resolveMusicUrl(data);
    final type = _resolveMusicType(data, url);
    final allowLocalAutoplay = prefs.getBool('il_music_autoplay') ?? false;
    final previousUrl = _currentUrl;

    if (url.isEmpty) {
      await stop();
      isVisibleNotifier.value = false;
      return;
    }

    isVisibleNotifier.value = true;
    _currentUrl = url;
    _currentType = type;

    if (allowLocalAutoplay) {
      if (url != previousUrl || !isPlayingNotifier.value) {
        await play(url, type: type);
      }
    } else {
      await stop(keepCurrentUrl: true);
    }
  }

  Map<String, dynamic> _readLocalMusicData(SharedPreferences prefs) {
    final localUrl = (prefs.getString('il_local_music_url') ?? '').trim();
    if (!isLocalAudioPath(localUrl)) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{
      'bgMusic': localUrl,
      'musicLink': (prefs.getString('il_local_music_link') ?? localUrl).trim(),
      'musicType': (prefs.getString('il_local_music_type') ?? 'audio').trim(),
      'musicTitle': (prefs.getString('il_local_music_title') ?? '').trim(),
      'musicAutoEnabled': true,
    };
  }

  String _resolveMusicUrl(Map<String, dynamic> data) {
    final candidates = <String>[
      (data['bgMusic'] ?? '').toString().trim(),
    ];
    for (final candidate in candidates) {
      if (isSupportedMusicUrl(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  String _resolveMusicType(Map<String, dynamic> _, String url) {
    return inferMediaType(url);
  }

  Future<void> play(String url, {String? type}) async {
    final normalizedUrl = url.trim();
    if (!isSupportedMusicUrl(normalizedUrl)) {
      debugPrint('Rejected background music URL: $normalizedUrl');
      await stop();
      isVisibleNotifier.value = false;
      return;
    }

    _currentUrl = normalizedUrl;
    _currentType = type ?? inferMediaType(normalizedUrl);
    isVisibleNotifier.value = true;
    try {
      await _audioPlayer.play(DeviceFileSource(normalizedUrl));
    } catch (e) {
      debugPrint('Error playing music: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể phát nhạc.',
      ).message}');
      isPlayingNotifier.value = false;
    }
  }

  Future<void> stop({bool keepCurrentUrl = false}) async {
    await _audioPlayer.stop();
    isPlayingNotifier.value = false;
    if (!keepCurrentUrl) {
      _currentUrl = null;
      _currentType = 'audio';
    }
  }

  Future<void> toggle() async {
    if (isPlayingNotifier.value) {
      await _audioPlayer.pause();
      return;
    }

    if (_currentUrl != null) {
      await play(_currentUrl!, type: _currentType);
    }
  }

  String get currentType => _currentType;
  String? get currentUrl => _currentUrl;
}
