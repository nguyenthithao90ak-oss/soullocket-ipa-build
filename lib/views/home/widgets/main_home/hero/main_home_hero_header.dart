part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroHeader extends StatefulWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final VoidCallback? onOpenSettings;
  final GlobalKey? firstGuideSettingsKey;

  const _MainHomeHeroHeader({
    required this.state,
    required this.isSingle,
    this.onOpenSettings,
    this.firstGuideSettingsKey,
  });

  @override
  State<_MainHomeHeroHeader> createState() => _MainHomeHeroHeaderState();
}

class _MainHomeHeroHeaderState extends State<_MainHomeHeroHeader> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 14,
          child: ValueListenableBuilder<bool>(
            valueListenable: UiPrefs.captureModeNotifier,
            builder: (context, captureMode, _) {
              final hideButton =
                  widget.state._hideSettingsButtonUntilRestart || captureMode;
              return IgnorePointer(
                ignoring: captureMode,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: hideButton ? 0.0 : 1.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: hideButton ? 0.92 : 1.0,
                    child: widget.state._buildHeaderButton(
                      key: widget.firstGuideSettingsKey,
                      icon: Icons.settings_rounded,
                      color: SLTheme.primary,
                      onLongPress: widget.state._hideSettingsButtonForSession,
                      onTap: widget.onOpenSettings ??
                          () => Navigator.push(
                                context,
                                SLRoute(
                                  builder: (_) => const SettingsTab(
                                    showGuideOnOpen: true,
                                  ),
                                ),
                              ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.state._showLegacyMessengerButton && !widget.isSingle)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 66,
            child: widget.state._buildHeaderButton(
              icon: Icons.messenger_outline,
              color: const Color(0xFFD81B60),
              onTap: () => Navigator.push(
                context,
                SLRoute(
                  builder: (_) => const MessengerScreen(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
