part of '../../consent_gate.dart';

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
            const Icon(
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
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7597), Color(0xFFFF5277)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5277).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: verticalPadding ?? (compact ? 11 : 13),
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
  );
}
