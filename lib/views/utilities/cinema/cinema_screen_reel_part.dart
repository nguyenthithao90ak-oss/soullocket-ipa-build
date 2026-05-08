part of '../cinema_screen.dart';

extension _CinemaScreenStateReelPart on _CinemaScreenState {
  _CinemaDailyReel? _buildDailyReel({
    required DateTime now,
    required DateTime startDate,
    required LoveInsightTimelineEntry milestone,
    required List<_CinemaMemoryRecord> records,
  }) {
    if (records.isEmpty) {
      return null;
    }

    final today = _normalizeDate(now);
    final badge = _buildBadge(milestone);
    final selected = _pickDailyItems(records, today);
    if (selected.isEmpty) {
      return null;
    }

    return _CinemaDailyReel(
      dateKey: _dateKey(today),
      title: 'Video ${badge.label}',
      subtitle:
          'Dựng tự động từ ${selected.length} ảnh ngẫu nhiên trong kho kỷ niệm của hai bạn cho mốc ${badge.label}.',
      accentValue: badge.accent.toARGB32(),
      createdAt: now,
      expiresAt: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      items: selected,
    );
  }

  List<_CinemaMemoryRecord> _pickDailyItems(
    List<_CinemaMemoryRecord> records,
    DateTime day,
  ) {
    final candidates = List<_CinemaMemoryRecord>.from(records)
      ..sort((a, b) => a.id.compareTo(b.id));
    candidates.shuffle(
        math.Random(_stableSeed('${widget.houseId}_${_dateKey(day)}')));
    final limit = math.min(_kCinemaReelFrameLimit, candidates.length);
    return candidates.take(limit).toList(growable: false);
  }

  int _stableSeed(String raw) {
    var hash = 17;
    for (final codeUnit in raw.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + codeUnit);
    }
    return hash;
  }

  _CinemaReelBadge _buildBadge(LoveInsightTimelineEntry milestone) {
    final lowerTitle = milestone.title.toLowerCase();
    final shortLabel = milestone.title
        .replaceFirst(RegExp(r'^kỷ niệm\s*', caseSensitive: false), '')
        .trim();

    if (lowerTitle.contains('ngày')) {
      return _CinemaReelBadge(
        icon: Icons.favorite_rounded,
        label: shortLabel.isEmpty ? milestone.title : shortLabel,
        accent: const Color(0xFFFF6FA5),
      );
    }
    if (lowerTitle.contains('năm')) {
      return _CinemaReelBadge(
        icon: Icons.workspace_premium_rounded,
        label: shortLabel.isEmpty ? milestone.title : shortLabel,
        accent: const Color(0xFFFFC857),
      );
    }
    return _CinemaReelBadge(
      icon: Icons.auto_awesome_rounded,
      label: shortLabel.isEmpty ? milestone.title : shortLabel,
      accent: const Color(0xFF7FD3FF),
    );
  }

  List<LoveInsightTimelineEntry> _milestoneTimeline(DateTime? startDate) {
    if (startDate == null) {
      return const <LoveInsightTimelineEntry>[];
    }

    final entries = _loveInsightService
        .buildMilestoneTimeline(
          startDate: _normalizeDate(startDate),
          isSingle: false,
        )
        .where((entry) => entry.type == 'milestone')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final deduped = <String, LoveInsightTimelineEntry>{};
    for (final entry in entries) {
      final key = _dateKey(_normalizeDate(entry.date));
      final existing = deduped[key];
      if (existing == null ||
          _milestonePriority(entry) > _milestonePriority(existing)) {
        deduped[key] = entry;
      }
    }

    final result = deduped.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  int _milestonePriority(LoveInsightTimelineEntry entry) {
    final title = entry.title.toLowerCase();
    if (title.contains('ngày')) return 3;
    if (title.contains('năm')) return 2;
    if (title.contains('tháng')) return 1;
    return 0;
  }

  LoveInsightTimelineEntry? _milestoneForDate(DateTime value) {
    final target = _normalizeDate(value);
    for (final entry in _milestoneTimeline(_startDate)) {
      if (_normalizeDate(entry.date) == target) {
        return entry;
      }
    }
    return null;
  }

  LoveInsightTimelineEntry? _nextAnniversaryMilestone(
    DateTime now,
    DateTime? startDate,
  ) {
    final target = _normalizeDate(now);
    for (final entry in _milestoneTimeline(startDate)) {
      final entryDate = _normalizeDate(entry.date);
      if (!entryDate.isBefore(target)) {
        return entry;
      }
    }
    return null;
  }

  int _resolvePreviewIndex(
    _CinemaDailyReel? reel,
    String? previousItemId,
  ) {
    if (reel == null || reel.items.isEmpty) {
      return 0;
    }
    if (previousItemId == null) {
      return _previewIndex.clamp(0, reel.items.length - 1);
    }
    final index = reel.items.indexWhere((item) => item.id == previousItemId);
    if (index >= 0) {
      return index;
    }
    return 0;
  }

  void _startPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(_kCinemaFrameDuration, (_) {
      final reel = _activeReel;
      if (!mounted || reel == null || reel.items.length < 2) {
        return;
      }
      _setPreviewIndex((_previewIndex + 1) % reel.items.length);
    });
  }

  void _setPreviewIndex(int index, {bool animateFilmstrip = true}) {
    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return;
    }

    final nextIndex = index.clamp(0, reel.items.length - 1);
    if (_previewIndex == nextIndex) {
      _scheduleFilmstripAlignment(animate: animateFilmstrip);
      return;
    }

    _commitState(() {
      _previewIndex = nextIndex;
    });
    _scheduleFilmstripAlignment(animate: animateFilmstrip);
  }

  void _showPreviousPreview() {
    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return;
    }
    _setPreviewIndex(
        (_previewIndex - 1 + reel.items.length) % reel.items.length);
  }

  void _showNextPreview() {
    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return;
    }
    _setPreviewIndex((_previewIndex + 1) % reel.items.length);
  }

  Future<void> _openPlayer() async {
    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CinemaReelPlayerScreen(
          reel: reel,
          initialIndex: _previewIndex.clamp(0, reel.items.length - 1),
        ),
      ),
    );
  }

  void _scheduleFilmstripAlignment({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_filmstripController.hasClients) {
        return;
      }
      unawaited(_scrollFilmstripToPreview(animate: animate));
    });
  }

  Future<void> _scrollFilmstripToPreview({bool animate = true}) async {
    if (!_filmstripController.hasClients) {
      return;
    }

    final reel = _activeReel;
    if (reel == null || reel.items.isEmpty) {
      return;
    }

    final position = _filmstripController.position;
    if (position.maxScrollExtent <= 0) {
      if (position.pixels != 0) {
        await _filmstripController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final target = (_previewIndex *
            (_kCinemaFilmstripCardWidth + _kCinemaFilmstripSpacing)) -
        ((position.viewportDimension - _kCinemaFilmstripCardWidth) / 2);
    final clampedTarget = target.clamp(0.0, position.maxScrollExtent);
    if ((position.pixels - clampedTarget).abs() < 0.5) {
      return;
    }

    await _filmstripController.animateTo(
      clampedTarget,
      duration: animate
          ? const Duration(milliseconds: 260)
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}
