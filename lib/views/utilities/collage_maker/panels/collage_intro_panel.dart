part of '../../collage_maker_screen.dart';

extension _CollageIntroPanel on _CollageMakerScreenState {
  // ignore: unused_element
  Widget _buildIntroTagRow() {
    final labels = <String>[
      context.tr('util_huyhiustic_c17a85'),
      context.tr('util_giyghich_1aafe3'),
      context.tr('util_bngmm_1e42a6'),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final spacing = compact ? 8.0 : 10.0;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _IntroChip(
                        label: labels[0],
                        centered: true,
                        fixedHeight: 32,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _IntroChip(
                        label: labels[1],
                        centered: true,
                        fixedHeight: 32,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: SizedBox(
                      width: double.infinity,
                      child: _IntroChip(
                        label: labels[2],
                        centered: true,
                        fixedHeight: 32,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: _IntroChip(
                      label: labels[i],
                      centered: true,
                      fixedHeight: 32,
                    ),
                  ),
                ),
                if (i != labels.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8F1), Color(0xFFF4E9DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _paperLine.withValues(alpha: 0.9)),
        boxShadow: _paperShadow(_paperRoseDeep),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _paperRoseDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _paperRoseDeep.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.auto_awesome_mosaic_rounded,
              color: _paperRoseDeep,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('collage_subtitle'),
                  style: SLTheme.quicksand(
                    color: _paperInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr(
                    'ui_utilities_choose_2_to_9_photos_choose_a_a76a0d',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: _paperMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
