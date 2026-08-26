part of '../../consent_gate.dart';

Widget _buildStartupCookieStorageSection(
  BuildContext context, {
  required String cookieLevel,
  required ValueChanged<String> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildCookieChoiceCard(
        value: 'essential',
        groupValue: cookieLevel,
        accent: _accentBlue,
        title: context.tr('consent_thityu_cd979a'),
        subtitle: context.tr('consent_gingnhpcon_189e36'),
        bullets: const [],
        onTap: () => onChanged('essential'),
      ),
      const SizedBox(height: 6),
      _buildCookieChoiceCard(
        value: 'all',
        groupValue: cookieLevel,
        accent: _accentGreen,
        title: context.tr('consent_ttc_d8586d'),
        subtitle: context.tr('consent_thmcnhnhac_f0e289'),
        bullets: const [],
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
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFFBF7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF00BFA5) : const Color(0xFFE8E0E4),
          width: selected ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFF00BFA5).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: selected ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFF00BFA5) : Colors.white,
              border: Border.all(
                color: selected ? const Color(0xFF00BFA5) : const Color(0xFFCCCCCC),
                width: selected ? 0 : 2.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1D2335),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF00897B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF757575),
                    height: 1.3,
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
