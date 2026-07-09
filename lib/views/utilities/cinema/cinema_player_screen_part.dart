part of '../cinema_screen.dart';

class _CinemaReelPlayerScreen extends StatefulWidget {
  final _CinemaDailyReel reel;
  final int initialIndex;

  const _CinemaReelPlayerScreen({
    required this.reel,
    required this.initialIndex,
  });

  @override
  State<_CinemaReelPlayerScreen> createState() =>
      _CinemaReelPlayerScreenState();
}

class _CinemaReelPlayerScreenState extends State<_CinemaReelPlayerScreen> {
  static const Offset _kDefaultTitleAnchor = Offset(0.08, 0.58);

  final CinemaVideoExportService _videoExportService =
      createCinemaVideoExportService();

  late final PageController _pageController;
  late final TextEditingController _titleController;
  late int _index;
  Timer? _timer;

  Offset _titleAnchor = _kDefaultTitleAnchor;
  bool _isAdjustingTitlePosition = false;
  bool _isExportingVideo = false;
  bool _isSavingVideo = false;
  double? _videoProgress;
  String? _videoStatus;
  String? _exportedVideoPath;
  String? _exportedVideoSignature;
  CinemaVideoQualityPreset _qualityPreset = CinemaVideoQualityPreset.balanced;
  final bool _useHevc = true;

  void _commitState(VoidCallback action) => setState(action);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.reel.items.length - 1);
    _pageController = PageController(initialPage: _index);
    _titleController =
        TextEditingController(text: _buildDefaultExportTitle(widget.reel));
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_kCinemaFrameDuration, (_) {
      if (!mounted || widget.reel.items.length < 2) {
        return;
      }
      _goToIndex((_index + 1) % widget.reel.items.length);
    });
  }

  void _goToIndex(int nextIndex) {
    if (!mounted) {
      return;
    }
    setState(() {
      _index = nextIndex;
    });
    _startTimer();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showPrevious() {
    _goToIndex(
      (_index - 1 + widget.reel.items.length) % widget.reel.items.length,
    );
  }

  void _showNext() {
    _goToIndex((_index + 1) % widget.reel.items.length);
  }

  String get _exportTitle {
    final text = _titleController.text.trim();
    return text.isEmpty ? _buildDefaultExportTitle(widget.reel) : text;
  }

  String get _exportSubtitle {
    final subtitle = widget.reel.subtitle.trim();
    if (subtitle.isNotEmpty) {
      return subtitle;
    }
    return context.tr('util_albumnhcso_007f75');
  }

  String get _exportTagLabel {
    final cleaned = _cleanReelLabel(widget.reel.title);
    if (cleaned.isEmpty) {
      return context.tr('util_knimtrongn_4bf058');
    }
    return 'Kỷ niệm $cleaned';
  }

  String get _currentExportSignature {
    return <String>[
      widget.reel.dateKey,
      _exportTitle,
      _titleAnchor.dx.toStringAsFixed(3),
      _titleAnchor.dy.toStringAsFixed(3),
    ].join('|');
  }

  bool get _hasFreshExport {
    final path = _exportedVideoPath;
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    return _exportedVideoSignature == _currentExportSignature;
  }

  String _cleanReelLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceFirst(RegExp(r'^video\s*', caseSensitive: false), '');
  }

  String _buildDefaultExportTitle(_CinemaDailyReel reel) {
    final cleaned = _cleanReelLabel(reel.title);
    if (cleaned.isEmpty) {
      return context.tr('util_knimalbumn_62ecb7');
    }
    if (cleaned.toLowerCase().startsWith(context.tr('util_knim_61098c'))) {
      return cleaned;
    }
    return 'Kỷ niệm album ảnh $cleaned';
  }

  void _toggleTitleAdjustment() {
    setState(() {
      _isAdjustingTitlePosition = !_isAdjustingTitlePosition;
      if (_isAdjustingTitlePosition) {
        _videoStatus = context.tr('util_kokhitiuti_18a059');
      }
    });
  }

  void _updateTitleAnchor(Offset delta, Size viewport, double titleWidth) {
    final maxX =
        ((viewport.width - titleWidth - 16) / viewport.width).clamp(0.03, 1.0);
    final maxY = ((viewport.height - 220) / viewport.height).clamp(0.12, 0.82);

    setState(() {
      _titleAnchor = Offset(
        (_titleAnchor.dx + (delta.dx / viewport.width))
            .clamp(0.03, maxX.toDouble()),
        (_titleAnchor.dy + (delta.dy / viewport.height))
            .clamp(0.12, maxY.toDouble()),
      );
      _exportedVideoPath = null;
      _exportedVideoSignature = null;
      _videoProgress = null;
      _videoStatus = context.tr('util_vtrtiuthay_12e0a5');
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.reel.items[_index];
    final accent = Color(widget.reel.accentValue);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              physics: const SLPagePhysics(),
              controller: _pageController,
              itemCount: widget.reel.items.length,
              onPageChanged: (value) {
                if (_index == value) {
                  return;
                }
                setState(() => _index = value);
                _startTimer();
              },
              itemBuilder: (context, index) {
                final frame = widget.reel.items[index];
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildContainedImage(
                      frame.imageUrl,
                      maxWidthDiskCache: 1600,
                      errorIconSize: 42,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _buildOverlayDecorations(accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: List<Widget>.generate(
                            widget.reel.items.length,
                            (segmentIndex) {
                              final isDone = segmentIndex < _index;
                              final isActive = segmentIndex == _index;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: segmentIndex ==
                                            widget.reel.items.length - 1
                                        ? 0
                                        : 4,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: SizedBox(
                                      height: 4,
                                      child: ColoredBox(
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: isActive
                                              ? TweenAnimationBuilder<double>(
                                                  key: ValueKey<String>(
                                                    'player-progress-$segmentIndex-$_index',
                                                  ),
                                                  tween: Tween<double>(
                                                    begin: 0,
                                                    end: 1,
                                                  ),
                                                  duration:
                                                      _kCinemaFrameDuration,
                                                  builder:
                                                      (context, value, child) {
                                                    return FractionallySizedBox(
                                                      widthFactor: value,
                                                      child: child,
                                                    );
                                                  },
                                                  child: ColoredBox(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                  ),
                                                )
                                              : FractionallySizedBox(
                                                  widthFactor: isDone ? 1 : 0,
                                                  child: ColoredBox(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.88),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      _playerArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _showPrevious,
                      ),
                      const Spacer(),
                      _playerArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _showNext,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.movie_creation_outlined,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                widget.reel.title,
                                style: SLTheme.quicksand(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.authorName.isEmpty
                                    ? '${_index + 1}/${widget.reel.items.length} - Video kỷ niệm trong ngày'
                                    : '${_index + 1}/${widget.reel.items.length} - Ảnh được lưu bởi ${item.authorName}',
                                style: SLTheme.quicksand(
                                  fontSize: 13.5,
                                  color: Colors.white.withValues(alpha: 0.74),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildControlChip(
                      icon: Icons.tune_rounded,
                      label: context.tr('util_citvideo_dbe045'),
                      onTap: () => _showVideoSettingsSheet(accent),
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
