part of '../../consent_gate.dart';

Widget _buildStartupAcknowledgement(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_circle_rounded,
              color: _accentLavender, size: 18),
        ),
        SLSpacing.w8,
        Expanded(
          child: Text(
            context.tr('consent_khinhnvoap_7418c8'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStartupAgreeBar(
  BuildContext context, {
  required bool compact,
  required double bottomInset,
  required String cookieLevel,
  required VoidCallback onConfirm,
}) {
  final storageLabel = cookieLevel == 'essential'
      ? context.tr('consent_lutrthityu_2d2969')
      : context.tr('consent_lutry_ea3cfa');

  return Container(
    padding: EdgeInsets.fromLTRB(
      4,
      8,
      4,
      bottomInset > 0 ? bottomInset + 8 : 10,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: _accentGreen,
              size: 16,
            ),
            SLSpacing.w8,
            Expanded(
              child: Text(
                storageLabel,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Text(
              context.tr('consent_cthisau_73e33d'),
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildPrimaryButton(
          context,
          accent: _accentBlue,
          label: context.tr('consent_ngvvoapp_93cd33'),
          scaleDownContent: true,
          fontSize: 15,
          verticalPadding: 13,
          onTap: onConfirm,
        ),
      ],
    ),
  );
}

Widget _buildPrimaryButton(
  BuildContext context, {
  required Color accent,
  required String label,
  required VoidCallback? onTap,
  IconData? icon,
  bool scaleDownContent = false,
  bool compact = false,
  double fontSize = 13.5,
  double? verticalPadding,
}) {
  final enabled = onTap != null;

  return Opacity(
    opacity: enabled ? 1 : 0.45,
    child: SizedBox(
      width: double.infinity,
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: verticalPadding ?? (compact ? 10 : 12),
            ),
            child: FittedBox(
              fit: scaleDownContent ? BoxFit.scaleDown : BoxFit.none,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 17),
                    SLSpacing.w8,
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
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
  );
}

Widget _buildRequiredConsentHint(
  BuildContext context, {
  required Color accent,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: accent, size: 16),
        SLSpacing.w8,
        Expanded(
          child: Text(
            context.tr('consent_bncnngtipt_207123'),
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _ink.withValues(alpha: 0.85),
              height: 1.30,
            ),
          ),
        ),
      ],
    ),
  );
}
