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
        final timeDetail = state._getLoveTimeDetail(startDate);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              state._buildTimeCell(timeDetail['h']!, context.tr('home_gi_770f40')),
              SLSpacing.w8,
              state._buildTimeCell(timeDetail['m']!, context.tr('home_pht_06b001')),
              SLSpacing.w8,
              state._buildTimeCell(timeDetail['s']!, context.tr('home_giy_392758')),
            ],
          ),
        );
      },
    );
  }
}
