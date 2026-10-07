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
      return _TimeRow(
        children: [
          _TimeCell(
            companionId: 'home-time-left',
            value: timeDetail['h']!,
            label: context.tr('home_gi_770f40'),
          ),
          const _TimeDivider(),
          _TimeCell(
            companionId: 'home-time-middle',
            value: timeDetail['m']!,
            label: context.tr('home_pht_06b001'),
          ),
          const _TimeDivider(),
          _TimeCell(
            companionId: 'home-time-right',
            value: timeDetail['s']!,
            label: context.tr('home_giy_392758'),
          ),
        ],
      );
    } else {
      final ymdDetail = state._getLoveYmdDetail(startDate);
      return _TimeRow(
        children: [
          _TimeCell(
            companionId: 'home-time-left',
            value: ymdDetail['y']!,
            label: context.tr('util_nm_923e10').toUpperCase(),
          ),
          const _TimeDivider(),
          _TimeCell(
            companionId: 'home-time-middle',
            value: ymdDetail['M']!,
            label: context.tr('util_thng_59900e').toUpperCase(),
          ),
          const _TimeDivider(),
          _TimeCell(
            companionId: 'home-time-right',
            value: ymdDetail['d']!,
            label: context.tr('home_ngy_48e4b0'),
          ),
        ],
      );
    }
  }
}

/// Co lại vừa màn hẹp 320dp hoặc chữ hệ thống lớn, không tràn ngang.
class _TimeRow extends StatelessWidget {
  final List<Widget> children;

  const _TimeRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  final String value;
  final String label;
  final String companionId;

  const _TimeCell({
    required this.value,
    required this.label,
    required this.companionId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    final animate = !MediaQuery.disableAnimationsOf(context);
    return HomeCompanionAnchor(
      id: companionId,
      shape: HomeCompanionSurfaceShape.outline,
      border: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 78),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.paper, palette.blush.withValues(alpha: .85)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: palette.border.withValues(alpha: .8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.rose.withValues(alpha: .14),
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Số đổi mượt nhưng chỉ đọc giá trị mới cho trình đọc màn hình.
            AnimatedSwitcher(
              duration: animate
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .28),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              ),
              child: ShaderMask(
                key: ValueKey(value),
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.numberColors,
                ).createShader(bounds),
                child: Text(
                  value,
                  style:
                      SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                        fontSize: 27,
                        height: 1.05,
                        color: palette.rose,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: .6,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dấu hai chấm nhỏ giữa các ô, chỉ để trang trí.
class _TimeDivider extends StatelessWidget {
  const _TimeDivider();

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    Widget dot() => Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: palette.rose.withValues(alpha: .45),
        shape: BoxShape.circle,
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [dot(), const SizedBox(height: 6), dot()],
        ),
      ),
    );
  }
}
