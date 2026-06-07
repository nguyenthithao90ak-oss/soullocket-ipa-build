part of '../../consent_gate.dart';

Widget _buildStartupScrollHint() {
  return Center(
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        shape: BoxShape.circle,
        border: Border.all(color: _panelBorder.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _accentLavender.withValues(alpha: 0.82),
        size: 26,
      ),
    ),
  );
}
