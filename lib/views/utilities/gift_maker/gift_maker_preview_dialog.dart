part of '../gift_maker_screen.dart';

enum _GiftStage { bubble, box, letterClosed, letterOpen, scratch, finalStage }

class GiftPreviewDialog extends StatefulWidget {
  final GiftData gift;
  final Future<void> Function()? onOpened;

  const GiftPreviewDialog({
    super.key,
    required this.gift,
    this.onOpened,
  });

  @override
  State<GiftPreviewDialog> createState() => _GiftPreviewDialogState();
}

class _GiftPreviewDialogState extends State<GiftPreviewDialog> {
  late _GiftStage _stage;
  late int _remainingTaps;
  late List<bool> _bubbleStates;
  double _scratchProgress = 0;
  bool _openedMarked = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _remainingTaps = GiftMakerService.tapCountFor(widget.gift.giftType);
    _bubbleStates = List<bool>.filled(
      GiftMakerService.bubbleCountFor(widget.gift.giftType),
      false,
    );
    _stage = _initialStage();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  _GiftStage _initialStage() {
    switch (widget.gift.giftType) {
      case GiftType.bubbleWrap:
      case GiftType.surpriseEgg:
        return _GiftStage.bubble;
      case GiftType.giftBox:
        return _GiftStage.box;
      case GiftType.loveLetter:
        return _GiftStage.letterClosed;
      case GiftType.scratchReveal:
        return _GiftStage.scratch;
      default:
        return _GiftStage.finalStage;
    }
  }

  Future<void> _markOpenedOnce() async {
    if (_openedMarked) return;
    _openedMarked = true;
    await widget.onOpened?.call();
  }

  Future<void> _showFinalStage() async {
    await _markOpenedOnce();
    if (!mounted) return;
    setState(() => _stage = _GiftStage.finalStage);
    try {
      await _audioPlayer.play(UrlSource(
          'https://actions.google.com/sounds/v1/cartoon/magic_chime.ogg'));
    } catch (_) {}
  }

  Future<void> _handleBubbleTap(int index) async {
    if (_bubbleStates[index]) return;
    setState(() => _bubbleStates[index] = true);
    if (_bubbleStates.every((done) => done)) {
      if (widget.gift.giftType == GiftType.surpriseEgg) {
        setState(() => _stage = _GiftStage.box);
      } else {
        await _showFinalStage();
      }
    }
  }

  Future<void> _handleBoxTap() async {
    if (_remainingTaps > 1) {
      setState(() => _remainingTaps--);
      return;
    }
    await _showFinalStage();
  }

  Future<void> _handleScratch() async {
    final next = (_scratchProgress + 0.25).clamp(0.0, 1.0).toDouble();
    setState(() => _scratchProgress = next);
    if (next >= 1) {
      await _showFinalStage();
    }
  }

  bool _isCompactDialog(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return size.width < 390 || size.height < 760 || textScale > 1.08;
  }

  double _stageSquareSize(
    double availableWidth, {
    double minSize = 132,
    double maxSize = 160,
  }) {
    return (availableWidth * 0.42).clamp(minSize, maxSize).toDouble();
  }

  double _stageImageHeight(double availableWidth) {
    return (availableWidth * 0.48).clamp(132.0, 180.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactDialog(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 14 : 24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogHeight = min(constraints.maxHeight, 720.0);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              height: dialogHeight,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  compact ? 14 : 16,
                  compact ? 14 : 16,
                  compact ? 14 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFF4F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 48 : 52,
                          height: compact ? 48 : 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEF4),
                            borderRadius: SLRadius.lgAll,
                          ),
                          child: Text(
                            GiftMakerService.giftEmoji(widget.gift.giftType),
                            style: TextStyle(fontSize: compact ? 26 : 28),
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                GiftMakerService.giftLabel(
                                    widget.gift.giftType),
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 16 : 17,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                'Từ ${widget.gift.fromName}',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildStageCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStageCard() {
    switch (_stage) {
      case _GiftStage.bubble:
        return _buildBubbleStage();
      case _GiftStage.box:
        return _buildBoxStage();
      case _GiftStage.letterClosed:
        return _buildLetterClosedStage();
      case _GiftStage.letterOpen:
        return _buildLetterOpenStage();
      case _GiftStage.scratch:
        return _buildScratchStage();
      case _GiftStage.finalStage:
        return _buildFinalStage();
    }
  }

  Widget _buildBubbleStage() {
    return _stageShell(
      title: context.tr('util_bpbongbngt_8b7e15'),
      subtitle: 'Mở hết ${_bubbleStates.length} bong bóng để tiếp tục.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(
          _bubbleStates.length,
          (index) => InkWell(
            onTap: () => _handleBubbleTap(index),
            borderRadius: SLRadius.lgAll,
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bubbleStates[index]
                    ? const Color(0xFFF3F4F6)
                    : const Color(0xFFE0F2FE),
                borderRadius: SLRadius.lgAll,
              ),
              child: Text(
                _bubbleStates[index] ? '·' : '🫧',
                style: TextStyle(
                  fontSize: _bubbleStates[index] ? 24 : 28,
                  color: _bubbleStates[index] ? const Color(0xFF9CA3AF) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoxStage() {
    final emoji = widget.gift.giftType == GiftType.surpriseEgg ? '🥚' : '🎁';
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = _stageSquareSize(constraints.maxWidth);
        final emojiSize = (artSize * 0.46).clamp(58.0, 74.0).toDouble();
        return _stageShell(
          title: widget.gift.giftType == GiftType.surpriseEgg
              ? context.tr('util_chmtrngn_eeffa0')
              : context.tr('util_chmmhpqu_59f8b0'),
          subtitle: 'Còn $_remainingTaps lần chạm để mở quà.',
          child: Column(
            children: [
              GestureDetector(
                onTap: _handleBoxTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: artSize,
                  height: artSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0F6), Color(0xFFFFD9E8)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: emojiSize),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ),
              ),
              SLSpacing.h12,
              Text(
                context.tr('util_chmlintcmk_75b323'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLetterClosedStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final letterWidth = (constraints.maxWidth * 0.50).clamp(142.0, 170.0);
        final letterHeight = (letterWidth * 0.76).clamp(110.0, 130.0);
        final emojiSize = (letterHeight * 0.56).clamp(60.0, 74.0).toDouble();
        return _stageShell(
          title: context.tr('util_bnnhncmtbc_99e3b4'),
          subtitle: context.tr('util_nhnvophong_6923c9'),
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _stage = _GiftStage.letterOpen),
              child: Container(
                width: letterWidth,
                height: letterHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3E0), Color(0xFFFDE68A)],
                  ),
                  borderRadius: SLRadius.xlAll,
                ),
                child: Text(
                  '💌',
                  style: TextStyle(fontSize: emojiSize),
                  textScaler: const TextScaler.linear(1.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetterOpenStage() {
    return _stageShell(
      title: context.tr('util_linhnm_9b1dfc'),
      subtitle: context.tr('util_cxongribmt_b36fb3'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.gift.message,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          SLSpacing.h12,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _showFinalStage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
              ),
              child: Text(
                context.tr('util_tiptc_555f1f'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScratchStage() {
    return _stageShell(
      title: context.tr('util_colmnqu_1c010f'),
      subtitle: context.tr('util_milnchmsco_4557e2'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F6), Color(0xFFFFDDEA)],
                  ),
                  borderRadius: SLRadius.xlAll,
                ),
                child: Text(
                  widget.gift.message,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    height: 1.5,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: (1 - _scratchProgress).clamp(0, 1),
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        borderRadius: SLRadius.xlAll,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          LinearProgressIndicator(
            value: _scratchProgress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
          ),
          SLSpacing.h12,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _handleScratch,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
              ),
              child: Text(
                _scratchProgress >= 0.75 ? context.tr('util_cont_01a0f4') : context.tr('util_cothm_1e2656'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = _stageImageHeight(constraints.maxWidth);
        final emojiSize =
            (constraints.maxWidth * 0.20).clamp(58.0, 72.0).toDouble();
        return _stageShell(
          title: context.tr('util_mnqudnhcho_834cef'),
          subtitle: context.tr('util_qucmxongbn_7edf8c'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: List.generate(
                  6,
                  (_) => const Text('✨', style: TextStyle(fontSize: 18))
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .moveY(begin: -6, end: 0, duration: 450.ms),
                ),
              ),
              SLSpacing.h8,
              if (widget.gift.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: SLRadius.lgAll,
                  child: widget.gift.imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          memCacheWidth: 900,
                          imageUrl: widget.gift.imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          height: imageHeight,
                          width: double.infinity,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD81B60),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported_rounded,
                            color: Color(0xFFD81B60),
                            size: 40,
                          ),
                        )
                      : Image.file(
                          File(widget.gift.imageUrl),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          height: imageHeight,
                          width: double.infinity,
                        ),
                )
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.easeOutBack)
                    .fadeIn()
              else
                Text(
                  GiftMakerService.giftEmoji(widget.gift.giftType),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: emojiSize),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .rotate(begin: -0.2, end: 0)
                    .fadeIn(),
              SLSpacing.h16,
              Text(
                widget.gift.message,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: constraints.maxWidth < 360 ? 17 : 18,
                  height: 1.5,
                  color: const Color(0xFFD81B60),
                ),
              )
                  .animate()
                  .slideY(
                    begin: 0.3,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(delay: 200.ms),
              SLSpacing.h8,
              Text(
                'Từ ${widget.gift.fromName}',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ).animate().fadeIn(delay: 400.ms),
              SLSpacing.h16,
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                  ),
                  child: Text(
                    context.tr('util_ng_f63d1e'),
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stageShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            16,
            compact ? 14 : 16,
            compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.xlAll,
            border: Border.all(color: const Color(0xFFF3D7E3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 17 : 18,
                  color: const Color(0xFF1F2937),
                ),
              ),
              SLSpacing.h8,
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 14 : 16),
              child,
            ],
          ),
        );
      },
    );
  }
}
