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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFEFF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                child: useBrandMarkIcon
                    ? Center(
                        child: ValueListenableBuilder<UiPrefsState>(
                          valueListenable: UiPrefs.notifier,
                          builder: (context, ui, _) => SoulLocketBrandMark(
                            styleKey: ui.brandMarkKey,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 21),
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
                        color: const Color(0xFF1F2A37),
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: SLTheme.quicksand(
                          fontSize: 11.9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF667085),
                          height: 1.42,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: value ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 13.4,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF667085),
                    height: 1.42,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          activeColor: Colors.white,
          activeTrackColor: accentColor,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD9E2EC),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
