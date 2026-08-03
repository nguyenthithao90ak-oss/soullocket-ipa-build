// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownPulseCardExt on _CountdownModeIndependentScreenState {
  int _pulseMetric(int seed, int min, int max) {
    final days = _anchorDate == null
        ? 0
        : DateTime.now().difference(_anchorDate!).inDays;
    final spread = max - min;
    if (spread <= 0) return min;
    final value =
        (days * 7 + DateTime.now().day * 13 + seed * 17) % (spread + 1);
    return min + value;
  }

  // ignore: unused_element
  Widget _buildPulseCard(_CountdownModeThemeData themeData) {
    final subtitleColor = _subtitleColor(themeData);
    final metrics = <({String label, int value, Color color})>[
      (
        label: context.tr('home_mp_84d641'),
        value: _pulseMetric(1, 72, 96),
        color: const Color(0xFFD94C86)
      ),
      (
        label: context.tr('home_ktni_74e82a'),
        value: _pulseMetric(2, 68, 94),
        color: const Color(0xFF4BA7FF)
      ),
      (
        label: context.tr('home_nhnhung_cf22ff'),
        value: _pulseMetric(3, 60, 90),
        color: const Color(0xFF8C7BFF)
      ),
    ];

    return _CountdownSurfaceContainer(
      themeData: themeData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFD94C86),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _singleMode
                      ? context.tr('home_tngquanhmn_0e1b6b')
                      : context.tr('home_hnhtrnhiqu_cbcf59'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: const Color(0xFFD94C86),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _singleMode
                ? context.tr('home_gilikhitng_b1ed7c')
                : context.tr('home_gilikhitng_0bfb93'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final children = metrics
                  .map(
                    (metric) => Container(
                      width: compact ? (constraints.maxWidth - 8) / 2 : null,
                      height: compact ? 104 : 112,
                      margin: EdgeInsets.symmetric(
                        horizontal: compact ? 0 : 4,
                        vertical: compact ? 4 : 0,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 10,
                        12,
                        compact ? 8 : 10,
                        12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: themeData.isDark ? 0.08 : 0.60),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(
                              alpha: themeData.isDark ? 0.12 : 0.82),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: metric.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${metric.value}',
                              style: SLTheme.quicksand(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: metric.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            metric.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: compact ? 10.5 : 11,
                              fontWeight: FontWeight.w800,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList();

              if (!compact) {
                return Row(
                  children:
                      children.map((child) => Expanded(child: child)).toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 0,
                children: children,
              );
            },
          ),
        ],
      ),
    );
  }
}
