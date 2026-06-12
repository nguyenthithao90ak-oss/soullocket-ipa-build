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
        : context.tr('home_sinhtrchcc_9d6c56');

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
    Key? key,
    List<IconData> accentIcons = const [],
    String? badgeText,
    Widget? footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: textColor, size: 26),
                ),
                const SizedBox(width: 16),
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
                            color: const Color(0xFF243041),
                          ),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      color: const Color(0xFF66758A),
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFC1C8D4)),
          ],
        ),
      ),
    )));
  }

  Widget _buildSectionBlock({
    required Widget child,
    required Color colorTint,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorTint.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorTint.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colorTint.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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

  Widget _buildSubCard({
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1.2,
        ),
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
    required Color borderColor,
    required Widget child,
    bool hideBackButton = false,
    Widget? titleBadge,
    bool flatMode = false,
  }) {
    final isStandalone = Navigator.of(context).canPop();
    final showBack = isStandalone && !hideBackButton;
    final showExpand = !isStandalone;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                        border: Border.all(
                            color: borderColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 16, color: borderColor),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('home_quayli_69043b'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: borderColor.withValues(alpha: 0.18),
              height: 1,
              thickness: 1,
            ),
          ),
          Padding(
            padding: flatMode
                ? const EdgeInsets.fromLTRB(10, 8, 10, 12)
                : const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: child,
          ),
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
      {int? maxLength, Color? accentColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        decoration: LegacyWebUi.softInputDecoration(
          hintText: hint,
          accent: accentColor ?? LegacyWebUi.accentPink,
        ),
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
    Color? contentColor,
    required VoidCallback onTap,
  }) {
    final effectiveLabel = icon == Icons.heart_broken
        ? (_isBreakupBusy ? context.tr('home_angxlyucu_0b316c') : _breakupActionLabel)
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
        border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
    final dateLabel =
        _formatPendingAccountDeletionDate(_pendingAccountDeletionAtMs);
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
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFFC62828), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMine ? context.tr('home_tikhonangc_66e7e3') : context.tr('home_nhangcyucu_460ec8'),
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
            'Dự kiến xóa: $dateLabel. ${isMine ? 'Bạn có thể hoàn tác trước thời điểm này.' : context.tr('home_chtikhongi_3eca08')}',
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
                    SLNotice.showInfo(context, context.tr('home_anghontc_b7c262'));
                    await _authService.undoScheduledDeletion();
                    if (!mounted) return;
                    setState(() {
                      _pendingAccountDeletionAtMs = 0;
                      _pendingAccountDeletionUid = '';
                    });
                    SLNotice.showSuccess(context, context.tr('home_hontcxathn_58b732'));
                  } catch (e) {
                    if (!mounted) return;
                    SLNotice.showError(
                      context,
                      AppErrorMapper.resolve(
                        e,
                        fallbackMessage:
                            context.tr('home_chathhontc_cd8493'),
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
    final tileBg = color.withValues(alpha: 0.08);
    final tileBorder = color.withValues(alpha: 0.22);

    return GestureDetector(
      onTap: onTap ?? () => _showToast(context.tr('home_angm_1441cf')),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tileBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                color: color.withValues(alpha: 0.12),
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
    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFD81B60),
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
                ? const Color(0xFFD81B60).withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value
                  ? const Color(0xFFD81B60).withValues(alpha: 0.2)
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
