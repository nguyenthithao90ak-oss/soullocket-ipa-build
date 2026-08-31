part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroCounters extends StatelessWidget {
  final _MainHomeTabState state;
  final String? startDate;

  const _MainHomeHeroCounters({required this.state, required this.startDate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: state._secondStream,
      builder: (context, snapshot) {
        return _CountersBody(state: state, startDate: startDate);
      },
    );
  }
}

class _CountersBody extends StatelessWidget {
  final _MainHomeTabState state;
  final String? startDate;

  const _CountersBody({required this.state, required this.startDate});

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
              _TimeCell(
                value: timeDetail['h']!,
                label: context.tr('home_gi_770f40'),
              ),
              const SizedBox(width: 8),
              _TimeCell(
                value: timeDetail['m']!,
                label: context.tr('home_pht_06b001'),
              ),
              const SizedBox(width: 8),
              _TimeCell(
                value: timeDetail['s']!,
                label: context.tr('home_giy_392758'),
              ),
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
              _TimeCell(
                value: ymdDetail['y']!,
                label: context.tr('util_nm_923e10').toUpperCase(),
              ),
              const SizedBox(width: 8),
              _TimeCell(
                value: ymdDetail['M']!,
                label: context.tr('util_thng_59900e').toUpperCase(),
              ),
              const SizedBox(width: 8),
              _TimeCell(
                value: ymdDetail['d']!,
                label: context.tr('home_ngy_48e4b0'),
              ),
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

  const _TimeCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: BoxDecoration(
        color: SLColors.paper.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SLColors.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: SLColors.thread.withValues(alpha: 0.10),
            blurRadius: 12,
            spreadRadius: -5,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: SLColors.thread.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: SLColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: SLColors.textSecond,
            ),
          ),
        ],
      ),
    );
  }
}
