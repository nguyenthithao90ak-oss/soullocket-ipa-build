part of '../../consent_gate.dart';

Widget _buildStartupConsentHeader(BuildContext context,
    {required bool compact}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF5277), Color(0xFFFF7597)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF5277).withValues(alpha: 0.25),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        // Badge Icon thu gọn 40x40
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.tr('consent_btuanton_63a99e').toUpperCase(),
                      style: SLTheme.quicksand(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('consent_thitlpquyn_20c8a7'),
                style: SLTheme.quicksand(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('consent_xemnhanhqu_fd347e'),
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.25,
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
