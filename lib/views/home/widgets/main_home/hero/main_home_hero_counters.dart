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
              state._buildTimeCell(timeDetail['h']!, 'GIỜ'),
              SLSpacing.w8,
              state._buildTimeCell(timeDetail['m']!, 'PHÚT'),
              SLSpacing.w8,
              state._buildTimeCell(timeDetail['s']!, 'GIÂY'),
            ],
          ),
        );
      },
    );
  }
}
