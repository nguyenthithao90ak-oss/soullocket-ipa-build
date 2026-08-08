part of '../../consent_gate.dart';

Widget _buildStartupConsentHeader(BuildContext context,
    {required bool compact}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: SLColors.primary.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SLSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('consent_btuanton_63a99e'),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: _accentBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('consent_thitlpquyn_20c8a7'),
                style: SLTheme.quicksand(
                  fontSize: compact ? 19 : 21,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('consent_xemnhanhqu_fd347e'),
                style: SLTheme.quicksand(
                  fontSize: 13,
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
  );
}

Widget _buildHeaderIcon(
  BuildContext context, {
  required Color accent,
  required IconData icon,
}) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: accent, size: 21),
  );
}

Widget _buildStartupSectionLabel({
  required String title,
  required String subtitle,
}) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: SLTheme.quicksand(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _muted,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}
