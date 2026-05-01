part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroHeader extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final VoidCallback? onOpenSettings;

  const _MainHomeHeroHeader({
    required this.state,
    required this.isSingle,
    this.onOpenSettings,
  });

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
                  state._hideSettingsButtonUntilRestart || captureMode;
              return IgnorePointer(
                ignoring: hideButton,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: hideButton ? 0 : 1,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: hideButton ? 0.92 : 1,
                    child: state._buildHeaderButton(
                      icon: Icons.settings_rounded,
                      color: SLTheme.primary,
                      onLongPress: state._hideSettingsButtonForSession,
                      onTap: onOpenSettings ??
                          () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsTab(),
                                ),
                              ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (state._showLegacyMessengerButton && !isSingle)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 66,
            child: state._buildHeaderButton(
              icon: Icons.messenger_outline,
              color: const Color(0xFFD81B60),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessengerScreen(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
