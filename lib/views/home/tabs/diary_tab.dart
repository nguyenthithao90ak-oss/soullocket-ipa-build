// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:intl/intl.dart';

import '../../../core/sl_theme.dart';
import '../../../models/diary_post.dart';
import '../../../utils/services/interaction_metrics_service.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/admob_service.dart';
import '../../../utils/services/memory_share_allowance_service.dart';
import '../../../utils/services/memory_share_service.dart';
import '../../../utils/sl_notice.dart';
import '../../../widgets/share_bottom_sheet.dart';
import '../../../widgets/skeleton_container.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/security_service.dart';
import 'diary_composer.dart';
import 'package:soullocket_app/views/home/tabs/settings/settings_gift_links_manager_screen.dart';

import 'diary/controllers/diary_composer_controller.dart';
import 'diary/controllers/diary_feed_controller.dart';
import 'diary/controllers/diary_guard_controller.dart';
import 'diary/controllers/diary_memory_controller.dart';
import 'diary_item.dart';
import 'diary_list.dart';
import 'diary/widgets/diary_memory_section.dart';
import 'diary/widgets/diary_tab_shell_sections.dart';

part 'diary/sections/diary_composer_launcher_section.dart';
part 'diary/sections/diary_tab_shell.dart';

class DiaryTab extends StatefulWidget {
  final ValueNotifier<bool> isActiveListenable;
  final ValueChanged<bool>? onSelectionOverlayChanged;
  final ValueListenable<bool>? isSwipingListenable;

  const DiaryTab({
    super.key,
    required this.isActiveListenable,
    this.onSelectionOverlayChanged,
    this.isSwipingListenable,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

typedef _PreparedMemoryFeed = PreparedDiaryMemoryFeed;

class _DiaryTabState extends State<DiaryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DiaryFeedController _feedController = DiaryFeedController();
  final DiaryComposerController _composerState = DiaryComposerController();
  final DiaryMemoryController _memoryController = DiaryMemoryController();
  final DiaryGuardController _guardController = DiaryGuardController();
  final InteractionMetricsService _interactionMetricsService =
      InteractionMetricsService();
  final MemoryShareService _memoryShareService = MemoryShareService();
  final MemoryShareAllowanceService _memoryShareAllowanceService =
      MemoryShareAllowanceService();
  final ScrollController _diaryScrollController = ScrollController();
  Timer? _diaryScrollDebounce;
  Timer? _diaryActiveTimer;
  int _activeSecondsInDiary = 0;
  bool _isTabActive = false;
  bool _isActivatingTab = false;
  bool _deferMemoryLoad = true;
  bool _lastSelectionOverlayVisible = false;
  final Set<String> _warmedMemoryViewerKeys = <String>{};

  String _currentTab = 'memory';
  String? _lastSyncedMemoryHouseId;
  bool _isAnimatingTabSwitch = false;

  bool get _isLoading => _feedController.isLoading;
  bool get _isAuthenticated => _guardController.isAuthenticated;
  bool get _isCheckingAuth => _guardController.isCheckingAuth;
  bool get _showDiaryPrivacyNotice => _guardController.showDiaryPrivacyNotice;
  String? get _houseId => _feedController.houseId;
  String get _nameU1 => _feedController.nameU1;
  String get _nameU2 => _feedController.nameU2;
  String get _activeRoleKey => _feedController.activeRoleKey;
  String get _relationshipMode => _feedController.relationshipMode;
  DateTime? get _startDate => _feedController.startDate;
  bool get _isSelectionMode => _memoryController.isSelectionMode;
  Map<String, Map<String, dynamic>> get _selectedMemories =>
      _memoryController.selectedMemories;
  bool get _isLoadingMoreMemories => _memoryController.isLoadingMoreMemories;
  bool get _hasPendingMemoryUploadRetry =>
      _memoryController.hasPendingUploadRetry;
  String get _pendingMemoryUploadMessage =>
      _memoryController.pendingUploadMessage;
  Future<ConnectivityResult>? get _connectivityFuture =>
      _guardController.connectivityFuture;

  void _syncMemoryControllerHouse() {
    final houseId = _feedController.houseId;
    if (_lastSyncedMemoryHouseId == houseId) {
      return;
    }
    _lastSyncedMemoryHouseId = houseId;
    _memoryController.syncHouseId(houseId);
  }

  Timer? _rebuildThrottleTimer;

  void _handleFeedControllerChange() {
    _syncMemoryControllerHouse();
    _throttledRebuild();
  }

  void _handleControllerChange() {
    _syncSelectionOverlayVisibility();
    _throttledRebuild();
  }

  /// Throttle rebuild tối đa 1 lần mỗi frame (16ms) — tránh cascade
  /// setState khi upload batch, controller notify, và listener fire
  void _throttledRebuild() {
    if (!mounted || !_isTabActive) return;
    _rebuildThrottleTimer?.cancel();
    _rebuildThrottleTimer = Timer(const Duration(milliseconds: 16), () {
      if (mounted && _isTabActive) {
        setState(() {});
      }
    });
  }

  void _syncSelectionOverlayVisibility() {
    final bool visible = _isTabActive &&
        _currentTab == 'memory' &&
        _memoryController.isSelectionMode &&
        _memoryController.selectedMemories.isNotEmpty;
    if (_lastSelectionOverlayVisible == visible) {
      return;
    }
    _lastSelectionOverlayVisible = visible;
    widget.onSelectionOverlayChanged?.call(visible);
  }

  void _toggleSelectionMode(Map<String, dynamic> photo) {
    _memoryController.toggleSelectionMode(photo);
    _preloadMemoryShareRewardedAd();
    _handleControllerChange();
  }

  void _exitSelectionMode() {
    _memoryController.exitSelectionMode();
    _handleControllerChange();
  }

  void _selectAllVisibleMemories() {
    final selectedCount = _memoryController.selectAllVisibleMemories();
    if (selectedCount == 0) {
      _showDiarySnackBar(
        context.tr('home_hychntnht1_7e4198'),
        backgroundColor: const Color(0xFFE53935),
      );
    }
    _preloadMemoryShareRewardedAd();
    _handleControllerChange();
  }

  void _preloadMemoryShareRewardedAd() {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 20), () async {
        final adMob = AdMobService();
        await adMob.initialize();
        adMob.preloadRewardedAd();
      }),
    );
  }

  void _setCurrentTab(String tab) {
    if (_currentTab == tab) return;
    setState(() {
      _isAnimatingTabSwitch = true;
      _currentTab = tab;
    });
    _memoryController.handleTabChanged(tab);
    // Defer loading until animation finishes
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() => _isAnimatingTabSwitch = false);
      }
    });
    _handleControllerChange();
  }

  Future<void> _deleteSelectedMemories() async {
    await _memoryController.deleteSelectedMemories(
      context: context,
      houseId: _houseId,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  Future<void> _saveSelectedMemories() async {
    await _memoryController.saveSelectedMemories(
      context: context,
      guardController: _guardController,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  Future<void> _shareSelectedMemories() async {
    await _createMemoryShareLink(_selectedMemories.values.toList());
    _handleControllerChange();
  }

  Future<void> _shareSingleMemory(Map<String, dynamic> item) async {
    await _createMemoryShareLink([item]);
  }

  Future<void> _createMemoryShareLink(
    List<Map<String, dynamic>> photos,
  ) async {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      _showDiarySnackBar(
        context.tr('home_chacmnhtol_5583df'),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (photos.isEmpty) {
      _showDiarySnackBar(
        context.tr('home_hychntnht1_7e4198'),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    // Start fetching network data early to mask latency while user picks expiry days
    final limitsFuture = _memoryShareService.fetchLimits();
    final isProUserFuture = AdMobService().isProUser();
    final currentUserFuture = _guardController.resolveCurrentUser();

    final expiryDays = await _pickMemoryShareExpiryDays();
    if (expiryDays == null || !mounted) {
      return;
    }

    final password = await _promptPasswordOption();
    if (password == null || !mounted) {
      return;
    }

    // Await the pre-fired futures. In most cases, they are already complete.
    final isProUser = await isProUserFuture;
    final memoryLimits = await limitsFuture;
    final currentUser = await currentUserFuture;

    final maxItems = isProUser
        ? memoryLimits.shareProMaxItems
        : memoryLimits.shareFreeMaxItems;
    if (photos.length > maxItems) {
      _showDiarySnackBar(
        'Mỗi liên kết chỉ hỗ trợ tối đa $maxItems ảnh đối với tài khoản ${isProUser ? 'PRO' : 'thường'}. Hãy bỏ chọn bớt ảnh nhé.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (currentUser == null) {
      _showDiarySnackBar(
        context.tr('home_phinngnhph_4893ad'),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    if (!isProUser) {
      _showDiarySnackBar(context.tr('home_angtiqungc_dbfb83'));
      final adMob = AdMobService();
      await adMob.initialize();
      final watched = await adMob.showRewardedAd(
        ignoreCooldown: true,
        loadTimeout: const Duration(seconds: 10),
      );
      if (!watched) {
        _showDiarySnackBar(
          'Bạn cần xem hết quảng cáo để tạo liên kết chia sẻ kỷ niệm.',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  context.tr('home_angtolinkt_21937e'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _memoryShareService.createShareLink(
        houseId: houseId,
        photos: photos,
        expiryDays: expiryDays,
        password: password,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      _memoryController.exitSelectionMode();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(result.expiresAt);
      final expiryLabel = DateFormat('dd/MM/yyyy').format(expiresAt);
      ShareBottomSheet.show(
        context: context,
        myHouseId: houseId,
        contentToShare:
            'Mình vừa gửi bạn album kỷ niệm trên SoulLocket gồm ${result.photoCount} ảnh. Link hết hạn ngày $expiryLabel.',
        shareUrl: result.url,
        loadInAppTargets: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      final errStr = error.toString();
      if (errStr.contains('EXCEEDED_ACTIVE_LINKS_LIMIT')) {
        final isProError = errStr.contains('PRO');
        _showActiveLinksLimitExceededDialog(isProError);
        return;
      }
      final resolvedError = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('home_chathtolin_20194a'),
      );
      _showDiarySnackBar(
        resolvedError.message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  void _showActiveLinksLimitExceededDialog(bool isPro) {
    final houseId = _houseId?.trim() ?? '';
    SLNotice.showConfirmDialog(
      context,
      title: 'Đạt giới hạn liên kết',
      message: isPro
          ? 'Tài khoản PRO đã đạt giới hạn tối đa 20 liên kết chia sẻ kỷ niệm đang hoạt động cùng lúc. Vui lòng vào Cài đặt để xóa bớt liên kết cũ.'
          : 'Tài khoản thường chỉ được tạo tối đa 5 liên kết chia sẻ kỷ niệm đang hoạt động cùng lúc. Vui lòng vào Cài đặt để xóa bớt liên kết cũ, hoặc nâng cấp lên PRO để tăng giới hạn lên 20 liên kết.',
      confirmText: 'Đi tới Cài đặt',
      cancelText: 'Đóng',
    ).then((confirmed) {
      if (confirmed == true && mounted && houseId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsGiftLinksManagerScreen(houseId: houseId),
          ),
        );
      }
    });
  }

  Future<int?> _pickMemoryShareExpiryDays() {
    final options = <({int days, String label, String subtitle})>[
      (
        days: 7,
        label: context.tr('home_7ngy_d51ffb'),
        subtitle: context.tr('home_mcnh_a57a8e')
      ),
      (
        days: 14,
        label: context.tr('home_14ngy_b98056'),
        subtitle: context.tr('home_thm1tun_2da196')
      ),
      (
        days: 30,
        label: context.tr('home_30ngy_06199c'),
        subtitle: context.tr('home_khong1thng_5fa21c')
      ),
      (
        days: 90,
        label: context.tr('home_3thng_f220f0'),
        subtitle: context.tr('home_giluhn_238ae5')
      ),
      (
        days: 183,
        label: context.tr('home_6thng_06506c'),
        subtitle: context.tr('home_tia_9b8ce7')
      ),
    ];

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('home_chnthihnli_2f138c'),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('home_linktmcnhl_54cf39'),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF66758A),
                ),
              ),
              const SizedBox(height: 14),
              for (final option in options) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option.days == 7
                        ? Icons.check_circle_rounded
                        : Icons.timelapse_rounded,
                    color: option.days == 7
                        ? const Color(0xFFD81B60)
                        : const Color(0xFF5C6BC0),
                  ),
                  title: Text(
                    option.label,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF243041),
                    ),
                  ),
                  subtitle: Text(
                    option.subtitle,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF66758A),
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(option.days),
                ),
                if (option != options.last)
                  const Divider(height: 1, color: Color(0xFFE5EAF1)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptPasswordOption() async {
    final controller = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Text(
            'Mật khẩu bảo vệ (Tùy chọn)',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF243041),
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập mật khẩu nếu bạn muốn người nhận phải nhập đúng mật khẩu mới xem được album.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF66758A),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscureText,
                maxLength: 32,
                onChanged: (_) => setState(() {}),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF243041),
                ),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  labelStyle: SLTheme.quicksand(
                    color: const Color(0xFF66758A),
                    fontWeight: FontWeight.w700,
                  ),
                  hintText: 'Để trống nếu không khóa',
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: const Color(0xFF66758A),
                    ),
                    onPressed: () {
                      setState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFD81B60), width: 1.8),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Hủy',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF66758A),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                controller.text.trim().isEmpty
                    ? 'Bỏ qua (Không khóa)'
                    : 'Xác nhận đặt',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMemoryViewerActions(
    BuildContext dialogContext,
    Map<String, dynamic> item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: Text(context.tr('home_lunh_9088ba')),
                onTap: () => Navigator.of(sheetContext).pop('save'),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(context.tr('home_chiasnh_003604')),
                onTap: () => Navigator.of(sheetContext).pop('share'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(context.tr('home_chititnh_958bbd')),
                onTap: () => Navigator.of(sheetContext).pop('info'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B),
                ),
                title: Text(
                  context.tr('home_xanh_0b98d1'),
                  style: SLTheme.quicksand(
                    color: const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );

    switch (action) {
      case 'save':
        await _downloadSingleImage(item['url']);
        break;
      case 'share':
        Navigator.pop(dialogContext);
        await _shareSingleMemory(item);
        break;
      case 'info':
        await _showMemoryInfoSheet(dialogContext, item);
        break;
      case 'delete':
        Navigator.pop(dialogContext);
        await _deleteMemory(item);
        break;
    }
  }

  Future<void> _downloadSingleImage(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await _memoryController.downloadSingleImage(
      context: context,
      url: trimmed,
      guardController: _guardController,
      showSnackBar: _showDiarySnackBar,
    );
  }

  Future<void> _retryPendingMemoryUpload() async {
    await _memoryController.retryPendingUpload(
      context: context,
      guardController: _guardController,
      feedController: _feedController,
      showSnackBar: _showDiarySnackBar,
    );
  }

  void _onDiaryScroll() {
    if (_currentTab == 'memory') return;
    if (!_diaryScrollController.hasClients) return;
    final maxScroll = _diaryScrollController.position.maxScrollExtent;
    final currentScroll = _diaryScrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _diaryScrollDebounce?.cancel();
      _diaryScrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        unawaited(_feedController.fetchNextDiaryPage());
      });
    }
  }

  BannerAd? _bottomBannerAd;
  bool _isBottomBannerReady = false;

  void _loadBottomBanner() async {
    if (kIsWeb) return;
    final adMob = AdMobService();
    await adMob.initialize();
    if (!mounted) return;

    if (await adMob.isProUser()) {
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      if (!mounted) return;
      setState(() => _isBottomBannerReady = false);
      return;
    }

    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    if (!mounted) return;
    final banner = await adMob.createBannerAd(
      onAdLoaded: (_) {
        if (!mounted) return;
        setState(() => _isBottomBannerReady = true);
      },
    );
    if (!mounted) {
      banner?.dispose();
      return;
    }
    _bottomBannerAd = banner;
  }

  Widget _buildBottomAdBanner(BannerAd bannerAd) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        AdMobService().showInterstitialAd();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: SLColors.bgElevated.withValues(alpha: 0.72),
              borderRadius: SLRadius.lgAll,
              border: Border.all(
                color: SLColors.bgElevated.withValues(alpha: 0.45),
              ),
              boxShadow: SLShadow.subtle,
            ),
            child: ClipRRect(
              borderRadius: SLRadius.mdAll,
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startDiaryActiveTimer() {
    _diaryActiveTimer?.cancel();
    _diaryActiveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted || !_isTabActive) {
        timer.cancel();
        return;
      }
      _activeSecondsInDiary += 10;
      if (_activeSecondsInDiary >= 15 * 60) {
        _showForcedDiaryAd();
      }
    });
  }

  void _stopDiaryActiveTimer() {
    _diaryActiveTimer?.cancel();
    _diaryActiveTimer = null;
  }

  Future<void> _showForcedDiaryAd() async {
    final adMob = AdMobService();
    if (await adMob.isProUser()) return;

    final hasRecent =
        adMob.hasRecentFullscreenAd(cooldown: const Duration(minutes: 15));
    if (hasRecent) {
      return;
    }

    debugPrint(
        'DiaryTab: Showing forced interstitial ad after 15 minutes of activity.');
    final shown = await adMob.showInterstitialAd();
    if (shown) {
      _activeSecondsInDiary = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _isTabActive = widget.isActiveListenable.value;
    if (_isTabActive) {
      _startDiaryActiveTimer();
    }
    widget.isActiveListenable.addListener(_onActiveChanged);
    _feedController.addListener(_handleFeedControllerChange);
    _memoryController.addListener(_handleControllerChange);
    _guardController.addListener(_handleControllerChange);
    _diaryScrollController.addListener(_onDiaryScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectionOverlayVisibility();
      unawaited(_prepareDiaryOnMount());
      Future<void>.delayed(const Duration(seconds: 15), () {
        if (!mounted) return;
        _loadBottomBanner();
      });
    });
  }

  void _onActiveChanged() {
    if (!mounted) return;
    final nextActive = widget.isActiveListenable.value;
    if (_isTabActive != nextActive) {
      _handleTabActivityChanged(nextActive);
    }
  }

  @override
  void didUpdateWidget(covariant DiaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSelectionOverlayChanged !=
        widget.onSelectionOverlayChanged) {
      _syncSelectionOverlayVisibility();
    }
    if (oldWidget.isActiveListenable != widget.isActiveListenable) {
      oldWidget.isActiveListenable.removeListener(_onActiveChanged);
      widget.isActiveListenable.addListener(_onActiveChanged);
      final nextActive = widget.isActiveListenable.value;
      if (_isTabActive != nextActive) {
        _handleTabActivityChanged(nextActive);
      }
    }
  }

  @override
  void dispose() {
    _stopDiaryActiveTimer();
    _bottomBannerAd?.dispose();
    widget.onSelectionOverlayChanged?.call(false);
    widget.isActiveListenable.removeListener(_onActiveChanged);
    _feedController.removeListener(_handleFeedControllerChange);
    _memoryController.removeListener(_handleControllerChange);
    _guardController.removeListener(_handleControllerChange);
    _diaryScrollController.removeListener(_onDiaryScroll);
    _diaryScrollDebounce?.cancel();
    _rebuildThrottleTimer?.cancel();
    _diaryScrollController.dispose();
    _feedController.dispose();
    _memoryController.dispose();
    _guardController.dispose();
    _composerState.dispose();
    super.dispose();
  }

  void _handleTabActivityChanged(bool isActive) {
    _isTabActive = isActive;
    _syncSelectionOverlayVisibility();
    if (isActive) {
      _startDiaryActiveTimer();
      // ⚡ Defer memory section load until after swipe animation
      if (_deferMemoryLoad) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _deferMemoryLoad = false);
        });
      }
      // ⚡ Flush any setState calls that were skipped while tab was inactive.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isTabActive) setState(() {});
        });
      }
      final currentHouseId = _feedController.houseId;
      if (_feedController.postsVN.value.isEmpty ||
          _lastSyncedMemoryHouseId != currentHouseId) {
        // ⚡ Increased from 300ms → 450ms to clear swipe animation before fetch
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted || !_isTabActive) return;
          unawaited(_activateDiaryTab());
        });
      }
    } else {
      _stopDiaryActiveTimer();
    }
  }

  Future<void> _prepareDiaryOnMount() async {
    await _guardController.loadPrivacyNoticeState();
    final resolvedHouseId = await _feedController.resolveHouseId();
    if (!mounted) {
      return;
    }
    _handleFeedControllerChange();

    await _guardController.prepareAccessState(
      houseId: resolvedHouseId,
    );
    if (!mounted) {
      return;
    }

    if (_isTabActive) {
      await _activateDiaryTab();
    }

    if (!mounted) {
      return;
    }
    _handleControllerChange();
  }

  Future<void> _activateDiaryTab() async {
    if (!_isTabActive || !mounted || _isActivatingTab) {
      return;
    }
    _isActivatingTab = true;
    try {
      if (_guardController.isAuthenticated) {
        await _fetchDiaryPosts();
        await _recordDiaryView();
        return;
      }
      await _checkDiaryLockReal();
    } finally {
      _isActivatingTab = false;
    }
  }

  Future<void> _checkDiaryLockReal() async {
    await _guardController.unlockDiary(
      context,
      houseId: _houseId,
      onUnlocked: () async {
        if (!_isTabActive) {
          return;
        }
        await _fetchDiaryPosts();
        await _recordDiaryView();
      },
    );
    _handleControllerChange();
  }

  String _resolvedPostAuthorName(DiaryPost post) {
    return _feedController.resolvedPostAuthorName(post);
  }

  void _loadMoreMemories() {
    _memoryController.loadMoreMemories();
    _handleControllerChange();
  }

  void _finishLoadingMoreMemoriesIfNeeded(bool waitingForLive) {
    _memoryController.finishLoadingMoreIfNeeded(
      waitingForLive,
      schedulePostFrame: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      },
    );
  }

  _PreparedMemoryFeed _prepareMemoryFeed({
    required Object? liveSource,
    required Object? cacheSource,
    required bool useLiveSource,
    required bool isOffline,
    required bool waitingForLive,
  }) {
    return _memoryController.prepareMemoryFeed(
      houseId: _houseId,
      startDate: _startDate,
      relationshipMode: _relationshipMode,
      liveSource: liveSource,
      cacheSource: cacheSource,
      useLiveSource: useLiveSource,
      isOffline: isOffline,
      waitingForLive: waitingForLive,
    );
  }

  Future<void> _fetchDiaryPosts({bool allowInactive = false}) async {
    if (!_isTabActive && !allowInactive) {
      return;
    }
    await _feedController.fetchDiaryPosts(
      resolveCurrentUser: _guardController.resolveCurrentUser,
    );
    _handleFeedControllerChange();
  }

  Future<void> _recordDiaryView() async {
    final houseId = _houseId?.trim();
    final role = _activeRoleKey.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }
    try {
      await _interactionMetricsService.recordDiaryView(
        houseId: houseId,
        role: role,
      );
    } catch (_) {}
  }

  void _showDiarySnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    if (backgroundColor == const Color(0xFFE53935) ||
        backgroundColor == const Color(0xFFEF6C57)) {
      SLNotice.showError(context, message);
    } else {
      SLNotice.showSuccess(context, message);
    }
  }

  Future<void> _updateMemoryGroupDate({
    required DateTime selectedDate,
    required List<Map<String, dynamic>> photos,
  }) async {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      _showDiarySnackBar(
        context.tr('home_chacmnhtol_5583df'),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (photos.isEmpty) {
      return;
    }

    try {
      await _memoryController.updateMemoryGroupDate(
        houseId: houseId,
        selectedDate: selectedDate,
        photos: photos,
      );
      _showDiarySnackBar(
        'Đã đổi ngày album sang ${DateFormat('dd/MM/yyyy').format(selectedDate)}.',
      );
    } catch (error) {
      _showDiarySnackBar(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể đổi ngày album lúc này.',
        ).message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> _submitDiaryPost() async {
    // Throttle: chống spam tạo post nhật ký liên tục
    if (!await SecurityService().guardAction(context, 'diary_post')) return;
    await _composerState.submit(
      feedController: _feedController,
      resolveCurrentUser: _guardController.resolveCurrentUser,
      showSnackBar: _showDiarySnackBar,
    );
    _handleFeedControllerChange();
  }

  Future<void> _confirmDeleteDiaryPost(DiaryPost post) async {
    if (_houseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(L10nService().translate(context.tr('home_xcnhnxa_f4ccd7'))),
        content: Text(
          L10nService().translate(context.tr('home_bncchcmunx_483a7a')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10nService().translate(context.tr('home_hy_1e4050'))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(L10nService().translate('OK')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _feedController.deleteDiaryPost(post);
      _handleFeedControllerChange();
      _showDiarySnackBar(
          L10nService().translate(context.tr('home_xatms_0872c5')));
    } catch (error) {
      _showDiarySnackBar(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('home_khngxactms_fea0e9'),
        ).message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Stream<DatabaseEvent>? _getMemoriesStream() {
    return _memoryController.getMemoriesStream(_houseId);
  }

  Future<dynamic> _getMemoriesCacheFuture() {
    return _memoryController.getMemoriesCacheFuture(_houseId);
  }

  dynamic _getMemoriesCacheSync() {
    return _memoryController.getMemoriesCacheSync(_houseId);
  }

  Future<void> _deleteMemory(Map<String, dynamic> item) async {
    await _memoryController.deleteMemory(
      context: context,
      houseId: _houseId,
      item: item,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  void _showMemoryZoom(
    Map<String, dynamic> initialItem,
    List<Map<String, dynamic>> allPhotos,
  ) {
    final initialIndex =
        allPhotos.indexWhere((photo) => photo['id'] == initialItem['id']);
    int currentIndex = initialIndex < 0 ? 0 : initialIndex;
    final pageController = PageController(initialPage: currentIndex);
    _warmMemoryViewerAroundIndex(allPhotos, currentIndex);

    Navigator.push<void>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final bgOpacityNotifier = ValueNotifier<double>(1.0);
          final isZoomedInNotifier = ValueNotifier<bool>(false);
          final dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
          final dragScaleNotifier = ValueNotifier<double>(1.0);

          return StatefulBuilder(
            builder: (context, setState) {
              final currentItem =
                  allPhotos.isNotEmpty ? allPhotos[currentIndex] : initialItem;

              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: bgOpacityNotifier,
                        builder: (context, dragOpacity, _) {
                          // Nền xung quanh tối hẳn (1.0) để làm nổi bật ảnh
                          final double opacity =
                              1.0 * dragOpacity * animation.value;
                          return Container(
                            color: Colors.black.withValues(alpha: opacity),
                          );
                        },
                      );
                    },
                  ),
                  _MemoryZoomDraggableWrapper(
                    onDismiss: () => Navigator.pop(dialogContext),
                    bgOpacityNotifier: bgOpacityNotifier,
                    isZoomedInNotifier: isZoomedInNotifier,
                    dragOffsetNotifier: dragOffsetNotifier,
                    dragScaleNotifier: dragScaleNotifier,
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(color: Colors.transparent),
                          ),
                          if (allPhotos.isNotEmpty)
                            PageView.builder(
                              controller: pageController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: allPhotos.length,
                              onPageChanged: (index) {
                                setState(() {
                                  currentIndex = index;
                                });
                                isZoomedInNotifier.value = false;
                                _warmMemoryViewerAroundIndex(allPhotos, index);
                              },
                              itemBuilder: (context, index) {
                                return _MemoryViewerPage(
                                  item: allPhotos[index],
                                  dragOffsetNotifier: dragOffsetNotifier,
                                  dragScaleNotifier: dragScaleNotifier,
                                  isZoomedInNotifier: isZoomedInNotifier,
                                  onLongPress: () => _showMemoryViewerActions(
                                      dialogContext, allPhotos[index]),
                                  imageProviderBuilder: _memoryImageProvider,
                                );
                              },
                            )
                          else
                            Builder(
                              builder: (context) => _MemoryViewerPage(
                                item: initialItem,
                                dragOffsetNotifier: dragOffsetNotifier,
                                dragScaleNotifier: dragScaleNotifier,
                                isZoomedInNotifier: isZoomedInNotifier,
                                onLongPress: () => _showMemoryViewerActions(
                                    dialogContext, initialItem),
                                imageProviderBuilder: _memoryImageProvider,
                              ),
                            ),
                          AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) {
                              return ValueListenableBuilder<double>(
                                valueListenable: bgOpacityNotifier,
                                builder: (context, dragOpacity, _) {
                                  final double baseUiOpacity =
                                      ((dragOpacity - 0.82) / 0.18)
                                          .clamp(0.0, 1.0);
                                  final double uiOpacity =
                                      baseUiOpacity * animation.value;
                                  return Opacity(
                                    opacity: uiOpacity,
                                    child: IgnorePointer(
                                      ignoring: uiOpacity < 0.5,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.black.withValues(
                                                          alpha: 0.45),
                                                      Colors.transparent,
                                                      Colors.transparent,
                                                      Colors.black.withValues(
                                                          alpha: 0.45),
                                                    ],
                                                    stops: const [
                                                      0.0,
                                                      0.15,
                                                      0.85,
                                                      1.0
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 18,
                                            right: 86,
                                            bottom: MediaQuery.of(context)
                                                    .padding
                                                    .bottom +
                                                18,
                                            child: IgnorePointer(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.42),
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.10),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF6F91),
                                                            Color(0xFF7C8BFF)
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.favorite_rounded,
                                                        color: Colors.white,
                                                        size: 17,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${currentIndex + 1}/${allPhotos.isEmpty ? 1 : allPhotos.length} kỷ niệm',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: SLTheme
                                                                .quicksand(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            _formatMemoryTimestamp(
                                                                currentItem),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: SLTheme
                                                                .quicksand(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.68),
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: MediaQuery.of(context)
                                                    .padding
                                                    .top +
                                                16,
                                            left: 12,
                                            child: IconButton(
                                              tooltip: context
                                                  .tr('home_ng_f63d1e'),
                                              onPressed: () => Navigator.pop(
                                                  dialogContext),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: MediaQuery.of(context)
                                                    .padding
                                                    .top +
                                                16,
                                            right: 12,
                                            child: PopupMenuButton<String>(
                                                tooltip: context
                                                    .tr('home_tychnnh_5e18e0'),
                                                padding:
                                                    const EdgeInsets.all(11),
                                                icon: const Icon(
                                                  Icons.more_vert_rounded,
                                                  color: Colors.white,
                                                  size: 23,
                                                ),
                                                color: const Color(0xFF171A21),
                                                surfaceTintColor:
                                                    const Color(0xFF171A21),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                itemBuilder: (menuContext) => [
                                                  PopupMenuItem<String>(
                                                    value: 'save',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .download_rounded,
                                                          color: Colors.white,
                                                          size: 19,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Text(
                                                          context.tr(
                                                              'home_lunh_9088ba'),
                                                          style:
                                                              SLTheme.quicksand(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'share',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.link_rounded,
                                                          color: Colors.white,
                                                          size: 19,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Text(
                                                          context.tr(
                                                              'home_chiasnh_003604'),
                                                          style:
                                                              SLTheme.quicksand(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'info',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .info_outline_rounded,
                                                          color: Colors.white,
                                                          size: 19,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Text(
                                                          context.tr(
                                                              'home_chititnh_958bbd'),
                                                          style:
                                                              SLTheme.quicksand(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color:
                                                              Color(0xFFFF6B6B),
                                                          size: 19,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Text(
                                                          context.tr(
                                                              'home_xanh_0b98d1'),
                                                          style:
                                                              SLTheme.quicksand(
                                                            color: const Color(
                                                                0xFFFF6B6B),
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                onSelected: (value) async {
                                                  switch (value) {
                                                    case 'save':
                                                      await _downloadSingleImage(
                                                          currentItem['url']);
                                                      break;
                                                    case 'share':
                                                      Navigator.pop(
                                                          dialogContext);
                                                      await _shareSingleMemory(
                                                          currentItem);
                                                      break;
                                                    case 'info':
                                                      await _showMemoryInfoSheet(
                                                          dialogContext,
                                                          currentItem);
                                                      break;
                                                    case 'delete':
                                                      Navigator.pop(
                                                          dialogContext);
                                                      await _deleteMemory(
                                                          currentItem);
                                                      break;
                                                  }
                                                },
                                              ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  String _formatMemoryTimestamp(Map<String, dynamic> item) {
    final timestamp = item['ts'] as int? ?? 0;
    return DateFormat('dd/MM/yyyy • HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  Future<void> _showMemoryInfoSheet(
    BuildContext dialogContext,
    Map<String, dynamic> item,
  ) async {
    final authorName = _resolveMemoryAuthorName(item).trim();
    final postedAt = _formatMemoryTimestamp(item);

    await showModalBottomSheet<void>(
      context: dialogContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15181F).withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('home_chititnh_958bbd'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MemoryInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: context.tr('home_nging_c93b87'),
                    value: authorName.isEmpty
                        ? context.tr('home_chacthngti_ad20b9')
                        : authorName,
                  ),
                  const SizedBox(height: 12),
                  _MemoryInfoTile(
                    icon: Icons.schedule_rounded,
                    label: context.tr('home_ngyng_d1c813'),
                    value: postedAt,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveMemoryAuthorName(Map<String, dynamic> item) {
    return _feedController.resolveMemoryAuthorName(item);
  }

  int _memoryThumbnailCacheWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ((mediaQuery.size.width / 3) * mediaQuery.devicePixelRatio * 1.18)
        .round()
        .clamp(480, 1440);
  }

  int _postImageCacheWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return (mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .round()
        .clamp(720, 1600);
  }

  ImageProvider<Object> _memoryImageProvider(String url, {int? maxWidth}) {
    final trimmedUrl = url.trim();
    if (kIsWeb) {
      return NetworkImage(trimmedUrl);
    }
    return CachedNetworkImageProvider(trimmedUrl, maxWidth: maxWidth);
  }

  void _warmMemoryViewerAroundIndex(
    List<Map<String, dynamic>> allPhotos,
    int index,
  ) {
    if (!mounted || allPhotos.isEmpty) {
      return;
    }
    final int start = (index - 1).clamp(0, allPhotos.length - 1);
    final int end = (index + 1).clamp(0, allPhotos.length - 1);
    for (int i = start; i <= end; i++) {
      final url = (allPhotos[i]['url']?.toString() ?? '').trim();
      if (url.isEmpty) {
        continue;
      }
      final key = '2200|$url';
      if (!_warmedMemoryViewerKeys.add(key)) {
        continue;
      }
      unawaited(
        precacheImage(
          _memoryImageProvider(url, maxWidth: 2200),
          context,
        ),
      );
    }
  }

  Future<void> _uploadMemoryPhotos() async {
    await _memoryController.uploadMemoryPhotos(
      context: context,
      guardController: _guardController,
      feedController: _feedController,
      showSnackBar: _showDiarySnackBar,
    );
    _handleControllerChange();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _DiaryTabShell(state: this);
  }
}

class _MemoryZoomDraggableWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final ValueNotifier<double> bgOpacityNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;

  const _MemoryZoomDraggableWrapper({
    required this.child,
    required this.onDismiss,
    required this.bgOpacityNotifier,
    required this.isZoomedInNotifier,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
  });

  @override
  State<_MemoryZoomDraggableWrapper> createState() =>
      _MemoryZoomDraggableWrapperState();
}

class _MemoryZoomDraggableWrapperState
    extends State<_MemoryZoomDraggableWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragY = 0.0;
  double _dragStartAnimY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _controller.addListener(() {
      setState(() {
        final double curveValue = CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ).value;
        _dragY = _dragStartAnimY * (1.0 - curveValue);
        _updateOpacity();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOpacity() {
    widget.bgOpacityNotifier.value = (1.0 - (_dragY / 320.0)).clamp(0.0, 1.0);
    widget.dragOffsetNotifier.value = Offset(0, _dragY);
    widget.dragScaleNotifier.value = (1.0 - (_dragY / 380.0)).clamp(0.35, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (details) {
        if (widget.isZoomedInNotifier.value) return;
        _controller.stop();
        _dragStartAnimY = _dragY;
      },
      onVerticalDragUpdate: (details) {
        if (widget.isZoomedInNotifier.value) return;
        setState(() {
          _dragY += details.delta.dy;
          if (_dragY < 0.0) _dragY = 0.0;
          _updateOpacity();
        });
      },
      onVerticalDragEnd: (details) {
        if (widget.isZoomedInNotifier.value) return;
        final velocity = details.primaryVelocity ?? 0;
        if (_dragY > 140 || velocity > 250) {
          widget.onDismiss();
        } else {
          _dragStartAnimY = _dragY;
          _controller.forward(from: 0.0);
        }
      },
      child: widget.child,
    );
  }
}

class _MemoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final VoidCallback onLongPress;
  final ImageProvider<Object> Function(String, {int? maxWidth})
      imageProviderBuilder;

  const _MemoryViewerPage({
    required this.item,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
    required this.isZoomedInNotifier,
    required this.onLongPress,
    required this.imageProviderBuilder,
  });

  @override
  State<_MemoryViewerPage> createState() => _MemoryViewerPageState();
}

class _MemoryViewerPageState extends State<_MemoryViewerPage> {
  late final ImageProvider<Object> _imageProvider;
  late final TransformationController _transformationController;
  late final ValueNotifier<bool> _panEnabledVN;

  @override
  void initState() {
    super.initState();
    _imageProvider = widget.imageProviderBuilder(
      widget.item['url']?.toString() ?? '',
      maxWidth: 2200,
    );
    _transformationController = TransformationController();
    _panEnabledVN = ValueNotifier<bool>(false);

    _transformationController.addListener(_handleTransformChanged);
  }

  void _handleTransformChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final shouldEnablePan = scale > 1.02;
    if (_panEnabledVN.value != shouldEnablePan) {
      _panEnabledVN.value = shouldEnablePan;
      widget.isZoomedInNotifier.value = shouldEnablePan;
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _panEnabledVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      child: ValueListenableBuilder<bool>(
        valueListenable: _panEnabledVN,
        builder: (context, panEnabled, _) {
          return AnimatedBuilder(
            animation: Listenable.merge(
                [widget.dragOffsetNotifier, widget.dragScaleNotifier]),
            builder: (context, child) {
              return Transform.translate(
                offset: widget.dragOffsetNotifier.value,
                child: Transform.scale(
                  scale: widget.dragScaleNotifier.value,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: panEnabled,
                    minScale: 1.0,
                    maxScale: 4.5,
                    boundaryMargin:
                        panEnabled ? const EdgeInsets.all(24) : EdgeInsets.zero,
                    clipBehavior: Clip.none,
                    interactionEndFrictionCoefficient: 0.00008,
                    child: Hero(
                      tag: 'memory_image_${widget.item['id']}',
                      child: Image(
                        image: _imageProvider,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
