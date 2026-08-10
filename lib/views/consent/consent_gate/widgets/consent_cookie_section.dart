part of '../../consent_gate.dart';

Widget _buildStartupCookieStorageSection(
  BuildContext context, {
  required String cookieLevel,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cookie_rounded,
                  color: _accentGreen, size: 19),
            ),
            SLSpacing.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('consent_cookielutr_6b35ac'),
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('consent_chnmclutrc_0fe956'),
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCookieChoiceCard(
          value: 'essential',
          groupValue: cookieLevel,
          accent: _accentBlue,
          title: context.tr('consent_thityu_cd979a'),
          subtitle: context.tr('consent_gingnhpcon_189e36'),
          bullets: [
            context.tr('consent_tigindliul_a475c3'),
            context.tr('consent_phhpnubnmu_d29e36'),
          ],
          onTap: () => onChanged('essential'),
        ),
        const SizedBox(height: 6),
        _buildCookieChoiceCard(
          value: 'all',
          groupValue: cookieLevel,
          accent: _accentGreen,
          title: context.tr('consent_ttc_d8586d'),
          subtitle: context.tr('consent_thmcnhnhac_f0e289'),
          bullets: [
            context.tr('consent_phhpnubnmu_4875ce'),
            context.tr('consent_cthlunhiud_1e2ff6'),
          ],
          badge: context.tr('consent_xut_59efad'),
          onTap: () => onChanged('all'),
        ),
        const SizedBox(height: 8),
        _buildInlineDocLink(
          accent: _accentBlue,
          label: context.tr('consent_xemchnhsch_10073b'),
          onTap: () => _openDoc(
              context,
              context.tr('consent_chnhschcoo_9209d0'),
              'assets/docs/cookie-policy.html'),
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
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.30)
              : const Color(0xFFE0E0E0),
          width: selected ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Colors.transparent,
              border: Border.all(
                color: selected ? accent : const Color(0xFFCCCCCC),
                width: selected ? 1.5 : 1.8,
              ),
            ),
            child: selected
                ? const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: large ? 15 : 13.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: SLTheme.quicksand(
                            fontSize: large ? 11 : 9.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: large ? 13 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                ...bullets.map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: accent.withValues(alpha: 0.65),
                            size: large ? 12 : 10,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            bullet,
                            style: SLTheme.quicksand(
                              fontSize: large ? 12.5 : 11,
                              fontWeight: FontWeight.w600,
                              color: _ink.withValues(alpha: 0.78),
                              height: 1.30,
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
        ],
      ),
    ),
  );
}
