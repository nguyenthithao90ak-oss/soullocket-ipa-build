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
    return const SizedBox.shrink();
  }
}
