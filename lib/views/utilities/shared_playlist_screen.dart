import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/sl_theme.dart';

// ============================================================
// PHASE 34: SHARED PLAYLIST VIBE — GRA FULLSTACK
// Backend Service + UI Screen cùng 1 file
// ============================================================

class PlaylistVibeService {
  static final PlaylistVibeService _i = PlaylistVibeService._();
  factory PlaylistVibeService() => _i;
  PlaylistVibeService._();

  final _db = FirebaseDatabase.instance;

  Future<void> syncNowPlaying(
      String houseId, Map<String, dynamic> track) async {
    await _db.ref('houses/$houseId/playlist/now_playing').set({
      ...track,
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> syncPlaybackState(String houseId, bool isPlaying) async {
    await _db.ref('houses/$houseId/playlist/now_playing').update({
      'isPlaying': isPlaying,
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> skipTrack(String houseId) async {
    await _db
        .ref('houses/$houseId/playlist/command')
        .set({'action': 'skip', 'ts': ServerValue.timestamp});
  }

  Stream<Map<dynamic, dynamic>?> listenToNowPlaying(String houseId) {
    return _db.ref('houses/$houseId/playlist/now_playing').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return null;
      return Map<dynamic, dynamic>.from(raw);
    });
  }

  Stream<List<Map<String, dynamic>>> listenToTracks(String houseId) {
    return _db.ref('houses/$houseId/couple_songs/list').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return [];
      final data = Map<dynamic, dynamic>.from(raw);
      final tracks = <Map<String, dynamic>>[];
      for (final entry in data.entries) {
        if (entry.value is! Map) continue;
        final item = Map<String, dynamic>.from(entry.value);
        item['id'] = entry.key;
        tracks.add(item);
      }
      tracks.sort(
        (a, b) => ((b['ts'] as num?)?.toInt() ?? 0)
            .compareTo((a['ts'] as num?)?.toInt() ?? 0),
      );
      return tracks;
    });
  }
}

class SharedPlaylistScreen extends StatefulWidget {
  final String houseId;
  const SharedPlaylistScreen({super.key, required this.houseId});

  @override
  State<SharedPlaylistScreen> createState() => _SharedPlaylistScreenState();
}

class _SharedPlaylistScreenState extends State<SharedPlaylistScreen>
    with TickerProviderStateMixin {
  final _svc = PlaylistVibeService();
  late AnimationController _vinylController;
  late AnimationController _barsController;
  StreamSubscription<List<Map<String, dynamic>>>? _tracksSubscription;
  StreamSubscription<Map<dynamic, dynamic>?>? _nowPlayingSubscription;
  bool _isPlaying = true;
  List<Map<String, dynamic>> _tracks = [];
  int _currentIndex = 0;
  String? _nowPlayingId;
  bool? _remotePlaybackState;

  @override
  void initState() {
    super.initState();
    _vinylController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _barsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _tracksSubscription = _svc.listenToTracks(widget.houseId).listen((tracks) {
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        if (_tracks.isEmpty) {
          _currentIndex = 0;
          _nowPlayingId = null;
        } else if (_nowPlayingId != null) {
          final index = _tracks.indexWhere(
            (track) => track['id']?.toString() == _nowPlayingId,
          );
          _currentIndex = index >= 0 ? index : 0;
        } else if (_currentIndex >= _tracks.length) {
          _currentIndex = 0;
        }
        if (_remotePlaybackState != null) {
          _isPlaying = _remotePlaybackState!;
        }
      });
      _applyPlaybackAnimation();
    });

    _nowPlayingSubscription =
        _svc.listenToNowPlaying(widget.houseId).listen((current) {
      if (!mounted || current == null) return;
      final id = current['id']?.toString();
      final remoteIsPlaying = _parseIsPlaying(current['isPlaying']);
      if ((id == null || id.isEmpty) && remoteIsPlaying == null) return;
      final index = id == null || id.isEmpty || _tracks.isEmpty
          ? -1
          : _tracks.indexWhere((track) => track['id']?.toString() == id);
      setState(() {
        if (id != null && id.isNotEmpty) {
          _nowPlayingId = id;
        }
        if (index >= 0) {
          _currentIndex = index;
        }
        if (remoteIsPlaying != null) {
          _remotePlaybackState = remoteIsPlaying;
          _isPlaying = remoteIsPlaying;
        }
      });
      _applyPlaybackAnimation();
    });
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _nowPlayingSubscription?.cancel();
    _vinylController.dispose();
    _barsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTracks = _tracks.isNotEmpty;
    final track = hasTracks ? _tracks[_currentIndex] : null;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: SLSpacing.all20,
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white)),
                    Expanded(
                        child: Text('Cùng Nghe Nhạc 🎶',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20))),
                    SLSpacing.gapW(48),
                  ],
                ),
              ),
              SLSpacing.h20,
              AnimatedBuilder(
                animation: _vinylController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _isPlaying && hasTracks
                        ? _vinylController.value * 2 * pi
                        : 0,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [
                      Color(0xFF2d2d2d),
                      Color(0xFF1a1a1a),
                      Color(0xFF3d3d3d)
                    ], stops: [
                      0.3,
                      0.6,
                      1.0
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      hasTracks ? '🎵' : '💿',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
              SLSpacing.gapH(30),
              Text(
                hasTracks
                    ? (track!['title']?.toString() ?? 'Chưa có bài hát')
                    : 'Chưa có bài hát chung',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24),
              ),
              SLSpacing.h8,
              Text(
                hasTracks
                    ? (track!['a']?.toString().isNotEmpty == true
                        ? 'Thêm bởi ${track['a']}'
                        : 'Playlist đôi')
                    : 'Hãy thêm bài hát trong mục Bài Hát đôi',
                style: SLTheme.quicksand(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
              if (hasTracks &&
                  (track!['note']?.toString().trim().isNotEmpty ?? false)) ...[
                SLSpacing.h12,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    track['note'].toString(),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              SLSpacing.gapH(30),
              AnimatedBuilder(
                animation: _barsController,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(12, (i) {
                      final h = _isPlaying && hasTracks
                          ? (20 +
                                  sin(_barsController.value * pi + i * 0.8) *
                                      20)
                              .abs()
                          : 4.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 5,
                        height: h,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                              Colors.purple, Colors.pinkAccent, i / 12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                },
              ),
              SLSpacing.gapH(30),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white),
                    onPressed: !hasTracks
                        ? null
                        : () {
                            setState(() {
                              _currentIndex =
                                  (_currentIndex - 1 + _tracks.length) %
                                      _tracks.length;
                              _isPlaying = true;
                            });
                            _applyPlaybackAnimation();
                            _syncSelectedTrack();
                          },
                  ),
                  SLSpacing.w20,
                  GestureDetector(
                    onTap: !hasTracks
                        ? null
                        : () async {
                            await _setPlayback(!_isPlaying);
                          },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [Colors.purple, Colors.pinkAccent])),
                      child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40),
                    ),
                  ),
                  SLSpacing.w20,
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white),
                    onPressed: !hasTracks
                        ? null
                        : () async {
                            setState(() {
                              _currentIndex =
                                  (_currentIndex + 1) % _tracks.length;
                              _isPlaying = true;
                            });
                            _applyPlaybackAnimation();
                            await _syncSelectedTrack();
                            await _svc.skipTrack(widget.houseId);
                          },
                  ),
                ],
              ),
              SLSpacing.h20,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔴 Đang phát cùng người ấy • Realtime',
                      style: SLTheme.quicksand(
                          color: Colors.pinkAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (hasTracks) ...[
                    SLSpacing.w8,
                    GestureDetector(
                      onTap: () =>
                          _openTrackLink(track!['link']?.toString() ?? ''),
                      child: Text(
                        'MỞ LINK',
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SLSpacing.h24,
              Expanded(
                child: hasTracks ? _buildPlaylist() : _buildEmptyPlaylist(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncSelectedTrack() async {
    if (_tracks.isEmpty) return;
    final track = _tracks[_currentIndex];
    await _svc.syncNowPlaying(widget.houseId, {
      'id': track['id'],
      'title': track['title'],
      'artist': track['a'] ?? '',
      'note': track['note'] ?? '',
      'link': track['link'] ?? '',
      'isPlaying': _isPlaying,
    });
  }

  bool? _parseIsPlaying(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  void _applyPlaybackAnimation() {
    if (_isPlaying && _tracks.isNotEmpty) {
      if (!_vinylController.isAnimating) {
        _vinylController.repeat();
      }
      if (!_barsController.isAnimating) {
        _barsController.repeat(reverse: true);
      }
      return;
    }
    _vinylController.stop();
    _barsController.stop();
  }

  Future<void> _setPlayback(bool isPlaying) async {
    setState(() {
      _isPlaying = isPlaying;
    });
    _applyPlaybackAnimation();
    if (_tracks.isEmpty) return;
    if (isPlaying) {
      await _syncSelectedTrack();
      return;
    }
    await _svc.syncPlaybackState(widget.houseId, false);
  }

  Future<void> _openTrackLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildPlaylist() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        final isCurrent = index == _currentIndex;
        return GestureDetector(
          onTap: () async {
            setState(() {
              _currentIndex = index;
              _isPlaying = true;
            });
            _applyPlaybackAnimation();
            await _syncSelectedTrack();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.white.withOpacity(0.16)
                  : Colors.white.withOpacity(0.08),
              borderRadius: SLRadius.lgAll,
              border: Border.all(
                color: isCurrent
                    ? Colors.pinkAccent.withOpacity(0.6)
                    : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: SLRadius.mdAll,
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.equalizer_rounded
                        : Icons.music_note_rounded,
                    color: Colors.white,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title']?.toString() ?? 'Bài hát chưa đặt tên',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        track['a']?.toString().isNotEmpty == true
                            ? 'Thêm bởi ${track['a']}'
                            : 'Playlist đôi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaylist() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'Chưa có bài hát chung nào để đồng bộ. Hãy thêm bài hát trong mục Bài Hát đôi rồi quay lại đây để nghe cùng nhau.',
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
