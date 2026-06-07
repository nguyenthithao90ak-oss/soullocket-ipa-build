part of '../../consent_gate.dart';

Widget _buildStartupCookieStorageSection(BuildContext context, {
  required String cookieLevel,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Color.lerp(Colors.white, _accentGreen, 0.035),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _accentGreen.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _accentGreen.withValues(alpha: 0.16)),
              ),
              child: const Icon(Icons.cookie_rounded,
                  color: _accentGreen, size: 20),
            ),
            SLSpacing.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('consent_cookielutr_6b35ac'),
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('consent_chnmclutrc_0fe956'),
                    style: SLTheme.quicksand(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      height: 1.30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        _buildCookieChoiceCard(
          value: 'essential',
          groupValue: cookieLevel,
          accent: _accentBlue,
          title: context.tr('consent_thityu_cd979a'),
          subtitle:
              context.tr('consent_gingnhpcon_189e36'),
          bullets: [
            context.tr('consent_tigindliul_a475c3'),
            context.tr('consent_phhpnubnmu_d29e36'),
          ],
          onTap: () => onChanged('essential'),
        ),
        const SizedBox(height: 8),
        _buildCookieChoiceCard(
          value: 'all',
          groupValue: cookieLevel,
          accent: _accentGreen,
          title: context.tr('consent_ttc_d8586d'),
          subtitle:
              context.tr('consent_thmcnhnhac_f0e289'),
          bullets: [
            context.tr('consent_phhpnubnmu_4875ce'),
            context.tr('consent_cthlunhiud_1e2ff6'),
          ],
          badge: context.tr('consent_xut_59efad'),
          onTap: () => onChanged('all'),
        ),
        const SizedBox(height: 11),
        _buildInlineDocLink(
          accent: _accentBlue,
          label: context.tr('consent_xemchnhsch_10073b'),
          onTap: () =>
              _openDoc(context, context.tr('consent_chnhschcoo_9209d0'), 'assets/docs/cookie-policy.html'),
        ),
      ],
    ),
  );
}

Widget _buildCookieChoiceCard({
  required String value,
  required String groupValue,
  required Color accent,
  required String title,
  required String subtitle,
  required List<String> bullets,
  String? badge,
  bool large = false,
  required VoidCallback onTap,
}) {
  final selected = value == groupValue;
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: large
          ? const EdgeInsets.fromLTRB(11, 13, 13, 13)
          : const EdgeInsets.fromLTRB(9, 11, 11, 11),
      decoration: BoxDecoration(
        color: selected
            ? Color.lerp(Colors.white, accent, 0.10)
            : _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.28) : _panelBorder,
          width: selected ? 1.35 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: selected ? 14 : 6,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(-2, 0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(
                  color: selected ? accent : _panelBorder,
                  width: selected ? 7 : 2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: large ? 16 : 14.1,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        badge,
                        style: SLTheme.quicksand(
                          fontSize: large ? 12 : 10.2,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: large ? 14 : 11.9,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ...bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              bullet,
                              style: SLTheme.quicksand(
                                fontSize: large ? 13.5 : 11.55,
                                fontWeight: FontWeight.w700,
                                color: _ink.withValues(alpha: 0.84),
                                height: 1.28,
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
        ],
      ),
    ),
  );
}
