part of '../../consent_gate.dart';

Widget _buildStartupConsentHeader(BuildContext context, {required bool compact}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(16, compact ? 14 : 16, 16, 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF2F6FF),
          Color(0xFFFFF4FA),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE4EAF6)),
      boxShadow: [
        BoxShadow(
          color: _accentBlue.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accentBlue.withValues(alpha: 0.16),
                _accentLavender.withValues(alpha: 0.11),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            color: _accentBlue,
            size: 23,
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: _accentBlue,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('consent_thitlpquyn_20c8a7'),
                style: SLTheme.quicksand(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('consent_xemnhanhqu_fd347e'),
                style: SLTheme.quicksand(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  height: 1.32,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildHeaderIcon(BuildContext context, {
  required Color accent,
  required IconData icon,
}) {
  // Responsive scaling based on device pixel ratio
  // Standard baseline is 160 DPI (Android mdpi), scale up/down from there
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final scaleNormalization =
      1.6 / dpr; // Normalize to prevent over-scaling on low-DPI
  final containerSize = (42 * scaleNormalization).clamp(38.0, 46.0);
  final iconSize = (21 * scaleNormalization).clamp(18.0, 24.0);

  return Container(
    width: containerSize,
    height: containerSize,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.18),
          accent.withValues(alpha: 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.22)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: accent, size: iconSize),
  );
}

Widget _buildStartupSectionLabel({
  required String title,
  required String subtitle,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: SLTheme.quicksand(
            fontSize: 12.6,
            fontWeight: FontWeight.w700,
            color: _muted,
            height: 1.30,
          ),
        ),
      ],
    ),
  );
}
