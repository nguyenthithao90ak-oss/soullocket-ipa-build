import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:share_plus/share_plus.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';

import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/cinema_video_export_service.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/love_insight_service.dart';

part 'cinema/cinema_models_part.dart';
part 'cinema/cinema_screen_reel_part.dart';
part 'cinema/cinema_screen_widgets.dart';
part 'cinema/cinema_screen_helpers.dart';
part 'cinema/cinema_player_screen_part.dart';
part 'cinema/cinema_player_dialogs_part.dart';
part 'cinema/cinema_player_export_part.dart';
part 'cinema/cinema_player_widgets_part.dart';

const int _kCinemaReelFrameLimit = 15;
const Duration _kCinemaFrameDuration = Duration(seconds: 4);
const double _kCinemaFilmstripCardWidth = 92;
const double _kCinemaFilmstripSpacing = 10;

class CinemaScreen extends StatefulWidget {
  final String houseId;
  final String myName;
  final String? initialUrl;
  final String? initialTitle;
  final String? autoJoinInviteId;

  const CinemaScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.initialUrl,
    this.initialTitle,
    this.autoJoinInviteId,
  });

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ScrollController _filmstripController = ScrollController();
  final LoveInsightService _loveInsightService = LoveInsightService();

  StreamSubscription<DatabaseEvent>? _settingsSub;
  StreamSubscription<DatabaseEvent>? _memoriesSub;
  StreamSubscription<DatabaseEvent>? _dailyReelSub;
  Timer? _previewTimer;

  String _houseName = 'Rạp kỷ niệm';
  DateTime? _startDate;
  List<_CinemaMemoryRecord> _records = const <_CinemaMemoryRecord>[];
  _CinemaDailyReel? _dailyReel;
  int _previewIndex = 0;

  bool _didLoadSettings = false;
  bool _didLoadMemories = false;
  bool _didLoadDailyReel = false;
  bool _isEnsuringDailyReel = false;

  DatabaseReference get _dailyReelRef =>
      _dbRef.child('houses/${widget.houseId}/cinema_daily_reel');

  bool get _hasLegacyPayload =>
      (widget.initialUrl ?? '').trim().isNotEmpty ||
      (widget.initialTitle ?? '').trim().isNotEmpty ||
      (widget.autoJoinInviteId ?? '').trim().isNotEmpty;

  bool get _isLoading =>
      !_didLoadSettings || !_didLoadMemories || !_didLoadDailyReel;

  bool get _isAnniversaryToday {
    return _milestoneForDate(DateTime.now()) != null;
  }

  LoveInsightTimelineEntry? get _todayMilestone =>
      _milestoneForDate(DateTime.now());

  _CinemaDailyReel? get _activeReel {
    final reel = _dailyReel;
    if (reel == null) {
      return null;
    }
    final now = DateTime.now();
    return reel.isActiveAt(now) ? reel : null;
  }

  _CinemaMemoryRecord? get _selectedItem {
    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return null;
    }
    final safeIndex = _previewIndex.clamp(0, reel.items.length - 1);
    return reel.items[safeIndex];
  }

  void _commitState(VoidCallback action) => setState(action);

  @override
  void initState() {
    super.initState();
    _listenToSettings();
    _listenToMemories();
    _listenToDailyReel();
    _startPreviewTimer();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _memoriesSub?.cancel();
    _dailyReelSub?.cancel();
    _previewTimer?.cancel();
    _filmstripController.dispose();
    super.dispose();
  }

  void _listenToSettings() {
    _settingsSub =
        _dbRef.child('houses/${widget.houseId}/settings').onValue.listen(
      (event) {
        final data = _asMap(event.snapshot.value);
        final nextHouseName = _readTrimmedString(data['houseName']);
        _houseName = nextHouseName.isEmpty ? 'Rạp kỷ niệm' : nextHouseName;
        _startDate = _parseDate(data['startDate']);
        _didLoadSettings = true;
        if (mounted) {
          setState(() {});
        }
        unawaited(_ensureDailyReel());
      },
      onError: (Object error) {
        debugPrint(
          'Cinema settings listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tải cài đặt rạp.',
          ).message}',
        );
      },
    );
  }

  void _listenToMemories() {
    _memoriesSub =
        _dbRef.child('houses/${widget.houseId}/memories').onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        final records = <_CinemaMemoryRecord>[];

        if (raw is Map) {
          final memories = Map<dynamic, dynamic>.from(raw);
          memories.forEach((key, value) {
            if (value is! Map) {
              return;
            }
            final item =
                Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
            final imageUrl = _resolveMemoryImage(item);
            if (imageUrl == null) {
              return;
            }

            records.add(
              _CinemaMemoryRecord(
                id: key.toString(),
                imageUrl: imageUrl,
                thumbnailUrl: _readTrimmedString(item['thumbUrl']),
                authorName: _readTrimmedString(
                  item['authorName'] ?? item['author'],
                ),
                timestamp: _parseMemoryTimestamp(item),
              ),
            );
          });
        }

        records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _records = records;
        _didLoadMemories = true;
        if (mounted) {
          setState(() {});
        }
        unawaited(_ensureDailyReel());
      },
      onError: (Object error) {
        debugPrint(
          'Cinema memories listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tải ảnh rạp.',
          ).message}',
        );
      },
    );
  }

  void _listenToDailyReel() {
    _dailyReelSub = _dailyReelRef.onValue.listen(
      (event) {
        final nextReel = _CinemaDailyReel.fromRaw(event.snapshot.value);
        final previousItemId = _selectedItem?.id;
        final nextIndex = _resolvePreviewIndex(nextReel, previousItemId);
        _didLoadDailyReel = true;

        if (!mounted) {
          return;
        }

        setState(() {
          _dailyReel = nextReel;
          _previewIndex = nextIndex;
        });
        _scheduleFilmstripAlignment(animate: false);
        unawaited(_ensureDailyReel());
      },
      onError: (Object error) {
        debugPrint(
          'Cinema reel listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tải reel hôm nay.',
          ).message}',
        );
      },
    );
  }

  Future<void> _ensureDailyReel() async {
    if (_isEnsuringDailyReel ||
        !_didLoadSettings ||
        !_didLoadMemories ||
        !_didLoadDailyReel) {
      return;
    }

    final existing = _dailyReel;
    final now = DateTime.now();
    final todayKey = _dateKey(_normalizeDate(now));
    final milestone = _milestoneForDate(now);

    if (milestone == null || _startDate == null || _records.isEmpty) {
      return;
    }

    if (existing != null &&
        existing.dateKey == todayKey &&
        existing.isActiveAt(now) &&
        existing.items.isNotEmpty) {
      return;
    }

    final nextReel = _buildDailyReel(
      now: now,
      startDate: _startDate!,
      milestone: milestone,
      records: _records,
    );
    if (nextReel == null) {
      return;
    }

    _isEnsuringDailyReel = true;
    try {
      await _dailyReelRef.set(nextReel.toMap());
    } catch (_) {
      // The live subscription remains the source of truth, so ignore local write failures.
    } finally {
      _isEnsuringDailyReel = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reel = _activeReel;
    final selectedItem = _selectedItem;
    final todayMilestone = _todayMilestone;

    return Scaffold(
      backgroundColor: const Color(0xFF09121E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF08111D),
              Color(0xFF121728),
              Color(0xFF1A1020),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -160,
              right: -110,
              child: _buildGlow(
                color: const Color(0x66FF78B8),
                size: 320,
              ),
            ),
            Positioned(
              left: -90,
              top: 210,
              child: _buildGlow(
                color: const Color(0x4477D9FF),
                size: 260,
              ),
            ),
            Positioned(
              bottom: -150,
              left: 40,
              child: _buildGlow(
                color: const Color(0x33FFD36E),
                size: 280,
              ),
            ),
            Positioned(
              bottom: 90,
              right: -70,
              child: _buildGlow(
                color: const Color(0x228F7CFF),
                size: 220,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildTopBar(),
                    const SizedBox(height: 12),
                    _buildHeroCard(reel),
                    if (_hasLegacyPayload) ...<Widget>[
                      const SizedBox(height: 12),
                      _buildLegacyBanner(),
                    ],
                    const SizedBox(height: 14),
                    if (_isLoading)
                      _buildStateCard(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Đang dựng suất chiếu',
                        message:
                            'SoulLocket đang lấy ảnh từ Nhật ký, kiểm tra ngày hôm nay và đồng bộ video kỷ niệm trong ngày.',
                        child: const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            color: Color(0xFFFF6FA5),
                            backgroundColor: Color(0x22FFFFFF),
                          ),
                        ),
                      )
                    else if (_startDate == null)
                      _buildStateCard(
                        icon: Icons.event_busy_rounded,
                        title: 'Chưa có ngày bắt đầu',
                        message:
                            'Rạp chỉ mở được khi nhà của hai bạn có startDate. Hãy cập nhật ngày bắt đầu trong cài đặt cặp đôi trước.',
                      )
                    else if (!_isAnniversaryToday)
                      _buildStateCard(
                        icon: Icons.lock_clock_rounded,
                        title: 'Rạp chưa mở hôm nay',
                        message:
                            'Rạp chỉ mở khi chạm đúng mốc kỷ niệm như 10 ngày, 30 ngày, 100 ngày, 200 ngày, 300 ngày, 365 ngày và các mốc tiếp theo trong phần Kỷ niệm.',
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildLockedShowtimeCard(),
                        ),
                      )
                    else if (_records.isEmpty)
                      _buildStateCard(
                        icon: Icons.photo_library_outlined,
                        title: 'Chưa có ảnh để dựng video',
                        message:
                            'Hôm nay đã tới đúng mốc ${todayMilestone?.title.toLowerCase() ?? 'kỷ niệm'}, nhưng kho Nhật ký của hai bạn chưa có ảnh nào để tạo reel kỷ niệm.',
                      )
                    else if (reel == null || selectedItem == null)
                      _buildStateCard(
                        icon: Icons.movie_creation_outlined,
                        title: 'Đang chốt reel hôm nay',
                        message:
                            'Video kỷ niệm đang được chọn ảnh và đồng bộ cho cả hai người. Mở lại sau vài giây nhé.',
                        child: const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            color: Color(0xFF7FD3FF),
                            backgroundColor: Color(0x22FFFFFF),
                          ),
                        ),
                      )
                    else ...<Widget>[
                      _buildPreviewCard(reel, selectedItem),
                      const SizedBox(height: 14),
                      _buildFilmstrip(reel),
                      const SizedBox(height: 14),
                      _buildReelInfoCard(reel),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
