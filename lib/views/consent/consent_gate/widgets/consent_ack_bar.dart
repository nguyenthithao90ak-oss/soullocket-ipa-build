part of '../../consent_gate.dart';

Widget _buildStartupAcknowledgement(BuildContext context) {
  return Container(
    padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
    decoration: BoxDecoration(
      color: _accentLavender.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border:
          Border.all(color: _accentLavender.withValues(alpha: 0.24), width: 1.3),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: _accentLavender, size: 24),
        SLSpacing.w12,
        Expanded(
          child: Text(
            context.tr('consent_khinhnvoap_7418c8'),
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _ink.withValues(alpha: 0.9),
              height: 1.30,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStartupAgreeBar(BuildContext context, {
  required bool compact,
  required double bottomInset,
  required String cookieLevel,
  required VoidCallback onConfirm,
}) {
  final storageLabel =
      cookieLevel == 'essential' ? context.tr('consent_lutrthityu_2d2969') : context.tr('consent_lutry_ea3cfa');

  return Container(
    padding: EdgeInsets.fromLTRB(
      0,
      10,
      0,
      bottomInset > 0 ? bottomInset + 10 : 12,
    ),
    decoration: const BoxDecoration(
      color: Colors.transparent,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _accentGreen,
                size: 18,
              ),
            ),
            SLSpacing.w8,
            Expanded(
              child: Text(
                storageLabel,
                style: SLTheme.quicksand(
                  fontSize: 12.4,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            Text(
              context.tr('consent_cthisau_73e33d'),
              style: SLTheme.quicksand(
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _buildPrimaryButton(context,
          accent: _accentBlue,
          label: context.tr('consent_ngvvoapp_93cd33'),
          scaleDownContent: true,
          fontSize: 15.5,
          verticalPadding: 14,
          onTap: onConfirm,
        ),
      ],
    ),
  );
}

Widget _buildPrimaryButton(BuildContext context, {
  required Color accent,
  required String label,
  required VoidCallback? onTap,
  IconData? icon,
  bool scaleDownContent = false,
  bool compact = false,
  double fontSize = 13.8,
  double? verticalPadding,
}) {
  final enabled = onTap != null;
  final endColor = Color.lerp(accent, Colors.black, 0.12) ?? accent;
  // Responsive scaling for button icons
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final buttonIconSize = (18 * (1.6 / dpr)).clamp(16.0, 20.0);

  return Opacity(
    opacity: enabled ? 1 : 0.56,
    child: SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, endColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 18,
                vertical: verticalPadding ?? (compact ? 10 : 13),
              ),
              child: FittedBox(
                fit: scaleDownContent ? BoxFit.scaleDown : BoxFit.none,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: buttonIconSize),
                      SLSpacing.w8,
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildRequiredConsentHint(BuildContext context, {
  required Color accent,
}) {
  // Responsive scaling for hint icon
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final hintIconSize = (18 * (1.6 / dpr)).clamp(16.0, 20.0);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.16)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: accent,
          size: hintIconSize,
        ),
        SLSpacing.w8,
        Expanded(
          child: Text(
            context.tr('consent_bncnngtipt_207123'),
            style: SLTheme.quicksand(
              fontSize: 11.6,
              fontWeight: FontWeight.w800,
              color: _ink.withValues(alpha: 0.92),
              height: 1.26,
            ),
          ),
        ),
      ],
    ),
  );
}
