// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../../services/consent_service.dart';
import '../home/screens/document_viewer_screen.dart';
import '../../core/sl_theme.dart';

class ConsentGate extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onReady;

  const ConsentGate({
    super.key,
    required this.child,
    this.onReady,
  });

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
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

  final ConsentService _consentService = ConsentService();
  bool _ready = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero);
      if (mounted) {
        _ensureConsent();
      }
    });
  }

  Future<void> _ensureConsent() async {
    if (_running) return;
    _running = true;
    try {
      if (!mounted) return;
      final hasStartupConsent = await _consentService.hasValidConsent();
      if (!hasStartupConsent) {
        final initialCookieLevel =
            await _consentService.getCookieConsentLevel();
        if (!mounted) return;
        final result = await _showStartupConsentDialog(
          initialCookieLevel: initialCookieLevel,
        );
        if (result == null || !mounted) return;
        await _consentService.setTosAccepted(true);
        await _consentService.setPrivacyAccepted(true);
        await _consentService.setCookieConsentLevel(result.cookieLevel);
      }

      if (!mounted) return;
      setState(() => _ready = true);
      Future<void>(() async {
        try {
          await widget.onReady?.call();
        } catch (e) {
          debugPrint('ConsentGate onReady error: $e');
        }
      });
    } catch (e, st) {
      debugPrint('ConsentGate failed: $e\n$st');
      if (!mounted) return;
      setState(() => _ready = true);
    } finally {
      _running = false;
    }
  }

  Future<void> _openDoc(String title, String assetPath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  Future<_StartupConsentResult?> _showStartupConsentDialog({
    String? initialCookieLevel,
  }) {
    return showDialog<_StartupConsentResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        var cookieLevel =
            initialCookieLevel == 'essential' ? 'essential' : 'all';
        var showScrollHint = true;

        return StatefulBuilder(
          builder: (ctx, setState) {
            final screenSize = MediaQuery.sizeOf(ctx);
            final mediaPadding = MediaQuery.of(ctx).padding;
            final compact = screenSize.width < 620;
            final dialogRadius = compact ? 0.0 : 22.0;
            final horizontalInset = compact ? 0.0 : 18.0;
            final verticalInset = compact ? 0.0 : 16.0;
            final horizontalPadding = compact ? 12.0 : 16.0;

            return PopScope(
              canPop: false,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                  vertical: verticalInset,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(dialogRadius),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: compact ? screenSize.width : 680,
                      maxHeight: compact
                          ? screenSize.height
                          : screenSize.height * 0.96,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
                      ),
                      border: Border.all(color: _panelBorder, width: 1.1),
                      boxShadow: compact
                          ? null
                          : [
                              BoxShadow(
                                color: _accentLavender.withOpacity(0.10),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: SafeArea(
                      top: compact,
                      bottom: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    final shouldShow =
                                        notification.metrics.pixels <= 8 &&
                                            notification.metrics.maxScrollExtent >
                                                16;
                                    if (showScrollHint != shouldShow) {
                                      setState(() {
                                        showScrollHint = shouldShow;
                                      });
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      compact ? 12 : 16,
                                      horizontalPadding,
                                      mediaPadding.bottom > 0
                                          ? mediaPadding.bottom + 12
                                          : 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildStartupConsentHeader(
                                            compact: compact),
                                        const SizedBox(height: 18),
                                        _buildStartupSectionLabel(
                                          title: 'Trước khi bắt đầu',
                                          subtitle:
                                              'Bạn cần xem các thông tin pháp lý chính trước khi vào SoulLocket.',
                                        ),
                                        const SizedBox(height: 10),
                                        _buildStartupLegalSection(
                                          accent: _accentRose,
                                          icon: Icons.gavel_rounded,
                                          title: 'Điều khoản sử dụng',
                                          subtitle:
                                              'Tóm tắt cách dùng SoulLocket, quyền lợi, trách nhiệm và các giới hạn chính.',
                                          bullets: const [
                                            'Áp dụng cho tài khoản, ghép đôi/nhà, bài viết, chat, media, tiện ích và gói dịch vụ.',
                                            'Bạn cần dùng app đúng luật, tôn trọng người khác và tự chịu trách nhiệm với nội dung mình gửi.',
                                            'App có thể giới hạn, ẩn hoặc xử lý nội dung/tài khoản vi phạm để bảo vệ cộng đồng.',
                                          ],
                                          actionLabel: 'Xem Điều khoản',
                                          onTap: () => _openDoc(
                                            'Điều khoản sử dụng',
                                            'assets/docs/terms.html',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildStartupLegalSection(
                                          accent: _accentLavender,
                                          icon: Icons.privacy_tip_rounded,
                                          title: 'Chính sách bảo mật',
                                          subtitle:
                                              'Tóm tắt dữ liệu app có thể dùng, lý do dùng và cách bạn kiểm soát dữ liệu.',
                                          bullets: const [
                                            'Có thể gồm tài khoản, nhà/ghép đôi, bài viết, chat, ảnh/media, vị trí, sức khỏe, thiết bị và thanh toán.',
                                            'Dữ liệu dùng để đăng nhập, đồng bộ, cá nhân hóa, bảo mật, vận hành tiện ích và hỗ trợ khi có sự cố.',
                                            'Bạn có thể đổi quyền riêng tư, quản lý quyền thiết bị hoặc yêu cầu xóa dữ liệu trong Cài đặt.',
                                          ],
                                          actionLabel: 'Xem Bảo mật',
                                          onTap: () => _openDoc(
                                            'Chính sách bảo mật',
                                            'assets/docs/privacy.html',
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _buildStartupAcknowledgement(),
                                        const SizedBox(height: 22),
                                        _buildStartupSectionLabel(
                                          title: 'Tùy chọn lưu trữ',
                                          subtitle:
                                              'Chọn mức cookie và lưu trữ cục bộ. Bạn có thể đổi lại sau trong Cài đặt.',
                                        ),
                                        const SizedBox(height: 10),
                                        _buildStartupCookieStorageSection(
                                          cookieLevel: cookieLevel,
                                          onChanged: (value) => setState(() {
                                            cookieLevel = value;
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 8,
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      opacity: showScrollHint ? 1 : 0,
                                      child: _buildStartupScrollHint(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStartupAgreeBar(
                            compact: compact,
                            bottomInset: mediaPadding.bottom,
                            cookieLevel: cookieLevel,
                            onConfirm: () => Navigator.pop(
                              ctx,
                              _StartupConsentResult(
                                cookieLevel: cookieLevel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStartupConsentHeader({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 14 : 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF2F6FF),
            Color(0xFFFFF4FA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EAF6)),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentBlue.withOpacity(0.16),
                  _accentLavender.withOpacity(0.11),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.86)),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _accentBlue,
              size: 23,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bắt đầu an toàn',
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: _accentBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Thiết lập quyền riêng tư',
                  style: SLTheme.quicksand(
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Xem nhanh quyền, bảo mật và chọn lưu trữ trước khi vào app.',
                  style: SLTheme.quicksand(
                    fontSize: 13.2,
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

  Widget _buildStartupSectionLabel({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 12.6,
              fontWeight: FontWeight.w700,
              color: _muted,
              height: 1.30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupLegalSection({
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, accent, 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.76),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withOpacity(0.16)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              SLSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 12.9,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        height: 1.30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bullets.take(2).map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      bullet,
                      style: SLTheme.quicksand(
                        fontSize: 12.55,
                        fontWeight: FontWeight.w700,
                        color: _ink.withOpacity(0.86),
                        height: 1.26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildInlineDocLink(accent: accent, label: actionLabel, onTap: onTap),
        ],
      ),
    );
  }

  Widget _buildStartupAcknowledgement() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: _accentLavender.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: _accentLavender.withOpacity(0.24), width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: _accentLavender, size: 24),
          SLSpacing.w12,
          Expanded(
            child: Text(
              'Khi nhấn “Vào app và đồng ý”, bạn xác nhận đã đọc và đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: _ink.withOpacity(0.9),
                height: 1.30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupCookieStorageSection({
    required String cookieLevel,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, _accentGreen, 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentGreen.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.76),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _accentGreen.withOpacity(0.16)),
                ),
                child: const Icon(Icons.cookie_rounded,
                    color: _accentGreen, size: 20),
              ),
              SLSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cookie & lưu trữ',
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn mức lưu trữ cho phiên đăng nhập và trải nghiệm trong app.',
                      style: SLTheme.quicksand(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        height: 1.30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _buildCookieChoiceCard(
            value: 'essential',
            groupValue: cookieLevel,
            accent: _accentBlue,
            title: 'Thiết yếu',
            subtitle:
                'Giữ đăng nhập, consent pháp lý và các chức năng cốt lõi.',
            bullets: const [
              'Tối giản dữ liệu lưu cục bộ.',
              'Phù hợp nếu bạn muốn vào app thật nhanh.',
            ],
            onTap: () => onChanged('essential'),
          ),
          const SizedBox(height: 8),
          _buildCookieChoiceCard(
            value: 'all',
            groupValue: cookieLevel,
            accent: _accentGreen,
            title: 'Tất cả',
            subtitle:
                'Thêm cá nhân hóa, cache tiện ích và trải nghiệm mượt hơn.',
            bullets: const [
              'Phù hợp nếu bạn muốn trải nghiệm đầy đủ hơn.',
              'Có thể lưu nhiều dữ liệu cục bộ hơn để tăng tốc.',
            ],
            badge: 'Đề xuất',
            onTap: () => onChanged('all'),
          ),
          const SizedBox(height: 11),
          _buildInlineDocLink(
            accent: _accentBlue,
            label: 'Xem Chính sách Cookie',
            onTap: () =>
                _openDoc('Chính sách Cookie', 'assets/docs/cookie-policy.html'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupScrollHint() {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          shape: BoxShape.circle,
          border: Border.all(color: _panelBorder.withOpacity(0.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _accentLavender.withOpacity(0.82),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildStartupAgreeBar({
    required bool compact,
    required double bottomInset,
    required String cookieLevel,
    required VoidCallback onConfirm,
  }) {
    final storageLabel =
        cookieLevel == 'essential' ? 'Lưu trữ thiết yếu' : 'Lưu trữ đầy đủ';

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        10,
        compact ? 12 : 16,
        bottomInset > 0 ? bottomInset + 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        border: Border(
          top: BorderSide(color: _panelBorder.withOpacity(0.88)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _accentGreen,
                  size: 18,
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  storageLabel,
                  style: SLTheme.quicksand(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                'Có thể đổi sau',
                style: SLTheme.quicksand(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _buildPrimaryButton(
            accent: _accentGreen,
            label: 'Đồng ý và vào app',
            scaleDownContent: true,
            icon: Icons.arrow_forward_rounded,
            fontSize: 15.5,
            verticalPadding: 14,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedConsentSection({
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentBlue.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withOpacity(0.14)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 15.5),
              ),
              SLSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bullet,
                      style: SLTheme.quicksand(
                        fontSize: 11.15,
                        fontWeight: FontWeight.w700,
                        color: _ink.withOpacity(0.84),
                        height: 1.24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildInlineDocLink(
            accent: accent,
            label: actionLabel,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  Future<bool?> _showTosDialog() {
    return _showConsentDialog(
      title: 'Điều khoản sử dụng (TOS)',
      subtitle:
          'Trước khi vào app, bạn cần xác nhận đã đọc bộ điều khoản sử dụng để hiểu rõ quyền lợi, trách nhiệm và quy tắc sử dụng SoulLocket.',
      actionLabel: 'Xem chi tiết Điều khoản',
      assetPath: 'assets/docs/terms.html',
      checkboxLabel:
          'Tôi đã đọc và đồng ý với Điều khoản sử dụng của SoulLocket',
      leadingIcon: Icons.gavel_rounded,
      accent: _accentRose,
      highlightItems: const [
        _ConsentHighlight(
          icon: Icons.verified_user_rounded,
          title: 'Quyền và trách nhiệm',
          description:
              'Làm rõ trách nhiệm tài khoản, hành vi được phép và giới hạn sử dụng trong ứng dụng.',
        ),
        _ConsentHighlight(
          icon: Icons.groups_rounded,
          title: 'Quy tắc cộng đồng',
          description:
              'Nêu các nguyên tắc khi đăng bài, chat, chia sẻ media và tương tác với người khác.',
        ),
        _ConsentHighlight(
          icon: Icons.workspace_premium_rounded,
          title: 'PRO và dịch vụ số',
          description:
              'Giải thích cách hoạt động của PRO, quà tặng, quảng cáo thưởng và các quyền lợi mở rộng.',
        ),
      ],
    );
  }

  Future<bool?> _showPrivacyDialog() {
    return _showConsentDialog(
      title: 'Chính sách bảo mật',
      subtitle:
          'Bảng này tóm tắt dữ liệu nào được dùng, vì sao được dùng và cách bạn kiểm soát dữ liệu của mình trước khi tiếp tục.',
      actionLabel: 'Xem chi tiết Bảo mật',
      assetPath: 'assets/docs/privacy.html',
      checkboxLabel:
          'Tôi đã đọc và đồng ý với Chính sách bảo mật của SoulLocket',
      leadingIcon: Icons.privacy_tip_rounded,
      accent: _accentLavender,
      highlightItems: const [
        _ConsentHighlight(
          icon: Icons.folder_shared_rounded,
          title: 'Dữ liệu được xử lý',
          description:
              'Bao gồm định vị GPS (ngay cả trong nền để cập nhật bản đồ), ảnh riêng tư, dữ liệu sức khỏe (chu kỳ kinh nguyệt), tin nhắn chat và thiết bị.',
        ),
        _ConsentHighlight(
          icon: Icons.lock_outline_rounded,
          title: 'Mục đích sử dụng',
          description:
              'Dùng để kết nối cặp đôi, chia sẻ vị trí realtime, sao lưu kỷ niệm, nhắc nhở chu kỳ sức khỏe và cảnh báo bảo mật thiết bị.',
        ),
        _ConsentHighlight(
          icon: Icons.manage_accounts_rounded,
          title: 'Quyền kiểm soát',
          description:
              'Bạn có thể tắt GPS, xóa tin nhắn, xóa ảnh hoặc yêu cầu xóa toàn bộ dữ liệu tài khoản trong Cài đặt bất kỳ lúc nào.',
        ),
      ],
    );
  }

  Future<bool?> _showSecurityDeviceSignalsDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
              ),
              borderRadius: SLRadius.xlAll,
              border: Border.all(color: _panelBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _accentGreen.withOpacity(0.12),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderIcon(
                          accent: _accentGreen,
                          icon: Icons.verified_user_rounded,
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bảo mật thiết bị và đăng nhập',
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                'SoulLocket có thể lưu mẫu thiết bị, địa chỉ IP công khai và vị trí gần đúng suy ra từ IP để phát hiện đăng nhập lạ, duyệt thiết bị và gửi cảnh báo bảo mật. Dữ liệu này không dùng cho quảng cáo.',
                                style: SLTheme.quicksand(
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h12,
                    _buildHighlightList(
                      const [
                        _ConsentHighlight(
                          icon: Icons.phone_iphone_rounded,
                          title: 'Dữ liệu được lưu',
                          description:
                              'Model máy, hệ điều hành, token thiết bị, IP công khai và dấu thời gian đăng nhập.',
                        ),
                        _ConsentHighlight(
                          icon: Icons.public_rounded,
                          title: 'Vị trí gần đúng từ IP',
                          description:
                              'Chỉ suy ra ở mức thành phố/khu vực từ IP công khai, không phải GPS nền.',
                        ),
                        _ConsentHighlight(
                          icon: Icons.security_rounded,
                          title: 'Mục đích sử dụng',
                          description:
                              'Cảnh báo đăng nhập bất thường, phê duyệt/chặn thiết bị và hỗ trợ điều tra sự cố bảo mật.',
                        ),
                      ],
                      accent: _accentGreen,
                    ),
                    SLSpacing.h12,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentGreen.withOpacity(0.08),
                        borderRadius: SLRadius.lgAll,
                        border: Border.all(
                          color: _accentGreen.withOpacity(0.16),
                        ),
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
                    SLSpacing.h12,
                    _buildPrimaryButton(
                      accent: _accentGreen,
                      label: 'Xem chi tiết Chính sách bảo mật',
                      icon: Icons.open_in_new_rounded,
                      onTap: () => _openDoc(
                        'Chính sách bảo mật',
                        'assets/docs/privacy.html',
                      ),
                    ),
                    SLSpacing.h12,
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(
                              foregroundColor: _accentGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              'Không bật lúc này',
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
                            accent: _accentGreen,
                            label: 'Bật bảo vệ thiết bị',
                            icon: Icons.shield_rounded,
                            onTap: () => Navigator.pop(ctx, true),
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
      ),
    );
  }

  Future<bool?> _showConsentDialog({
    required String title,
    required String subtitle,
    required String actionLabel,
    required String assetPath,
    required String checkboxLabel,
    required IconData leadingIcon,
    required Color accent,
    required List<_ConsentHighlight> highlightItems,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        bool checked = false;
        bool showRequiredHint = false;
        return StatefulBuilder(
          builder: (ctx, setState) => PopScope(
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
                      color: accent.withOpacity(0.12),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderIcon(accent: accent, icon: leadingIcon),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: SLTheme.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  SLSpacing.h4,
                                  Text(
                                    subtitle,
                                    style: SLTheme.quicksand(
                                      fontSize: 12.4,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SLSpacing.h12,
                        _buildHighlightList(highlightItems, accent: accent),
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          accent: accent,
                          label: actionLabel,
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(title, assetPath),
                        ),
                        SLSpacing.h8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: checked
                                ? accent.withOpacity(0.08)
                                : _cardBackground,
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(
                              color: checked
                                  ? accent.withOpacity(0.24)
                                  : _panelBorder,
                              width: checked ? 1.3 : 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: checked
                                    ? accent.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: checked ? 16 : 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              checked = !checked;
                              if (checked) showRequiredHint = false;
                            }),
                            borderRadius: SLRadius.lgAll,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (v) => setState(() {
                                    checked = v ?? false;
                                    if (checked) showRequiredHint = false;
                                  }),
                                  activeColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: SLRadius.smAll,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 11, bottom: 11),
                                    child: Text(
                                      checkboxLabel,
                                      style: SLTheme.quicksand(
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w800,
                                        color: _ink.withOpacity(0.9),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showRequiredHint) ...[
                          const SizedBox(height: 10),
                          _buildRequiredConsentHint(accent: accent),
                        ],
                        SLSpacing.h12,
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => showRequiredHint = true),
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'Không đồng ý',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 138,
                              child: _buildPrimaryButton(
                                accent: accent,
                                label: 'Tiếp tục',
                                icon: Icons.check_rounded,
                                onTap: checked
                                    ? () => Navigator.pop(ctx, true)
                                    : null,
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
          ),
        );
      },
    );
  }

  Future<String?> _showCookieConsentSheet() {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String level = 'all';
        bool showRequiredHint = false;
        return SafeArea(
          top: false,
          child: PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (ctx, setState) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
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
                        color: _accentBlue.withOpacity(0.12),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 54,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _panelBorder.withOpacity(0.8),
                              borderRadius: SLRadius.pillAll,
                            ),
                          ),
                        ),
                        SLSpacing.h8,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderIcon(
                              accent: _accentBlue,
                              icon: Icons.cookie_rounded,
                            ),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tùy chọn Cookie & lưu trữ',
                                    style: SLTheme.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  Text(
                                    'Chọn mức lưu trữ phù hợp để app hoạt động ổn định và bạn dễ kiểm soát quyền riêng tư hơn.',
                                    style: SLTheme.quicksand(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SLSpacing.h12,
                        _buildCookieChoiceCard(
                          value: 'essential',
                          groupValue: level,
                          accent: _accentBlue,
                          title: 'Thiết yếu',
                          subtitle:
                              'Giữ đăng nhập, consent pháp lý, bảo mật phiên và các chức năng cốt lõi của ứng dụng.',
                          bullets: const [
                            'Bắt buộc để app hoạt động ổn định.',
                            'Phù hợp nếu bạn muốn tối giản lưu trữ mở rộng.',
                          ],
                          onTap: () => setState(() {
                            level = 'essential';
                            showRequiredHint = false;
                          }),
                        ),
                        SLSpacing.h8,
                        _buildCookieChoiceCard(
                          value: 'all',
                          groupValue: level,
                          accent: _accentGreen,
                          title: 'Tất cả',
                          subtitle:
                              'Bao gồm thiết yếu, thêm cá nhân hóa, cache tiện ích và các dịch vụ mở rộng để trải nghiệm mượt hơn.',
                          bullets: const [
                            'Phù hợp nếu bạn muốn trải nghiệm đầy đủ hơn.',
                            'Cho phép nhiều dữ liệu cục bộ hơn để tăng tốc và cá nhân hóa.',
                          ],
                          badge: 'Mặc định',
                          onTap: () => setState(() {
                            level = 'all';
                            showRequiredHint = false;
                          }),
                        ),
                        if (showRequiredHint) ...[
                          const SizedBox(height: 10),
                          _buildRequiredConsentHint(accent: _accentBlue),
                        ],
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          accent: _accentBlue,
                          label: 'Xem chi tiết Chính sách Cookie',
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(
                            'Chính sách Cookie',
                            'assets/docs/cookie-policy.html',
                          ),
                        ),
                        SLSpacing.h12,
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => showRequiredHint = true),
                              style: TextButton.styleFrom(
                                foregroundColor: _accentRose,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'Không đồng ý',
                                style: SLTheme.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 138,
                              child: _buildPrimaryButton(
                                accent:
                                    level == 'all' ? _accentGreen : _accentBlue,
                                label: 'Xác nhận',
                                icon: Icons.check_rounded,
                                onTap: () => Navigator.pop(ctx, level),
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
          ),
        );
      },
    );
  }

  Widget _buildHeaderIcon({
    required Color accent,
    required IconData icon,
  }) {
    // Responsive scaling based on device pixel ratio
    // Standard baseline is 160 DPI (Android mdpi), scale up/down from there
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final scaleNormalization =
        1.6 / dpr; // Normalize to prevent over-scaling on low-DPI
    final containerSize = (42 * scaleNormalization).clamp(38.0, 46.0);
    final iconSize = (21 * scaleNormalization).clamp(18.0, 24.0);

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.18),
            accent.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: accent, size: iconSize),
    );
  }

  Widget _buildHighlightList(
    List<_ConsentHighlight> items, {
    required Color accent,
  }) {
    // Responsive scaling for highlight list icons
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final scaleNormalization = 1.6 / dpr;
    final containerSize = (32 * scaleNormalization).clamp(28.0, 36.0);
    final iconSize = (16 * scaleNormalization).clamp(14.0, 18.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = identical(item, items.last);
          return Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
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
                  width: containerSize,
                  height: containerSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.82),
                    borderRadius: SLRadius.smAll,
                    border: Border.all(color: accent.withOpacity(0.14)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, color: accent, size: iconSize),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: SLTheme.quicksand(
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      SLSpacing.gapH(2),
                      Text(
                        item.description,
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
        }).toList(),
      ),
    );
  }

  Widget _buildCookieChoiceCard({
    required String value,
    required String groupValue,
    required Color accent,
    required String title,
    required String subtitle,
    required List<String> bullets,
    String? badge,
    bool large = false,
    required VoidCallback onTap,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: large
            ? const EdgeInsets.fromLTRB(11, 13, 13, 13)
            : const EdgeInsets.fromLTRB(9, 11, 11, 11),
        decoration: BoxDecoration(
          color: selected
              ? Color.lerp(Colors.white, accent, 0.10)
              : _cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent.withOpacity(0.28) : _panelBorder,
            width: selected ? 1.35 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              blurRadius: selected ? 14 : 6,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(-6, 0),
              child: Radio<String>(
                value: value,
                groupValue: groupValue,
                onChanged: (_) => onTap(),
                activeColor: accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: large ? 16 : 14.1,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent.withOpacity(0.18)),
                        ),
                        child: Text(
                          badge,
                          style: SLTheme.quicksand(
                            fontSize: large ? 12 : 10.2,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: large ? 14 : 11.9,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ...bullets.map(
                      (bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                bullet,
                                style: SLTheme.quicksand(
                                  fontSize: large ? 13.5 : 11.55,
                                  fontWeight: FontWeight.w700,
                                  color: _ink.withOpacity(0.84),
                                  height: 1.28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDocLink({
    required Color accent,
    required String label,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(Icons.open_in_new_rounded, size: 14, color: accent),
        label: Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 11.8,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required Color accent,
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    bool scaleDownContent = false,
    bool compact = false,
    double fontSize = 13.8,
    double? verticalPadding,
  }) {
    final enabled = onTap != null;
    final endColor = Color.lerp(accent, Colors.black, 0.12) ?? accent;
    // Responsive scaling for button icons
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final buttonIconSize = (18 * (1.6 / dpr)).clamp(16.0, 20.0);

    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, endColor],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 18,
                  vertical: verticalPadding ?? (compact ? 10 : 13),
                ),
                child: FittedBox(
                  fit: scaleDownContent ? BoxFit.scaleDown : BoxFit.none,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: buttonIconSize),
                        SLSpacing.w8,
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredConsentHint({
    required Color accent,
  }) {
    // Responsive scaling for hint icon
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hintIconSize = (18 * (1.6 / dpr)).clamp(16.0, 20.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: accent,
            size: hintIconSize,
          ),
          SLSpacing.w8,
          Expanded(
            child: Text(
              'Bạn cần đồng ý để tiếp tục vào SoulLocket.',
              style: SLTheme.quicksand(
                fontSize: 11.6,
                fontWeight: FontWeight.w800,
                color: _ink.withOpacity(0.92),
                height: 1.26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFD81B60)),
      ),
    );
  }
}

class _ConsentHighlight {
  final IconData icon;
  final String title;
  final String description;

  const _ConsentHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _StartupConsentResult {
  final String cookieLevel;

  const _StartupConsentResult({
    required this.cookieLevel,
  });
}
