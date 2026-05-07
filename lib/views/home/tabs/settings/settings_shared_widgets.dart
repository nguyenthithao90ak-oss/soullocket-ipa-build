part of '../settings_tab.dart';
// ignore_for_file: unused_element

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
        ? 'App chưa bật khóa bảo vệ. Bạn nên bật khóa app để phần Cài đặt an toàn hơn.'
        : 'Sinh trắc học chưa được bật. Bạn có thể thêm vân tay hoặc Face ID để xác thực nhanh và an toàn hơn.';

    _markSecurityWarningShownThisSession();

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF9A9A),
          width: 1.2,
        ),
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
                          'Bỏ qua',
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                    final title = Text(
                      'CẢNH BÁO BẢO MẬT',
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
                      children: [Expanded(child: title), dismiss],
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
    final recentHistory = _securityWarningShownHistory
        .where((shownAt) =>
            !shownAt.isAfter(now) &&
            now.difference(shownAt) <=
                const Duration(days: _kSecurityWarnWindowDays))
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
    final recentHistory = rawHistory
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where((shownAt) =>
            !shownAt.isAfter(now) &&
            now.difference(shownAt) <=
                const Duration(days: _kSecurityWarnWindowDays))
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
      _securityWarningShownHistory =
          shouldPermanentlyDisable ? const [] : recentHistory;
      _securityWarningStateLoaded = true;
    });
  }

  Widget _buildHeaderAction(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    List<IconData> accentIcons = const [],
    String? badgeText,
    Widget? footer,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 180;
          final labelMaxLines = isNarrow ? 2 : 1;
          final descMaxLines = isNarrow ? 4 : 3;
          final labelFontSize = isNarrow ? 15.0 : 16.0;
          final descFontSize = isNarrow ? 10.9 : 11.4;
          final iconSize = isNarrow ? 26.0 : 30.0;
          final miniIconSize = isNarrow ? 15.0 : 16.5;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border.withValues(alpha: 0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: textColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12,
                  bottom: -16,
                  child: IgnorePointer(
                    child: Icon(
                      accentIcons.isNotEmpty ? accentIcons.first : icon,
                      size: isNarrow ? 62 : 72,
                      color: textColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 14,
                    isNarrow ? 13 : 15,
                    isNarrow ? 12 : 14,
                    isNarrow ? 13 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isNarrow ? 50 : 58,
                            height: isNarrow ? 50 : 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.96),
                                  Colors.white.withValues(alpha: 0.74),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: textColor.withValues(alpha: 0.14),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: textColor.withValues(alpha: 0.20),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: textColor, size: iconSize),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: accentIcons.take(2).map((item) {
                                return Container(
                                  width: isNarrow ? 26 : 30,
                                  height: isNarrow ? 26 : 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: textColor.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Icon(
                                    item,
                                    color: textColor.withValues(alpha: 0.92),
                                    size: miniIconSize,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label.trim(),
                        textAlign: TextAlign.left,
                        maxLines: labelMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: textColor,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc.trim(),
                        textAlign: TextAlign.left,
                        maxLines: descMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: textColor.withValues(alpha: 0.72),
                          fontSize: descFontSize,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        footer,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {double topPadding = 20}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15, topPadding, 15, 10),
      child: Row(
        children: [
          // Thanh nhấn cạnh trái giúp tiêu đề mục dễ quét bằng mắt.
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD81B60), Color(0xFF9C27B0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFD81B60), Color(0xFF9c27b0), Color(0xFFff4d4d)],
            ).createShader(bounds),
            child: Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String id,
    required String title,
    required Color borderColor,
    required Widget child,
    bool hideBackButton = false,
    Widget? titleBadge,
  }) {
    final isStandalone = Navigator.of(context).canPop();
    final showBack = isStandalone && !hideBackButton;
    final showExpand = !isStandalone;
    return Container(
      // Không padding horizontal để nội dung có thể sát mép màn hình
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showBack) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 16, color: borderColor),
                          const SizedBox(width: 6),
                          Text(
                            'QUAY LẠI',
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: borderColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: borderColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (titleBadge != null) titleBadge,
                    ],
                  ),
                ),
                if (showExpand)
                  GestureDetector(
                    onTap: () => _togglePanel(id),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Divider(
              color: borderColor.withValues(alpha: 0.18),
              height: 1,
              thickness: 1,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF334155),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint,
      {int? maxLength}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        decoration: LegacyWebUi.softInputDecoration(hintText: hint),
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF5F4C58),
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
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 0.5,
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
    required VoidCallback onTap,
  }) {
    final effectiveLabel = icon == Icons.heart_broken
        ? (_isBreakupBusy ? 'Đang xử lý yêu cầu...' : _breakupActionLabel)
        : label;
    const baseSurface = Color(0xFF343A45);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(gradient.first.withValues(alpha: 0.12), baseSurface),
              Color.alphaBlend(gradient.last.withValues(alpha: 0.18), baseSurface),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.32), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradient.first, gradient.last],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradient.first, gradient.last],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.22),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
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
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textColor.withValues(alpha: 0.9),
              size: 13,
            ),
          ],
        ),
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
          if (trailing != null) trailing,
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
//           color: color.withOpacity(0.10),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: color.withOpacity(0.18)),
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
    final tileBg = color.withOpacity(0.08);
    final tileBorder = color.withOpacity(0.22);

    return GestureDetector(
      onTap: onTap ?? () => _showToast('Đang mở...'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tileBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
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
              color: color.withOpacity(0.9),
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
    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFD81B60),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFD81B60).withOpacity(0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value
                  ? const Color(0xFFD81B60).withOpacity(0.2)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
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
                        fontSize: 14,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    if (helperText != null && helperText.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        helperText.trim(),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.4,
                          height: 1.35,
                          color: const Color(0xFF64748B),
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
          color: Colors.white.withOpacity(0.88),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF78A8).withOpacity(0.2),
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
