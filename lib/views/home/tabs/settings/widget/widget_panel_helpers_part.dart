part of '../../settings_tab.dart';

extension _SettingsTabWidgetPanelHelpersPart on _SettingsTabState {
  Widget _buildWidgetSectionCard({
    IconData? icon,
    bool useBrandMarkIcon = false,
    required String title,
    String? subtitle,
    required Widget child,
    List<Color> iconGradient = const [Color(0xFFFF93AE), Color(0xFF57D9E9)],
  }) {
    return WidgetStudioSection(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: iconGradient.first,
      leading: useBrandMarkIcon
          ? ValueListenableBuilder<UiPrefsState>(
              valueListenable: UiPrefs.notifier,
              builder: (context, ui, _) =>
                  SoulLocketBrandMark(styleKey: ui.brandMarkKey, size: 21),
            )
          : null,
      child: child,
    );
  }

  Widget _buildWidgetToggleTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    void toggleValue() => onChanged(!value);

    return Semantics(
      button: true,
      toggled: value,
      label: title,
      hint: subtitle,
      onTap: toggleValue,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: toggleValue,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: value
                  ? accentColor.withValues(alpha: 0.07)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value
                    ? accentColor.withValues(alpha: 0.22)
                    : const Color(0xFFE8EDF3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: value
                        ? accentColor.withValues(alpha: 0.15)
                        : const Color(0xFFEEF2F7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: value ? accentColor : const Color(0xFF94A3B8),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                          color: value
                              ? const Color(0xFF1A2332)
                              : SLColors.textMedium,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: SLTheme.quicksand(
                            fontSize: 11.4,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            height: 1.38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  activeThumbColor: Colors.white,
                  activeTrackColor: accentColor,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCDD5DF),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
