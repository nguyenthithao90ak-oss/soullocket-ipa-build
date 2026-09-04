// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

extension _SettingsTabSharedWidgets on _SettingsTabState {
  // Key để lưu thời điểm bỏ qua cảnh báo bảo mật
  static const String _kSecurityWarnDismissedKey =
      'il_security_warning_dismissed_at';
  static const String _kSecurityWarnDisabledKey =
      'il_security_warning_disabled';
  static const String _kSecurityWarnShownHistoryKey =
      'il_security_warning_shown_history';

  // Số ngày giữa các lần hiển thị lại cảnh báo
  static const int _kSecurityWarnWindowDays = 7;

  Widget _buildSecurityWarningCard() {
    if (!_appLockSettingsLoaded || !_securityWarningStateLoaded) {
      return const SizedBox.shrink();
    }
    if (_securityWarningDisabled) {
      return const SizedBox.shrink();
    }

    final bool showWarning = !_isAppLockEnabled || !_useBiometrics;
    if (!showWarning) {
      return const SizedBox.shrink();
    }

    // Throttle: nếu đã bị bỏ qua trong vòng 2 ngày thì ẩn đi
    final now = DateTime.now();
    if (!_shouldShowSecurityWarning(now)) {
      return const SizedBox.shrink();
    }

    final String message = !_isAppLockEnabled
        ? context.tr('settings_app_lock_warning')
        : context.tr('home_sinhtrchcc_9d6c56');

    _markSecurityWarningShownThisSession();

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF9A9A), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 220;
                    final dismiss = GestureDetector(
                      onTap: _dismissSecurityWarning,
                      child: Padding(
                        padding: EdgeInsets.only(left: stacked ? 0 : 8),
                        child: Text(
                          context.tr('home_bqua_a3b533'),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                    final title = Text(
                      context.tr('home_cnhbobomt_a092b6'),
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFC62828),
                      ),
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 4), dismiss],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        dismiss,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: const Color(0xFF5F2120),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Skip the security warning when it has already been shown recently.
  bool _shouldShowSecurityWarning(DateTime now) {
    if (_securityWarningDismissedUntil != null &&
        now.isBefore(_securityWarningDismissedUntil!)) {
      return false;
    }

    final recentHistory = _pruneSecurityWarningHistory(now);
    if (recentHistory.isNotEmpty &&
        now.difference(recentHistory.last) <
            const Duration(days: _kSecurityWarnWindowDays)) {
      return false;
    }

    return true;
  }

  List<DateTime> _pruneSecurityWarningHistory(DateTime now) {
    final recentHistory =
        _securityWarningShownHistory
            .where(
              (shownAt) =>
                  !shownAt.isAfter(now) &&
                  now.difference(shownAt) <=
                      const Duration(days: _kSecurityWarnWindowDays),
            )
            .toList()
          ..sort();
    return recentHistory;
  }

  void _markSecurityWarningShownThisSession() {
    final now = DateTime.now();
    _securityWarningShownHistory = [..._pruneSecurityWarningHistory(now), now]
      ..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recordSecurityWarningImpression());
    });
  }

  Future<void> _recordSecurityWarningImpression() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSecurityWarnShownHistoryKey,
      _securityWarningShownHistory
          .map((shownAt) => shownAt.toIso8601String())
          .toList(),
    );
  }

  Future<void> _dismissSecurityWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSecurityWarnDisabledKey, true);
    await prefs.remove(_kSecurityWarnDismissedKey);
    await prefs.remove(_kSecurityWarnShownHistoryKey);
    if (!mounted) return;
    setState(() {
      _securityWarningDisabled = true;
      _securityWarningDismissedUntil = null;
      _securityWarningShownHistory = const [];
    });
  }

  /// Load trạng thái bỏ qua cảnh báo bảo mật từ SharedPreferences.
  Future<void> _loadSecurityWarningDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDismissed = prefs.getString(_kSecurityWarnDismissedKey);
    final disabledFromPrefs = prefs.getBool(_kSecurityWarnDisabledKey) ?? false;
    final shouldPermanentlyDisable = disabledFromPrefs || rawDismissed != null;
    final rawHistory = prefs.getStringList(_kSecurityWarnShownHistoryKey) ?? [];
    final now = DateTime.now();
    final until = rawDismissed == null ? null : DateTime.tryParse(rawDismissed);
    final recentHistory =
        rawHistory
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .where(
              (shownAt) =>
                  !shownAt.isAfter(now) &&
                  now.difference(shownAt) <=
                      const Duration(days: _kSecurityWarnWindowDays),
            )
            .toList()
          ..sort();

    if (recentHistory.length != rawHistory.length) {
      await prefs.setStringList(
        _kSecurityWarnShownHistoryKey,
        recentHistory.map((shownAt) => shownAt.toIso8601String()).toList(),
      );
    }

    if (shouldPermanentlyDisable && !disabledFromPrefs) {
      await prefs.setBool(_kSecurityWarnDisabledKey, true);
      await prefs.remove(_kSecurityWarnDismissedKey);
      await prefs.remove(_kSecurityWarnShownHistoryKey);
    }

    if (!mounted) return;
    setState(() {
      _securityWarningDisabled = shouldPermanentlyDisable;
      _securityWarningDismissedUntil = shouldPermanentlyDisable ? null : until;
      _securityWarningShownHistory = shouldPermanentlyDisable
          ? const []
          : recentHistory;
      _securityWarningStateLoaded = true;
    });
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kSettingsHeaderSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kSettingsHeaderBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFFF78A8), size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required IconData icon,
    required String label,
    required String desc,
    required List<Color> gradient,
    required Color border,
    required Color textColor,
    required VoidCallback onTap,
    Key? key,
    String? badgeText,
    Widget? footer,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    final accent = gradient.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282128) : SLColors.paper,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : border.withValues(alpha: 0.36),
          width: 1.15,
        ),
        boxShadow: isDark ? null : SLShadow.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.11),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(icon, color: accent, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: SLTheme.quicksand(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : SLColors.ink,
                              ),
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: SLTheme.quicksand(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey[500]
                              : SLColors.textSecond,
                          height: 1.3,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        footer,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: accent.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBlock({
    required Widget child,
    required Color colorTint,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282128) : SLColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : colorTint.withValues(alpha: 0.22),
        ),
        boxShadow: isDark ? null : SLShadow.subtle,
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, {double topPadding = 20}) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    return Padding(
      padding: EdgeInsets.fromLTRB(18, topPadding, 18, 9),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? SLColors.primary.withValues(alpha: 0.2)
                  : SLColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 13,
              color: SLColors.primary,
            ),
          ),
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : SLColors.ink,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SLColors.thread.withValues(alpha: isDark ? 0.4 : 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCard({
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark ? const Color(0xFF2C252D) : SLColors.bgSubtle),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? Colors.white.withValues(alpha: 0.10) : SLColors.border),
          width: 1.05,
        ),
        boxShadow: isDark ? null : SLShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildPanel({
    required String id,
    required String title,
    Color? borderColor,
    required Widget child,
    bool hideBackButton = false,
    Widget? titleBadge,
    bool flatMode = false,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    final isStandalone = Navigator.of(context).canPop();
    final showBack = isStandalone && !hideBackButton;
    final showExpand = !isStandalone;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final isMobile = shortestSide < 600;

    final margin = flatMode
        ? const EdgeInsets.symmetric(horizontal: 0, vertical: 0)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    final borderRadius = BorderRadius.circular(26);
    final accent = borderColor ?? SLColors.thread;

    final border = flatMode
        ? null
        : Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : accent.withValues(alpha: 0.24),
            width: 1.15,
          );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211A20) : SLColors.paper,
        borderRadius: borderRadius,
        border: border,
        boxShadow: flatMode
            ? null
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : SLColors.ink.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.34 : 0.18),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                if (showBack) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 11),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.20)),
                  ),
                  child: Icon(Icons.favorite_rounded, size: 18, color: accent),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: SLTheme.textStyleForKey(
                          'dancingScript',
                          fontSize: isMobile ? 21 : 23,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : SLColors.ink,
                          height: 1.05,
                        ),
                      ),
                      ?titleBadge,
                    ],
                  ),
                ),
                if (showExpand)
                  InkWell(
                    onTap: () => _togglePanel(id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: accent),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
              height: 1,
              thickness: 1,
            ),
          ),
          Padding(
            padding: flatMode
                ? const EdgeInsets.fromLTRB(10, 10, 10, 14)
                : const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 9, left: 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: SLColors.thread,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? SLColors.darkTextPrimary : SLColors.ink,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint, {
    int? maxLength,
    Color? accentColor,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    final accent = accentColor ?? SLColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        decoration: InputDecoration(
          hintText: hint,
          counterStyle: SLTheme.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? SLColors.darkTextSecond : SLColors.textTertiary,
          ),
          hintStyle: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? SLColors.darkTextSecond : SLColors.textTertiary,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF211A20) : SLColors.paper,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : SLColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
        ),
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? SLColors.darkTextPrimary : SLColors.ink,
        ),
      ),
    );
  }

  Widget _buildGradientBtn({
    required String label,
    required List<Color> gradient,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required Color textColor,
    Color? contentColor,
    required VoidCallback onTap,
  }) {
    final effectiveLabel = icon == Icons.heart_broken
        ? (_isBreakupBusy
              ? context.tr('home_angxlyucu_0b316c')
              : _breakupActionLabel)
        : label;
    final color = contentColor ?? Colors.white;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      effectiveLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color.withValues(alpha: 0.8),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingAccountDeletionCard() {
    if (_pendingAccountDeletionAtMs <= 0) return const SizedBox.shrink();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMine = _pendingAccountDeletionUid == currentUid;
    final dateLabel = _formatPendingAccountDeletionDate(
      _pendingAccountDeletionAtMs,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFFC62828),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMine
                      ? context.tr('home_tikhonangc_66e7e3')
                      : context.tr('home_nhangcyucu_460ec8'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            L10nService().format(
              isMine
                  ? 'settings_delete_scheduled_mine'
                  : 'settings_delete_scheduled_partner',
              {
                'date': dateLabel,
                'detail': context.tr('home_chtikhongi_3eca08'),
              },
            ),
            style: SLTheme.quicksand(
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: const Color(0xFF6B2B2B),
            ),
          ),
          if (isMine) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    SLNotice.showInfo(
                      context,
                      context.tr('home_anghontc_b7c262'),
                    );
                    await _authService.undoScheduledDeletion();
                    if (!mounted) return;
                    setState(() {
                      _pendingAccountDeletionAtMs = 0;
                      _pendingAccountDeletionUid = '';
                    });
                    SLNotice.showSuccess(
                      context,
                      context.tr('home_hontcxathn_58b732'),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    SLNotice.showError(
                      context,
                      AppErrorMapper.resolve(
                        e,
                        fallbackMessage: context.tr('home_chathhontc_cd8493'),
                      ).message,
                    );
                  }
                },
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: Text(
                  context.tr('home_hontc_96ce27'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityLine({
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$label:',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF6D4C41),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: valueColor ?? const Color(0xFF424242),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  //   Widget _buildMiniSecurityAction({
  //     required IconData icon,
  //     required String label,
  //     required Color color,
  //     required VoidCallback onTap,
  //   }) {
  //     return GestureDetector(
  //       onTap: onTap,
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //         decoration: BoxDecoration(
  //           color: color.withValues(alpha: 0.10),
  //           borderRadius: BorderRadius.circular(14),
  //           border: Border.all(color: color.withValues(alpha: 0.18)),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(icon, size: 18, color: color),
  //             const SizedBox(width: 8),
  //             Flexible(
  //               child: Text(
  //                 label,
  //                 style: SLTheme.quicksand(
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w900,
  //                   color: color,
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }

  Widget _buildLegalBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final tileBg = Color.alphaBlend(
      color.withValues(alpha: 0.045),
      SLColors.paper,
    );
    final tileBorder = color.withValues(alpha: 0.22);

    return GestureDetector(
      onTap: onTap ?? () => _showToast(context.tr('home_angm_1441cf')),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tileBorder),
          boxShadow: SLShadow.subtle,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: _kSettingsActionTileText,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              color: color.withValues(alpha: 0.9),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? helperText,
    VoidCallback? onTap,
    bool ignoreDirectSwitchTap = false,
  }) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: SLColors.primary,
      inactiveTrackColor: isDark
          ? const Color(0xFF39393D)
          : const Color(0xFFE9E9EB),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282128) : SLColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : SLColors.border,
              width: 1.0,
            ),
            boxShadow: isDark ? null : SLShadow.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : SLColors.ink,
                      ),
                    ),
                    if (helperText != null && helperText.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        helperText.trim(),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.35,
                          color: isDark
                              ? Colors.grey[500]
                              : SLColors.textSecond,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ignoreDirectSwitchTap)
                IgnorePointer(child: switchWidget)
              else
                switchWidget,
            ],
          ),
        ),
      ),
    );
  }

  /// Renders một dòng bước hướng dẫn có số thứ tự tròn màu hồng
  Widget _buildStepRow(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFD81B60),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5F4C58),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SparkleBetaBadge extends StatelessWidget {
  const _SparkleBetaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3B0), Color(0xFFFF78A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF78A8).withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 0.2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 10,
            color: Color(0xFF8EBBFF),
          ),
          const SizedBox(width: 4),
          Text(
            'BETA',
            style: SLTheme.quicksand(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: const Color(0xFF7FB3FF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget compact row cho toggle (Switch/Checkbox) bên trong các card cài đặt.
/// Thay thế layout Container dài dòng cũ: chỉ icon + label + control.
class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  // Switch
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  // Checkbox
  final bool useCheckbox;
  final bool? checkValue;
  final ValueChanged<bool?>? onCheckChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.switchValue,
    this.onSwitchChanged,
    this.useCheckbox = false,
    this.checkValue,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282128) : SLColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : SLColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: iconColor.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? SLColors.darkTextPrimary : SLColors.ink,
              ),
            ),
          ),
          if (useCheckbox)
            Checkbox(
              value: checkValue ?? false,
              activeColor: iconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              onChanged: onCheckChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )
          else
            Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                value: switchValue ?? false,
                activeThumbColor: iconColor,
                onChanged: onSwitchChanged,
              ),
            ),
        ],
      ),
    );
  }
}
