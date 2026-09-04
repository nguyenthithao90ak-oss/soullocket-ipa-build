part of '../messenger_screen.dart';

extension _MessengerEmptyLoadingPart on _MessengerScreenState {
  Widget _buildMessengerLoadingState() {
    return Center(
      child: SLTheme.softPanel(
        padding: const EdgeInsets.all(20),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: SLColors.primary,
            strokeWidth: 2.8,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SLTheme.softPanel(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [SLColors.primary, SLColors.secondary],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: SLShadow.subtle,
                  ),
                  child: Icon(icon, size: 34, color: Colors.white),
                ),
                SLSpacing.h16,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: SLColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: SLColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
