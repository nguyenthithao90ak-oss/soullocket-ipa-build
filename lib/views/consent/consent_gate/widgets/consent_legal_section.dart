part of '../../consent_gate.dart';

Widget _buildStartupLegalSection({
  required Color accent,
  required IconData icon,
  required String title,
  required String subtitle,
  required List<String> bullets,
  required String actionLabel,
  required VoidCallback onTap,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
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
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            SLSpacing.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 12.9,
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
        const SizedBox(height: 10),
        ...bullets.take(2).map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: accent.withValues(alpha: 0.85),
                      size: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet,
                        style: SLTheme.quicksand(
                          fontSize: 12.55,
                          fontWeight: FontWeight.w700,
                          color: _ink.withValues(alpha: 0.86),
                          height: 1.26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 4),
        _buildInlineDocLink(accent: accent, label: actionLabel, onTap: onTap),
      ],
    ),
  );
}

Widget _buildInlineDocLink({
  required Color accent,
  required String label,
  required VoidCallback onTap,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(Icons.open_in_new_rounded, size: 14, color: accent),
      label: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
          color: accent,
          height: 1.1,
        ),
      ),
    ),
  );
}
