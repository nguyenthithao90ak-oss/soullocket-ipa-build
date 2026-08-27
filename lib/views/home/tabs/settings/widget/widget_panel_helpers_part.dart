part of '../../settings_tab.dart';

extension _SettingsTabWidgetPanelHelpersPart on _SettingsTabState {
  Widget _buildWidgetSectionCard({
    IconData? icon,
    bool useBrandMarkIcon = false,
    required String title,
    String? subtitle,
    required Widget child,
    List<Color> iconGradient = const [
      Color(0xFFFF93AE),
      Color(0xFF57D9E9),
    ],
  }) {
    final accentColor = iconGradient.first;
    final secondaryAccent = iconGradient.last;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.15), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: secondaryAccent.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip with decorative elements
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconGradient.first.withValues(alpha: 0.09),
                    iconGradient.last.withValues(alpha: 0.04),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Decorative floating dots
                  Positioned(
                    top: -2,
                    right: 8,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 20,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secondaryAccent.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 32,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Main header content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: iconGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: iconGradient.first.withValues(alpha: 0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: useBrandMarkIcon
                            ? Center(
                                child: ValueListenableBuilder<UiPrefsState>(
                                  valueListenable: UiPrefs.notifier,
                                  builder: (context, ui, _) =>
                                      SoulLocketBrandMark(
                                    styleKey: ui.brandMarkKey,
                                    size: 22,
                                  ),
                                ),
                              )
                            : Icon(icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: SLTheme.quicksand(
                                fontSize: 14.2,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1A2332),
                              ),
                            ),
                            if (subtitle != null &&
                                subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: SLTheme.quicksand(
                                  fontSize: 11.6,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF667085),
                                  height: 1.38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Gradient accent line
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.25),
                    secondaryAccent.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: child,
            ),
          ],
        ),
      ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
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
    );
  }
}
