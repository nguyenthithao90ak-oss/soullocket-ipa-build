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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFF0E6EA),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2C1B22),
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new_rounded,
                  color: accent,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
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
