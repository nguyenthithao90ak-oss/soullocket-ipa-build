import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/consent_service.dart';
import '../home/screens/document_viewer_screen.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';

part 'consent_gate/models/consent_models.dart';
part 'consent_gate/widgets/consent_header.dart';
part 'consent_gate/widgets/consent_legal_section.dart';
part 'consent_gate/widgets/consent_cookie_section.dart';
part 'consent_gate/widgets/consent_ack_bar.dart';
part 'consent_gate/widgets/consent_highlight_list.dart';
part 'consent_gate/widgets/consent_scroll_hint.dart';

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

const Color _accentRose = Color(0xFFE65372);
const Color _accentLavender = Color(0xFF8F72D8);
const Color _accentBlue = Color(0xFF5D8DE8);
const Color _accentGreen = Color(0xFF2C9B86);
const Color _ink = Color(0xFF3B2830);
const Color _muted = Color(0xFF79646D);
const Color _panelBorder = Color(0xFFF0DDE3);
const Color _dialogBg = Color(0xFFFFFDF9);
const Color _surfaceBg = Color(0xFFFFF5F7);
const Color _dialogBackgroundTop = Color(0xFFFFFDF9);
const Color _dialogBackgroundBottom = Color(0xFFF4EEFF);
const Color _cardBackground = Color(0xFFFFFEFC);

Future<void> _openDoc(
    BuildContext context, String title, String assetPath) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DocumentViewerScreen(
        title: title,
        assetPath: assetPath,
      ),
    ),
  );
}

class _ConsentGateState extends State<ConsentGate> {
  static const bool _appReviewConsentBypass =
      bool.fromEnvironment('APP_REVIEW_BYPASS_CONSENT', defaultValue: false);

  final ConsentService _consentService = ConsentService();
  bool _ready = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      if (_appReviewConsentBypass) {
        await _seedAppReviewConsent();
        if (!mounted) return;
        setState(() => _ready = true);
        return;
      }
      _ensureConsent();
    });
  }

  Future<void> _seedAppReviewConsent() async {
    await _consentService.setTosAccepted(true);
    await _consentService.setPrivacyAccepted(true);
    await _consentService.setCookieConsentLevel('essential');
  }

  Future<void> _ensureConsent() async {
    if (_running) return;
    _running = true;
    try {
      if (!mounted) return;
      var hasStartupConsent = _consentService.hasValidConsentSync();
      if (!hasStartupConsent) {
        hasStartupConsent = await _consentService.hasValidConsent();
      }
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
          debugPrint(
              'ConsentGate onReady error: ${AppErrorMapper.resolve(e).message}');
        }
      });
    } catch (e) {
      debugPrint('ConsentGate failed: ${AppErrorMapper.resolve(e).message}');
      if (!mounted) return;
      setState(() => _ready = true);
    } finally {
      _running = false;
    }
  }

  Future<_StartupConsentResult?> _showStartupConsentDialog({
    String? initialCookieLevel,
  }) {
    return showDialog<_StartupConsentResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: const Color(0xFF18191B),
      builder: (ctx) {
        final l10n = L10nService();
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: const Color(0xFF18191B),
            child: Scaffold(
              backgroundColor: const Color(0xFF18191B),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Brand Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242527),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333538)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 13,
                              color: Color(0xFFFF5277),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'SoulLocket Privacy',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE4E6EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Title exactly like Image 1
                      Text(
                        l10n.translate('Điều khoản và Chính sách quyền riêng tư của SoulLocket'),
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.28,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Subtitle & Interactive RichText exactly like Image 1
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 14.5,
                            height: 1.55,
                            color: Color(0xFFB0B3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: l10n.translate('Bằng cách tiếp tục, bạn đồng ý với '),
                            ),
                            TextSpan(
                              text: l10n.translate('Điều khoản của SoulLocket'),
                              style: const TextStyle(
                                color: Color(0xFF4599FF),
                                fontWeight: FontWeight.w800,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openDoc(
                                      ctx,
                                      l10n.translate('Điều khoản dịch vụ'),
                                      'assets/docs/terms.html',
                                    ),
                            ),
                            TextSpan(
                              text: l10n.translate(' và '),
                            ),
                            TextSpan(
                              text: l10n.translate('Chính sách quyền riêng tư của chúng tôi'),
                              style: const TextStyle(
                                color: Color(0xFF4599FF),
                                fontWeight: FontWeight.w800,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openDoc(
                                      ctx,
                                      l10n.translate('Chính sách quyền riêng tư'),
                                      'assets/docs/privacy.html',
                                    ),
                            ),
                            TextSpan(
                              text: l10n.translate(
                                '. SoulLocket bảo vệ không gian riêng tư của hai bạn bằng hệ thống mã hóa an toàn. Bạn có thể kiểm tra hoặc quản lý cài đặt bất cứ lúc nào. ',
                              ),
                            ),
                            TextSpan(
                              text: l10n.translate('Tìm hiểu thêm'),
                              style: const TextStyle(
                                color: Color(0xFF4599FF),
                                fontWeight: FontWeight.w800,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showMetaStyleLearnMore(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Clean Meta/Apple-style Trust Highlights
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242527),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF333538), width: 1.1),
                        ),
                        child: Column(
                          children: [
                            _buildMetaPrivacyBullet(
                              icon: Icons.favorite_border_rounded,
                              iconColor: const Color(0xFFFF6987),
                              title: l10n.translate('Không gian riêng hai người'),
                              desc: l10n.translate('Hình ảnh và khoảnh khắc chỉ hiển thị riêng cho hai bạn.'),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Color(0xFF383A3D), height: 1),
                            ),
                            _buildMetaPrivacyBullet(
                              icon: Icons.shield_outlined,
                              iconColor: const Color(0xFF4599FF),
                              title: l10n.translate('Bảo mật dữ liệu tuyệt đối'),
                              desc: l10n.translate('Cam kết không bao giờ bán dữ liệu cho bên thứ ba.'),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Color(0xFF383A3D), height: 1),
                            ),
                            _buildMetaPrivacyBullet(
                              icon: Icons.lock_outline_rounded,
                              iconColor: const Color(0xFF4CD964),
                              title: l10n.translate('Bạn luôn làm chủ'),
                              desc: l10n.translate('Toàn quyền xuất hoặc xóa vĩnh viễn dữ liệu bất kỳ lúc nào.'),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Bottom Meta Blue CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop(
                              const _StartupConsentResult(cookieLevel: 'all'),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0064E0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            l10n.translate('Tiếp tục'),
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Bottom Home bar indicator
                      Center(
                        child: Container(
                          width: 134,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4E4F52),
                            borderRadius: BorderRadius.circular(3),
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
  }

  Widget _buildMetaPrivacyBullet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB0B3B8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMetaStyleLearnMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF242527),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        final l10n = L10nService();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4E4F52),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.translate('Cam kết bảo mật của SoulLocket'),
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.translate(
                    '1. Hình ảnh và khoảnh khắc được lưu trữ an toàn trên đám mây Cloudflare R2 mã hóa.\n\n'
                    '2. Chỉ có bạn và người ghép đôi mới xem được nội dung trong nhà chung.\n\n'
                    '3. Ứng dụng không theo dõi hành vi và không bán dữ liệu cho bên thứ ba.\n\n'
                    '4. Bạn có toàn quyền xuất hoặc xóa vĩnh viễn dữ liệu tài khoản bất cứ lúc nào.',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFFB0B3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(bottomCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0064E0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: Text(
                      l10n.translate('Đã hiểu'),
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
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
  }

  Future<bool?> _showPrivacyDialog() {
    return _showConsentDialog(
      title: context.tr('consent_chnhschbom_98b319'),
      subtitle: context.tr('consent_bngnytmttd_7ba1b0'),
      actionLabel: context.tr('consent_xemchititb_d4c7c5'),
      assetPath: 'assets/docs/privacy.html',
      checkboxLabel: context.tr('consent_ticvngvich_383523'),
      leadingIcon: Icons.privacy_tip_rounded,
      accent: _accentLavender,
      highlightItems: [
        _ConsentHighlight(
          icon: Icons.folder_shared_rounded,
          title: context.tr('consent_dliucxl_cbc4d9'),
          description: context.tr('consent_baogmnhvgp_7cae8c'),
        ),
        _ConsentHighlight(
          icon: Icons.lock_outline_rounded,
          title: context.tr('consent_mcchsdng_803f65'),
          description: context.tr('consent_dngktnicpi_abde74'),
        ),
        _ConsentHighlight(
          icon: Icons.manage_accounts_rounded,
          title: context.tr('consent_quynkimsot_363315'),
          description: context.tr('consent_bncthttgps_338c10'),
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
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _panelBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _accentGreen.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
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
                          ctx,
                          accent: _accentGreen,
                          icon: Icons.verified_user_rounded,
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('consent_bomtthitbv_6b7891'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                context.tr('consent_soullocket_3df71a'),
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
                      ctx,
                      [
                        _ConsentHighlight(
                          icon: Icons.phone_iphone_rounded,
                          title: context.tr('consent_dliuclu_f572e2'),
                          description: context.tr('consent_modelmyhiu_a0b2e6'),
                        ),
                        _ConsentHighlight(
                          icon: Icons.public_rounded,
                          title: context.tr('consent_vtrgnngtip_a84a67'),
                          description: context.tr('consent_chsuyramct_3cfdc0'),
                        ),
                        _ConsentHighlight(
                          icon: Icons.security_rounded,
                          title: context.tr('consent_mcchsdng_803f65'),
                          description: context.tr('consent_cnhbongnhp_c8f63c'),
                        ),
                      ],
                      accent: _accentGreen,
                    ),
                    SLSpacing.h12,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.08),
                        borderRadius: SLRadius.lgAll,
                        border: Border.all(
                          color: _accentGreen.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        context.tr('consent_nubnkhngbt_347436'),
                        style: SLTheme.quicksand(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                          color: _ink.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ),
                    SLSpacing.h12,
                    _buildPrimaryButton(
                      ctx,
                      accent: _accentGreen,
                      label: context.tr('consent_xemchititc_1cad13'),
                      icon: Icons.open_in_new_rounded,
                      onTap: () => _openDoc(
                        ctx,
                        context.tr('consent_chnhschbom_98b319'),
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
                              context.tr('consent_khngbtlcny_fff385'),
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
                            ctx,
                            accent: _accentGreen,
                            label: context.tr('consent_btbovthitb_ce67e5'),
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
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_dialogBackgroundTop, _dialogBackgroundBottom],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _panelBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: const Color(0xFF3B2830).withValues(alpha: 0.05),
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
                            _buildHeaderIcon(ctx,
                                accent: accent, icon: leadingIcon),
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
                        _buildHighlightList(ctx, highlightItems,
                            accent: accent),
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          ctx,
                          accent: accent,
                          label: actionLabel,
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(ctx, title, assetPath),
                        ),
                        SLSpacing.h8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: checked
                                ? accent.withValues(alpha: 0.08)
                                : _cardBackground,
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(
                              color: checked
                                  ? accent.withValues(alpha: 0.24)
                                  : _panelBorder,
                              width: checked ? 1.3 : 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: checked
                                    ? accent.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.03),
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
                                        color: _ink.withValues(alpha: 0.9),
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
                          _buildRequiredConsentHint(ctx, accent: accent),
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
                                context.tr('consent_khngng_e6ce42'),
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
                                ctx,
                                accent: accent,
                                label: context.tr('consent_tiptc_555f1f'),
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
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _panelBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentBlue.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
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
                              color: _panelBorder.withValues(alpha: 0.8),
                              borderRadius: SLRadius.pillAll,
                            ),
                          ),
                        ),
                        SLSpacing.h8,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderIcon(
                              ctx,
                              accent: _accentBlue,
                              icon: Icons.cookie_rounded,
                            ),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('consent_tychncooki_f0907c'),
                                    style: SLTheme.quicksand(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  Text(
                                    context.tr('consent_chnmclutrp_061bfc'),
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
                          title: context.tr('consent_thityu_cd979a'),
                          subtitle: context.tr('consent_gingnhpcon_525036'),
                          bullets: [
                            context.tr('consent_btbucappho_b21b5b'),
                            context.tr('consent_phhpnubnmu_575815'),
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
                          title: context.tr('consent_ttc_d8586d'),
                          subtitle: context.tr('consent_baogmthity_291746'),
                          bullets: [
                            context.tr('consent_phhpnubnmu_4875ce'),
                            context.tr('consent_chophpnhiu_2f2045'),
                          ],
                          badge: context.tr('consent_mcnh_a57a8e'),
                          onTap: () => setState(() {
                            level = 'all';
                            showRequiredHint = false;
                          }),
                        ),
                        if (showRequiredHint) ...[
                          const SizedBox(height: 10),
                          _buildRequiredConsentHint(ctx, accent: _accentBlue),
                        ],
                        SLSpacing.h12,
                        _buildPrimaryButton(
                          ctx,
                          accent: _accentBlue,
                          label: context.tr('consent_xemchititc_de27c6'),
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openDoc(
                            ctx,
                            context.tr('consent_chnhschcoo_9209d0'),
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
                                context.tr('consent_khngng_e6ce42'),
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
                                ctx,
                                accent:
                                    level == 'all' ? _accentGreen : _accentBlue,
                                label: context.tr('consent_xcnhn_1e2eb2'),
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

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
