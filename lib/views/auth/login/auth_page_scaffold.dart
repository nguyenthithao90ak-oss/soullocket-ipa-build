import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_language_toggle.dart';
import 'auth_visual_style.dart';
import 'aurora_hero_background.dart';

class AuthPageScaffold extends StatelessWidget {
  final Widget Function(bool compact) contentBuilder;
  final VoidCallback onSyncGuide;
  final String copyrightYear;
  final bool transitioning;
  const AuthPageScaffold({
    super.key,
    required this.contentBuilder,
    required this.onSyncGuide,
    required this.copyrightYear,
    this.transitioning = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final l10n = L10nService();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: style.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            const Positioned.fill(child: AuroraHeroBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final inset = MediaQuery.viewInsetsOf(context).bottom;
                  final gutter = constraints.maxWidth < 450 ? 16.0 : 32.0;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16 + inset),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 24 - inset).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 1000 : 460,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    tooltip: l10n.translate('auth_sync_guide'),
                                    onPressed: onSyncGuide,
                                    icon: Icon(
                                      Icons.devices_rounded,
                                      size: 21,
                                      color: style.muted,
                                    ),
                                  ),
                                  AuthLanguageToggle(
                                    currentLocale: l10n.localeCode,
                                    onSelect: (code) => l10n.setLocale(code),
                                  ),
                                ],
                              ),
                              SizedBox(height: wide ? 28 : 8),
                              AnimatedOpacity(
                                duration:
                                    MediaQuery.of(context).disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                opacity: transitioning ? 0 : 1,
                                child: contentBuilder(!wide),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.format('auth_refresh_copyright', {
                                  'year': copyrightYear,
                                }),
                                textAlign: TextAlign.center,
                                style: style.text(size: 10, color: style.muted),
                              ),
                            ],
                          ),
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
    );
  }
}
