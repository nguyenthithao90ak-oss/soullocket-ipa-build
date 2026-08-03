import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';

class MusicTrack {
  final String url;
  final String title;
  final String type;

  MusicTrack({required this.url, required this.title, required this.type});

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'audio',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'type': type,
      };
}

class MusicService {
  static final MusicService _instance = MusicService._internal();

  factory MusicService() => _instance;

  MusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isVisibleNotifier = ValueNotifier<bool>(false);

  List<MusicTrack> _playlist = [];
  int _currentIndex = 0;

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
    if (kIsWeb) return false;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return false;
    final normalizedPath = _normalizedMediaPath(trimmed);
    if (normalizedPath.isEmpty) return false;
    return _hasSupportedAudioExtension(normalizedPath);
  }

  static bool isSupportedMusicUrl(String url) {
    return isLocalAudioPath(url);
  }

  static String inferMediaType(String url) {
    final path = _normalizedMediaPath(url);
    if (path.endsWith('.mp4')) return 'video';
    return 'audio';
  }

  void _onPlayerStateChanged(PlayerState state) {
    isPlayingNotifier.value = state == PlayerState.playing;
  }

  void _onPlayerComplete() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    final nextTrack = _playlist[_currentIndex];
    if (isSupportedMusicUrl(nextTrack.url)) {
      play(nextTrack.url, type: nextTrack.type);
    } else {
      stop();
      isVisibleNotifier.value = false;
    }
  }

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _playerStateSub =
        _audioPlayer.onPlayerStateChanged.listen(_onPlayerStateChanged);
    _playerCompleteSub =
        _audioPlayer.onPlayerComplete.listen((_) => _onPlayerComplete());

    UiPrefs.notifier.addListener(_handleUiPrefsChanged);

    unawaited(_applyResolvedMusic());
  }

  /// Giải phóng tài nguyên — gọi khi service không còn được dùng.
  void dispose() {
    if (!_isInitialized) return;
    _isInitialized = false;

    _playerStateSub?.cancel();
    _playerStateSub = null;
    _playerCompleteSub?.cancel();
    _playerCompleteSub = null;
    UiPrefs.notifier.removeListener(_handleUiPrefsChanged);
    _audioPlayer.dispose();
    isPlayingNotifier.dispose();
    isVisibleNotifier.dispose();
  }

  void _handleUiPrefsChanged() {
    final state = UiPrefs.notifier.value;
    if (!state.musicAutoplay) {
      if (isPlayingNotifier.value) {
        stop(keepPlaylist: true);
      }
    } else {
      if (!isPlayingNotifier.value && _playlist.isNotEmpty) {
        final track = _playlist[_currentIndex];
        play(track.url, type: track.type);
      }
    }
  }

  Future<void> _applyResolvedMusic() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    _playlist = _readLocalMusicData(prefs);
    _currentIndex = 0;
    final allowLocalAutoplay = prefs.getBool('il_music_autoplay') ?? false;

    if (_playlist.isEmpty) {
      await stop();
      isVisibleNotifier.value = false;
      return;
    }

    isVisibleNotifier.value = true;
    final track = _playlist[_currentIndex];

    if (allowLocalAutoplay) {
      await play(track.url, type: track.type);
    } else {
      await stop(keepPlaylist: true);
    }
  }

  List<MusicTrack> _readLocalMusicData(SharedPreferences prefs) {
    final playlistJson = prefs.getString('il_local_music_playlist');
    if (playlistJson != null && playlistJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(playlistJson);
        final list = decoded
            .map((e) => MusicTrack.fromJson(e))
            .where((t) => isLocalAudioPath(t.url))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Error decoding playlist: $e');
      }
    }

    final localUrl = (prefs.getString('il_local_music_url') ?? '').trim();
    if (isLocalAudioPath(localUrl)) {
      final type = (prefs.getString('il_local_music_type') ?? 'audio').trim();
      final title = (prefs.getString('il_local_music_title') ?? '').trim();
      return [MusicTrack(url: localUrl, title: title, type: type)];
    }

    return [];
  }

  Future<void> reloadPlaylist() async {
    await _applyResolvedMusic();
  }

  Future<void> play(String url, {String? type}) async {
    final normalizedUrl = url.trim();
    if (!isSupportedMusicUrl(normalizedUrl)) {
      debugPrint('Rejected background music URL: $normalizedUrl');
      await stop();
      isVisibleNotifier.value = false;
      return;
    }

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

  Future<void> stop({bool keepPlaylist = false}) async {
    await _audioPlayer.stop();
    isPlayingNotifier.value = false;
    if (!keepPlaylist) {
      _playlist.clear();
      _currentIndex = 0;
    }
  }

  Future<void> toggle() async {
    if (isPlayingNotifier.value) {
      await _audioPlayer.pause();
      return;
    }

    if (_playlist.isNotEmpty) {
      final track = _playlist[_currentIndex];
      await play(track.url, type: track.type);
    }
  }

  String get currentType =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
          ? _playlist[_currentIndex].type
          : 'audio';
  String? get currentUrl =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
          ? _playlist[_currentIndex].url
          : null;
  List<MusicTrack> get playlist => _playlist;
}
