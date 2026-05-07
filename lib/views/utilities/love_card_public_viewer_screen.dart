import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/sl_theme.dart';
import '../../services/love_card_link_service.dart';

part 'love_card/love_card_public_viewer_helpers.dart';

class LoveCardPublicViewerScreen extends StatefulWidget {
  final LoveCardLinkPayload payload;
  final Uri? sourceUri;

  const LoveCardPublicViewerScreen({
    super.key,
    required this.payload,
    this.sourceUri,
  });

  @override
  State<LoveCardPublicViewerScreen> createState() =>
      _LoveCardPublicViewerScreenState();
}

class _LoveCardPublicViewerScreenState extends State<LoveCardPublicViewerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _openController;
  late final AnimationController _burstController;
  late final AnimationController _tearController;

  bool _hasStartedOpen = false;
  bool _canTear = false;
  bool _isTornOpen = false;

  _LoveCardViewerTheme get _palette =>
      _LoveCardViewerTheme.of(widget.payload.theme);

  String get _senderName {
    final value = widget.payload.senderName.trim();
    return value.isEmpty ? 'Người thương của bạn' : value;
  }

  String get _signature {
    final value = widget.payload.signature?.trim() ?? '';
    return value.isEmpty ? _palette.signatureFallback : value;
  }

  String get _messageText {
    final value = widget.payload.content.trim();
    return value.isEmpty ? 'Một lời nhắn dịu dàng dành riêng cho bạn.' : value;
  }

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _tearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _openController.dispose();
    _burstController.dispose();
    _tearController.dispose();
    super.dispose();
  }

  Future<void> _startOpenSequence() async {
    if (_hasStartedOpen) {
      return;
    }
    setState(() => _hasStartedOpen = true);
    HapticFeedback.lightImpact();
    _burstController.forward(from: 0);
    await _openController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() => _canTear = true);
  }

  Future<void> _handleTearEnd() async {
    if (_isTornOpen) {
      return;
    }

    if (_tearController.value >= 0.72) {
      await _tearController.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _isTornOpen = true);
      return;
    }

    await _tearController.animateBack(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTearDrag(DragUpdateDetails details, double width) {
    if (!_canTear || _isTornOpen || width <= 0) {
      return;
    }

    final nextValue =
        (_tearController.value + (details.primaryDelta ?? 0) / width)
            .clamp(0.0, 1.0);
    _tearController.value = nextValue;
  }

  Future<void> _copyCardContent() async {
    final text = widget.payload.content.trim();
    if (text.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung thiệp.')),
    );
  }

  Future<void> _shareCard() async {
    final message = [
      widget.payload.content.trim(),
      if (widget.sourceUri != null) widget.sourceUri.toString(),
    ].where((value) => value.isNotEmpty).join('\n\n');

    if (message.isEmpty) {
      return;
    }
    await SharePlus.instance.share(ShareParams(text: message));
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    return Scaffold(
      backgroundColor: palette.background.last,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: palette.background,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final merged = Listenable.merge([
              _openController,
              _burstController,
              _tearController,
            ]);

            return AnimatedBuilder(
              animation: merged,
              builder: (context, child) {
                final openValue =
                    Curves.easeOutCubic.transform(_openController.value);
                final paperValue = Curves.easeOutBack.transform(
                  ((_openController.value - 0.10) / 0.90).clamp(0.0, 1.0),
                );
                final tearValue = _isTornOpen
                    ? 1.0
                    : Curves.easeOut.transform(_tearController.value);
                final contentOpacity = lerpDouble(0.16, 1.0, tearValue) ?? 1.0;
                final sidePadding = constraints.maxWidth >= 1080 ? 26.0 : 0.0;
                final envelopeInset =
                    constraints.maxWidth >= 1080 ? sidePadding + 14 : 0.0;
                final tearInset =
                    constraints.maxWidth >= 1080 ? sidePadding + 20 : 0.0;
                final sheetTop = max(
                  MediaQuery.of(context).padding.top + 68,
                  72.0,
                ).toDouble();

                return Stack(
                  children: [
                    Positioned(
                      top: -110,
                      left: -40,
                      child: _GlowOrb(
                        size: 300,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    Positioned(
                      right: -90,
                      top: 160,
                      child: _GlowOrb(
                        size: 260,
                        color: palette.accent.withValues(alpha: 0.22),
                      ),
                    ),
                    Positioned(
                      left: -70,
                      bottom: -110,
                      child: _GlowOrb(
                        size: 320,
                        color: palette.envelope.withValues(alpha: 0.22),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ThemeAmbientPainter(
                            themeKey: widget.payload.theme,
                            openProgress: openValue,
                            tearProgress: tearValue,
                            accent: palette.accent,
                            softAccent: palette.envelopeLight,
                            backdrop: palette.background.last,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BurstParticlesPainter(
                            themeKey: widget.payload.theme,
                            progress: _burstController.value,
                            openProgress: openValue,
                            accent: palette.accent,
                            softAccent: palette.envelopeLight,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            _ViewerCircleButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            Text(
                              palette.headerTitle,
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            _ViewerCircleButton(
                              icon: Icons.share_rounded,
                              onTap: _shareCard,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: sheetTop,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: sidePadding),
                        child: Transform.translate(
                          offset:
                              Offset(0, lerpDouble(210, 0, paperValue) ?? 0),
                          child: Transform.scale(
                            scale: lerpDouble(0.90, 1.0, paperValue) ?? 1,
                            child: Opacity(
                              opacity:
                                  ((openValue - 0.04) / 0.96).clamp(0.0, 1.0),
                              child: _buildPaperLayer(
                                palette: palette,
                                constraints: constraints,
                                contentOpacity: contentOpacity,
                                tearValue: tearValue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: sheetTop,
                      child: IgnorePointer(
                        ignoring: !_canTear || _isTornOpen,
                        child: AnimatedOpacity(
                          opacity: (!_canTear || _isTornOpen) ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              tearInset,
                              112,
                              tearInset,
                              0,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) {
                                  _handleTearDrag(
                                    details,
                                    max(
                                      constraints.maxWidth -
                                          (constraints.maxWidth >= 1080
                                              ? 120
                                              : 32),
                                      240,
                                    ).toDouble(),
                                  );
                                },
                                onHorizontalDragEnd: (_) {
                                  _handleTearEnd();
                                },
                                onHorizontalDragCancel: () {
                                  _handleTearEnd();
                                },
                                child: Transform.translate(
                                  offset: Offset(
                                    (constraints.maxWidth + 120) *
                                        _tearController.value,
                                    0,
                                  ),
                                  child: _PaperTearStrip(
                                    accent: palette.accent,
                                    label: palette.tearHint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          ignoring: _hasStartedOpen,
                          child: Opacity(
                            opacity: lerpDouble(
                                  1,
                                  0,
                                  ((openValue - 0.58) / 0.42).clamp(0.0, 1.0),
                                ) ??
                                0,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                lerpDouble(0, -46, openValue) ?? 0,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  envelopeInset,
                                  0,
                                  envelopeInset,
                                  max(
                                    MediaQuery.of(context).padding.bottom + 32,
                                    42,
                                  ).toDouble(),
                                ),
                                child: _EnvelopeStage(
                                  palette: palette,
                                  openValue: openValue,
                                  onOpen: _startOpenSequence,
                                  hintText: _hasStartedOpen
                                      ? 'Thiệp đang bung mở...'
                                      : palette.openHint,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaperLayer({
    required _LoveCardViewerTheme palette,
    required BoxConstraints constraints,
    required double contentOpacity,
    required double tearValue,
  }) {
    final imageUrl = widget.payload.imageUrl?.trim();
    final mediaVisible = imageUrl != null && imageUrl.isNotEmpty;
    final buttonEnabled = _isTornOpen;
    final paperRadius = constraints.maxWidth >= 720 ? 36.0 : 0.0;

    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(paperRadius),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.paper,
                Color.lerp(palette.paper, Colors.white, 0.32)!,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -140,
                right: -70,
                child: _PaperGlow(
                  size: 260,
                  color: palette.accent.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                left: -80,
                bottom: -120,
                child: _PaperGlow(
                  size: 300,
                  color: palette.envelope.withValues(alpha: 0.16),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.transparent,
                        palette.envelopeLight.withValues(alpha: 0.32),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        22,
                        22,
                        max(
                          MediaQuery.of(context).padding.bottom + 108,
                          132,
                        ).toDouble(),
                      ),
                      child: Opacity(
                        opacity: contentOpacity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _PaperBadge(
                                        label: palette.badge,
                                        background:
                                            palette.accent.withValues(alpha: 0.12),
                                        foreground: palette.accent,
                                      ),
                                      _PaperBadge(
                                        label: _isTornOpen
                                            ? 'Thiệp đã mở'
                                            : 'Thiệp riêng đang mở',
                                        background: palette.envelopeLight,
                                        foreground: palette.muted,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatTime(widget.payload.timestampMs),
                                  textAlign: TextAlign.right,
                                  style: SLTheme.quicksand(
                                    color: palette.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Từ $_senderName',
                              style: SLTheme.quicksand(
                                color: palette.ink,
                                fontSize: constraints.maxWidth < 420 ? 28 : 34,
                                height: 1.12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _signature,
                              style: SLTheme.quicksand(
                                color: palette.muted,
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              palette.headline,
                              style: SLTheme.quicksand(
                                color: palette.ink.withValues(alpha: 0.92),
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (mediaVisible) ...[
                              const SizedBox(height: 22),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: palette.envelopeLight,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: palette.accent,
                                              size: 34,
                                            ),
                                          );
                                        },
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.18),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(22, 22, 22, 26),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.10),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withValues(alpha: 0.08),
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.accent.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          palette.stampIcon,
                                          color: palette.accent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          palette.effectLabel,
                                          style: SLTheme.quicksand(
                                            color: palette.accent,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _messageText,
                                    style: GoogleFonts.dancingScript(
                                      color: palette.ink,
                                      fontSize:
                                          constraints.maxWidth < 420 ? 36 : 44,
                                      height: 1.42,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(
                                    color: palette.accent.withValues(alpha: 0.16),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    _signature,
                                    style: SLTheme.quicksand(
                                      color: palette.muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: palette.envelopeLight.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: palette.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      palette.stampIcon,
                                      color: palette.accent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Người gửi hiển thị rõ',
                                          style: SLTheme.quicksand(
                                            color: palette.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _senderName,
                                          style: SLTheme.quicksand(
                                            color: palette.ink,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isTornOpen) ...[
                              const SizedBox(height: 18),
                              Text(
                                'Kéo dải giấy ở phía trên để xé mở hoàn toàn.',
                                style: SLTheme.quicksand(
                                  color: palette.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              minHeight: 7,
                              value: tearValue,
                              borderRadius: BorderRadius.circular(999),
                              backgroundColor: palette.accent.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: max(
                  MediaQuery.of(context).padding.bottom + 14,
                  18,
                ).toDouble(),
                child: IgnorePointer(
                  ignoring: !buttonEnabled,
                  child: AnimatedOpacity(
                    opacity: buttonEnabled ? 1 : 0.54,
                    duration: const Duration(milliseconds: 220),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionPillButton(
                            label: 'Sao chép lời nhắn',
                            icon: Icons.content_copy_rounded,
                            onTap: _copyCardContent,
                            background: palette.accent.withValues(alpha: 0.10),
                            foreground: palette.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionPillButton(
                            label: 'Chia sẻ',
                            icon: Icons.ios_share_rounded,
                            onTap: _shareCard,
                            background: palette.accent,
                            foreground: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
