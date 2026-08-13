part of '../../main_home_tab.dart';

class _CountdownQuickCustomizeSheetContent extends StatefulWidget {
  final List<_CountdownQuickOption> styleOptions;
  final Set<String> unlockedStyles;
  final bool isVip;
  final _MainHomeTabState homeState;
  final BuildContext sheetContext;

  const _CountdownQuickCustomizeSheetContent({
    required this.styleOptions,
    required this.unlockedStyles,
    required this.isVip,
    required this.homeState,
    required this.sheetContext,
  });

  @override
  State<_CountdownQuickCustomizeSheetContent> createState() =>
      _CountdownQuickCustomizeSheetContentState();
}

class _CountdownQuickCustomizeSheetContentState
    extends State<_CountdownQuickCustomizeSheetContent> {
  double? _tempCountdownSize;
  bool _isUploadingBg = false;
  double? _bgUploadProgress;
  String? _unlockingStyleKey;
  late Set<String> _unlockedStyles;

  @override
  void initState() {
    super.initState();
    _unlockedStyles = Set<String>.from(widget.unlockedStyles);
  }

  Widget buildOptionChip({
    required _CountdownQuickOption option,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = option.accent;
    final borderColor = selected ? accent : accent.withValues(alpha: 0.28);
    final backgroundColor =
        selected ? accent.withValues(alpha: 0.14) : Colors.white;
    final textColor = selected ? accent : const Color(0xFF584450);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: SLTheme.quicksand(
                  fontSize: 12.6,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLockedAdButton({
    required _CountdownQuickOption option,
    required Future<void> Function(_CountdownQuickOption option) onUnlocked,
  }) {
    final isThisUnlocking = _unlockingStyleKey == option.value;
    final accent = option.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isThisUnlocking
            ? null
            : () async {
                if (_unlockingStyleKey != null) return;
                HapticFeedback.mediumImpact();
                setState(() {
                  _unlockingStyleKey = option.value;
                });
                try {
                  final adMob = AdMobService();
                  final adSuccess = await adMob.showRewardedAd();
                  if (!mounted) return;
                  if (adSuccess) {
                    final prefs = await SharedPreferences.getInstance();
                    final now = DateTime.now().millisecondsSinceEpoch;
                    await prefs.setInt('il_last_any_rewarded_ad_ts', now);
                    final expiry = now +
                        _MainHomeTabState
                            ._kCountdownQuickUnlockWindow.inMilliseconds;
                    final expiryKey =
                        'il_countdown_style_unlock_expiry_${option.value}';
                    await prefs.setInt(expiryKey, expiry);
                    setState(() {
                      _unlockedStyles = {..._unlockedStyles, option.value};
                    });
                    await onUnlocked(option);
                    widget.homeState._showLatestSnackBar(
                        'Đã mở khóa "${option.label}" trong 5 tiếng!');
                  } else {
                    widget.homeState._showLatestSnackBar(
                        'Chưa mở khóa. Vui lòng xem hết quảng cáo.');
                  }
                } catch (_) {
                  widget.homeState
                      ._showLatestSnackBar('Đã xảy ra lỗi khi tải quảng cáo.');
                } finally {
                  if (mounted) {
                    setState(() {
                      _unlockingStyleKey = null;
                    });
                  }
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              if (isThisUnlocking)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              else
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 22,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLockedVipButton({
    required _CountdownQuickOption option,
  }) {
    final accent = option.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        HapticFeedback.mediumImpact();
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.diamond_rounded, size: 36, color: accent),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Đặc quyền VIP 💎',
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2D1B24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Giao diện "${option.label}" là đặc quyền dành riêng cho tài khoản VIP.\nVui lòng nâng cấp VIP để trải nghiệm tính năng này 💕',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A6472),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Đã hiểu',
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.diamond_rounded,
              size: 22,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection({
    required String title,
    required String description,
    required IconData icon,
    required List<_CountdownQuickOption> options,
    required String selectedValue,
    required Future<void> Function(_CountdownQuickOption option) onSelect,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final isLocked =
                  option.isPremium && !_unlockedStyles.contains(option.value);
              if (isLocked) {
                return buildLockedAdButton(
                  option: option,
                  onUnlocked: (opt) async {
                    HapticFeedback.selectionClick();
                    await onSelect(opt);
                  },
                );
              }
              return buildOptionChip(
                option: option,
                selected: selectedValue == option.value,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await onSelect(option);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildCollapsedSection({
    required String title,
    required String description,
    required IconData icon,
    required List<_CountdownQuickOption> options,
    required String selectedValue,
    required Future<void> Function(_CountdownQuickOption option) onSelect,
  }) {
    final selectedOption = options.firstWhere(
      (o) => o.value == selectedValue,
      orElse: () => options.first,
    );
    final accent = selectedOption.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.8),
                      accent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2D1B24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6472),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                _showOptionsDialog(title, options, selectedValue, onSelect);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedOption.icon,
                      color: accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Đang dùng: ',
                              style: SLTheme.quicksand(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7A6472),
                              ),
                            ),
                            TextSpan(
                              text: selectedOption.label,
                              style: SLTheme.quicksand(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: accent,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(
    String title,
    List<_CountdownQuickOption> options,
    String selectedValue,
    Future<void> Function(_CountdownQuickOption option) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: EdgeInsets.fromLTRB(
                  12, 0, 12, max(MediaQuery.of(context).padding.bottom, 12.0)),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: options.map((option) {
                            final isVipLocked =
                                option.isVipOnly && !widget.isVip;
                            final isAdLocked = option.isPremium &&
                                !_unlockedStyles.contains(option.value);

                            Widget button;
                            if (isVipLocked) {
                              button = buildLockedVipButton(option: option);
                            } else if (isAdLocked) {
                              button = buildLockedAdButton(
                                option: option,
                                onUnlocked: (opt) async {
                                  HapticFeedback.selectionClick();
                                  await onSelect(opt);
                                  setModalState(() {
                                    selectedValue = opt.value;
                                  });
                                  setState(() {});
                                },
                              );
                            } else {
                              button = buildOptionChip(
                                option: option,
                                selected: selectedValue == option.value,
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  await onSelect(option);
                                  setModalState(() {
                                    selectedValue = option.value;
                                  });
                                  setState(() {});
                                },
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: button,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Đóng',
                          style: SLTheme.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF806575),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildTextColorSection({
    required String selectedColorHex,
    required Future<void> Function(String hex) onSelect,
  }) {
    final colors = [
      '', // Mặc định
      '#MULTI', // Dải màu đa sắc
      '#FFFFFF', // Trắng
      '#000000', // Đen
      '#F44336', // Đỏ
      '#E91E63', // Hồng
      '#9C27B0', // Tím
      '#673AB7', // Tím đậm
      '#3F51B5', // Xanh chàm
      '#2196F3', // Xanh dương
      '#00BCD4', // Xanh ngọc
      '#4CAF50', // Xanh lá
      '#FFEB3B', // Vàng
      '#FF9800', // Cam
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4B2B).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.format_color_text_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Màu chữ vòng đếm',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thay đổi màu sắc nhãn và số ngày yêu.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((hex) {
                final isSelected = selectedColorHex == hex;
                final isDefault = hex.isEmpty;
                final isMulti = hex == '#MULTI';
                final color = isDefault || isMulti
                    ? Colors.transparent
                    : Color(int.parse(hex.replaceFirst('#', '0xFF')));

                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await onSelect(hex);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      gradient: isMulti
                          ? const SweepGradient(
                              colors: [
                                Color(0xFF00C6FF),
                                Color(0xFF9D50BB),
                                Color(0xFFF44336),
                                Color(0xFF00C6FF)
                              ],
                            )
                          : null,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD81B60)
                            : const Color(0xFFF0DDE4),
                        width: isSelected ? 3.0 : 1.5,
                      ),
                    ),
                    child: isDefault
                        ? Icon(Icons.format_color_reset_rounded,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFFD81B60)
                                : const Color(0xFF8E6F7E))
                        : (isMulti
                            ? (isSelected
                                ? const Icon(Icons.check_rounded,
                                    size: 20, color: Colors.white)
                                : null)
                            : (isSelected
                                ? Icon(Icons.check_rounded,
                                    size: 20,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white)
                                : null)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSizeSection({
    required String title,
    required String description,
    required IconData icon,
    required double currentValue,
    required double? tempValue,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangedEnd,
    required VoidCallback onSave,
    required String? customBgUrl,
  }) {
    final displayValue = tempValue ?? currentValue;
    final hasChanges =
        tempValue != null && (tempValue - currentValue).abs() > 0.01;
    final hasBg = customBgUrl != null && customBgUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C9FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.zoom_out_rounded,
                color: Color(0xFF8E6F7E),
                size: 20,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFD81B60),
                    inactiveTrackColor: const Color(0xFFFDE8F0),
                    thumbColor: const Color(0xFFD81B60),
                    overlayColor:
                        const Color(0xFFD81B60).withValues(alpha: 0.12),
                    trackHeight: 4.0,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16.0),
                  ),
                  child: Slider(
                    min: 200.0,
                    max: UiPrefs.maxCountdownSizePx,
                    value:
                        displayValue.clamp(200.0, UiPrefs.maxCountdownSizePx),
                    onChanged: onChanged,
                    onChangeEnd: onChangedEnd,
                  ),
                ),
              ),
              const Icon(
                Icons.zoom_in_rounded,
                color: Color(0xFFD81B60),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kích thước: ${displayValue.toInt()} px',
                style: SLTheme.quicksand(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w800,
                  color: hasChanges
                      ? const Color(0xFFD81B60)
                      : const Color(0xFF8E6F7E),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: hasChanges ? onSave : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasChanges
                          ? const Color(0xFFFFF2F7)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: hasChanges
                              ? const Color(0xFFF4D7E2)
                              : const Color(0xFFE0E0E0)),
                      boxShadow: hasChanges
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD81B60)
                                    .withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Lưu',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: hasChanges
                            ? const Color(0xFFD81B60)
                            : const Color(0xFFBDBDBD),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF0DDE4), height: 1),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9733EE).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh nền trang chủ',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tải lên hoặc xóa ảnh nền trang chủ.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isUploadingBg) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _bgUploadProgress != null
                        ? 'Đang tải lên: ${(_bgUploadProgress! * 100).toInt()}%'
                        : 'Đang chuẩn bị tải lên...',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (hasBg) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: customBgUrl.trim(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF0DDE4)),
                      foregroundColor: const Color(0xFF4A3640),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _pickBgImage,
                    icon: const Icon(Icons.upload_rounded,
                        size: 16, color: Color(0xFFD81B60)),
                    label: Text(
                      hasBg ? 'Thay đổi ảnh' : 'Tải ảnh lên',
                      style: SLTheme.quicksand(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (hasBg) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF4D7E2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFD81B60), size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Xóa ảnh nền?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900),
                            ),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa ảnh nền trang chủ không?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w700),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  'Hủy',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8E6F7E)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              TextButton(
                                child: Text(
                                  'Xóa',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearBgImage();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickBgImage() async {
    final homeState = widget.homeState;
    final houseId = (homeState._houseId ?? '').trim();
    if (houseId.isEmpty) {
      homeState._showLatestSnackBar(
          'Vui lòng đăng nhập hoặc tham gia nhà để đổi ảnh nền.');
      return;
    }

    if (!widget.isVip && !kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final lastAdTimeStr = prefs.getString('last_bg_ad_time');
      bool shouldShowAd = true;
      if (lastAdTimeStr != null) {
        final lastAdTime = DateTime.parse(lastAdTimeStr);
        if (DateTime.now().difference(lastAdTime).inMinutes < 15) {
          shouldShowAd = false;
        }
      }

      if (shouldShowAd) {
        final adMob = AdMobService();
        if (!context.mounted) return;
        final adSuccess = await adMob.showRewardedAd(
          ignoreCooldown: true,
          loadTimeout: const Duration(seconds: 12),
        );
        if (!mounted) return;
        if (!adSuccess) {
          homeState._showLatestSnackBar(
              'Cần xem hết quảng cáo để thay đổi ảnh nền.');
          return;
        }
        await prefs.setString(
            'last_bg_ad_time', DateTime.now().toIso8601String());
      }
    }

    try {
      final pickedFile = await homeState._storageService.pickImage();
      if (pickedFile == null || !mounted) return;
      XFile file = pickedFile;

      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 82,
          maxWidth: 1440,
          maxHeight: 3200,
          uiSettings: [
            
          AndroidUiSettings(
            toolbarTitle: 'Chỉnh sửa ảnh nền',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFFF6D97),
            dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
            cropFrameColor: Colors.transparent,
            cropGridColor: Colors.transparent,
            showCropGrid: false,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            
          ),
            IOSUiSettings(
              title: 'Chỉnh sửa ảnh nền',
              // Using ratio16x9 since ratio9x16 was removed in image_cropper v7
              aspectRatioPresets: const [CropAspectRatioPreset.ratio16x9],
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
        if (croppedFile != null) {
          file = XFile(croppedFile.path);
        }
      } catch (e) {
        debugPrint('Lỗi cắt ảnh: $e');
      }

      if (!mounted) return;
      setState(() {
        _isUploadingBg = true;
        _bgUploadProgress = 0.0;
      });

      final url = await homeState._storageService.uploadImage(
        houseId,
        'themes',
        file,
        quality: 95,
        minWidth: 1440,
        minHeight: 1440,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _bgUploadProgress = progress;
            });
          }
        },
      );

      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        homeState._showLatestSnackBar('Tải ảnh nền thất bại.');
        return;
      }

      final oldUrl = UiPrefs.notifier.value.customBackgroundUrl;
      if (oldUrl.isNotEmpty) {
        try {
          homeState._storageService.deleteImageByUrl(oldUrl);
        } catch (_) {}
      }

      await homeState._saveCountdownQuickUiPrefs(
        customBackgroundUrl: url.trim(),
        isVip: widget.isVip,
      );

      homeState._showLatestSnackBar('Đã lưu ảnh nền thành công!');
    } catch (e) {
      if (mounted) {
        homeState._showLatestSnackBar('Đã xảy ra lỗi khi tải lên ảnh nền.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBg = false;
          _bgUploadProgress = null;
        });
      }
    }
  }

  Future<void> _clearBgImage() async {
    final oldUrl = UiPrefs.notifier.value.customBackgroundUrl;
    if (oldUrl.isNotEmpty) {
      try {
        widget.homeState._storageService.deleteImageByUrl(oldUrl);
      } catch (_) {}
    }
    await widget.homeState._saveCountdownQuickUiPrefs(
      customBackgroundUrl: '',
      isVip: widget.isVip,
    );
    widget.homeState._showLatestSnackBar('Đã xóa ảnh nền trang chủ.');
  }

  Widget buildAvatarIconToggleSection({
    required bool showIcon,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8A2387),
                      Color(0xFFE94057),
                      Color(0xFFF27121)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE94057).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_border_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hiển thị icon trang trí',
                    style: SLTheme.quicksand(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A3640),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bật/tắt các biểu tượng trang trí trên khung.',
                    style: SLTheme.quicksand(
                      fontSize: 12.1,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: showIcon,
            activeThumbColor: const Color(0xFFD81B60),
            activeTrackColor: const Color(0xFFFDE8F0),
            inactiveThumbColor: const Color(0xFFB0B0B0),
            inactiveTrackColor: const Color(0xFFF0DDE4),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget buildTimerSection({
    required bool showTimer,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDC830), Color(0xFFF37335)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF37335).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bộ đếm giờ chi tiết',
                    style: SLTheme.quicksand(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A3640),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hiện giờ/phút/giây bên dưới số ngày.',
                    style: SLTheme.quicksand(
                      fontSize: 12.1,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: showTimer,
            activeThumbColor: const Color(0xFFD81B60),
            activeTrackColor: const Color(0xFFFDE8F0),
            inactiveThumbColor: const Color(0xFFB0B0B0),
            inactiveTrackColor: const Color(0xFFF0DDE4),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget buildBackgroundSection({
    required String? customBgUrl,
  }) {
    final hasBg = customBgUrl != null && customBgUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9733EE).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh nền trang chủ',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tải lên hoặc xóa ảnh nền trang chủ.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isUploadingBg) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _bgUploadProgress != null
                        ? 'Đang tải lên: ${(_bgUploadProgress! * 100).toInt()}%'
                        : 'Đang chuẩn bị tải lên...',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (hasBg) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: customBgUrl.trim(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF0DDE4)),
                      foregroundColor: const Color(0xFF4A3640),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _pickBgImage,
                    icon: const Icon(Icons.upload_rounded,
                        size: 16, color: Color(0xFFD81B60)),
                    label: Text(
                      hasBg ? 'Thay đổi ảnh' : 'Tải ảnh lên',
                      style: SLTheme.quicksand(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (hasBg) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF4D7E2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFD81B60), size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Xóa ảnh nền?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900),
                            ),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa ảnh nền trang chủ không?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w700),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  'Hủy',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8E6F7E)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              TextButton(
                                child: Text(
                                  'Xóa',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearBgImage();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildHomeLayoutSection({
    required String selectedLayout,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DDE4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1493).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bố cục trang chủ',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chọn giao diện hiển thị cho Màn hình chính.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildLayoutOptionChip(
                  label: 'Cổ điển',
                  icon: Icons.grid_view_rounded,
                  selected: selectedLayout != 'fullscreen',
                  onTap: () => onSelect('classic'),
                ),
              ),
              // [10/08/2026] Tạm thời ẩn mục Toàn màn hình chờ cập nhật sau.
              /*
              const SizedBox(width: 10),
              Expanded(
                child: _buildLayoutOptionChip(
                  label: 'Toàn màn hình',
                  icon: Icons.fullscreen_rounded,
                  selected: selectedLayout == 'fullscreen',
                  onTap: () => onSelect('fullscreen'),
                ),
              ),
              */
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOptionChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const accent = Color(0xFFD81B60);
    final borderColor = selected ? accent : accent.withValues(alpha: 0.28);
    final backgroundColor =
        selected ? accent.withValues(alpha: 0.14) : Colors.white;
    final textColor = selected ? accent : const Color(0xFF584450);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1.0),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, uiState, _) {
          final selectedStyle = widget.styleOptions.firstWhere(
            (option) => option.value == uiState.countdownStyleKey,
            orElse: () => widget.styleOptions.first,
          );

          final currentStyleIsLocked =
              _MainHomeTabState._kCountdownQuickPremiumStyleKeys.contains(
                    uiState.countdownStyleKey,
                  ) &&
                  !_unlockedStyles.contains(uiState.countdownStyleKey);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              max(mediaQuery.padding.bottom, 14.0) + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF8FB1),
                            Color(0xFFD81B60),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tùy chỉnh vòng đếm',
                            style: SLTheme.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF33262D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ấn giữ vòng đếm ngày để mở bảng này và đổi nhanh giao diện ngay trên trang chủ.',
                            style: SLTheme.quicksand(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF806575),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(widget.sheetContext).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF0DDE4),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFD81B60),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFF2F7),
                        Color(0xFFFFFBFD),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF4D7E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang dùng',
                        style: SLTheme.quicksand(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (selectedStyle.isVipOnly && !widget.isVip)
                            buildLockedVipButton(
                              option: selectedStyle,
                            )
                          else if (currentStyleIsLocked)
                            buildLockedAdButton(
                              option: selectedStyle,
                              onUnlocked: (opt) async {
                                await widget.homeState
                                    ._saveCountdownQuickUiPrefs(
                                  countdownStyleKey: opt.value,
                                  prevalidatedUnlockedStyles: _unlockedStyles,
                                  isVip: widget.isVip,
                                );
                              },
                            )
                          else
                            buildOptionChip(
                              option: selectedStyle,
                              selected: true,
                              onTap: () =>
                                  widget.homeState._saveCountdownQuickUiPrefs(
                                countdownStyleKey: selectedStyle.value,
                                prevalidatedUnlockedStyles: _unlockedStyles,
                                isVip: widget.isVip,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                buildHomeLayoutSection(
                  selectedLayout: uiState.homeLayoutKey,
                  onSelect: (layoutKey) async {
                    HapticFeedback.selectionClick();
                    await UiPrefs.setHomeLayoutKey(layoutKey);
                  },
                ),
                const SizedBox(height: 12),
                buildCollapsedSection(
                  title: 'Giao diện vòng đếm',
                  description: 'Đổi phong cách hiển thị vòng đếm ngày.',
                  icon: Icons.change_circle_rounded,
                  options: widget.styleOptions,
                  selectedValue: uiState.countdownStyleKey,
                  onSelect: (option) =>
                      widget.homeState._saveCountdownQuickUiPrefs(
                    countdownStyleKey: option.value,
                    prevalidatedUnlockedStyles: _unlockedStyles,
                    isVip: widget.isVip,
                  ),
                ),
                const SizedBox(height: 12),
                buildTextColorSection(
                  selectedColorHex: uiState.countdownTextColor,
                  onSelect: (hex) =>
                      widget.homeState._saveCountdownQuickUiPrefs(
                    countdownTextColor: hex,
                    prevalidatedUnlockedStyles: _unlockedStyles,
                    isVip: widget.isVip,
                  ),
                ),
                const SizedBox(height: 12),
                buildSizeSection(
                  title: 'Kích thước vòng đếm',
                  description: 'Kéo để điều chỉnh độ lớn của vòng đếm ngày.',
                  icon: Icons.photo_size_select_large_rounded,
                  currentValue: uiState.countdownSizePx,
                  tempValue: _tempCountdownSize,
                  customBgUrl: uiState.customBackgroundUrl,
                  onChanged: (value) {
                    setState(() {
                      _tempCountdownSize = value;
                    });
                  },
                  onChangedEnd: (value) {
                    setState(() {
                      _tempCountdownSize = value;
                    });
                  },
                  onSave: () async {
                    if (_tempCountdownSize != null) {
                      final sizeToSave = _tempCountdownSize!;

                      await widget.homeState._saveCountdownQuickUiPrefs(
                        countdownSizePx: sizeToSave,
                        isVip: widget.isVip,
                      );
                      HapticFeedback.mediumImpact();
                      if (mounted) {
                        setState(() => _tempCountdownSize = null);
                        widget.homeState
                            ._showLatestSnackBar('Đã lưu kích thước!');
                      }
                    }
                  },
                ),

                buildTimerSection(
                  showTimer: uiState.homeShowTimer,
                  onToggle: (val) async {
                    HapticFeedback.selectionClick();
                    await UiPrefs.setHomeShowTimer(val);
                  },
                ),
                const SizedBox(height: 12),
                // --- Kiểu khung avatar ---
                buildCollapsedSection(
                  title: 'Kiểu khung avatar',
                  description: 'Đổi kiểu viền avatar hiển thị trên trang chủ.',
                  icon: Icons.account_circle_rounded,
                  options: [
                    const _CountdownQuickOption(
                      label: 'Không',
                      value: 'off',
                      icon: Icons.block_rounded,
                      accent: Color(0xFFBDBDBD),
                    ),
                    const _CountdownQuickOption(
                      label: 'Tròn',
                      value: 'circle',
                      icon: Icons.circle_rounded,
                      accent: Color(0xFF2563EB),
                    ),
                    const _CountdownQuickOption(
                      label: 'Bo góc',
                      value: 'rounded',
                      icon: Icons.rounded_corner_rounded,
                      accent: Color(0xFFEC4899),
                    ),
                    const _CountdownQuickOption(
                      label: 'Squircle',
                      value: 'squircle',
                      icon: Icons.crop_square_rounded,
                      accent: Color(0xFF8B5CF6),
                    ),
                    const _CountdownQuickOption(
                      label: 'Ngọc trai',
                      value: 'pearl',
                      icon: Icons.blur_circular_rounded,
                      accent: Color(0xFFD4A520),
                    ),
                    const _CountdownQuickOption(
                      label: 'Thủy tinh',
                      value: 'glass',
                      icon: Icons.water_drop_rounded,
                      accent: Color(0xFF06B6D4),
                    ),
                  ],
                  selectedValue: uiState.avatarFrameKey.isEmpty
                      ? 'off'
                      : uiState.avatarFrameKey,
                  onSelect: (option) =>
                      widget.homeState._saveCountdownQuickUiPrefs(
                    avatarFrameKey: option.value,
                    isVip: widget.isVip,
                  ),
                ),
                const SizedBox(height: 12),
                buildAvatarIconToggleSection(
                  showIcon: uiState.showAvatarFrameIcon,
                  onToggle: (val) async {
                    HapticFeedback.selectionClick();
                    await UiPrefs.setShowAvatarFrameIcon(val);
                  },
                ),
                const SizedBox(height: 12),
                // --- Chất lượng đồ họa ---
                buildCollapsedSection(
                  title: 'Chất lượng đồ họa',
                  description:
                      'Tùy chỉnh chất lượng đồ họa và hiệu ứng hiển thị.',
                  icon: Icons.high_quality_rounded,
                  options: [
                    const _CountdownQuickOption(
                      label: 'Tự động',
                      value: 'auto',
                      icon: Icons.brightness_auto_rounded,
                      accent: Color(0xFF2563EB),
                    ),
                    const _CountdownQuickOption(
                      label: 'Thấp (Mượt)',
                      value: 'low',
                      icon: Icons.battery_saver_rounded,
                      accent: Color(0xFFE11D48),
                    ),
                    const _CountdownQuickOption(
                      label: 'Trung bình',
                      value: 'balanced',
                      icon: Icons.balance_rounded,
                      accent: Color(0xFFD97706),
                    ),
                    const _CountdownQuickOption(
                      label: 'Cao (Đẹp)',
                      value: 'high',
                      icon: Icons.bolt_rounded,
                      accent: Color(0xFF059669),
                    ),
                  ],
                  selectedValue: uiState.graphicsQualityKey.isEmpty
                      ? 'auto'
                      : uiState.graphicsQualityKey,
                  onSelect: (option) async {
                    HapticFeedback.selectionClick();
                    await UiPrefs.saveState(
                        uiState.copyWith(graphicsQualityKey: option.value));
                  },
                ),
                const SizedBox(height: 12),
                // --- Ngôn ngữ ---
                buildCollapsedSection(
                  title: 'Ngôn ngữ',
                  description: 'Đổi ngôn ngữ hiển thị của ứng dụng.',
                  icon: Icons.language_rounded,
                  options: [
                    const _CountdownQuickOption(
                        label: 'Tiếng Việt',
                        value: 'vi',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFFD81B60)),
                    const _CountdownQuickOption(
                        label: 'English',
                        value: 'en',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFF2563EB)),
                    const _CountdownQuickOption(
                        label: '中文 (简体)',
                        value: 'zh',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFFDC2626)),
                    const _CountdownQuickOption(
                        label: '中文 (繁體)',
                        value: 'zh-TW',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFF7C3AED)),
                    const _CountdownQuickOption(
                        label: '日本語',
                        value: 'ja',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFFEA580C)),
                    const _CountdownQuickOption(
                        label: '한국어',
                        value: 'ko',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFF0891B2)),
                    const _CountdownQuickOption(
                        label: 'ภาษาไทย',
                        value: 'th',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFF059669)),
                    const _CountdownQuickOption(
                        label: 'Bahasa Indonesia',
                        value: 'id',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFFD97706)),
                    const _CountdownQuickOption(
                        label: 'Español',
                        value: 'es',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFFB91C1C)),
                    const _CountdownQuickOption(
                        label: 'Français',
                        value: 'fr',
                        icon: Icons.flag_rounded,
                        accent: Color(0xFF1D4ED8)),
                  ],
                  selectedValue: L10nService().localeCode,
                  onSelect: (option) async {
                    HapticFeedback.selectionClick();
                    await Future.delayed(const Duration(milliseconds: 300));
                    await L10nService().setLocale(option.value);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(widget.sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Xong',
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
