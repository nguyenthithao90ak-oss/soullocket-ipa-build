import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../screens/document_viewer_screen.dart';

class LegalDocumentsModal extends StatefulWidget {
  const LegalDocumentsModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => const LegalDocumentsModal(),
    );
  }

  @override
  State<LegalDocumentsModal> createState() => _LegalDocumentsModalState();
}

class _LegalDocumentsModalState extends State<LegalDocumentsModal> {
  static const Color _accentRose = Color(0xFFD81B60);
  static const Color _accentLavender = Color(0xFF7C4DFF);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentGreen = Color(0xFF0F766E);
  static const Color _ink = Color(0xFF24324A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _panelBorder = Color(0xFFE9DCE7);
  static const Color _dialogBackgroundTop = Color(0xFFFFFCFE);
  static const Color _dialogBackgroundBottom = Color(0xFFFFF6FB);
  static const Color _cardBackground = Color(0xFFFFFDFE);

  String _selectedTab = 'tos'; // tos, privacy, security, cookie

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
            ),
            borderRadius: SLRadius.xlAll,
            border: Border.all(
              color: _panelBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentLavender.withOpacity(0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chính sách & Điều khoản',
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    'Vui lòng xem xét và chấp nhận các chính sách của chúng tôi',
                    style: SLTheme.quicksand(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                  SLSpacing.h12,
                  // Tab Navigation
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(
                            'tos', 'Bảo mật', Icons.gavel_rounded, _accentRose),
                        SLSpacing.w8,
                        _buildTabButton('privacy', 'Điều khoản',
                            Icons.privacy_tip_rounded, _accentLavender),
                        SLSpacing.w8,
                        _buildTabButton('security', 'Cookie',
                            Icons.security_rounded, _accentGreen),
                      ],
                    ),
                  ),
                  SLSpacing.h12,
                  // Content based on selected tab
                  _buildTabContent(),
                  SLSpacing.h12,
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: _accentLavender,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Không đồng ý',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      SLSpacing.w8,
                      Expanded(
                        child: _buildPrimaryButton(
                          label: 'Tiếp tục',
                          accent: _getTabAccent(),
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTabAccent() {
    switch (_selectedTab) {
      case 'tos':
        return _accentRose;
      case 'privacy':
        return _accentLavender;
      case 'security':
        return _accentGreen;
      case 'cookie':
        return _accentBlue;
      default:
        return _accentRose;
    }
  }

  Widget _buildTabButton(
      String tabId, String label, IconData icon, Color accent) {
    final isActive = _selectedTab == tabId;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.15) : _cardBackground,
          borderRadius: SLRadius.mdAll,
          border: Border.all(
            color: isActive ? accent.withOpacity(0.34) : _panelBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 16),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? accent : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'tos':
        return _buildTosTab();
      case 'privacy':
        return _buildPrivacyTab();
      case 'security':
        return _buildSecurityTab();
      case 'cookie':
        return _buildCookieTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ============ TOS Tab ============
  Widget _buildTosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentRose.withOpacity(0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentRose.withOpacity(0.16)),
          ),
          child: Text(
            'Trước khi vào app, bạn cần xác nhận đã đọc bộ điều khoản sử dụng để hiểu rõ quyền lợi, trách nhiệm và quy tắc sử dụng SoulLocket.',
            style: SLTheme.quicksand(
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.4,
            ),
          ),
        ),
        SLSpacing.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            children: [
              _buildDocItem(
                icon: Icons.verified_user_rounded,
                title: 'Quyền và trách nhiệm',
                description:
                    'Làm rõ trách nhiệm tài khoản, hành vi được phép và giới hạn sử dụng trong ứng dụng.',
                accent: _accentRose,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.groups_rounded,
                title: 'Quy tắc cộng đồng',
                description:
                    'Nêu các nguyên tắc khi đăng bài, chat, chia sẻ media và tương tác với người khác.',
                accent: _accentRose,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.workspace_premium_rounded,
                title: 'PRO và dịch vụ số',
                description:
                    'Giải thích cách hoạt động của PRO, quà tặng, quảng cáo thưởng và các quyền lợi mở rộng.',
                accent: _accentRose,
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        _buildPrimaryButton(
          label: 'Xem chi tiết Điều khoản',
          icon: Icons.open_in_new_rounded,
          accent: _accentRose,
          onTap: () =>
              _openDoc('Điều khoản sử dụng (TOS)', 'assets/docs/terms.html'),
        ),
      ],
    );
  }

  // ============ Privacy Tab ============
  Widget _buildPrivacyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentLavender.withOpacity(0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentLavender.withOpacity(0.16)),
          ),
          child: Text(
            'Bảng này tóm tắt dữ liệu nào được dùng, vì sao được dùng và cách bạn kiểm soát dữ liệu của mình trước khi tiếp tục.',
            style: SLTheme.quicksand(
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.4,
            ),
          ),
        ),
        SLSpacing.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            children: [
              _buildDocItem(
                icon: Icons.folder_shared_rounded,
                title: 'Dữ liệu được xử lý',
                description:
                    'Bao gồm định vị GPS (ngay cả trong nền để cập nhật bản đồ), ảnh riêng tư, dữ liệu sức khỏe (chu kỳ kinh nguyệt), tin nhắn chat và thiết bị.',
                accent: _accentLavender,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.lock_outline_rounded,
                title: 'Mục đích sử dụng',
                description:
                    'Dùng để kết nối cặp đôi, chia sẻ vị trí realtime, sao lưu kỷ niệm, nhắc nhở chu kỳ sức khỏe và cảnh báo bảo mật thiết bị.',
                accent: _accentLavender,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.manage_accounts_rounded,
                title: 'Quyền kiểm soát',
                description:
                    'Bạn có thể tắt GPS, xóa tin nhắn, xóa ảnh hoặc yêu cầu xóa toàn bộ dữ liệu tài khoản trong Cài đặt bất kỳ lúc nào.',
                accent: _accentLavender,
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        _buildPrimaryButton(
          label: 'Xem chi tiết Bảo mật',
          icon: Icons.open_in_new_rounded,
          accent: _accentLavender,
          onTap: () =>
              _openDoc('Chính sách bảo mật', 'assets/docs/privacy.html'),
        ),
      ],
    );
  }

  // ============ Security Tab ============
  Widget _buildSecurityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentGreen.withOpacity(0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentGreen.withOpacity(0.16)),
          ),
          child: Text(
            'SoulLocket có thể lưu mẫu thiết bị, địa chỉ IP công khai và vị trí gần đúng suy ra từ IP để phát hiện đăng nhập lạ, duyệt thiết bị và gửi cảnh báo bảo mật. Dữ liệu này không dùng cho quảng cáo.',
            style: SLTheme.quicksand(
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.4,
            ),
          ),
        ),
        SLSpacing.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            children: [
              _buildDocItem(
                icon: Icons.phone_iphone_rounded,
                title: 'Dữ liệu được lưu',
                description:
                    'Model máy, hệ điều hành, token thiết bị, IP công khai và dấu thời gian đăng nhập.',
                accent: _accentGreen,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.public_rounded,
                title: 'Vị trí gần đúng từ IP',
                description:
                    'Chỉ suy ra ở mức thành phố/khu vực từ IP công khai, không phải GPS nền.',
                accent: _accentGreen,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.security_rounded,
                title: 'Mục đích sử dụng',
                description:
                    'Cảnh báo đăng nhập bất thường, phê duyệt/chặn thiết bị và hỗ trợ điều tra sự cố bảo mật.',
                accent: _accentGreen,
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentGreen.withOpacity(0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentGreen.withOpacity(0.16)),
          ),
          child: Text(
            'Nếu bạn không bật mục này, app vẫn dùng được nhưng nhật ký thiết bị và một số cảnh báo bảo mật sẽ không đầy đủ.',
            style: SLTheme.quicksand(
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
              color: _ink.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ============ Cookie Tab ============
  Widget _buildCookieTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentBlue.withOpacity(0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentBlue.withOpacity(0.16)),
          ),
          child: Text(
            'Chúng tôi sử dụng cookies để giúp bạn truy cập SoulLocket, cách người dùng tương tác với ứng dụng của chúng tôi, bảo vệ chống gian lận và cải thiện hiệu suất của chúng tôi.',
            style: SLTheme.quicksand(
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.4,
            ),
          ),
        ),
        SLSpacing.h12,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            children: [
              _buildDocItem(
                icon: Icons.check_rounded,
                title: 'Cookies cần thiết',
                description:
                    'Cần thiết để SoulLocket hoạt động bình thường (đăng nhập, bảo mật, tùy chỉnh).',
                accent: _accentBlue,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.analytics_rounded,
                title: 'Cookies phân tích',
                description:
                    'Giúp chúng tôi hiểu cách bạn sử dụng ứng dụng để cải thiện trải nghiệm.',
                accent: _accentBlue,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.campaign_rounded,
                title: 'Cookies tiếp thị',
                description:
                    'Được sử dụng để hiển thị quảng cáo liên quan và đo hiệu quả chiến dịch.',
                accent: _accentBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDoc(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  Widget _buildDocItem({
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: SLRadius.mdAll,
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: SLRadius.smAll,
              border: Border.all(color: accent.withOpacity(0.14)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 16),
          ),
          SLSpacing.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                SLSpacing.gapH(2),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required Color accent,
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final endColor = Color.lerp(accent, Colors.black, 0.12) ?? accent;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, endColor],
        ),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: SLRadius.lgAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  SLSpacing.w8,
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
