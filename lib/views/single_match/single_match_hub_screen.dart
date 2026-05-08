import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../models/single_match_models.dart';
import '../../services/single_match_service.dart';
import '../community/community_settings_screen.dart';
import '../relationship/video_call_screen.dart';
import '../visitors/visitor_profile_screen.dart';

part 'single_match/single_match_action_panels.dart';
part 'single_match/single_match_candidate_cards.dart';
part 'single_match/single_match_dialogs.dart';
part 'single_match/single_match_header.dart';
part 'single_match/single_match_state_helpers.dart';

class SingleMatchHubScreen extends StatefulWidget {
  final String houseId;

  const SingleMatchHubScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<SingleMatchHubScreen> createState() => _SingleMatchHubScreenState();
}

class _SingleMatchHubScreenState extends State<SingleMatchHubScreen>
    with SingleTickerProviderStateMixin {
  static const List<_MatchChoice> _goalOptions = <_MatchChoice>[
    _MatchChoice(
      value: 'meaningful',
      label: 'Nói chuyện sâu',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF5F8F),
    ),
    _MatchChoice(
      value: 'friendship',
      label: 'Bạn mới',
      icon: Icons.groups_rounded,
      color: Color(0xFF5B8DEF),
    ),
    _MatchChoice(
      value: 'serious',
      label: 'Hẹn hò nghiêm túc',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFB347),
    ),
    _MatchChoice(
      value: 'night_owl',
      label: 'Tâm sự đêm khuya',
      icon: Icons.nightlight_round,
      color: Color(0xFF7C5CFF),
    ),
  ];

  static const List<_MatchChoice> _voiceOptions = <_MatchChoice>[
    _MatchChoice(
      value: 'warm',
      label: 'Dịu dàng',
      icon: Icons.waves_rounded,
      color: Color(0xFFEF5DA8),
    ),
    _MatchChoice(
      value: 'funny',
      label: 'Hài hước',
      icon: Icons.celebration_rounded,
      color: Color(0xFFFF9D42),
    ),
    _MatchChoice(
      value: 'deep',
      label: 'Sâu sắc',
      icon: Icons.psychology_rounded,
      color: Color(0xFF4E7BF2),
    ),
    _MatchChoice(
      value: 'energetic',
      label: 'Năng lượng',
      icon: Icons.bolt_rounded,
      color: Color(0xFF18B67A),
    ),
  ];

  static const List<String> _tagSuggestions = <String>[
    'Âm nhạc',
    'Du lịch',
    'Cafe',
    'Podcast',
    'Đêm khuya',
    'Sách',
    'Chụp ảnh',
    'Game',
    'Chữa lành',
    'Workout',
    'Tâm lý',
    'Nấu ăn',
  ];

  final SingleMatchService _service = SingleMatchService.instance;
  final TextEditingController _introController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final Random _random = Random();

  late final TabController _tabController;
  late final Stream<List<SingleMatchHistoryEntry>> _historyStream;
  late final Stream<List<SingleMatchCandidate>> _candidateStream;
  late final Stream<_SingleMatchDiscoverySnapshot> _discoveryStream;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _callingHouseId;
  String? _featuredHouseId;
  String? _loadError;

  SingleMatchPreferences _savedPreferences = const SingleMatchPreferences();
  SingleMatchPreferences _draftPreferences = const SingleMatchPreferences();
  Set<String> _blockedHouseIds = <String>{};
  final Set<String> _sessionSkippedHouseIds = <String>{};

  Map<String, dynamic> _mySettings = <String, dynamic>{};
  String _myDob = '';
  String _savedDob = '';
  String _displayName = 'Bạn';
  // ignore: unused_field
  String _houseName = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _historyStream = _service.streamHistory(widget.houseId).asBroadcastStream();
    _candidateStream =
        _service.streamCandidates(currentHouseId: widget.houseId);
    _discoveryStream = _combineLatest2<List<SingleMatchHistoryEntry>,
        List<SingleMatchCandidate>, _SingleMatchDiscoverySnapshot>(
      _historyStream,
      _candidateStream,
      (history, candidates) => _SingleMatchDiscoverySnapshot(
        history: history,
        candidates: candidates,
      ),
    );
    _introController.addListener(_handleDraftTextChanged);
    _tagsController.addListener(_handleDraftTextChanged);
    _loadBootstrap();
  }

  @override
  void dispose() {
    _introController.removeListener(_handleDraftTextChanged);
    _tagsController.removeListener(_handleDraftTextChanged);
    _introController.dispose();
    _tagsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleDraftTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBootstrap() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    Future<T> guarded<T>(
      Future<T> future,
      T fallback,
      String label,
    ) async {
      try {
        return await future.timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint('[SingleMatch] $label failed: $error');
        return fallback;
      }
    }

    try {
      final results = await Future.wait<dynamic>([
        guarded<Map<String, dynamic>>(
          _service.fetchHouseSettings(widget.houseId),
          <String, dynamic>{},
          'fetch house settings',
        ),
        guarded<SingleMatchPreferences>(
          _service.loadPreferences(widget.houseId),
          const SingleMatchPreferences(),
          'load preferences',
        ),
        guarded<Set<String>>(
          _service.fetchBlockedHouseIds(widget.houseId),
          <String>{},
          'fetch blocked houses',
        ),
      ]).timeout(const Duration(seconds: 10));

      final settings = results[0] as Map<String, dynamic>;
      final preferences = results[1] as SingleMatchPreferences;
      final blocked = Set<String>.from(results[2] as Set);

      final displayName = (settings['nameU1'] ?? settings['houseName'] ?? 'Bạn')
          .toString()
          .trim();
      final houseName =
          (settings['houseName'] ?? widget.houseId).toString().trim();
      final avatarUrl = (settings['houseAvatar'] ?? settings['avtUser1'] ?? '')
          .toString()
          .trim();
      final dob = (settings['dobU1'] ?? '').toString().trim();

      if (!mounted) {
        return;
      }

      _introController.text = preferences.intro;
      _tagsController.text = preferences.tags.join(', ');

      setState(() {
        _mySettings = settings;
        _savedPreferences = preferences;
        _draftPreferences = preferences;
        _blockedHouseIds = blocked;
        _displayName = displayName.isEmpty ? 'Bạn' : displayName;
        _houseName = houseName.isEmpty ? widget.houseId : houseName;
        _avatarUrl = avatarUrl;
        _myDob = dob;
        _savedDob = dob;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  SingleMatchPreferences get _currentPreferences {
    return _draftPreferences.copyWith(
      intro: _introController.text.trim(),
      tags: _parseTags(_tagsController.text),
    );
  }

  bool get _hasUnsavedChanges {
    return !_currentPreferences.sameAs(_savedPreferences) ||
        _myDob != _savedDob;
  }

  int? get _myAge => _ageFromDob(_myDob);

  bool get _hasEnabledCallMode =>
      _currentPreferences.allowAudioCalls ||
      _currentPreferences.allowVideoCalls;

  // ignore: unused_element
  List<String> get _activeTags => _parseTags(_tagsController.text);

  // ignore: unused_element
  List<String> _profileIssues() {
    final issues = <String>[];
    if (!_currentPreferences.enabled) {
      issues.add('đang tắt xuất hiện trong pool');
    }
    if (!_hasEnabledCallMode) {
      issues.add('chưa bật thoại hoặc video');
    }
    return issues;
  }

  int get _profileCompletion {
    var score = 0;
    if (_avatarUrl.trim().isNotEmpty) score++;
    if ((_mySettings['bio'] ?? '').toString().trim().isNotEmpty) score++;
    if (_myDob.trim().isNotEmpty) score++;
    if (_introController.text.trim().isNotEmpty) score++;
    if (_parseTags(_tagsController.text).isNotEmpty) score++;
    return ((score / 5) * 100).round();
  }

  List<String> _parseTags(String raw) {
    return _singleMatchParseTags(raw);
  }

  int? _ageFromDob(String rawDob) {
    return _singleMatchAgeFromDob(rawDob);
  }

  Future<void> _pickDob() async {
    final initial = DateTime.tryParse(_myDob) ??
        DateTime.now().subtract(const Duration(days: 365 * 23));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF4F87),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _myDob = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _savePreferences() async {
    if (_isSaving) {
      return;
    }

    final preferences = _currentPreferences;
    if (preferences.enabled &&
        !preferences.allowAudioCalls &&
        !preferences.allowVideoCalls) {
      _showSnack(
        'Hãy bật ít nhất thoại hoặc video nếu muốn hồ sơ xuất hiện trong Single Match.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service
          .savePreferences(
            houseId: widget.houseId,
            preferences: preferences,
          )
          .timeout(const Duration(seconds: 10));
      if (_myDob != _savedDob) {
        await _service
            .updateOwnDob(
              houseId: widget.houseId,
              isoDob: _myDob,
            )
            .timeout(const Duration(seconds: 10));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _savedPreferences = preferences;
        _draftPreferences = preferences;
        _savedDob = _myDob;
        _mySettings['dobU1'] = _myDob;
      });
      _showSnack('Đã lưu cài đặt ghép nối.');
    } catch (error) {
      _showSnack('Không thể lưu cài đặt: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openCommunitySettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsScreen(houseId: widget.houseId),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadBootstrap();
  }

  List<_ScoredCandidate> _scoreCandidates(
    List<SingleMatchCandidate> candidates,
    List<SingleMatchHistoryEntry> history,
  ) {
    final current = _currentPreferences;
    final myAge = _myAge;
    final myTags = _activeTags.map((tag) => tag.toLowerCase()).toSet();
    final latestHistoryByPeer = <String, SingleMatchHistoryEntry>{};
    for (final entry in history) {
      final peerHouseId = entry.peerHouseId.trim();
      if (peerHouseId.isEmpty) {
        continue;
      }
      latestHistoryByPeer.putIfAbsent(peerHouseId, () => entry);
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const skipCooldown = Duration(hours: 18);
    const recentSkipPenaltyWindow = Duration(days: 3);
    const recentCallCooldown = Duration(hours: 8);
    const recentCallPenaltyWindow = Duration(days: 3);

    final scored = <_ScoredCandidate>[];
    for (final candidate in candidates) {
      if (!candidate.enabled) {
        continue;
      }
      if (!candidate.allowAudioCalls && !candidate.allowVideoCalls) {
        continue;
      }
      if (_blockedHouseIds.contains(candidate.houseId) ||
          _sessionSkippedHouseIds.contains(candidate.houseId)) {
        continue;
      }

      final canAudioCall = current.allowAudioCalls && candidate.allowAudioCalls;
      final canVideoCall = current.allowVideoCalls && candidate.allowVideoCalls;
      if (!canAudioCall && !canVideoCall) {
        continue;
      }

      final lastAction = latestHistoryByPeer[candidate.houseId];
      final lastTouchedAt = max(
        lastAction?.endedAt ?? 0,
        lastAction?.startedAt ?? 0,
      );
      final lastActionAgeMs = lastTouchedAt > 0 ? nowMs - lastTouchedAt : null;
      if (lastAction != null &&
          lastAction.isSkipped &&
          lastActionAgeMs != null &&
          lastActionAgeMs < skipCooldown.inMilliseconds) {
        continue;
      }

      var score = canAudioCall && canVideoCall ? 32.0 : 29.0;
      final reasons = <String>[];
      if (!(canAudioCall && canVideoCall)) {
        reasons.add(
          _availableModesLabel(
            canAudioCall: canAudioCall,
            canVideoCall: canVideoCall,
          ),
        );
      }

      if (candidate.age != null) {
        final inRange = candidate.age! >= current.preferredAgeMin &&
            candidate.age! <= current.preferredAgeMax;
        if (inRange) {
          score += 22;
          reasons.add('Đúng độ tuổi bạn muốn');
        } else {
          final gap = candidate.age! < current.preferredAgeMin
              ? current.preferredAgeMin - candidate.age!
              : candidate.age! - current.preferredAgeMax;
          score += (18 - gap * 2).clamp(0, 18);
        }

        if (myAge != null) {
          final ageGap = (myAge - candidate.age!).abs();
          score += (12 - ageGap.toDouble()).clamp(0, 12);
        }
      }

      if (candidate.goal == current.goal) {
        score += 14;
        reasons.add('Cùng mục tiêu trò chuyện');
      }

      if (candidate.voiceStyle == current.voiceStyle) {
        score += 10;
        reasons.add('Vibe nói chuyện khá hợp');
      }

      final sharedTags = candidate.tags
          .where((tag) => myTags.contains(tag.toLowerCase()))
          .toList(growable: false);
      if (sharedTags.isNotEmpty) {
        score += min(18, sharedTags.length * 6).toDouble();
        reasons.add('Trùng sở thích: ${sharedTags.take(2).join(', ')}');
      }

      if (candidate.intro.trim().isNotEmpty) {
        score += 5;
      }
      if (candidate.bio.trim().isNotEmpty) {
        score += 7;
      }
      if (candidate.avatarUrl.trim().isNotEmpty) {
        score += 4;
      }

      final updatedDelta = nowMs - candidate.updatedAt;
      if (candidate.updatedAt > 0) {
        if (updatedDelta <= const Duration(days: 3).inMilliseconds) {
          score += 8;
          reasons.add('Hồ sơ vừa hoạt động');
        } else if (updatedDelta <= const Duration(days: 14).inMilliseconds) {
          score += 4;
        }
      }

      // Xóa logic cũ - không sử dụng legacyLastAction nữa

      if (lastAction != null && lastActionAgeMs != null) {
        if (lastAction.isCall) {
          if (lastActionAgeMs < recentCallCooldown.inMilliseconds) {
            score -= 18;
            reasons.add('Vừa kết nối gần đây');
          } else if (lastActionAgeMs < recentCallPenaltyWindow.inMilliseconds) {
            score -= 10;
            reasons.add('Ưu tiên thử hồ sơ mới trước');
          } else {
            score += 4;
            reasons.add('Từng nói chuyện khá ổn');
          }
        } else if (lastAction.isSkipped &&
            lastActionAgeMs < recentSkipPenaltyWindow.inMilliseconds) {
          score -= 8;
          reasons.add('Bạn vừa bỏ qua hồ sơ này');
        }
      }

      final previewText = _buildCandidatePreviewText(
        candidate,
        sharedTags: sharedTags,
        canAudioCall: canAudioCall,
        canVideoCall: canVideoCall,
      );

      scored.add(
        _ScoredCandidate(
          candidate: candidate,
          score: score.clamp(24, 98).toDouble(),
          reasons: reasons.take(3).toList(growable: false),
          sharedTags: sharedTags,
          canAudioCall: canAudioCall,
          canVideoCall: canVideoCall,
          previewText: previewText,
        ),
      );
    }

    scored.sort((left, right) => right.score.compareTo(left.score));
    return scored;
  }

  _ScoredCandidate? _resolveFeatured(List<_ScoredCandidate> candidates) {
    return _resolveFeaturedCandidate(candidates, _featuredHouseId);
  }

  _ScoredCandidate _pickRandomCandidate(List<_ScoredCandidate> candidates) {
    return _pickRandomCandidateFromPool(candidates, _featuredHouseId, _random);
  }

  Future<void> _spinRandomMatch(List<_ScoredCandidate> candidates) async {
    if (candidates.isEmpty) {
      return;
    }
    final picked = _pickRandomCandidate(candidates);
    if (!mounted) {
      return;
    }
    setState(() => _featuredHouseId = picked.candidate.houseId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MatchReadySheet(
        scored: picked,
        goalLabel: _choiceLabel(_goalOptions, picked.candidate.goal),
        voiceLabel: _choiceLabel(_voiceOptions, picked.candidate.voiceStyle),
        onOpenProfile: () {
          // Tạm tắt mở hồ sơ từ Single Match; giữ code để nâng cấp lại sau.
          // Navigator.pop(context);
          // _openCandidateProfile(picked.candidate);
        },
        onAudioCall: picked.canAudioCall
            ? () {
                Navigator.pop(context);
                _launchCall(picked, isVideo: false);
              }
            : null,
        onVideoCall: picked.canVideoCall
            ? () {
                Navigator.pop(context);
                _launchCall(picked, isVideo: true);
              }
            : null,
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openCandidateProfile(SingleMatchCandidate candidate) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorProfileScreen(targetHouseId: candidate.houseId),
      ),
    );
  }

  Future<void> _skipCandidate(_ScoredCandidate scored) async {
    setState(() {
      _sessionSkippedHouseIds.add(scored.candidate.houseId);
      if (_featuredHouseId == scored.candidate.houseId) {
        _featuredHouseId = null;
      }
    });

    try {
      await _service
          .logHistory(
            houseId: widget.houseId,
            action: 'skipped',
            peerHouseId: scored.candidate.houseId,
            peerName: scored.candidate.displayName,
            peerAvatarUrl: scored.candidate.avatarUrl,
            goal: scored.candidate.goal,
            startedAt: DateTime.now().millisecondsSinceEpoch,
            endedAt: DateTime.now().millisecondsSinceEpoch,
            durationSeconds: 0,
            compatibilityScore: scored.score,
            note: 'Đã lướt qua từ danh sách ghép nối',
          )
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[SingleMatch] log skip history failed: $error');
    }
    _showSnack('Đã ẩn hồ sơ này trong phiên hiện tại.');
  }

  Future<void> _launchCall(
    _ScoredCandidate scored, {
    required bool isVideo,
  }) async {
    final candidate = scored.candidate;
    if ((isVideo && !scored.canVideoCall) ||
        (!isVideo && !scored.canAudioCall)) {
      _showSnack('Hồ sơ này chưa mở mode gọi bạn chọn.', isError: true);
      return;
    }
    if (_callingHouseId != null) {
      return;
    }

    final startedAt = DateTime.now().millisecondsSinceEpoch;
    setState(() => _callingHouseId = candidate.houseId);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            houseId: widget.houseId,
            targetHouseId: candidate.houseId,
            targetName: candidate.displayName,
            targetAvatarUrl: candidate.avatarUrl,
            isVideo: isVideo,
            onRoomCreated: (roomId) => _service.attachOutgoingCallMetadata(
              roomId: roomId,
              callerHouseId: widget.houseId,
              targetHouseId: candidate.houseId,
              callerName: _displayName,
              callerAvatar: _avatarUrl,
              isVideo: isVideo,
              source: 'single_match',
            ),
          ),
        ),
      );
    } finally {
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        await _service
            .logHistory(
              houseId: widget.houseId,
              action: isVideo ? 'video_call' : 'audio_call',
              peerHouseId: candidate.houseId,
              peerName: candidate.displayName,
              peerAvatarUrl: candidate.avatarUrl,
              goal: candidate.goal,
              startedAt: startedAt,
              endedAt: endedAt,
              durationSeconds: ((endedAt - startedAt) / 1000).round(),
              compatibilityScore: scored.score,
              note: 'Khởi tạo từ tab ghép nối ngẫu nhiên',
            )
            .timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint('[SingleMatch] log call history failed: $error');
      }
      if (mounted) {
        setState(() => _callingHouseId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE8FA),
      body: Stack(
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFFF9EAF1),
                  Color(0xFFF0EEFF),
                  Color(0xFFE7F3FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: -84,
            right: -36,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Color(0x47A86EFF),
                      Color(0x00A86EFF),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            top: 180,
            child: IgnorePointer(
              child: Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Color(0x2EFF7EAA),
                      Color(0x00FF7EAA),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 680;
                final compactWidth = constraints.maxWidth < 380;

                return Column(
                  children: <Widget>[
                    _buildTopBar(),
                    if (!compactHeight) _buildHeaderCard(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compactWidth ? 12 : 18,
                        compactHeight ? 8 : 12,
                        compactWidth ? 12 : 18,
                        0,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.94)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF7C61FF)
                                  .withValues(alpha: 0.10),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFFFF5A88),
                                Color(0xFF7C61FF),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFFAA68FF)
                                    .withValues(alpha: 0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          indicatorPadding: const EdgeInsets.all(5),
                          splashBorderRadius: BorderRadius.circular(18),
                          labelPadding: EdgeInsets.zero,
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF6D5E78),
                          labelStyle: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            fontSize: compactWidth ? 12 : 13,
                          ),
                          tabs: const <Tab>[
                            Tab(text: 'Ghép nối'),
                            Tab(text: 'Lịch sử'),
                            Tab(text: 'Cài đặt'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF4F87),
                              ),
                            )
                          : _loadError != null
                              ? _buildLoadError()
                              : TabBarView(
                                  controller: _tabController,
                                  children: <Widget>[
                                    _buildDiscoveryTab(),
                                    _buildHistoryTab(),
                                    _buildSettingsTab(),
                                  ],
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return _SingleMatchTopBar(
      onBack: () => Navigator.pop(context),
      onRefresh: _loadBootstrap,
    );
  }

  Widget _buildHeaderCard() {
    final ageText = _myAge == null ? 'Chưa có tuổi' : '$_myAge tuổi';
    final goalText = _choiceLabel(_goalOptions, _currentPreferences.goal);
    return _SingleMatchHeaderCard(
      avatarUrl: _avatarUrl,
      displayName: _displayName,
      profileCompletion: _profileCompletion,
      ageText: ageText,
      goalText: goalText,
      tagsCount: _parseTags(_tagsController.text).length,
    );
  }

  Widget _buildLoadError() {
    return _SingleMatchLoadErrorCard(
      loadError: _loadError,
      onRetry: _loadBootstrap,
    );
  }

  Widget _buildDiscoveryTab() {
    return StreamBuilder<_SingleMatchDiscoverySnapshot>(
      stream: _discoveryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SingleMatchLoadErrorCard(
            loadError: snapshot.error.toString(),
            onRetry: _loadBootstrap,
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: <Widget>[
              _buildWarningCard(),
              const SizedBox(height: 14),
              _buildActiveFiltersCard(),
              const SizedBox(height: 14),
              _buildEmptyPoolCard(),
            ],
          );
        }

        final history = snapshot.data!.history;
        final scored = _scoreCandidates(snapshot.data!.candidates, history);
        final featured = _resolveFeatured(scored);
        if (featured == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: <Widget>[
              _buildWarningCard(),
              const SizedBox(height: 14),
              _buildActiveFiltersCard(),
              const SizedBox(height: 14),
              _buildEmptyPoolCard(),
            ],
          );
        }

        final historyPeers = history.map((entry) => entry.peerHouseId).toSet();
        final others = scored
            .where(
                (item) => item.candidate.houseId != featured.candidate.houseId)
            .take(12)
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: <Widget>[
            _buildWarningCard(),
            const SizedBox(height: 14),
            _buildActiveFiltersCard(),
            const SizedBox(height: 14),
            _buildFeaturedCard(
              scored: featured,
              totalPool: scored.length,
              seenCount: historyPeers.length,
              onSpin: () => _spinRandomMatch(scored),
            ),
            const SizedBox(height: 18),
            _buildStatStrip(scored.length, history),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Hồ sơ phù hợp nhất',
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF32203B),
                    ),
                  ),
                ),
                Text(
                  '${others.length + 1} hồ sơ',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8B7A90),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...others.map(_buildCandidateCard),
          ],
        );
      },
    );
  }

  Widget _buildWarningCard() {
    final issues = <String>[];
    if (_myDob.trim().isEmpty) {
      issues.add('thiếu ngày sinh');
    }
    if ((_mySettings['bio'] ?? '').toString().trim().isEmpty) {
      issues.add('thiếu bio công khai');
    }
    if (_avatarUrl.trim().isEmpty) {
      issues.add('thiếu avatar hồ sơ');
    }

    return _SingleMatchWarningCard(
      enabled: _currentPreferences.enabled,
      issues: issues,
    );
  }

  Widget _buildActiveFiltersCard() {
    final current = _currentPreferences;
    final tags = _activeTags;
    return _SingleMatchActiveFiltersCard(
      current: current,
      activeTags: tags,
      hasEnabledCallMode: _hasEnabledCallMode,
      goalLabel: _choiceLabel(_goalOptions, current.goal),
      voiceLabel: _choiceLabel(_voiceOptions, current.voiceStyle),
      callModesLabel: _availableModesLabel(
        canAudioCall: current.allowAudioCalls,
        canVideoCall: current.allowVideoCalls,
      ),
    );
  }

  Widget _buildEmptyPoolCard() {
    return _SingleMatchEmptyPoolCard(
      onEditProfile: _openCommunitySettings,
      onOpenFilters: () => _tabController.animateTo(2),
    );
  }

  Widget _buildFeaturedCard({
    required _ScoredCandidate scored,
    required int totalPool,
    required int seenCount,
    required VoidCallback onSpin,
  }) {
    final candidate = scored.candidate;
    final callingThisCard = _callingHouseId == candidate.houseId;
    final goalLabel = _choiceLabel(_goalOptions, candidate.goal);
    final voiceLabel = _choiceLabel(_voiceOptions, candidate.voiceStyle);
    return _SingleMatchFeaturedCard(
      scored: scored,
      totalPool: totalPool,
      seenCount: seenCount,
      callingThisCard: callingThisCard,
      goalLabel: goalLabel,
      voiceLabel: voiceLabel,
      onSpin: onSpin,
      onOpenProfile: () {
        // Tạm tắt mở hồ sơ từ Single Match; giữ code để nâng cấp lại sau.
        // _openCandidateProfile(candidate);
      },
      onAudioCall: (!candidate.allowAudioCalls || callingThisCard)
          ? null
          : () => _launchCall(scored, isVideo: false),
      onVideoCall: candidate.allowVideoCalls && !callingThisCard
          ? () => _launchCall(scored, isVideo: true)
          : null,
    );
  }

  Widget _buildStatStrip(
    int totalCandidates,
    List<SingleMatchHistoryEntry> history,
  ) {
    final callCount = history.where((entry) => entry.isCall).length;
    final skipCount = history.where((entry) => entry.isSkipped).length;
    final avgScore = history.isEmpty
        ? 0.0
        : history.fold<double>(
                0, (sum, entry) => sum + entry.compatibilityScore) /
            history.length;

    return _SingleMatchStatStrip(
      totalCandidates: totalCandidates,
      callCount: callCount,
      skipCount: skipCount,
      avgScore: avgScore,
    );
  }

  Widget _buildCandidateCard(_ScoredCandidate scored) {
    final candidate = scored.candidate;
    final callingThisCard = _callingHouseId == candidate.houseId;
    return _SingleMatchCandidateCard(
      scored: scored,
      callingThisCard: callingThisCard,
      goalLabel: _choiceLabel(_goalOptions, candidate.goal),
      voiceLabel: _choiceLabel(_voiceOptions, candidate.voiceStyle),
      onSkip: () => _skipCandidate(scored),
      onOpenProfile: () {
        // Tạm tắt mở hồ sơ từ Single Match; giữ code để nâng cấp lại sau.
        // _openCandidateProfile(candidate);
      },
      onAudioCall: candidate.allowAudioCalls && !callingThisCard
          ? () => _launchCall(scored, isVideo: false)
          : null,
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<SingleMatchHistoryEntry>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        final history = snapshot.data ?? const <SingleMatchHistoryEntry>[];
        if (snapshot.hasError) {
          return _SingleMatchLoadErrorCard(
            loadError: snapshot.error.toString(),
            onRetry: _loadBootstrap,
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 52,
                      color: Color(0xFF7C61FF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có lịch sử',
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF32203B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khi bạn gọi hoặc lướt qua hồ sơ trong Single Match, mọi thứ sẽ hiện ở đây để gọi lại nhanh hơn.',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B7A90),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final callEntries = history.where((entry) => entry.isCall).toList();
        final totalMinutes = callEntries.fold<int>(
          0,
          (sum, entry) => sum + entry.durationSeconds ~/ 60,
        );

        if (history.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 52,
                      color: Color(0xFF7C61FF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có lịch sử',
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF32203B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khi bạn gọi hoặc lướt qua hồ sơ trong Single Match, mọi thứ sẽ hiện ở đây để gọi lại nhanh hơn.',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B7A90),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    label: 'Tổng cuộc gọi',
                    value: '${callEntries.length}',
                    icon: Icons.call_rounded,
                    color: const Color(0xFFFF4F87),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Phút trò chuyện',
                    value: '$totalMinutes',
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF7C61FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...history.map(_buildHistoryCard),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(SingleMatchHistoryEntry entry) {
    final isVideo = entry.action == 'video_call';
    final actionLabel = switch (entry.action) {
      'audio_call' => 'Cuộc gọi thoại',
      'video_call' => 'Cuộc gọi video',
      'skipped' => 'Đã lướt qua',
      _ => 'Hoạt động',
    };
    final accent = switch (entry.action) {
      'audio_call' => const Color(0xFFFF4F87),
      'video_call' => const Color(0xFF7C61FF),
      'skipped' => const Color(0xFF18B67A),
      _ => const Color(0xFF5B8DEF),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAvatarVisual(
              avatarUrl: entry.peerAvatarUrl,
              radius: 24,
              fallback: entry.peerName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.peerName.isEmpty ? 'Hồ sơ cũ' : entry.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF32203B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          actionLabel,
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatRelativeTime(entry.startedAt)} • ${entry.compatibilityScore.toStringAsFixed(0)}% match',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8A798E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.isCall
                        ? _formatDuration(entry.durationSeconds)
                        : entry.note,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5A495E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: <Widget>[
                      if (entry.peerHouseId.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VisitorProfileScreen(
                                  targetHouseId: entry.peerHouseId),
                            ),
                          ),
                          icon:
                              const Icon(Icons.person_search_rounded, size: 17),
                          label: const Text('Mở hồ sơ'),
                        ),
                      if (entry.isCall && entry.peerHouseId.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _launchCall(
                            _ScoredCandidate(
                              candidate: SingleMatchCandidate(
                                houseId: entry.peerHouseId,
                                displayName: entry.peerName,
                                houseName: entry.peerName,
                                avatarUrl: entry.peerAvatarUrl,
                                bio: '',
                                intro: '',
                                goal: entry.goal,
                                voiceStyle: _currentPreferences.voiceStyle,
                                tags: const <String>[],
                                allowAudioCalls: true,
                                allowVideoCalls: true,
                                enabled: true,
                                privacy: 'public',
                                updatedAt: entry.startedAt,
                                age: null,
                              ),
                              score: entry.compatibilityScore,
                              reasons: const <String>[],
                              sharedTags: const <String>[],
                              canAudioCall: true,
                              canVideoCall: true,
                              previewText: entry.note,
                            ),
                            isVideo: isVideo,
                          ),
                          icon: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_made_rounded,
                            size: 17,
                          ),
                          label: Text(isVideo ? 'Gọi video lại' : 'Gọi lại'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final current = _currentPreferences;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: <Widget>[
        _buildSettingsSection(
          title: 'Hồ sơ hiển thị khi ghép',
          subtitle:
              'Avatar, bio và quyền riêng tư đang lấy từ hồ sơ cộng đồng hiện tại của bạn.',
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildAvatarVisual(
                    avatarUrl: _avatarUrl,
                    radius: 28,
                    fallback: _displayName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _displayName,
                          style: SLTheme.quicksand(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF32203B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_mySettings['bio'] ?? '').toString().trim().isEmpty
                              ? 'Chưa có bio công khai'
                              : (_mySettings['bio'] ?? '').toString().trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8A798E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openCommunitySettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C61FF),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Sửa'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F4FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.cake_rounded,
                      color: Color(0xFFFF4F87),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _myAge == null
                            ? 'Bạn chưa thêm ngày sinh nên bộ lọc tuổi chưa chính xác.'
                            : 'Đang dùng $_myAge tuổi cho thuật toán gợi ý.',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5C4A62),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDob,
                      child: const Text('Cập nhật'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Pool và mode gọi',
          subtitle:
              'Bật xuất hiện trong random pool và chọn kiểu cuộc gọi bạn sẵn sàng nhận.',
          child: Column(
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: current.enabled,
                activeThumbColor: const Color(0xFFFF4F87),
                title: Text(
                  'Xuất hiện trong ghép nối ngẫu nhiên',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Khi tắt, hồ sơ của bạn sẽ không hiện trong pool single match.',
                  style: SLTheme.quicksand(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onChanged: (value) {
                  setState(() {
                    _draftPreferences =
                        _draftPreferences.copyWith(enabled: value);
                  });
                },
              ),
              const Divider(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: current.allowAudioCalls,
                activeThumbColor: const Color(0xFFFF4F87),
                title: Text(
                  'Cho phép gọi thoại',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Giữ mode nhẹ, dễ bắt chuyện nhanh như Litmatch.',
                  style: SLTheme.quicksand(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onChanged: (value) {
                  setState(() {
                    _draftPreferences =
                        _draftPreferences.copyWith(allowAudioCalls: value);
                  });
                },
              ),
              const Divider(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: current.allowVideoCalls,
                activeThumbColor: const Color(0xFFFF4F87),
                title: Text(
                  'Cho phép gọi video',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Chỉ bật khi bạn muốn thấy mặt ngay sau khi match.',
                  style: SLTheme.quicksand(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onChanged: (value) {
                  setState(() {
                    _draftPreferences =
                        _draftPreferences.copyWith(allowVideoCalls: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Độ tuổi bạn muốn gặp',
          subtitle:
              'Thuật toán ưu tiên hồ sơ nằm trong khoảng này trước khi random.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${current.preferredAgeMin} - ${current.preferredAgeMax} tuổi',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF32203B),
                ),
              ),
              RangeSlider(
                values: RangeValues(
                  current.preferredAgeMin.toDouble(),
                  current.preferredAgeMax.toDouble(),
                ),
                min: SingleMatchPreferences.minAgeFloor.toDouble(),
                max: SingleMatchPreferences.maxAgeCeiling.toDouble(),
                activeColor: const Color(0xFFFF4F87),
                inactiveColor: const Color(0xFFFFDCE7),
                labels: RangeLabels(
                  '${current.preferredAgeMin}',
                  '${current.preferredAgeMax}',
                ),
                onChanged: (values) {
                  setState(() {
                    _draftPreferences = _draftPreferences.copyWith(
                      preferredAgeMin: values.start.round(),
                      preferredAgeMax: values.end.round(),
                    );
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Bạn muốn gặp người theo kiểu nào',
          subtitle:
              'Mục tiêu này sẽ tăng điểm tương thích cho các hồ sơ cùng gu.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _goalOptions
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selected: current.goal == option.value,
                    selectedColor: option.color.withValues(alpha: 0.18),
                    labelStyle: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: current.goal == option.value
                          ? option.color
                          : const Color(0xFF5D4B63),
                    ),
                    avatar: Icon(
                      option.icon,
                      size: 18,
                      color: current.goal == option.value
                          ? option.color
                          : const Color(0xFF8A798E),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _draftPreferences =
                            _draftPreferences.copyWith(goal: option.value);
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Vibe giọng nói của bạn',
          subtitle:
              'Dùng để ưu tiên những hồ sơ có kiểu trò chuyện gần với vibe bạn thích.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _voiceOptions
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selected: current.voiceStyle == option.value,
                    selectedColor: option.color.withValues(alpha: 0.18),
                    labelStyle: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: current.voiceStyle == option.value
                          ? option.color
                          : const Color(0xFF5D4B63),
                    ),
                    avatar: Icon(
                      option.icon,
                      size: 18,
                      color: current.voiceStyle == option.value
                          ? option.color
                          : const Color(0xFF8A798E),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _draftPreferences = _draftPreferences.copyWith(
                            voiceStyle: option.value);
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Sở thích nổi bật',
          subtitle:
              'Nhập bằng dấu phẩy hoặc chạm gợi ý nhanh. Đây là phần giúp tìm người hợp thật.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Âm nhạc, Đêm khuya, Podcast',
                  filled: true,
                  fillColor: const Color(0xFFF9F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagSuggestions
                    .map(
                      (tag) => ActionChip(
                        label: Text(tag),
                        onPressed: () {
                          final tags = _parseTags(_tagsController.text);
                          if (tags.any((value) =>
                              value.toLowerCase() == tag.toLowerCase())) {
                            return;
                          }
                          tags.add(tag);
                          _tagsController.text = tags.join(', ');
                          _tagsController.selection = TextSelection.collapsed(
                            offset: _tagsController.text.length,
                          );
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSettingsSection(
          title: 'Lời mở đầu khi match',
          subtitle:
              'Một intro ngắn sẽ xuất hiện ngay ở top card để người kia quyết định gọi nhanh hơn.',
          child: TextField(
            controller: _introController,
            minLines: 3,
            maxLines: 5,
            maxLength: 180,
            decoration: InputDecoration(
              hintText:
                  'Ví dụ: Mình thích những cuộc gọi nhẹ nhàng, không cần quá gồng, chỉ cần nói chuyện thật.',
              filled: true,
              fillColor: const Color(0xFFF9F4FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed:
                (_isSaving || !_hasUnsavedChanges) ? null : _savePreferences,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4F87),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'Đang lưu...' : 'Lưu cài đặt ghép nối',
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _SingleMatchSettingsSection(
      title: title,
      subtitle: subtitle,
      child: child,
    );
  }

  Widget _buildAvatarVisual({
    required String avatarUrl,
    required double radius,
    required String fallback,
  }) {
    return _SingleMatchAvatarVisual(
      avatarUrl: avatarUrl,
      radius: radius,
      fallback: fallback,
    );
  }
}
