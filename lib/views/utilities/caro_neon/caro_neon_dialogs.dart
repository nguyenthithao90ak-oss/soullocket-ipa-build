part of '../caro_neon_screen.dart';

class _StartSetupResult {
  const _StartSetupResult({
    required this.winLength,
    this.botStyle,
  });

  final int winLength;
  final _BotStyle? botStyle;
}

class _StartSetupDialog extends StatefulWidget {
  const _StartSetupDialog({
    required this.isBotMode,
    required this.selectedWinLength,
    required this.selectedBotStyle,
    required this.botStyleLabelBuilder,
    required this.botStyleDescriptionBuilder,
  });

  final bool isBotMode;
  final int selectedWinLength;
  final _BotStyle selectedBotStyle;
  final String Function(_BotStyle style) botStyleLabelBuilder;
  final String Function(_BotStyle style) botStyleDescriptionBuilder;

  @override
  State<_StartSetupDialog> createState() => _StartSetupDialogState();
}

class _StartSetupDialogState extends State<_StartSetupDialog> {
  late int _winLength;
  late _BotStyle _botStyle;

  @override
  void initState() {
    super.initState();
    _winLength = widget.selectedWinLength;
    _botStyle = widget.selectedBotStyle;
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.isBotMode ? const Color(0xFFFF5E9E) : const Color(0xFF4EDBFF);
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xF0140A22),
                    Color(0xEE111931),
                    Color(0xF00D0918),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(34),
                ),
                border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 34,
                    spreadRadius: 1,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isBotMode
                                  ? context.tr('util_btuvibotne_db98cc')
                                  : context.tr('util_mbnring_58f533'),
                              style: SLTheme.quicksand(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.isBotMode
                                  ? context.tr('util_chnkiubnvc_c5cf34')
                                  : context.tr('util_chnkiubnri_f50454'),
                              style: SLTheme.quicksand(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD8D2E8),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('util_chnkiubn_6c61c5'),
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StartChoiceCard(
                          label: context.tr('util_3thng_080f34'),
                          caption: context.tr('util_nhanhgndvo_ba02e0'),
                          icon: Icons.grid_3x3_rounded,
                          accent: const Color(0xFF4EDBFF),
                          selected: _winLength == 3,
                          onTap: () => setState(() => _winLength = 3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StartChoiceCard(
                          label: context.tr('util_5thng_5e66bf'),
                          caption: context.tr('util_rnghnnhmth_d19d25'),
                          icon: Icons.grid_4x4_rounded,
                          accent: const Color(0xFFFFB86F),
                          selected: _winLength == 5,
                          onTap: () => setState(() => _winLength = 5),
                        ),
                      ),
                    ],
                  ),
                  if (widget.isBotMode) ...[
                    const SizedBox(height: 18),
                    Text(
                      context.tr('util_chnkiubot_8f6aca'),
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _BotStyle.values
                          .map(
                            (style) => _BotStyleChoiceChip(
                              label: widget.botStyleLabelBuilder(style),
                              caption: widget.botStyleDescriptionBuilder(style),
                              selected: _botStyle == style,
                              accent: style == _BotStyle.gentle
                                  ? const Color(0xFF79E2B0)
                                  : style == _BotStyle.balanced
                                      ? const Color(0xFF4EDBFF)
                                      : const Color(0xFFFF7DA8),
                              onTap: () => setState(() => _botStyle = style),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x161E2435),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x245A6FA6)),
                    ),
                    child: Text(
                      widget.isBotMode
                          ? context.tr('util_bn3cabotcg_346050')
                          : context.tr('util_saukhichnx_967297'),
                      style: SLTheme.quicksand(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE8E2F4),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0x445AF1FF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            context.tr('util_sau_8a3721'),
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(
                              _StartSetupResult(
                                winLength: _winLength,
                                botStyle: widget.isBotMode ? _botStyle : null,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: const Color(0xFF14051A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            context.tr('util_vochi_e0d812'),
                            style: SLTheme.quicksand(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartChoiceCard extends StatelessWidget {
  const _StartChoiceCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? <Color>[
                      accent.withValues(alpha: 0.22),
                      const Color(0xFF130A21),
                    ]
                  : const <Color>[
                      Color(0xAA191126),
                      Color(0xAA0E1426),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? accent : const Color(0x33486888),
              width: 1.3,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD7D1E7),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotStyleChoiceChip extends StatelessWidget {
  const _BotStyleChoiceChip({
    required this.label,
    required this.caption,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color:
                  selected ? accent.withValues(alpha: 0.14) : const Color(0x1B1B2235),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent : const Color(0x33486888),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: SLTheme.quicksand(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD7D1E7),
                    height: 1.4,
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
