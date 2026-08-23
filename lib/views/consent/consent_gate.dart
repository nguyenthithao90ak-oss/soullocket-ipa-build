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

const Color _accentRose = Color(0xFFD81B60);
const Color _accentLavender = Color(0xFF7C4DFF);
const Color _accentBlue = Color(0xFF2563EB);
const Color _accentGreen = Color(0xFF0F766E);
const Color _ink = Color(0xFF1C1E21);
const Color _muted = Color(0xFF65676B);

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
        setState(() {});
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
      setState(() {});
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
      setState(() {});
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

        return StatefulBuilder(
          builder: (ctx, setState) {
            final screenSize = MediaQuery.sizeOf(ctx);
            final mediaPadding = MediaQuery.of(ctx).padding;
            final compact = screenSize.width < 620;
            const dialogRadius = 26.0;
            const horizontalInset = 16.0;
            const verticalInset = 32.0;
            const horizontalPadding = 18.0;

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
                        maxWidth: 460, // Mở rộng chiều ngang cho thoáng hơn
                        maxHeight: screenSize.height * 0.82,
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

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
