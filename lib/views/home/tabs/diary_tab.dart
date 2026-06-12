// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import 'diary_composer.dart';

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
  final bool isActive;
  final ValueChanged<bool>? onSelectionOverlayChanged;

  const DiaryTab({
    super.key,
    required this.isActive,
    this.onSelectionOverlayChanged,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

typedef _PreparedMemoryFeed = PreparedDiaryMemoryFeed;

class _DiaryTabState extends State<DiaryTab> with AutomaticKeepAliveClientMixin {
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
  bool _isTabActive = false;
  bool _isActivatingTab = false;
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

  void _handleFeedControllerChange() {
    _syncMemoryControllerHouse();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleControllerChange() {
    _syncSelectionOverlayVisibility();
    if (mounted) {
      setState(() {});
    }
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
    unawaited(() async {
      final adMob = AdMobService();
      await adMob.initialize();
      adMob.preloadRewardedAd();
    }());
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

    final maxItems = isProUser ? memoryLimits.shareProMaxItems : memoryLimits.shareFreeMaxItems;
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

    MemoryShareAllowanceGateResult? gateResult;
    if (!isProUser) {
      gateResult = await _memoryShareAllowanceService.allowNextCreate(
        showRewardedAd: () async {
          _showDiarySnackBar(context.tr('home_angtiqungc_dbfb83'));
          final adMob = AdMobService();
          await adMob.initialize();
          return adMob.showRewardedAd(
            ignoreCooldown: true,
            loadTimeout: const Duration(seconds: 10),
          );
        },
      );
      if (!gateResult.allow) {
        _showDiarySnackBar(
          gateResult.requiresAd
              ? context.tr('util_khngticqun_ce9d80')
              : context.tr('home_cnxemqungc_878e59'),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }
    }

    if (gateResult != null && gateResult.rewardGranted > 0) {
      _showDiarySnackBar(
        'Bạn nhận được ${gateResult.rewardGranted} lượt tạo liên kết. Còn lại ${gateResult.remainingCredits} lượt.',
      );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
                    borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.8),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                controller.text.trim().isEmpty ? 'Bỏ qua (Không khóa)' : 'Xác nhận đặt',
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
      unawaited(_feedController.fetchNextDiaryPage());
    }
  }

  @override
  void initState() {
    super.initState();
    _isTabActive = widget.isActive;
    _feedController.addListener(_handleFeedControllerChange);
    _memoryController.addListener(_handleControllerChange);
    _guardController.addListener(_handleControllerChange);
    _diaryScrollController.addListener(_onDiaryScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectionOverlayVisibility();
      unawaited(_prepareDiaryOnMount());
    });
  }

  @override
  void didUpdateWidget(covariant DiaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSelectionOverlayChanged !=
        widget.onSelectionOverlayChanged) {
      _syncSelectionOverlayVisibility();
    }
    if (oldWidget.isActive == widget.isActive) {
      return;
    }
    _handleTabActivityChanged(widget.isActive);
  }

  @override
  void dispose() {
    widget.onSelectionOverlayChanged?.call(false);
    _feedController.removeListener(_handleFeedControllerChange);
    _memoryController.removeListener(_handleControllerChange);
    _guardController.removeListener(_handleControllerChange);
    _diaryScrollController.removeListener(_onDiaryScroll);
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
      unawaited(_activateDiaryTab());
      return;
    }
    unawaited(_feedController.pauseRealtime());
  }

  Future<void> _prepareDiaryOnMount() async {
    await _guardController.loadPrivacyNoticeState();
    final resolvedHouseId = await _feedController.resolveHouseId();
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
          barrierColor: Colors.black.withValues(alpha: 0.92),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (dialogContext, animation, secondaryAnimation) =>
              StatefulBuilder(
            builder: (context, setState) {
              final currentItem =
                  allPhotos.isNotEmpty ? allPhotos[currentIndex] : initialItem;

              void closeOnVerticalSwipe(DragEndDetails details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 200) {
                  return;
                }
                Navigator.pop(dialogContext);
              }

              Widget buildViewerImage(Map<String, dynamic> item) {
                final imageProvider = _memoryImageProvider(
                  item['url']?.toString() ?? '',
                  maxWidth: 2200,
                );
                final transformationController = TransformationController();
                final panEnabledVN = ValueNotifier<bool>(false);

                void handleTransformChanged() {
                  final matrix = transformationController.value;
                  final scale = matrix.getMaxScaleOnAxis();
                  final shouldEnablePan = scale > 1.02;
                  if (panEnabledVN.value != shouldEnablePan) {
                    panEnabledVN.value = shouldEnablePan;
                  }
                }

                void handleSwipeDown() {
                  final scale =
                      transformationController.value.getMaxScaleOnAxis();
                  if (scale > 1.05) {
                    transformationController.value = Matrix4.identity();
                    handleTransformChanged();
                    return;
                  }
                  Navigator.pop(dialogContext);
                }

                transformationController.addListener(handleTransformChanged);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () =>
                      _showMemoryViewerActions(dialogContext, item),
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 220) {
                      handleSwipeDown();
                    }
                  },
                  child: ValueListenableBuilder<bool>(
                    valueListenable: panEnabledVN,
                    builder: (context, panEnabled, _) {
                      return InteractiveViewer(
                        transformationController: transformationController,
                        panEnabled: panEnabled,
                        minScale: 1.0,
                        maxScale: 4.5,
                        boundaryMargin: const EdgeInsets.all(24),
                        clipBehavior: Clip.none,
                        interactionEndFrictionCoefficient: 0.00008,
                        child: Hero(
                          tag: 'memory_image_${item['id']}',
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }

              return FadeTransition(
                opacity: animation,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(color: Colors.transparent),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.62),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.58),
                                ],
                                stops: const [0.0, 0.22, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (allPhotos.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragEnd: closeOnVerticalSwipe,
                          child: PageView.builder(
                            controller: pageController,
                            physics: const BouncingScrollPhysics(),
                            itemCount: allPhotos.length,
                            onPageChanged: (index) {
                              setState(() {
                                currentIndex = index;
                              });
                              _warmMemoryViewerAroundIndex(allPhotos, index);
                            },
                            itemBuilder: (context, index) {
                              return buildViewerImage(allPhotos[index]);
                            },
                          ),
                        )
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragEnd: closeOnVerticalSwipe,
                          child: Builder(
                            builder: (context) => buildViewerImage(initialItem),
                          ),
                        ),
                      Positioned(
                        left: 18,
                        right: 86,
                        bottom: MediaQuery.of(context).padding.bottom + 18,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6F91),
                                        Color(0xFF7C8BFF)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
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
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${currentIndex + 1}/${allPhotos.isEmpty ? 1 : allPhotos.length} kỷ niệm',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatMemoryTimestamp(currentItem),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          color: Colors.white
                                              .withValues(alpha: 0.68),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
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
                        top: MediaQuery.of(context).padding.top + 14,
                        left: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: IconButton(
                            tooltip: context.tr('home_ng_f63d1e'),
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 14,
                        right: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: context.tr('home_tychnnh_5e18e0'),
                            padding: const EdgeInsets.all(11),
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                            color: const Color(0xFF171A21),
                            surfaceTintColor: const Color(0xFF171A21),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            itemBuilder: (menuContext) => [
                              PopupMenuItem<String>(
                                value: 'save',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      context.tr('home_lunh_9088ba'),
                                      style: SLTheme.quicksand(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
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
                                    const SizedBox(width: 12),
                                    Text(
                                      context.tr('home_chiasnh_003604'),
                                      style: SLTheme.quicksand(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
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
                                      Icons.info_outline_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      context.tr('home_chititnh_958bbd'),
                                      style: SLTheme.quicksand(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
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
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFFF6B6B),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      context.tr('home_xanh_0b98d1'),
                                      style: SLTheme.quicksand(
                                        color: const Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w800,
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
                                  Navigator.pop(dialogContext);
                                  await _shareSingleMemory(currentItem);
                                  break;
                                case 'info':
                                  await _showMemoryInfoSheet(
                                      dialogContext, currentItem);
                                  break;
                                case 'delete':
                                  Navigator.pop(dialogContext);
                                  await _deleteMemory(currentItem);
                                  break;
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ));
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
