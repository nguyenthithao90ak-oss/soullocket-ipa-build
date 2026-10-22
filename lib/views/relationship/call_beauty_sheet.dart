import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';

class CallBeautySheet extends StatefulWidget {
  const CallBeautySheet({
    super.key,
    required this.amount,
    required this.onApply,
  });
  final double amount;
  final Future<void> Function(double amount) onApply;

  @override
  State<CallBeautySheet> createState() => _CallBeautySheetState();
}

class _CallBeautySheetState extends State<CallBeautySheet> {
  late double _amount = widget.amount;
  late double _applied = widget.amount;
  bool _saving = false;
  bool _error = false;

  Future<void> _apply(double amount) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = false;
      _amount = amount;
    });
    try {
      await widget.onApply(amount);
      if (mounted) setState(() => _applied = amount);
    } catch (_) {
      if (mounted) {
        setState(() {
          _amount = _applied;
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('call_beauty'),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('core_close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          Text(
            context.tr('call_beauty_hint'),
            style: SLTheme.quicksand(
              color: const Color(0xFFC1BED2),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _choice(
                context,
                key: const ValueKey('beauty-original'),
                icon: Icons.face_outlined,
                label: context.tr('call_beauty_original'),
                selected: _applied == 0,
                onTap: () => _apply(0),
              ),
              const SizedBox(width: 12),
              _choice(
                context,
                key: const ValueKey('beauty-brighten'),
                icon: Icons.auto_awesome_rounded,
                label: context.tr('call_beauty_skin'),
                selected: _applied > 0,
                onTap: () => _apply(0.45),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('call_beauty_intensity'),
                  style: SLTheme.quicksand(color: Colors.white70, fontSize: 13),
                ),
              ),
              Text(
                '${(_amount * 100).round()}%',
                style: SLTheme.quicksand(
                  color: const Color(0xFFE5B9CC),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('beauty-intensity'),
            value: _amount,
            divisions: 20,
            activeColor: const Color(0xFFE5B9CC),
            inactiveColor: Colors.white12,
            semanticFormatterCallback: (v) => '${(v * 100).round()}%',
            onChanged: _saving
                ? null
                : (value) => setState(() => _amount = value),
            onChangeEnd: _saving ? null : _apply,
          ),
          if (_saving) const LinearProgressIndicator(color: Color(0xFFE5B9CC)),
          if (_error)
            Text(
              context.tr('call_beauty_unavailable'),
              style: const TextStyle(color: Color(0xFFFFB3B3)),
            ),
        ],
      ),
    ),
  );

  Widget _choice(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: OutlinedButton(
      key: key,
      onPressed: _saving ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? const Color(0xFF242438) : Colors.white70,
        backgroundColor: selected
            ? const Color(0xFFE5B9CC)
            : Colors.white.withValues(alpha: 0.04),
        side: BorderSide(
          color: selected ? const Color(0xFFE5B9CC) : Colors.white12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
