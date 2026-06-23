part of '../messenger_screen.dart';

extension _MessengerEmptyLoadingPart on _MessengerScreenState {
  Widget _buildMessengerLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFD81B60)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F2F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: const Color(0xFFD81B60)),
            ),
            SLSpacing.h16,
            Text(
              repairMojibakeText(title),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            SLSpacing.h8,
            Text(
              repairMojibakeText(body),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
