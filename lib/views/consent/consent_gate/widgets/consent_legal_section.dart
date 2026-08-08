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
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
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
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            SLSpacing.w10,
            Expanded(
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
                  const SizedBox(height: 3),
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
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...bullets.take(2).map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: accent.withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bullet,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 2),
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
  return Padding(
    padding: const EdgeInsets.only(left: 46),
    child: GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new_rounded, size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Compact legal row — 1 dòng icon + title + nút xem,
/// phong cách Google consent screen.
Widget _buildCompactLegalRow({
  required Color accent,
  required IconData icon,
  required String title,
  required String actionLabel,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _panelBorder,
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _muted.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

