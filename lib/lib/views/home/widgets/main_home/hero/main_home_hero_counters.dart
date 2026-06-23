part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroCounters extends StatelessWidget {
  final _MainHomeTabState state;
  final String? startDate;

  const _MainHomeHeroCounters({
    required this.state,
    required this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: state._secondStream,
      builder: (context, snapshot) {
        return _CountersBody(
          state: state,
          startDate: startDate,
        );
      },
    );
  }
}

class _CountersBody extends StatelessWidget {
  final _MainHomeTabState state;
  final String? startDate;

  const _CountersBody({
    required this.state,
    required this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    final showHMS = DateTime.now().second % 6 < 3;

    if (showHMS) {
      final timeDetail = state._getLoveTimeDetail(startDate);
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeCell(value: timeDetail['h']!, label: context.tr('home_gi_770f40')),
              const SizedBox(width: 8),
              _TimeCell(value: timeDetail['m']!, label: context.tr('home_pht_06b001')),
              const SizedBox(width: 8),
              _TimeCell(value: timeDetail['s']!, label: context.tr('home_giy_392758')),
            ],
          ),
        ),
      );
    } else {
      final ymdDetail = state._getLoveYmdDetail(startDate);
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeCell(value: ymdDetail['y']!, label: context.tr('util_nm_923e10').toUpperCase()),
              const SizedBox(width: 8),
              _TimeCell(value: ymdDetail['M']!, label: context.tr('util_thng_59900e').toUpperCase()),
              const SizedBox(width: 8),
              _TimeCell(value: ymdDetail['d']!, label: context.tr('home_ngy_48e4b0')),
            ],
          ),
        ),
      );
    }
  }
}

class _TimeCell extends StatelessWidget {
  final String value;
  final String label;

  const _TimeCell({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
