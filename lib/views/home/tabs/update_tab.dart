import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/sl_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/l10n_service.dart';
import '../../utilities/user_support_chat_screen.dart';
import '../screens/document_viewer_screen.dart';

class UpdateTab extends StatelessWidget {
  const UpdateTab({super.key});

  static const String _version = 'v1.0.0';
  static const String _supportEmail = 'hotroviethoangdev.lo.ve@gmail.com';
  static final Uri _webAppUri = Uri.parse(AppConfig.webBaseUrl);
  static String? _cachedAdminUid;
  static Future<bool>? _cachedAdminFuture;

  bool get _isEnglish => L10nService().locale.languageCode == 'en';

  String _tr(String vi, String en) => _isEnglish ? en : vi;

  Future<bool> _adminFuture() {
    final uid = AuthService().currentUser?.uid.trim() ?? '';
    if (_cachedAdminFuture == null || _cachedAdminUid != uid) {
      _cachedAdminUid = uid;
      _cachedAdminFuture = AuthService().isCurrentUserAdmin();
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
            'Cập nhật màn hình quản lý bạn bè mới với đầy đủ Tab Bạn bè, Lời mời và Tìm kiếm.',
            'Updated the new friends management screen with full Friends, Requests, and Search tabs.',
          ),
          _tr(
            'Sửa lỗi "ancestor path" khi tạo nhà mới trong Firebase.',
            'Fixed the "ancestor path" issue when creating a new house in Firebase.',
          ),
          _tr(
            'Gỡ bỏ thanh "Trợ lý Tiện Ích" trong tab Tiện ích để giao diện thoáng hơn.',
            'Removed the "Utility Assistant" bar from the Utilities tab for a cleaner layout.',
          ),
          _tr(
            'Tối ưu hóa tốc độ tải dữ liệu cho bảng tin cộng đồng.',
            'Improved community feed data loading performance.',
          ),
        ],
      },
      {
        'version': 'v0.9.9',
        'date': '20/03/2026',
        'items': [
          _tr(
            'Làm lại giao diện các tab Game, Giao diện và Top Hot.',
            'Redesigned the Game, Theme, and Top Hot tabs.',
          ),
          _tr(
            'Tích hợp tính năng Chat với Admin/Bot ngay trong ứng dụng.',
            'Integrated in-app chat with Admin/Bot.',
          ),
          _tr(
            'Cải thiện hệ thống thông báo đẩy cho ngày kỷ niệm.',
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

  void _openSupportContact(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSupportChatScreen()),
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    Uri uri, {
    String? clipboardFallback,
  }) async {
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (ok || !context.mounted) return;

    if (clipboardFallback != null && clipboardFallback.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: clipboardFallback));
      if (context.mounted) {
        _showToast(
          context,
          _tr(
            'Không mở được liên kết. Mình đã sao chép thông tin hỗ trợ.',
            'Could not open the link. Support details have been copied.',
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      _showToast(
        context,
        _tr('Không mở được liên kết hỗ trợ.',
            'Could not open the support link.'),
      );
    }
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: _labelStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteGuide(BuildContext context) {
    _openDoc(
      context,
      title: _tr('Hướng dẫn xóa dữ liệu', 'Data deletion guide'),
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
                    _tr('Nhật ký cập nhật', 'Update log'),
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
                color: const Color(0xFFD81B60).withOpacity(0.1),
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
    return FutureBuilder<bool>(
      future: _adminFuture(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
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
                      _buildSupportBoard(context, isAdmin: isAdmin),
                      SLSpacing.h24,
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                          _tr('UPDATE & ĐIỀU KHOẢN', 'UPDATE & TERMS'),
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
              SLSpacing.gapW(36),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5F7), Color(0xFFF4F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF7CAD8)),
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
                  _tr('Cập nhật: 19/04/2026', 'Updated: 19/04/2026'),
                  const Color(0xFFE3F2FD),
                  const Color(0xFF1976D2)),
              _buildHeroBadge(
                  Icons.verified_user_rounded,
                  _tr('Tài liệu đang hiệu lực', 'Documents in effect'),
                  const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32)),
            ],
          ),
          SLSpacing.h16,
          Text(
            _tr(
              'Trung tâm tài liệu, cập nhật và hỗ trợ của SoulLocket',
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
              'Mở nhanh bộ tài liệu đã rà soát, xem phạm vi tính năng hiện có và đi thẳng tới kênh hỗ trợ ngay tại đây.',
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
                  title: _tr('Hướng dẫn sử dụng app', 'App usage guide'),
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
                    borderRadius: SLRadius.lgAll,
                  ),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(
                  _tr('Mở cẩm nang', 'Open handbook'),
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
                    borderRadius: SLRadius.lgAll,
                  ),
                ),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: Text(
                  _tr('Chat hỗ trợ', 'Support chat'),
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
                  _tr('Tài liệu đã rà soát', 'Docs reviewed'),
                  '19/04/2026',
                  _tr(
                    'Giới thiệu, hướng dẫn, bảo mật, cookie và điều khoản.',
                    'About, guide, privacy, cookie, and terms documents.',
                  ),
                  Colors.white,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildMiniStatusCard(
                  _tr('Trạng thái hỗ trợ', 'Support status'),
                  'Online',
                  _tr(
                    'Email hỗ trợ, chat trong app và trang web công khai.',
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
      title: _tr('Nhóm tính năng đang có', 'Current feature groups'),
      subtitle: _tr(
        'Tóm tắt nhanh các cụm tính năng đang có trong bản hiện tại của SoulLocket.',
        'A quick summary of the feature groups available in the current SoulLocket build.',
      ),
      child: Column(
        children: [
          _buildRoadmapItem(
            context,
            Icons.people_alt_rounded,
            _tr('Community, nhắn tin và gọi',
                'Community, messaging, and calls'),
            _tr(
              'App hiện có community feed, chat chi tiết, chat nhóm, gọi audio/video và luồng xem cùng nhau trong phạm vi các màn đã triển khai.',
              'The app currently includes a community feed, direct chat, group chat, audio/video calls, and watch-together flows where those screens are available.',
            ),
            const Color(0xFFFFF8E1),
            const Color(0xFFF57C00),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.favorite_rounded,
            _tr('Đáng chú ý cho cặp đôi', 'Important for couples'),
            _tr(
              'SoulLocket hiện được thiết kế theo hướng hai bạn dùng chung một tài khoản. Để dùng cùng nhau, cả hai chỉ cần đăng nhập bằng cùng email và mật khẩu, hoặc cùng đúng phương thức đăng nhập đã tạo tài khoản trước đó. Hiện tại app chưa có bất kỳ cơ chế ghép nối, pair code, quét QR hay liên kết hai tài khoản riêng biệt với nhau.',
              'SoulLocket is currently designed for two people to share one account. To use it together, both people simply sign in with the same email and password, or with the exact same login method originally used for that account. At this time, the app does not provide any pairing flow, pair code, QR join flow, or account-linking system between two separate accounts.',
            ),
            const Color(0xFFF3E5F5),
            const Color(0xFF1976D2),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.apps_rounded,
            _tr('Nhật ký, tiện ích và quyền lợi',
                'Diary, utilities, and access'),
            _tr(
              'Các khu nhật ký, game, quà tặng, tarot, tài chính, Secret Vault, Time Capsule, AI hỗ trợ, PRO/mua gói và quảng cáo được hiển thị theo phạm vi màn hình và quyền truy cập hiện có.',
              'Diary, games, gift flows, tarot, finance, Secret Vault, Time Capsule, AI support, PRO purchases, and ads are available according to the screens and access level in this build.',
            ),
            const Color(0xFFE8F5E9),
            const Color(0xFF388E3C),
          ),
          if (!Platform.isIOS) ...[
            SLSpacing.h12,
            _buildRoadmapItem(
              context,
              Icons.public_rounded,
              _tr('Android và truy cập web', 'Android and web access'),
              _tr(
                'Ngoài bản app, tài liệu công khai và một số luồng hỗ trợ có thể truy cập qua web tại ${AppConfig.webHost}. Trải nghiệm và phạm vi tính năng trên web có thể khác bản ứng dụng.',
                'Besides the app build, public documents and some support flows are available on the web at ${AppConfig.webHost}. The web experience and feature scope may differ from the app.',
              ),
              const Color(0xFFF8FAFC),
              const Color(0xFF334155),
              linkText: AppConfig.webHost,
              linkUri: _webAppUri,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _buildPanel(
      title: _tr('Truy cập nhanh', 'Quick access'),
      subtitle: _tr(
        'Các mục quan trọng nhất được gom vào một chỗ để mở nhanh.',
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
            _tr('Hướng dẫn sử dụng', 'Usage guide'),
            Icons.book_rounded,
            const Color(0xFF2196F3),
            () => _openDoc(
              context,
              title: _tr('Hướng dẫn sử dụng app', 'App usage guide'),
              assetPath: 'assets/docs/huong_dan.html',
            ),
          ),
          _buildQuickCard(
            _tr('Liên hệ hệ thống', 'Contact support'),
            Icons.headset_mic_rounded,
            const Color(0xFF263238),
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
            _tr('Chat với admin', 'Chat with admin'),
            Icons.smart_toy_rounded,
            const Color(0xFF0288D1),
            () => _openSupportContact(context),
          ),
          _buildQuickCard(
            _tr('Nhận tin mới', 'Latest news'),
            Icons.favorite_rounded,
            const Color(0xFFF06292),
            () => _showNewsSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapBoard(BuildContext context) {
    return _buildPanel(
      title: _tr('Điểm cập nhật gần đây', 'Recent updates'),
      subtitle: _tr(
        'Các thay đổi đã lên bản và đang phản ánh trong ứng dụng hiện tại.',
        'Changes that are already shipped and reflected in the current app.',
      ),
      child: Column(
        children: [
          _buildRoadmapItem(
            context,
            Icons.description_rounded,
            _tr('Rà soát lại bộ tài liệu', 'Reviewed documentation set'),
            _tr(
              'Đã cập nhật lại nội dung giới thiệu, hướng dẫn, bảo mật, cookie, điều khoản và hướng dẫn xóa dữ liệu theo đúng phạm vi tính năng đang có.',
              'About, guide, privacy, cookie, terms, and deletion documents were revised to match the current feature scope.',
            ),
            const Color(0xFFFFF7FA),
            const Color(0xFFD81B60),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.public_rounded,
            _tr('Quản lý bạn bè mới', 'New friends management'),
            _tr(
              'Tab Bạn bè, Lời mời và Tìm kiếm đã được đưa vào luồng quản lý bạn bè.',
              'Friends, Requests, and Search are now part of the friend management flow.',
            ),
            const Color(0xFFF7FBFF),
            const Color(0xFF1976D2),
          ),
          SLSpacing.h12,
          _buildRoadmapItem(
            context,
            Icons.bug_report_rounded,
            _tr('Tối ưu và sửa lỗi nền', 'Optimization and core fixes'),
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
              'Các tính năng thú vị cho cặp đôi',
              'Fun features for couples',
            ),
            _tr(
              'Khám phá thêm các tính năng thú vị dành cho cặp đôi, ấn vào đây để chuyển hướng sang trang tổng hợp tính năng.',
              'Explore more fun features for couples, tap here to open the feature page.',
            ),
            const Color(0xFFFFF9F2),
            const Color(0xFFFB8C00),
            linkText: _tr('ấn vào đây', 'tap here'),
            linkUri: _webAppUri,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBoard(BuildContext context) {
    return _buildPanel(
      title: _tr('Hướng dẫn và chính sách', 'Guides and policies'),
      subtitle: _tr(
        'Mở nhanh bộ tài liệu đã được rà soát lại theo đúng tính năng hiện có.',
        'Open the reviewed document set aligned with the features currently available.',
      ),
      child: Column(
        children: [
          _buildGuideAction(
            _tr('Giới thiệu về SoulLocket', 'About SoulLocket'),
            Icons.info_rounded,
            const Color(0xFF00695C),
            () => _openDoc(
              context,
              title: _tr('Giới thiệu về SoulLocket', 'About SoulLocket'),
              assetPath: 'assets/docs/about.html',
            ),
          ),
          SLSpacing.h12,
          _buildGuideAction(
            _tr('Mở hướng dẫn sử dụng app', 'Open the app guide'),
            Icons.menu_book_rounded,
            const Color(0xFF2196F3),
            () => _openDoc(
              context,
              title: _tr('Hướng dẫn sử dụng app', 'App usage guide'),
              assetPath: 'assets/docs/huong_dan.html',
            ),
          ),
          SLSpacing.h12,
          _buildGuideAction(
            _tr('Chính sách bảo mật', 'Privacy Policy'),
            Icons.privacy_tip_rounded,
            const Color(0xFFD81B60),
            () => _openDoc(
              context,
              title: _tr('Chính sách bảo mật', 'Privacy Policy'),
              assetPath: 'assets/docs/privacy.html',
            ),
          ),
          SLSpacing.h12,
          _buildGuideAction(
            _tr('Điều khoản sử dụng', 'Terms of Use'),
            Icons.gavel_rounded,
            const Color(0xFF6D4C41),
            () => _openDoc(
              context,
              title: _tr('Điều khoản sử dụng', 'Terms of Use'),
              assetPath: 'assets/docs/terms.html',
            ),
          ),
          SLSpacing.h12,
          _buildGuideAction(
            _tr('Chính sách Cookie', 'Cookie Policy'),
            Icons.cookie_rounded,
            const Color(0xFFF57C00),
            () => _openDoc(
              context,
              title: _tr('Chính sách Cookie', 'Cookie Policy'),
              assetPath: 'assets/docs/cookie-policy.html',
            ),
          ),
          SLSpacing.h12,
          _buildGuideAction(
            _tr('Hướng dẫn xóa dữ liệu', 'Data deletion guide'),
            Icons.warning_amber_rounded,
            const Color(0xFFE53935),
            () => _showDeleteGuide(context),
          ),
          SLSpacing.h12,
          Container(
            padding: SLSpacing.symmetric(
              horizontal: SLSpacing.sm,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: SLRadius.mdAll,
              border: Border.all(color: const Color(0xFFE8EDF4)),
            ),
            child: Text(
              _tr(
                'Mỗi mục sẽ mở trực tiếp tài liệu đầy đủ. Cập nhật lần cuối: 19/04/2026.',
                'Each item opens the full document directly. Last updated: 19/04/2026.',
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
      title: _tr('Kênh hỗ trợ', 'Support channels'),
      subtitle: _tr(
        'Nếu bạn gặp lỗi, cần hỗ trợ tài khoản hoặc muốn góp ý tính năng, hãy dùng một trong các kênh dưới đây.',
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
            size: 18, color: Colors.grey.withOpacity(0.75)),
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
            '© 2026 SoulLocket • Tài liệu và kênh hỗ trợ trong ứng dụng.',
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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.lgAll,
        child: Ink(
          padding: SLSpacing.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: SLRadius.lgAll,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  title,
                  style: _labelStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: SLRadius.mdAll,
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
        borderRadius: SLRadius.mdAll,
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.055),
            borderRadius: SLRadius.mdAll,
            border: Border(
              bottom: BorderSide(color: color.withOpacity(0.22)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.16)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: _labelStyle(
                    color: Color.lerp(
                          const Color(0xFF1F2937),
                          color,
                          0.18,
                        ) ??
                        const Color(0xFF1F2937),
                    fontSize: 13.6,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: color,
                  size: 20,
                ),
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
        side: BorderSide(color: color.withOpacity(0.35)),
        backgroundColor: Colors.white,
        padding: SLSpacing.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: _labelStyle(color: color),
      ),
    );
  }
}
