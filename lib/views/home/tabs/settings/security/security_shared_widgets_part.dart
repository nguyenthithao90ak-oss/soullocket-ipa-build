part of '../../settings_tab.dart';

extension _SettingsTabSecuritySharedWidgetsPart on _SettingsTabState {
  Widget _buildSecurityBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildSecurityInlineButton({
    required String label,
    required List<Color> gradient,
    required VoidCallback? onTap,
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required String title,
    String? subtitle,
    required Color borderColor,
    required Color backgroundColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: borderColor.withOpacity(0.95),
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7A6A74),
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernIdentityTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isVerified,
    required VoidCallback? onAction,
    required String actionLabel,
    String? statusLabel,
    Color accentColor = const Color(0xFFD81B60),
    bool isLoading = false,
    bool showCheckmark = true,
    VoidCallback? onSecondaryAction,
    String? secondaryActionLabel,
  }) {
    final statusText = statusLabel ?? (isVerified ? 'Đã xác thực' : 'Chưa xác thực');
    final statusBg = isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final statusFg = isVerified ? const Color(0xFF2E7D32) : const Color(0xFFE65100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF0F4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (showCheckmark && isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20)
              else if (statusLabel != null || !isVerified)
                _buildSecurityBadge(
                  statusText,
                  background: statusBg,
                  foreground: statusFg,
                ),
            ],
          ),
          if (onAction != null || onSecondaryAction != null || isLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onSecondaryAction != null)
                  Expanded(
                    child: _buildCompactActionBtn(
                      label: secondaryActionLabel ?? 'Thay đổi',
                      onTap: onSecondaryAction,
                      isPrimary: false,
                    ),
                  ),
                if (onSecondaryAction != null && (onAction != null || isLoading))
                  const SizedBox(width: 8),
                if (onAction != null || isLoading)
                  Expanded(
                    child: _buildCompactActionBtn(
                      label: isLoading ? 'Đang xử lý...' : actionLabel,
                      onTap: isLoading ? null : onAction,
                      isPrimary: true,
                      accentColor: accentColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactActionBtn({
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = true,
    Color accentColor = const Color(0xFFD81B60),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? accentColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isPrimary ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  void _showSecondaryEmailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Email dự phòng',
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dùng để nhận mã khôi phục khi bạn không thể truy cập email chính.',
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            _buildInput(_secondaryEmailCtrl, 'Nhập email phụ / email dự phòng'),
            const SizedBox(height: 16),
            _buildGradientBtn(
              label: _secondaryEmail.isEmpty ? 'THÊM EMAIL PHỤ' : 'CẬP NHẬT',
              gradient: const [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
              onTap: () {
                Navigator.pop(context);
                _saveSecondaryEmail();
              },
            ),
          ],
        ),
      ),
    );
  }
}

