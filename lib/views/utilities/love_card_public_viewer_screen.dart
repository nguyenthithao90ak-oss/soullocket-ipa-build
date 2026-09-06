import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/love_card_link_service.dart';

part 'love_card/love_card_public_viewer_helpers.dart';

class LoveCardPublicViewerScreen extends StatefulWidget {
  final LoveCardLinkPayload payload;
  final Uri? sourceUri;
  final VoidCallback? onBack;

  const LoveCardPublicViewerScreen({
    super.key,
    required this.payload,
    this.sourceUri,
    this.onBack,
  });

  @override
  State<LoveCardPublicViewerScreen> createState() =>
      _LoveCardPublicViewerScreenState();
}

class _LoveCardPublicViewerScreenState
    extends State<LoveCardPublicViewerScreen> {
  bool _opened = false;

  _LoveCardViewerTheme get _palette =>
      _LoveCardViewerTheme.of(widget.payload.theme);

  String get _senderName {
    final value = widget.payload.senderName.trim();
    return value.isEmpty ? context.tr('util_ngithngcab_27bf12') : value;
  }

  String get _signature {
    final value = widget.payload.signature?.trim() ?? '';
    return value.isEmpty ? _palette.signatureFallback : value;
  }

  String get _messageText {
    final value = widget.payload.content.trim();
    return value.isEmpty ? context.tr('util_mtlinhndud_27a576') : value;
  }

  void _openLetter() {
    if (_opened) return;
    HapticFeedback.mediumImpact();
    setState(() => _opened = true);
  }

  Future<void> _copyCardContent() async {
    final text = widget.payload.content.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('util_saochpnidu_7d192f'))),
    );
  }

  Future<void> _shareCard() async {
    final message = [
      widget.payload.content.trim(),
      if (widget.sourceUri != null) widget.sourceUri.toString(),
    ].where((value) => value.isNotEmpty).join('\n\n');
    if (message.isEmpty) return;
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
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _LoveCardBackdropMotif(palette: palette),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(palette),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      // Giữ animation trong [0, 1] cho cả độ mờ và tỉ lệ.
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.96,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _opened
                          ? _buildOpenedLetter(palette)
                          : _buildSealedLetter(palette),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_LoveCardViewerTheme palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _ViewerCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  palette.headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _opened
                      ? context.tr('love_card_receiver_opened_badge')
                      : context.tr('love_card_receiver_private_badge'),
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _ViewerCircleButton(
            icon: Icons.ios_share_rounded,
            tooltip: context.tr('share'),
            onTap: _shareCard,
          ),
        ],
      ),
    );
  }

  Widget _buildSealedLetter(_LoveCardViewerTheme palette) {
    return Center(
      key: const ValueKey('sealed-letter'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              _LetterBadge(
                icon: palette.leadingIcon,
                label: palette.badge,
                color: palette.accent,
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('love_card_receiver_unopened_title'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('love_card_receiver_unopened_subtitle'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              _SealedLoveEnvelope(
                palette: palette,
                senderName: _senderName,
                onOpen: _openLetter,
              ),
              const SizedBox(height: 22),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openLetter,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: palette.envelopeLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('love_card_receiver_open_action'),
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
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

  Widget _buildOpenedLetter(_LoveCardViewerTheme palette) {
    final imageUrl = widget.payload.imageUrl?.trim() ?? '';
    return LayoutBuilder(
      key: const ValueKey('opened-letter'),
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 420 ? 14.0 : 22.0;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            MediaQuery.paddingOf(context).bottom + 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -42,
                      right: -34,
                      child: Container(
                        width: 145,
                        height: 145,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.envelopeLight.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _LetterBadge(
                                icon: palette.leadingIcon,
                                label: palette.badge,
                                color: palette.accent,
                                onPaper: true,
                              ),
                              const Spacer(),
                              _PostageStamp(palette: palette),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            palette.headline,
                            style: SLTheme.quicksand(
                              color: palette.ink,
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            L10nService().format('love_card_receiver_from', {
                              'name': _senderName,
                            }),
                            style: SLTheme.quicksand(
                              color: palette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (imageUrl.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(
                                    milliseconds: 180,
                                  ),
                                  placeholder: (context, imageUrl) =>
                                      ColoredBox(
                                        color: palette.envelopeLight.withValues(
                                          alpha: 0.26,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: palette.accent,
                                          ),
                                        ),
                                      ),
                                  errorWidget: (context, imageUrl, error) =>
                                      ColoredBox(
                                        color: palette.envelopeLight.withValues(
                                          alpha: 0.22,
                                        ),
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: palette.muted,
                                          size: 34,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: palette.accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              _messageText,
                              style: GoogleFonts.dancingScript(
                                color: palette.ink,
                                fontSize: 29,
                                height: 1.42,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _LetterDivider(palette: palette),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  palette.trailingIcon,
                                  color: palette.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _senderName,
                                      style: SLTheme.quicksand(
                                        color: palette.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _signature,
                                      style: GoogleFonts.dancingScript(
                                        color: palette.accent,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(widget.payload.timestampMs),
                                      style: SLTheme.quicksand(
                                        color: palette.muted,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionPillButton(
                                  label: context.tr('util_saochp_cbfba9'),
                                  icon: Icons.copy_rounded,
                                  onTap: _copyCardContent,
                                  background: palette.accent.withValues(
                                    alpha: 0.10,
                                  ),
                                  foreground: palette.accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionPillButton(
                                  label: context.tr('share'),
                                  icon: Icons.send_rounded,
                                  onTap: _shareCard,
                                  background: palette.accent,
                                  foreground: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
