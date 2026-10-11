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
    final ymdDetail = state._getLoveYmdDetail(startDate);
    return RelationshipDurationCard(
      years: ymdDetail['y']!,
      months: ymdDetail['M']!,
      days: ymdDetail['d']!,
    );
  }
}
