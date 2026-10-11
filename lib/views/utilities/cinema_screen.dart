import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:soullocket_app/core/sl_page_physics.dart';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:share_plus/share_plus.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';

import '../../core/sl_theme.dart';
import '../../core/sl_route.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/ui_copy.dart';
import '../../utils/screen_activity_mixin.dart';
import '../../utils/services/cinema_video_export_service.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/love_insight_service.dart';
import '../home/tabs/diary/utils/diary_memory_media.dart';
import '../home/tabs/diary/utils/private_memory_link_policy.dart';
import '../home/tabs/diary/widgets/private_diary_image.dart';
import 'cinema/cinema_waiting_room.dart';

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

class _CinemaScreenState extends State<CinemaScreen> with ScreenActivityMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ScrollController _filmstripController = ScrollController();
  final LoveInsightService _loveInsightService = LoveInsightService();

  StreamSubscription<DatabaseEvent>? _settingsSub;
  StreamSubscription<DatabaseEvent>? _memoriesSub;
  StreamSubscription<DatabaseEvent>? _dailyReelSub;
  Timer? _previewTimer;
  Timer? _dayRefreshTimer;

  String _houseName = L10nService().translate('util_rpknim_d094b9');
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

  late String _msgHouseNameDefault;
  late String _msgSettingsLoadFail;
  late String _msgMemoriesLoadFail;
  late String _msgReelLoadFail;

  @override
  void initState() {
    super.initState();

    _listenToSettings();
    _listenToMemories();
    _listenToDailyReel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _msgHouseNameDefault = context.tr('util_rpknim_d094b9');
    _msgSettingsLoadFail = context.tr('util_khngthtici_5693ed');
    _msgMemoriesLoadFail = context.tr('util_khngthtinh_b3efc6');
    _msgReelLoadFail = context.tr('util_khngthtire_9725ac');
  }

  @override
  void onScreenActivityChanged(bool active) {
    _startPreviewTimer();
    _scheduleDayRefresh();
    if (!active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isScreenActive) return;
      setState(() {});
      _startPreviewTimer();
      unawaited(_ensureDailyReel());
    });
  }

  void _scheduleDayRefresh() {
    _dayRefreshTimer?.cancel();
    if (!isScreenActive) return;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayRefreshTimer = Timer(tomorrow.difference(now), () {
      if (!isScreenActive) return;
      setState(() {});
      _startPreviewTimer();
      unawaited(_ensureDailyReel());
      _scheduleDayRefresh();
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _memoriesSub?.cancel();
    _dailyReelSub?.cancel();
    _previewTimer?.cancel();
    _dayRefreshTimer?.cancel();
    _filmstripController.dispose();
    super.dispose();
  }

  void _listenToSettings() {
    _loadSettingsOnce();
  }

  Future<void> _loadSettingsOnce() async {
    try {
      final snapshot = await _dbRef
          .child('houses/${widget.houseId}/settings')
          .get();
      final data = _asMap(snapshot.value);
      final nextHouseName = _readTrimmedString(data['houseName']);
      _houseName = nextHouseName.isEmpty ? _msgHouseNameDefault : nextHouseName;
      _startDate = _parseDate(data['startDate']);
      _didLoadSettings = true;
      if (mounted) {
        setState(() {});
      }
      unawaited(_ensureDailyReel());
    } catch (error) {
      debugPrint(
        'Cinema settings load failed: ${AppErrorMapper.resolve(error, fallbackMessage: _msgSettingsLoadFail).message}',
      );
    }
  }

  void _listenToMemories() {
    _loadMemoriesOnce();
  }

  Future<void> _loadMemoriesOnce() async {
    try {
      final snapshot = await _dbRef
          .child('houses/${widget.houseId}/memories')
          .orderByChild('ts')
          .limitToLast(60)
          .get();
      final raw = snapshot.value;
      final records = <_CinemaMemoryRecord>[];

      if (raw is Map) {
        final memories = Map<dynamic, dynamic>.from(raw);
        memories.forEach((key, value) {
          if (value is! Map) {
            return;
          }
          final item = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(value),
          );
          item['id'] = key.toString();
          if (isDiaryMemoryVideo(item) ||
              item['deletedAt'] != null ||
              item['trashedAt'] != null) {
            return;
          }
          final isPrivate = PrivateMemoryLinkPolicy.isPrivate(item);
          final imageUrl = isPrivate ? '' : _resolveMemoryImage(item);
          if (!isPrivate && imageUrl == null) return;

          records.add(
            _CinemaMemoryRecord(
              id: key.toString(),
              imageUrl: imageUrl ?? '',
              isPrivate: isPrivate,
              thumbnailUrl: isPrivate
                  ? ''
                  : _readTrimmedString(item['thumbUrl']),
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
    } catch (error) {
      debugPrint(
        'Cinema memories load failed: ${AppErrorMapper.resolve(error, fallbackMessage: _msgMemoriesLoadFail).message}',
      );
    }
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
        _startPreviewTimer();
        _scheduleFilmstripAlignment(animate: false);
        unawaited(_ensureDailyReel());
      },
      onError: (Object error) {
        debugPrint(
          'Cinema reel listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: _msgReelLoadFail).message}',
        );
      },
    );
  }

  Future<void> _ensureDailyReel() async {
    if (!mounted ||
        _isEnsuringDailyReel ||
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

    if (!_isLoading &&
        (_startDate == null || !_isAnniversaryToday || _records.isEmpty)) {
      final teaserPhotos = _records.reversed.take(3).toList(growable: false);
      return CinemaWaitingRoom(
        key: ValueKey('cinema-waiting-${widget.houseId}'),
        houseName: _houseName,
        photoCount: teaserPhotos.length,
        photoBuilder: (context, index) =>
            _buildMemoryImage(teaserPhotos[index]),
        milestones: _milestoneTimeline(_startDate)
            .map(
              (entry) => CinemaMilestone(date: entry.date, title: entry.title),
            )
            .toList(growable: false),
        onBack: () => Navigator.of(context).maybePop(),
        onInfo: () => _showInfoDialog(context),
        notice: _hasLegacyPayload ? context.tr('util_linkphimcv_f4802e') : null,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09121E),
      body: Stack(
        children: <Widget>[
          if (reel != null && reel.items.isNotEmpty)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: Stack(
                  key: ValueKey<String>(reel.items.first.id),
                  fit: StackFit.expand,
                  children: [
                    _buildMemoryImage(reel.items.first),
                    FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
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
              ),
            ),
          Positioned.fill(
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -160,
                  right: -110,
                  child: _buildGlow(color: const Color(0x66FF78B8), size: 320),
                ),
                Positioned(
                  left: -90,
                  top: 210,
                  child: _buildGlow(color: const Color(0x4477D9FF), size: 260),
                ),
                Positioned(
                  bottom: -150,
                  left: 40,
                  child: _buildGlow(color: const Color(0x33FFD36E), size: 280),
                ),
                Positioned(
                  bottom: 90,
                  right: -70,
                  child: _buildGlow(color: const Color(0x228F7CFF), size: 220),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 720
                          ? 28.0
                          : 16.0;
                      final availableWidth =
                          constraints.maxWidth - (horizontalPadding * 2);
                      final contentWidth = math
                          .min(availableWidth, 1080.0)
                          .toDouble();

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          10,
                          horizontalPadding,
                          24,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: contentWidth,
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
                                    title: context.tr('util_angdngsutc_7c751f'),
                                    message: context.tr(
                                      'util_soullocket_a4255f',
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 18),
                                      child: LinearProgressIndicator(
                                        minHeight: 6,
                                        color: Color(0xFFFF6FA5),
                                        backgroundColor: Color(0x22FFFFFF),
                                      ),
                                    ),
                                  )
                                else if (reel == null || selectedItem == null)
                                  _buildStateCard(
                                    icon: Icons.movie_creation_outlined,
                                    title: context.tr('util_angchtreel_6b815f'),
                                    message: context.tr(
                                      'util_videoknima_b36e6c',
                                    ),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
