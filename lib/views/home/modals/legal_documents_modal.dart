import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
                color: _accentLavender.withValues(alpha: 0.12),
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
                  Text(
                    context.tr('home_chnhschiuk_b1904f'),
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    context.tr('home_vuilngxemx_a2d7c9'),
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
                        _buildTabButton('tos', context.tr('home_bomt_46487e'),
                            Icons.gavel_rounded, _accentRose),
                        SLSpacing.w8,
                        _buildTabButton(
                            'privacy',
                            context.tr('home_iukhon_bdeda1'),
                            Icons.privacy_tip_rounded,
                            _accentLavender),
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
                            context.tr('home_khngng_e6ce42'),
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
                          label: context.tr('home_tiptc_555f1f'),
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
          color: isActive ? accent.withValues(alpha: 0.15) : _cardBackground,
          borderRadius: SLRadius.mdAll,
          border: Border.all(
            color: isActive ? accent.withValues(alpha: 0.34) : _panelBorder,
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
            color: _accentRose.withValues(alpha: 0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentRose.withValues(alpha: 0.16)),
          ),
          child: Text(
            context.tr('home_trckhivoap_a78836'),
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
                title: context.tr('home_quynvtrchn_bb2554'),
                description: context.tr('home_lmrtrchnhi_ce82e7'),
                accent: _accentRose,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.groups_rounded,
                title: context.tr('home_quytccngng_8862e1'),
                description: context.tr('home_nuccnguynt_1015f9'),
                accent: _accentRose,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.workspace_premium_rounded,
                title: context.tr('home_provdchvs_00f86a'),
                description: context.tr('home_giithchcch_1cbbe5'),
                accent: _accentRose,
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        _buildPrimaryButton(
          label: context.tr('home_xemchititi_eda09f'),
          icon: Icons.open_in_new_rounded,
          accent: _accentRose,
          onTap: () => _openDoc(
              context.tr('home_iukhonsdng_b931f0'), 'assets/docs/terms.html'),
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
            color: _accentLavender.withValues(alpha: 0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentLavender.withValues(alpha: 0.16)),
          ),
          child: Text(
            context.tr('home_bngnytmttd_7ba1b0'),
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
                title: context.tr('home_dliucxl_cbc4d9'),
                description: context.tr('home_baogmnhvgp_7cae8c'),
                accent: _accentLavender,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.lock_outline_rounded,
                title: context.tr('home_mcchsdng_803f65'),
                description: context.tr('home_dngktnicpi_abde74'),
                accent: _accentLavender,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.manage_accounts_rounded,
                title: context.tr('home_quynkimsot_363315'),
                description: context.tr('home_bncthttgps_338c10'),
                accent: _accentLavender,
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        _buildPrimaryButton(
          label: context.tr('home_xemchititb_d4c7c5'),
          icon: Icons.open_in_new_rounded,
          accent: _accentLavender,
          onTap: () => _openDoc(
              context.tr('home_chnhschbom_98b319'), 'assets/docs/privacy.html'),
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
            color: _accentGreen.withValues(alpha: 0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentGreen.withValues(alpha: 0.16)),
          ),
          child: Text(
            context.tr('home_soullocket_3df71a'),
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
                title: context.tr('home_dliuclu_f572e2'),
                description: context.tr('home_modelmyhiu_a0b2e6'),
                accent: _accentGreen,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.public_rounded,
                title: context.tr('home_vtrgnngtip_a84a67'),
                description: context.tr('home_chsuyramct_3cfdc0'),
                accent: _accentGreen,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.security_rounded,
                title: context.tr('home_mcchsdng_803f65'),
                description: context.tr('home_cnhbongnhp_c8f63c'),
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
            color: _accentGreen.withValues(alpha: 0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentGreen.withValues(alpha: 0.16)),
          ),
          child: Text(
            context.tr('home_nubnkhngbt_347436'),
            style: SLTheme.quicksand(
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
              color: _ink.withValues(alpha: 0.9),
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
            color: _accentBlue.withValues(alpha: 0.08),
            borderRadius: SLRadius.lgAll,
            border: Border.all(color: _accentBlue.withValues(alpha: 0.16)),
          ),
          child: Text(
            context.tr('home_chngtisdng_5b806c'),
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
                title: context.tr('home_cookiescnt_91dc47'),
                description: context.tr('home_cnthitsoul_2d6da0'),
                accent: _accentBlue,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.analytics_rounded,
                title: context.tr('home_cookiesphn_3ea21d'),
                description: context.tr('home_gipchngtih_99fd82'),
                accent: _accentBlue,
              ),
              SLSpacing.h10,
              _buildDocItem(
                icon: Icons.campaign_rounded,
                title: context.tr('home_cookiestip_7fd163'),
                description: context.tr('home_csdnghinth_be761d'),
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
        color: accent.withValues(alpha: 0.06),
        borderRadius: SLRadius.mdAll,
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: SLRadius.smAll,
              border: Border.all(color: accent.withValues(alpha: 0.14)),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.24),
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
