import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
      SLSnackBar(content: Text(context.tr('util_saochpnidu_7d192f'))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = palette.backgroundFor(isDark);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: background.last,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Scaffold(
        backgroundColor: background.last,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: background,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: _LoveCardBackdropMotif(palette: palette),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(palette, isDark),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.98,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _opened
                            ? _buildOpenedLetter(palette, isDark)
                            : _buildSealedLetter(palette, isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(_LoveCardViewerTheme palette, bool isDark) {
    final foreground = palette.foregroundFor(isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _ViewerCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
            foreground: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  palette.headerTitle,
                  style: SLTheme.quicksand(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _opened
                      ? context.tr('love_card_receiver_opened_badge')
                      : context.tr('love_card_receiver_private_badge'),
                  style: SLTheme.quicksand(
                    color: palette.mutedFor(isDark),
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ViewerCircleButton(
            icon: Icons.ios_share_rounded,
            tooltip: context.tr('share'),
            onTap: _shareCard,
            foreground: foreground,
          ),
        ],
      ),
    );
  }

  Widget _buildSealedLetter(_LoveCardViewerTheme palette, bool isDark) {
    return Center(
      key: const ValueKey('sealed-letter'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            children: [
              _LetterBadge(
                icon: palette.leadingIcon,
                label: palette.badge,
                color: isDark ? palette.envelopeLight : palette.accentInk,
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('love_card_receiver_unopened_title'),
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: palette.foregroundFor(isDark),
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('love_card_receiver_unopened_subtitle'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: palette.mutedFor(isDark),
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              _SealedLoveEnvelope(palette: palette, onOpen: _openLetter),
              const SizedBox(height: 24),
              Text(
                L10nService().format('love_card_receiver_from', {
                  'name': _senderName,
                }),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: palette.foregroundFor(isDark),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _ActionPillButton(
                key: const ValueKey('open-card-action'),
                label: context.tr('love_card_receiver_open_action'),
                icon: Icons.mark_email_read_outlined,
                onTap: _openLetter,
                background: palette.accentInk,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenedLetter(_LoveCardViewerTheme palette, bool isDark) {
    final imageUrl = widget.payload.imageUrl?.trim() ?? '';
    return LayoutBuilder(
      key: const ValueKey('opened-letter'),
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 22.0;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    child: Container(
                      key: const ValueKey('love-card-keepsake-paper'),
                      decoration: BoxDecoration(
                        color: palette.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.accentInk.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.14 : 0.05,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr(
                                          'love_card_receiver_private_badge',
                                        ),
                                        style: SLTheme.quicksand(
                                          color: palette.mutedInk,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _LetterBadge(
                                        icon: palette.leadingIcon,
                                        label: palette.badge,
                                        color: palette.accentInk,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _PostageStamp(palette: palette),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              palette.headline,
                              style: GoogleFonts.playfairDisplay(
                                color: palette.ink,
                                fontSize: 26,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              L10nService().format('love_card_receiver_from', {
                                'name': _senderName,
                              }),
                              style: SLTheme.quicksand(
                                color: palette.mutedInk,
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (imageUrl.isNotEmpty) ...[
                              _LetterPhoto(
                                palette: palette,
                                imageUrl: imageUrl,
                              ),
                              const SizedBox(height: 26),
                            ] else ...[
                              _LetterDivider(palette: palette),
                              const SizedBox(height: 24),
                            ],
                            Text(
                              _messageText,
                              key: const ValueKey('love-card-message'),
                              style: GoogleFonts.lora(
                                color: palette.ink,
                                fontSize: 18,
                                height: 1.75,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _LetterDivider(palette: palette),
                            const SizedBox(height: 22),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _signature,
                                    key: const ValueKey('love-card-signature'),
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.dancingScript(
                                      color: palette.accentInk,
                                      fontSize: 27,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _senderName,
                                    textAlign: TextAlign.end,
                                    style: SLTheme.quicksand(
                                      color: palette.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTime(widget.payload.timestampMs),
                                    key: const ValueKey('love-card-date'),
                                    textAlign: TextAlign.end,
                                    style: SLTheme.quicksand(
                                      color: palette.mutedInk,
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLetterActions(palette, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetterActions(_LoveCardViewerTheme palette, bool isDark) {
    final copy = _ActionPillButton(
      key: const ValueKey('copy-card-action'),
      label: context.tr('util_saochp_cbfba9'),
      icon: Icons.copy_outlined,
      onTap: _copyCardContent,
      background: palette.foregroundFor(isDark).withValues(alpha: 0.04),
      foreground: palette.foregroundFor(isDark),
      outlined: true,
    );
    final share = _ActionPillButton(
      key: const ValueKey('share-card-action'),
      label: context.tr('share'),
      icon: Icons.ios_share_rounded,
      onTap: _shareCard,
      background: palette.accentInk,
      foreground: Colors.white,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(13) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 10), share],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 12),
            Expanded(child: share),
          ],
        );
      },
    );
  }
}
