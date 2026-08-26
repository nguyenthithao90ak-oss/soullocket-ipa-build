part of '../../consent_gate.dart';

Widget _buildStartupScrollHint() {
  return Center(
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _muted.withValues(alpha: 0.7),
        size: 22,
      ),
    ),
  );
}
