// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/sl_theme.dart';
import 'package:soullocket_app/core/sl_route.dart';
import '../../../utils/services/auth_service.dart';
import '../../../utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import '../../utilities/user_support_chat_screen.dart';
import '../screens/document_viewer_screen.dart';
import 'settings_tab.dart';

class UpdateTab extends StatefulWidget {
  const UpdateTab({super.key});

  @override
  State<UpdateTab> createState() => _UpdateTabState();
}

class _UpdateTabState extends State<UpdateTab> {
  static const String _version = 'v2.0.0+53';
  static const String _supportEmail = 'hotroviethoangdev.lo.ve@gmail.com';
  static final Uri _webAppUri = Uri.parse(AppConfig.webBaseUrl);
  static String? _cachedAdminUid;
  static Future<bool>? _cachedAdminFuture;

  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _isSendingFeedback = false;
  DateTime? _lastFeedbackSentAt;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    try {
      final isAdmin = await _adminFuture();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  bool get _isEnglish => L10nService().locale.languageCode == 'en';

  String _tr(String vi, String en) => _isEnglish ? en : vi;

  Future<bool> _adminFuture() {
    final uid = AuthService().currentUser?.uid.trim() ?? '';
    if (_cachedAdminFuture == null || _cachedAdminUid != uid) {
      _cachedAdminUid = uid;
      _cachedAdminFuture =
          AuthService().isCurrentUserAdmin().catchError((_) => false);
    }
    return _cachedAdminFuture!;
  }

  List<Map<String, dynamic>> _buildChangelog() {
    return [
      {
        'version': 'v1.0.0',
        'date': '21/03/2026',
        'items': [
          _tr(
            L10nService().translate('home_cpnhtmnhnh_399dec'),
            'Updated the new friends management screen with full Friends, Requests, and Search tabs.',
          ),
          _tr(
            'Sửa lỗi "ancestor path" khi tạo nhà mới trong Firebase.',
            'Fixed the "ancestor path" issue when creating a new house in Firebase.',
          ),
          _tr(
            'Gỡ bỏ thanh ${L10nService().translate('home_trltinch_918abe')} trong tab Tiện ích để giao diện thoáng hơn.',
            'Removed the "Utility Assistant" bar from the Utilities tab for a cleaner layout.',
          ),
          _tr(
            L10nService().translate('home_tiuhatctid_1c12b6'),
            'Improved community feed data loading performance.',
          ),
        ],
      },
      {
        'version': 'v0.9.9',
        'date': '20/03/2026',
        'items': [
          _tr(
            L10nService().translate('home_lmligiaodi_d4e0cf'),
            'Redesigned the Game, Theme, and Top Hot tabs.',
          ),
          _tr(
            L10nService().translate('home_tchhptnhnn_a52c8c'),
            'Integrated in-app chat with Admin/Bot.',
          ),
          _tr(
            L10nService().translate('home_cithinhthn_65e1b9'),
            'Improved the push notification system for anniversaries.',
          ),
        ],
      },
    ];
  }

  TextStyle _titleStyle({
    Color? color,
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
  }) {
    return SLTypography.titleLarge.copyWith(
      color: color,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
    );
  }

  TextStyle _bodyStyle({
    Color? color,
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
  }) {
    return SLTypography.bodyMedium.copyWith(
      color: color,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
    );
  }

  TextStyle _labelStyle({
    Color? color,
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
  }) {
    return SLTypography.labelLarge.copyWith(
      color: color,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
    );
  }

  void _openDoc(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => DocumentViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  void _openSupportContact(BuildContext context) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      SLRoute(builder: (_) => const UserSupportChatScreen()),
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    Uri uri, {
    String? clipboardFallback,
  }) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;

    if (clipboardFallback != null && clipboardFallback.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: clipboardFallback));
      } catch (_) {}
      if (context.mounted) {
        _showToast(
          context,
          _tr(
            L10nService().translate('home_khngmclink_4121d0'),
            'Could not open the link. Support details have been copied.',
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      _showToast(
        context,
        _tr(L10nService().translate('home_khngmclink_bfd120'),
            'Could not open the support link.'),
      );
    }
  }

  void _showToast(BuildContext context, String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      try {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
              style:
                  _labelStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF78A8),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      } catch (_) {}
    }

    // Fallback: Show Dialog when ScaffoldMessenger is not found in context tree
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFFFF4B91),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteGuide(BuildContext context) {
    _openDoc(
      context,
      title: _tr(L10nService().translate('home_hngdnxadli_a627ed'),
          'Data deletion guide'),
      assetPath: 'assets/docs/delete_account.html',
    );
  }

  void _showNewsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Container(
              padding: SLSpacing.fromLTRB(
                SLSpacing.lg,
                SLSpacing.sm,
                SLSpacing.lg,
                22,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: SLSpacing.only(bottom: SLSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: SLRadius.smAll,
                      ),
                    ),
                  ),
                  Text(
                    _tr(L10nService().translate('home_nhtkcpnht_028a74'),
                        'Update log'),
                    style: _titleStyle(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SLSpacing.h16,
                  ..._buildChangelog()
                      .map((log) => _buildChangelogSection(log)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChangelogSection(Map<String, dynamic> log) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: SLSpacing.symmetric(
                horizontal: 10,
                vertical: SLSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                borderRadius: SLRadius.smAll,
              ),
              child: Text(
                log['version'],
                style: _labelStyle(
                  color: const Color(0xFFD81B60),
                  fontSize: 13,
                ),
              ),
            ),
            SLSpacing.w8,
            Text(
              log['date'],
              style: _bodyStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        SLSpacing.h12,
        ...(log['items'] as List<String>).map((item) => Padding(
              padding:
                  SLSpacing.only(bottom: SLSpacing.xs, left: SLSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: SLSpacing.only(top: 6),
                    child:
                        const Icon(Icons.circle, size: 6, color: Colors.grey),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Text(
                      item,
                      style: _bodyStyle(
                        color: const Color(0xFF475569),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        const Divider(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    L10nScope.of(context); // Listen to locale changes
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF818CF8).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF472B6).withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: 50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: SLSpacing.fromLTRB(6, 16, 6, 120),
                    children: [
                      _buildHeroBoard(context),
                      SLSpacing.h16,
                      _buildUpcomingEventsBoard(context),
                      SLSpacing.h16,
                      _buildQuickActions(context),
                      SLSpacing.h16,
                      _buildRoadmapBoard(context),
                      SLSpacing.h16,
                      _buildGuideBoard(context),
                      SLSpacing.h16,
                      _buildSupportBoard(context, isAdmin: _isAdmin),
                      SLSpacing.h16,
                      _buildFeedbackPanel(context),
                      SLSpacing.h24,
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                      ).createShader(bounds),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _tr(L10nService().translate('home_updateiukh_a0963e'),
                              'UPDATE & TERMS'),
                          maxLines: 1,
                          softWrap: false,
                          style: SLTheme.quicksand(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.h4,
                    Container(
                      width: 100,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                        ),
                        borderRadius: SLRadius.pillAll,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      SLRoute(builder: (_) => const SettingsTab()),
                    );
                  },
                  icon: const Icon(Icons.settings_rounded,
                      color: Color(0xFFE91E63)),
                  tooltip: _tr('Cài đặt', 'Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBoard(BuildContext context) {
    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SLSpacing.xs,
            runSpacing: SLSpacing.xs,
            children: [
              _buildHeroBadge(Icons.auto_awesome_rounded, _version,
                  const Color(0xFFFFE4EE), const Color(0xFFD81B60)),
              _buildHeroBadge(
                  Icons.calendar_month_rounded,
                  _tr(L10nService().translate('home_cpnht19042_20d59f'),
                      'Updated: 19/04/2026'),
                  const Color(0xFFE3F2FD),
                  const Color(0xFF1976D2)),
              _buildHeroBadge(
                  Icons.verified_user_rounded,
                  _tr(L10nService().translate('home_tiliuanghi_9c3983'),
                      'Documents in effect'),
                  const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32)),
            ],
          ),
          SLSpacing.h16,
          Text(
            _tr(
              L10nService().translate('home_trungtmtil_39e391'),
              'SoulLocket documents, updates, and support hub',
            ),
            style: _titleStyle(
              color: const Color(0xFF1E293B),
              fontSize: 24,
              height: 1.25,
            ),
          ),
          SLSpacing.h12,
          Text(
            _tr(
              L10nService().translate('home_mnhanhbtil_6fca2a'),
              'Open the reviewed documents, check the current feature scope, and reach support from one place.',
            ),
            style: _bodyStyle(
              color: const Color(0xFF64748B),
              height: 1.7,
            ),
          ),
          SLSpacing.h16,
          Wrap(
            spacing: SLSpacing.sm,
            runSpacing: SLSpacing.sm,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openDoc(
                  context,
                  title: _tr(L10nService().translate('home_hngdnsdnga_1d5442'),
                      'App usage guide'),
                  assetPath: 'assets/docs/huong_dan.html',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  padding: SLSpacing.symmetric(
                    horizontal: SLSpacing.md,
                    vertical: SLSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(
                  _tr(L10nService().translate('home_mcmnang_75f237'),
                      'Open handbook'),
                  style: _labelStyle(color: Colors.white),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSupportContact(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFD0D7E2)),
                  padding: SLSpacing.symmetric(
                    horizontal: SLSpacing.md,
                    vertical: SLSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: Text(
                  _tr(L10nService().translate('home_chathtr_789f29'),
                      'Support chat'),
                  style: _labelStyle(color: const Color(0xFF334155)),
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: _buildMiniStatusCard(
                  _tr(L10nService().translate('home_tiliursot_29e838'),
                      'Docs reviewed'),
                  '19/04/2026',
                  _tr(
                    L10nService().translate('home_giithiuhng_541e3c'),
                    'About, guide, privacy, cookie, and terms documents.',
                  ),
                  Colors.white,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildMiniStatusCard(
                  _tr(L10nService().translate('home_trngthihtr_e796c9'),
                      'Support status'),
                  'Online',
                  _tr(
                    L10nService().translate('home_emailhtrch_d34a60'),
                    'Support email, in-app chat, and public web pages.',
                  ),
                  const Color(0xFFFFF8FB),
                  accent: const Color(0xFFD81B60),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsBoard(BuildContext context) {
    return _buildPanel(
      title: _tr(L10nService().translate('home_nhmtnhnnga_bd84d9'),
          'Current feature groups'),
      subtitle: _tr(
        L10nService().translate('home_tmttnhanhc_0268ff'),
        'A quick summary of the feature groups available in the current SoulLocket build.',
      ),
      child: Column(
        children: [
          _buildRoadmapItem(
            context,
            Icons.people_alt_rounded,
            _tr(L10nService().translate('home_communityn_852100'),
                'Community, messaging, and calls'),
            _tr(
              L10nService().translate('home_apphinccom_3e94dd'),
              'The app currently includes a community feed, direct chat, group chat, audio/video calls, and watch-together flows where those screens are available.',
            ),
            const Color(0xFFFFF8E1),
            const Color(0xFFF57C00),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.favorite_rounded,
            _tr(L10nService().translate('home_ngchchocpi_dbb10a'),
                'Important for couples'),
            _tr(
              L10nService().translate('home_soullocket_ab23d4'),
              'SoulLocket is currently designed for two people to share one account. To use it together, both people simply sign in with the same email and password, or with the exact same login method originally used for that account. At this time, the app does not provide any pairing flow, pair code, QR join flow, or account-linking system between two separate accounts.',
            ),
            const Color(0xFFF3E5F5),
            const Color(0xFF1976D2),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.apps_rounded,
            _tr(L10nService().translate('home_nhtktinchv_26aa94'),
                'Diary, utilities, and access'),
            _tr(
              L10nService().translate('home_cckhunhtkg_2626f2'),
              'Diary, games, gift flows, tarot, finance, Secret Vault, Time Capsule, AI support, and ads are available according to the screens and access level in this build.',
            ),
            const Color(0xFFE8F5E9),
            const Color(0xFF388E3C),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _buildPanel(
      title: _tr(
          L10nService().translate('home_truycpnhan_7f5e55'), 'Quick access'),
      subtitle: _tr(
        L10nService().translate('home_ccmcquantr_9f1e17'),
        'The most important items are grouped here for quick access.',
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: SLSpacing.sm,
        mainAxisSpacing: SLSpacing.sm,
        childAspectRatio: 1.65,
        children: [
          _buildQuickCard(
            _tr(L10nService().translate('home_hngdnsdng_14c212'),
                'Usage guide'),
            Icons.book_rounded,
            const Color(0xFF3B82F6),
            const Color(0xFF2563EB),
            Colors.white,
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_hngdnsdnga_1d5442'),
                  'App usage guide'),
              assetPath: 'assets/docs/huong_dan.html',
            ),
          ),
          _buildQuickCard(
            _tr(L10nService().translate('home_linhhthng_fc8a3f'),
                'Contact support'),
            Icons.headset_mic_rounded,
            const Color(0xFF64748B),
            const Color(0xFF475569),
            Colors.white,
            () => _openExternal(
              context,
              Uri(
                scheme: 'mailto',
                path: _supportEmail,
                queryParameters: const {'subject': 'SoulLocket Support'},
              ),
              clipboardFallback: _supportEmail,
            ),
          ),
          _buildQuickCard(
            _tr(L10nService().translate('home_chatviadmi_6daadf'),
                'Chat with admin'),
            Icons.smart_toy_rounded,
            const Color(0xFF10B981),
            const Color(0xFF059669),
            Colors.white,
            () => _openSupportContact(context),
          ),
          _buildQuickCard(
            _tr(L10nService().translate('home_nhntinmi_fa749d'), 'Latest news'),
            Icons.favorite_rounded,
            const Color(0xFFF43F5E),
            const Color(0xFFE11D48),
            Colors.white,
            () => _showNewsSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapBoard(BuildContext context) {
    return _buildPanel(
      title: _tr(
          L10nService().translate('home_imcpnhtgny_2402af'), 'Recent updates'),
      subtitle: _tr(
        L10nService().translate('home_ccthayilnb_86d55f'),
        'Changes that are already shipped and reflected in the current app.',
      ),
      child: Column(
        children: [
          _buildRoadmapItem(
            context,
            Icons.description_rounded,
            _tr(L10nService().translate('home_rsotlibtil_c2bfa0'),
                'Reviewed documentation set'),
            _tr(
              L10nService().translate('home_cpnhtlinid_80e47a'),
              'About, guide, privacy, cookie, terms, and deletion documents were revised to match the current feature scope.',
            ),
            const Color(0xFFFFF7FA),
            const Color(0xFFD81B60),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.public_rounded,
            _tr(L10nService().translate('home_qunlbnbmi_f15152'),
                'New friends management'),
            _tr(
              L10nService().translate('home_tabbnblimi_e6a654'),
              'Friends, Requests, and Search are now part of the friend management flow.',
            ),
            const Color(0xFFF7FBFF),
            const Color(0xFF1976D2),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.bug_report_rounded,
            _tr(L10nService().translate('home_tiuvsalinn_407716'),
                'Optimization and core fixes'),
            _tr(
              'Đã làm gọn một số lớp giao diện tiện ích và xử lý lỗi "ancestor path" khi người dùng tạo nhà mới.',
              'The utilities surface was simplified and the "ancestor path" error when creating a new house was fixed.',
            ),
            const Color(0xFFF7FCF8),
            const Color(0xFF2E7D32),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.auto_awesome_rounded,
            _tr(
              L10nService().translate('home_cctnhnngth_2479da'),
              'Fun features for couples',
            ),
            Platform.isIOS
                ? _tr(
                    L10nService().translate('home_khmphthmcc_928269'),
                    'Explore more fun features for couples in the app.',
                  )
                : _tr(
                    L10nService().translate('home_khmphthmcc_0ebf20'),
                    'Explore more fun features for couples, tap here to open the feature page.',
                  ),
            const Color(0xFFFFF9F2),
            const Color(0xFFFB8C00),
            linkText: Platform.isIOS
                ? null
                : _tr(L10nService().translate('home_nvoy_41b59d'), 'tap here'),
            linkUri: Platform.isIOS ? null : _webAppUri,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBoard(BuildContext context) {
    return _buildPanel(
      title: _tr(L10nService().translate('home_hngdnvchnh_546b71'),
          'Guides and policies'),
      subtitle: _tr(
        L10nService().translate('home_mnhanhbtil_b2996f'),
        'Open the reviewed document set aligned with the features currently available.',
      ),
      child: Column(
        children: [
          _buildGuideAction(
            _tr(L10nService().translate('home_giithiuvso_07b6ae'),
                'About SoulLocket'),
            Icons.info_rounded,
            const Color(0xFF00695C),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_giithiuvso_07b6ae'),
                  'About SoulLocket'),
              assetPath: 'assets/docs/about.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_mhngdnsdng_ccfed6'),
                'Open the app guide'),
            Icons.menu_book_rounded,
            const Color(0xFF2196F3),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_hngdnsdnga_1d5442'),
                  'App usage guide'),
              assetPath: 'assets/docs/huong_dan.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_hngdncitln_85abba'),
                'First setup guide'),
            Icons.rocket_launch_rounded,
            const Color(0xFF7B1FA2),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_hngdncitln_85abba'),
                  'First setup guide'),
              assetPath: 'assets/docs/huong_dan_cai_dat_lan_dau.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_chnhschbom_98b319'),
                'Privacy Policy'),
            Icons.privacy_tip_rounded,
            const Color(0xFFD81B60),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_chnhschbom_98b319'),
                  'Privacy Policy'),
              assetPath: 'assets/docs/privacy.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_iukhonsdng_9a9c73'),
                'Terms of Use'),
            Icons.gavel_rounded,
            const Color(0xFF6D4C41),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_iukhonsdng_9a9c73'),
                  'Terms of Use'),
              assetPath: 'assets/docs/terms.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_chnhschcoo_9209d0'),
                'Cookie Policy'),
            Icons.cookie_rounded,
            const Color(0xFFF57C00),
            () => _openDoc(
              context,
              title: _tr(L10nService().translate('home_chnhschcoo_9209d0'),
                  'Cookie Policy'),
              assetPath: 'assets/docs/cookie-policy.html',
            ),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_hngdnxadli_a627ed'),
                'Data deletion guide'),
            Icons.warning_amber_rounded,
            const Color(0xFFE53935),
            () => _showDeleteGuide(context),
          ),
          SLSpacing.h8,
          _buildGuideAction(
            _tr(L10nService().translate('home_trangyucux_92da02'),
                'Account deletion request page'),
            Icons.open_in_new_rounded,
            const Color(0xFFAD1457),
            () => _openExternal(
              context,
              Uri.parse(AppConfig.deleteAccountPageUrl),
              clipboardFallback: AppConfig.deleteAccountPageUrl,
            ),
          ),
          SLSpacing.h16,
          Container(
            padding: SLSpacing.symmetric(
              horizontal: SLSpacing.sm,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8EDF4)),
            ),
            child: Text(
              _tr(
                L10nService().translate('home_mimcsmtrct_0fb470'),
                'Each item opens the full document directly: about, app guide, first setup, privacy, terms, cookie, and data deletion. Last updated: 19/04/2026.',
              ),
              style: _bodyStyle(
                color: const Color(0xFF64748B),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportBoard(BuildContext context, {required bool isAdmin}) {
    return _buildPanel(
      title: _tr(
          L10nService().translate('home_knhhtr_c41104'), 'Support channels'),
      subtitle: _tr(
        L10nService().translate('home_nubngplicn_c74a63'),
        'If you hit an issue, need account help, or want to suggest a feature, use one of the channels below.',
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSupportButton(
                  'Email',
                  Icons.mail_rounded,
                  const Color(0xFFEF6C00),
                  () => _openExternal(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: _supportEmail,
                      queryParameters: const {
                        'subject': 'SoulLocket Support',
                      },
                    ),
                    clipboardFallback: _supportEmail,
                  ),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildSupportButton(
                  _tr('Chat Admin', 'Admin chat'),
                  Icons.smart_toy_rounded,
                  const Color(0xFF0288D1),
                  () => _openSupportContact(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Icon(Icons.favorite_border_rounded,
            size: 18, color: Colors.grey.withValues(alpha: 0.75)),
        SLSpacing.h4,
        Text(
          'SoulLocket $_version',
          style: _labelStyle(
            color: const Color(0xFFA1A1AA),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SLSpacing.h4,
        Text(
          _tr(
            L10nService().translate('home_2026soullo_5cd3ca'),
            '© 2026 SoulLocket • In-app documents and support channels.',
          ),
          textAlign: TextAlign.center,
          style: _bodyStyle(
            color: const Color(0xFFC4C4CC),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _titleStyle(
              color: const Color(0xFFD81B60),
              fontSize: 17,
            ),
          ),
          if (subtitle != null) ...[
            SLSpacing.gapH(6),
            Text(
              subtitle,
              style: _bodyStyle(
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ],
          SLSpacing.h16,
          child,
        ],
      ),
    );
  }

  Widget _buildHeroBadge(
    IconData icon,
    String label,
    Color bg,
    Color color,
  ) {
    return Container(
      padding: SLSpacing.symmetric(
        horizontal: SLSpacing.sm,
        vertical: SLSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: SLRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SLSpacing.gapW(6),
          Text(
            label,
            style: _labelStyle(
              color: color,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusCard(
    String title,
    String value,
    String note,
    Color bg, {
    Color accent = const Color(0xFF111827),
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _labelStyle(
              color: const Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SLSpacing.h4,
          Text(
            value,
            style: _titleStyle(
              color: accent,
              fontSize: 18,
            ),
          ),
          SLSpacing.h4,
          Text(
            note,
            style: _bodyStyle(
              color: const Color(0xFF64748B),
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard(
    String title,
    IconData icon,
    Color bg,
    Color border,
    Color textColor,
    VoidCallback onTap,
  ) {
    return _UpdateScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: SLSpacing.symmetric(horizontal: 12, vertical: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 48,
                color: bg.withValues(alpha: 0.2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bg.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: bg, size: 18),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(
                      color: const Color(0xFF1E293B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapItem(
    BuildContext context,
    IconData icon,
    String title,
    String body,
    Color bg,
    Color color, {
    String? linkText,
    Uri? linkUri,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _labelStyle(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SLSpacing.h4,
                _buildRoadmapBody(
                  context,
                  body,
                  linkText: linkText,
                  linkUri: linkUri,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapBody(
    BuildContext context,
    String body, {
    String? linkText,
    Uri? linkUri,
  }) {
    final textStyle = _bodyStyle(
      color: const Color(0xFF64748B),
      fontSize: 12.5,
      height: 1.6,
    );

    if (linkText == null || linkUri == null || !body.contains(linkText)) {
      return Text(body, style: textStyle);
    }

    final parts = body.split(linkText);

    return RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: parts.first),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openExternal(
                context,
                linkUri,
                clipboardFallback: linkUri.toString(),
              ),
              child: Text(
                linkText,
                style: textStyle.copyWith(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: parts.skip(1).join(linkText)),
        ],
      ),
    );
  }

  Widget _buildGuideAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.32), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  label,
                  style: _labelStyle(
                    color: Color.lerp(
                          const Color(0xFF111827),
                          color,
                          0.65,
                        ) ??
                        const Color(0xFF111827),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.75),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.15)),
        backgroundColor: color.withValues(alpha: 0.05),
        padding: SLSpacing.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: _labelStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildFeedbackPanel(BuildContext context) {
    return _buildPanel(
      title: _tr('Đóng góp ý kiến', 'Suggest a feature / Feedback'),
      subtitle: _tr(
        'Chúng tôi luôn lắng nghe ý kiến đóng góp của bạn để hoàn thiện SoulLocket mỗi ngày.',
        'We always listen to your suggestions to improve SoulLocket every day.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _feedbackCtrl,
            maxLines: 4,
            maxLength: 500,
            style: _bodyStyle(color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: _tr('Nhập ý kiến đóng góp của bạn ở đây...',
                  'Enter your feedback here...'),
              hintStyle: _bodyStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: Color(0xFFFF4B91)),
              ),
              counterStyle: _bodyStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ),
          SLSpacing.h12,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isSendingFeedback ? null : () => _sendFeedback(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B91),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.lgAll,
                ),
                elevation: 0,
              ),
              child: _isSendingFeedback
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _tr('Gửi đóng góp', 'Submit Feedback'),
                      style: _labelStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final content = _feedbackCtrl.text.trim();
    if (content.length < 5) {
      _showToast(
          context,
          _tr('Ý kiến đóng góp phải có ít nhất 5 ký tự!',
              'Feedback must be at least 5 characters!'));
      return;
    }
    if (content.length > 500) {
      _showToast(
          context,
          _tr('Ý kiến đóng góp tối đa 500 ký tự!',
              'Feedback must be at most 500 characters!'));
      return;
    }

    final user = AuthService().currentUser;
    if (user == null) {
      _showToast(
          context,
          _tr('Vui lòng đăng nhập để gửi ý kiến!',
              'Please log in to send feedback!'));
      return;
    }

    setState(() => _isSendingFeedback = true);

    try {
      final houseId = await HouseService().getCurrentHouseId();
      if (houseId == null || houseId.trim().isEmpty) {
        _showToast(
            context,
            _tr('Không thể xác định thông tin nhà. Vui lòng thử lại sau!',
                'Could not determine house information. Please try again later!'));
        setState(() => _isSendingFeedback = false);
        return;
      }

      // Kiểm tra chặn User UID hoặc House ID
      final blockedUidSnap = await FirebaseDatabase.instance
          .ref('sys_settings/blocked_feedbacks/uids/${user.uid}')
          .get();
      if (blockedUidSnap.exists && blockedUidSnap.value == true) {
        _showToast(
            context,
            _tr('Tài khoản của bạn đã bị chặn gửi ý kiến đóng góp.',
                'Your account has been blocked from sending feedback.'));
        setState(() => _isSendingFeedback = false);
        return;
      }

      final blockedHouseSnap = await FirebaseDatabase.instance
          .ref('sys_settings/blocked_feedbacks/houses/$houseId')
          .get();
      if (blockedHouseSnap.exists && blockedHouseSnap.value == true) {
        _showToast(
            context,
            _tr('Nhà của bạn đã bị chặn gửi ý kiến đóng góp.',
                'Your house has been blocked from sending feedback.'));
        setState(() => _isSendingFeedback = false);
        return;
      }

      final dbRef = FirebaseDatabase.instance.ref('house_feedbacks/$houseId');
      final snap = await dbRef.get();

      Map<String, dynamic> slots = {};
      if (snap.exists) {
        final val = snap.value;
        if (val is Map) {
          slots = val.map((k, v) =>
              MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
        } else if (val is List) {
          for (int i = 0; i < val.length; i++) {
            final item = val[i];
            if (item is Map) {
              slots['slot_$i'] = Map<String, dynamic>.from(item);
            }
          }
        }
      }

      String? targetSlot;
      for (final s in ['slot_1', 'slot_2', 'slot_3']) {
        if (!slots.containsKey(s)) {
          targetSlot = s;
          break;
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (targetSlot == null) {
        // Cả 3 slot đều đã có dữ liệu, tìm slot cũ nhất
        String oldestSlot = 'slot_1';
        num oldestTime = slots['slot_1']?['createdAt'] ?? 0;

        for (final s in ['slot_2', 'slot_3']) {
          final time = slots[s]?['createdAt'] ?? 0;
          if (time < oldestTime) {
            oldestSlot = s;
            oldestTime = time;
          }
        }

        final diff = nowMs - oldestTime;
        if (diff < 86400000) {
          final remainingMs = 86400000 - diff;
          final hours = remainingMs ~/ 3600000;
          final mins = (remainingMs % 3600000) ~/ 60000;
          _showToast(
            context,
            _tr(
              'Nhà của bạn đã gửi tối đa 3 ý kiến trong 24 giờ. Vui lòng đợi $hours giờ $mins phút!',
              'Your house has submitted max 3 feedbacks in 24 hours. Please wait $hours hours $mins minutes!',
            ),
          );
          setState(() => _isSendingFeedback = false);
          return;
        }

        targetSlot = oldestSlot;
      }

      // Ghi dữ liệu lên slot đã chọn
      await dbRef.child(targetSlot).set({
        'uid': user.uid,
        'email': user.email ?? 'anonymous',
        'content': content,
        'createdAt': ServerValue.timestamp,
      });

      _feedbackCtrl.clear();
      _lastFeedbackSentAt = DateTime.now();
      if (mounted) {
        _showToast(
            context,
            _tr('Cảm ơn bạn đã đóng góp ý kiến!',
                'Thank you for your feedback!'));
      }
    } catch (e) {
      debugPrint('[Feedback] Error sending feedback: $e');
      if (mounted) {
        _showToast(
            context,
            _tr('Không thể gửi ý kiến. Vui lòng thử lại sau!',
                'Could not send feedback. Please try again later!'));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingFeedback = false);
      }
    }
  }
}

class _UpdateScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _UpdateScaleOnPress({
    required this.child,
    required this.onTap,
  });

  @override
  State<_UpdateScaleOnPress> createState() => _UpdateScaleOnPressState();
}

class _UpdateScaleOnPressState extends State<_UpdateScaleOnPress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
