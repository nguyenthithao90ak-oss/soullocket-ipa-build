import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/consent_service.dart';
import '../home/screens/document_viewer_screen.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';

part 'consent_gate/models/consent_models.dart';
part 'consent_gate/widgets/consent_header.dart';
part 'consent_gate/widgets/consent_legal_section.dart';
part 'consent_gate/widgets/consent_cookie_section.dart';
part 'consent_gate/widgets/consent_ack_bar.dart';
part 'consent_gate/widgets/consent_highlight_list.dart';
part 'consent_gate/widgets/consent_scroll_hint.dart';

class ConsentGate extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onReady;

  const ConsentGate({
    super.key,
    required this.child,
    this.onReady,
  });

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

const Color _accentRose = Color(0xFFE65372);
const Color _accentLavender = Color(0xFF8F72D8);
const Color _accentBlue = Color(0xFF5D8DE8);
const Color _accentGreen = Color(0xFF2C9B86);
const Color _ink = Color(0xFF3B2830);
const Color _muted = Color(0xFF79646D);
const Color _panelBorder = Color(0xFFF0DDE3);
const Color _dialogBg = Color(0xFFFFFDF9);
const Color _surfaceBg = Color(0xFFFFF5F7);
const Color _dialogBackgroundTop = Color(0xFFFFFDF9);
const Color _dialogBackgroundBottom = Color(0xFFF4EEFF);
const Color _cardBackground = Color(0xFFFFFEFC);

Future<void> _openDoc(
    BuildContext context, String title, String assetPath) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DocumentViewerScreen(
        title: title,
        assetPath: assetPath,
      ),
    ),
  );
}

class _ConsentGateState extends State<ConsentGate> {
  static const bool _appReviewConsentBypass =
      bool.fromEnvironment('APP_REVIEW_BYPASS_CONSENT', defaultValue: false);

  final ConsentService _consentService = ConsentService();
  bool _ready = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      if (_appReviewConsentBypass) {
        await _seedAppReviewConsent();
        if (!mounted) return;
        setState(() => _ready = true);
        return;
      }
      _ensureConsent();
    });
  }

  Future<void> _seedAppReviewConsent() async {
    await _consentService.setTosAccepted(true);
    await _consentService.setPrivacyAccepted(true);
    await _consentService.setCookieConsentLevel('essential');
  }

  Future<void> _ensureConsent() async {
    if (_running) return;
    _running = true;
    try {
      if (!mounted) return;
      var hasStartupConsent = _consentService.hasValidConsentSync();
      if (!hasStartupConsent) {
        hasStartupConsent = await _consentService.hasValidConsent();
      }
      if (!hasStartupConsent) {
        final initialCookieLevel =
            await _consentService.getCookieConsentLevel();
        if (!mounted) return;
        final result = await _showStartupConsentDialog(
          initialCookieLevel: initialCookieLevel,
        );
        if (result == null || !mounted) return;
        await _consentService.setTosAccepted(true);
        await _consentService.setPrivacyAccepted(true);
        await _consentService.setCookieConsentLevel(result.cookieLevel);
      }

      if (!mounted) return;
      setState(() => _ready = true);
      Future<void>(() async {
        try {
          await widget.onReady?.call();
        } catch (e) {
          debugPrint(
              'ConsentGate onReady error: ${AppErrorMapper.resolve(e).message}');
        }
      });
    } catch (e) {
      debugPrint('ConsentGate failed: ${AppErrorMapper.resolve(e).message}');
      if (!mounted) return;
      setState(() => _ready = true);
    } finally {
      _running = false;
    }
  }

  Future<_StartupConsentResult?> _showStartupConsentDialog({
    String? initialCookieLevel,
  }) {
    return showDialog<_StartupConsentResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18), // Nền phía sau nhìn thấy rõ Login màn hình hồng
      builder: (ctx) {
        var cookieLevel =
            initialCookieLevel == 'essential' ? 'essential' : 'all';
        final showScrollHintNotifier = ValueNotifier<bool>(true);

        return StatefulBuilder(
          builder: (ctx, setState) {
            final screenSize = MediaQuery.sizeOf(ctx);
            final mediaPadding = MediaQuery.of(ctx).padding;
            final compact = screenSize.width < 620;
            const dialogRadius = 26.0;
            const horizontalInset = 24.0;
            const verticalInset = 32.0;
            const horizontalPadding = 14.0;

            return PopScope(
              canPop: false,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                  vertical: verticalInset,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(dialogRadius),
                  child: FastBackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 380, // Thu gọn chiều rộng cho cực kỳ xinh xắn
                        maxHeight: screenSize.height * 0.82, // Thu gọn chiều cao
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF5F7).withValues(alpha: 0.90), // Kính mờ trắng hồng nổi trên Login
                        borderRadius: BorderRadius.circular(dialogRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4081).withValues(alpha: 0.15),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    child: SafeArea(
                      top: compact,
                      bottom: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    final shouldShow =
                                        notification.metrics.pixels <= 8 &&
                                            notification
                                                    .metrics.maxScrollExtent >
                                                16;
                                    if (showScrollHintNotifier.value !=
                                        shouldShow) {
                                      showScrollHintNotifier.value = shouldShow;
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      compact ? 12 : 16,
                                      horizontalPadding,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildStartupConsentHeader(ctx,
                                            compact: compact),
                                        const SizedBox(height: 14),
                                        _buildStartupLegalSection(
                                          accent: _accentRose,
                                          icon: Icons.gavel_rounded,
                                          title: context
                                              .tr('consent_iukhonsdng_9a9c73'),
                                          subtitle: context
                                              .tr('consent_tmttcchdng_0cbb57'),
                                          bullets: [],
                                          actionLabel: context
                                              .tr('consent_xemiukhon_5d9f36'),
                                          onTap: () => _openDoc(
                                            ctx,
                                            context.tr(
                                                'consent_iukhonsdng_9a9c73'),
                                            'assets/docs/terms.html',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildStartupLegalSection(
                                          accent: _accentLavender,
                                          icon: Icons.privacy_tip_rounded,
                                          title: context
                                              .tr('consent_chnhschbom_98b319'),
                                          subtitle: context
                                              .tr('consent_tmttdliuap_7cebb7'),
                                          bullets: [],
                                          actionLabel: context
                                              .tr('consent_xembomt_eaa9ec'),
                                          onTap: () => _openDoc(
                                            context,
                                            context.tr(
                                                'consent_chnhschbom_98b319'),
                                            'assets/docs/privacy.html',
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                                          child: Text(
                                            context.tr('consent_tychnlutr_ffd19f'),
                                            style: SLTheme.quicksand(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                        _buildStartupCookieStorageSection(
                                          ctx,
                                          cookieLevel: cookieLevel,
                                          onChanged: (value) => setState(() {
                                            cookieLevel = value;
                                          }),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildStartupAgreeBar(
                                          ctx,
                                          compact: compact,
                                          bottomInset: mediaPadding.bottom,
                                          cookieLevel: cookieLevel,
                                          onConfirm: () => Navigator.pop(
                                            ctx,
                                            _StartupConsentResult(
                                              cookieLevel: cookieLevel,
                                            ),
                                          ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 8,
                                  child: IgnorePointer(
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: showScrollHintNotifier,
                                      builder: (context, showHint, _) {
                                        return AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          opacity: showHint ? 1 : 0,
                                          child: _buildStartupScrollHint(),
                                        );
                                      },
                                    ),
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
              ),
            ),
          );
          },
        );
      },
    );
  }

  Future<bool?> _showPrivacyDialog() {
    return _showConsentDialog(
      title: context.tr('consent_chnhschbom_98b319'),
      subtitle: context.tr('consent_bngnytmttd_7ba1b0'),
      actionLabel: context.tr('consent_xemchititb_d4c7c5'),
      assetPath: 'assets/docs/privacy.html',
      checkboxLabel: context.tr('consent_ticvngvich_383523'),
      leadingIcon: Icons.privacy_tip_rounded,
      accent: _accentLavender,
      highlightItems: [
        _ConsentHighlight(
          icon: Icons.folder_shared_rounded,
          title: context.tr('consent_dliucxl_cbc4d9'),
          description: context.tr('consent_baogmnhvgp_7cae8c'),
        ),
        _ConsentHighlight(
          icon: Icons.lock_outline_rounded,
          title: context.tr('consent_mcchsdng_803f65'),
          description: context.tr('consent_dngktnicpi_abde74'),
        ),
        _ConsentHighlight(
          icon: Icons.manage_accounts_rounded,
          title: context.tr('consent_quynkimsot_363315'),
          description: context.tr('consent_bncthttgps_338c10'),
        ),
      ],
    );
  }

  Future<bool?> _showSecurityDeviceSignalsDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _panelBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _accentGreen.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderIcon(
                          ctx,
                          accent: _accentGreen,
                          icon: Icons.verified_user_rounded,
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('consent_bomtthitbv_6b7891'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                context.tr('consent_soullocket_3df71a'),
                                style: SLTheme.quicksand(
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h12,
                    _buildHighlightList(
                      ctx,
                      [
                        _ConsentHighlight(
                          icon: Icons.phone_iphone_rounded,
                          title: context.tr('consent_dliuclu_f572e2'),
                          description: context.tr('consent_modelmyhiu_a0b2e6'),
                        ),
                        _ConsentHighlight(
                          icon: Icons.public_rounded,
                          title: context.tr('consent_vtrgnngtip_a84a67'),
                          description: context.tr('consent_chsuyramct_3cfdc0'),
                        ),
                        _ConsentHighlight(
                          icon: Icons.security_rounded,
                          title: context.tr('consent_mcchsdng_803f65'),
                          description: context.tr('consent_cnhbongnhp_c8f63c'),
                        ),
                      ],
                      accent: _accentGreen,
                    ),
                    SLSpacing.h12,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.08),
                        borderRadius: SLRadius.lgAll,
                        border: Border.all(
                          color: _accentGreen.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        context.tr('consent_nubnkhngbt_347436'),
                        style: SLTheme.quicksand(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                          color: _ink.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ),
                    SLSpacing.h12,
                    _buildPrimaryButton(
                      ctx,
                      accent: _accentGreen,
                      label: context.tr('consent_xemchititc_1cad13'),
                      icon: Icons.open_in_new_rounded,
                      onTap: () => _openDoc(
                        ctx,
                        context.tr('consent_chnhschbom_98b319'),
                        'assets/docs/privacy.html',
                      ),
                    ),
                    SLSpacing.h12,
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(
                              foregroundColor: _accentGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              context.tr('consent_khngbtlcny_fff385'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SLSpacing.w8,
                        Expanded(
                          child: _buildPrimaryButton(
                            ctx,
                            accent: _accentGreen,
                            label: context.tr('consent_btbovthitb_ce67e5'),
                            icon: Icons.shield_rounded,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConsentDialog({
    required String title,
    required String subtitle,
    required String actionLabel,
    required String assetPath,
    required String checkboxLabel,
    required IconData leadingIcon,
    required Color accent,
    required List<_ConsentHighlight> highlightItems,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        bool checked = false;
        bool showRequiredHint = false;
        return StatefulBuilder(
          builder: (ctx, setState) => PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _panelBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: const Color(0xFF3B2830).withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderIcon(ctx,
                                accent: accent, icon: leadingIcon),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: SLTheme.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  SLSpacing.h4,
                                  Text(
                                    subtitle,
                                    style: SLTheme.quicksand(
                                      fontSize: 12.4,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SLSpacing.h12,
                        _buildHighlightList(ctx, highlightItems,
                            accent: accent),
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          ctx,
                          accent: accent,
                          label: actionLabel,
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(ctx, title, assetPath),
                        ),
                        SLSpacing.h8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: checked
                                ? accent.withValues(alpha: 0.08)
                                : _cardBackground,
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(
                              color: checked
                                  ? accent.withValues(alpha: 0.24)
                                  : _panelBorder,
                              width: checked ? 1.3 : 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: checked
                                    ? accent.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: checked ? 16 : 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              checked = !checked;
                              if (checked) showRequiredHint = false;
                            }),
                            borderRadius: SLRadius.lgAll,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (v) => setState(() {
                                    checked = v ?? false;
                                    if (checked) showRequiredHint = false;
                                  }),
                                  activeColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: SLRadius.smAll,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 11, bottom: 11),
                                    child: Text(
                                      checkboxLabel,
                                      style: SLTheme.quicksand(
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w800,
                                        color: _ink.withValues(alpha: 0.9),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showRequiredHint) ...[
                          const SizedBox(height: 10),
                          _buildRequiredConsentHint(ctx, accent: accent),
                        ],
                        SLSpacing.h12,
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => showRequiredHint = true),
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                context.tr('consent_khngng_e6ce42'),
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 138,
                              child: _buildPrimaryButton(
                                ctx,
                                accent: accent,
                                label: context.tr('consent_tiptc_555f1f'),
                                icon: Icons.check_rounded,
                                onTap: checked
                                    ? () => Navigator.pop(ctx, true)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCookieConsentSheet() {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String level = 'all';
        bool showRequiredHint = false;
        return SafeArea(
          top: false,
          child: PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (ctx, setState) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _panelBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentBlue.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 54,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _panelBorder.withValues(alpha: 0.8),
                              borderRadius: SLRadius.pillAll,
                            ),
                          ),
                        ),
                        SLSpacing.h8,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderIcon(
                              ctx,
                              accent: _accentBlue,
                              icon: Icons.cookie_rounded,
                            ),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('consent_tychncooki_f0907c'),
                                    style: SLTheme.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  Text(
                                    context.tr('consent_chnmclutrp_061bfc'),
                                    style: SLTheme.quicksand(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SLSpacing.h12,
                        _buildCookieChoiceCard(
                          value: 'essential',
                          groupValue: level,
                          accent: _accentBlue,
                          title: context.tr('consent_thityu_cd979a'),
                          subtitle: context.tr('consent_gingnhpcon_525036'),
                          bullets: [
                            context.tr('consent_btbucappho_b21b5b'),
                            context.tr('consent_phhpnubnmu_575815'),
                          ],
                          onTap: () => setState(() {
                            level = 'essential';
                            showRequiredHint = false;
                          }),
                        ),
                        SLSpacing.h8,
                        _buildCookieChoiceCard(
                          value: 'all',
                          groupValue: level,
                          accent: _accentGreen,
                          title: context.tr('consent_ttc_d8586d'),
                          subtitle: context.tr('consent_baogmthity_291746'),
                          bullets: [
                            context.tr('consent_phhpnubnmu_4875ce'),
                            context.tr('consent_chophpnhiu_2f2045'),
                          ],
                          badge: context.tr('consent_mcnh_a57a8e'),
                          onTap: () => setState(() {
                            level = 'all';
                            showRequiredHint = false;
                          }),
                        ),
                        if (showRequiredHint) ...[
                          const SizedBox(height: 10),
                          _buildRequiredConsentHint(ctx, accent: _accentBlue),
                        ],
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          ctx,
                          accent: _accentBlue,
                          label: context.tr('consent_xemchititc_de27c6'),
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(
                            ctx,
                            context.tr('consent_chnhschcoo_9209d0'),
                            'assets/docs/cookie-policy.html',
                          ),
                        ),
                        SLSpacing.h12,
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => showRequiredHint = true),
                              style: TextButton.styleFrom(
                                foregroundColor: _accentRose,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                context.tr('consent_khngng_e6ce42'),
                                style: SLTheme.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 138,
                              child: _buildPrimaryButton(
                                ctx,
                                accent:
                                    level == 'all' ? _accentGreen : _accentBlue,
                                label: context.tr('consent_xcnhn_1e2eb2'),
                                icon: Icons.check_rounded,
                                onTap: () => Navigator.pop(ctx, level),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
