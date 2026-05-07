// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/sl_theme.dart';
import '../../../models/diary_post.dart';
import '../../../services/interaction_metrics_service.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/admob_service.dart';
import '../../../utils/services/memory_share_allowance_service.dart';
import '../../../utils/services/memory_share_service.dart';
import '../../../utils/sl_notice.dart';
import '../../../widgets/share_bottom_sheet.dart';
import '../../../widgets/skeleton_container.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
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

class _DiaryTabState extends State<DiaryTab> {
  final DiaryFeedController _feedController = DiaryFeedController();
  final DiaryComposerController _composerState = DiaryComposerController();
  final DiaryMemoryController _memoryController = DiaryMemoryController();
  final DiaryGuardController _guardController = DiaryGuardController();
  final InteractionMetricsService _interactionMetricsService =
      InteractionMetricsService();
  final MemoryShareService _memoryShareService = MemoryShareService();
  final MemoryShareAllowanceService _memoryShareAllowanceService =
      MemoryShareAllowanceService();
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
    _handleControllerChange();
  }

  void _exitSelectionMode() {
    _memoryController.exitSelectionMode();
    _handleControllerChange();
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
        'Chưa có mã nhà để tạo liên kết.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (photos.isEmpty) {
      _showDiarySnackBar(
        'Hãy chọn ít nhất 1 ảnh để tạo liên kết.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    final memoryLimits = await _memoryShareService.fetchLimits();
    if (photos.length > memoryLimits.shareMaxItems) {
      _showDiarySnackBar(
        'Mỗi liên kết chỉ hỗ trợ tối đa ${memoryLimits.shareMaxItems} ảnh. Hãy bỏ chọn bớt ảnh nhé.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      _showDiarySnackBar(
        'Phiên đăng nhập đã hết. Vui lòng đăng nhập lại rồi thử lại.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final expiryDays = await _pickMemoryShareExpiryDays();
    if (expiryDays == null || !mounted) {
      return;
    }

    final gateResult = await _memoryShareAllowanceService.allowNextCreate(
      showRewardedAd: () async {
        await AdMobService().initialize();
        return AdMobService().showRewardedAd();
      },
    );
    if (!gateResult.allow) {
      _showDiarySnackBar(
        'Cần xem quảng cáo để tiếp tục tạo liên kết ở lần này.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    if (gateResult.rewardGranted > 0) {
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
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
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
                  'Đang tạo liên kết...',
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
        fallbackMessage:
            'Chưa thể tạo liên kết chia sẻ lúc này. Vui lòng thử lại sau.',
      );
      _showDiarySnackBar(
        resolvedError.message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<int?> _pickMemoryShareExpiryDays() {
    const options = <({int days, String label, String subtitle})>[
      (days: 7, label: '7 ngày', subtitle: 'Mặc định'),
      (days: 14, label: '14 ngày', subtitle: 'Thêm 1 tuần'),
      (days: 30, label: '30 ngày', subtitle: 'Khoảng 1 tháng'),
      (days: 90, label: '3 tháng', subtitle: 'Giữ lâu hơn'),
      (days: 183, label: '6 tháng', subtitle: 'Tối đa'),
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
                'Chọn thời hạn liên kết',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Liên kết mặc định là 7 ngày và tối đa 6 tháng.',
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

  Future<List<String>> _findActiveMemoryShareTokensForPhoto(
    Map<String, dynamic> item,
  ) async {
    final houseId = _houseId?.trim() ?? '';
    final photoId = item['id']?.toString().trim() ?? '';
    if (houseId.isEmpty || photoId.isEmpty) {
      return const <String>[];
    }

    final sharesIndexSnap = await FirebaseDatabase.instance
        .ref('houses/$houseId/memoryShares')
        .get();
    if (!sharesIndexSnap.exists || sharesIndexSnap.value is! Map) {
      return const <String>[];
    }

    final shareIndex =
        Map<dynamic, dynamic>.from(sharesIndexSnap.value as Map<dynamic, dynamic>);
    if (shareIndex.isEmpty) {
      return const <String>[];
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final tokens = <String>[];
    for (final entry in shareIndex.entries) {
      final token = entry.key?.toString().trim() ?? '';
      if (token.isEmpty) {
        continue;
      }
      final shareMeta = entry.value is Map
          ? Map<dynamic, dynamic>.from(entry.value as Map)
          : const <dynamic, dynamic>{};
      final revoked = shareMeta['revoked'] == true;
      final expiresAt = (shareMeta['expiresAt'] as num?)?.toInt() ?? 0;
      if (revoked || (expiresAt > 0 && expiresAt <= now)) {
        continue;
      }

      final shareSnap =
          await FirebaseDatabase.instance.ref('memory_shares/$token').get();
      if (!shareSnap.exists || shareSnap.value is! Map) {
        continue;
      }
      final share =
          Map<dynamic, dynamic>.from(shareSnap.value as Map<dynamic, dynamic>);
      if (share['revoked'] == true) {
        continue;
      }
      final rootExpiresAt = (share['expiresAt'] as num?)?.toInt() ?? 0;
      if (rootExpiresAt > 0 && rootExpiresAt <= now) {
        continue;
      }
      final photos = share['photos'];
      if (photos is! List) {
        continue;
      }
      final containsPhoto = photos.any((photo) {
        if (photo is! Map) {
          return false;
        }
        final normalized = Map<dynamic, dynamic>.from(photo);
        return (normalized['id']?.toString().trim() ?? '') == photoId;
      });
      if (containsPhoto) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  Future<void> _revokeMemoryShareLinksForPhoto(
    BuildContext dialogContext,
    Map<String, dynamic> item,
  ) async {
    final tokens = await _findActiveMemoryShareTokensForPhoto(item);
    if (tokens.isEmpty) {
      _showDiarySnackBar(
        'Ảnh này hiện chưa có liên kết chia sẻ nào còn hiệu lực.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Thu hồi liên kết?',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          tokens.length > 1
              ? 'Ảnh này đang nằm trong ${tokens.length} liên kết chia sẻ còn hiệu lực. Thu hồi tất cả các liên kết này?'
              : 'Ảnh này đang có 1 liên kết chia sẻ còn hiệu lực. Bạn muốn thu hồi liên kết đó?',
          style: SLTheme.quicksand(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      for (final token in tokens) {
        await _memoryShareService.revokeShareLink(token);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      Navigator.of(dialogContext).pop();
      _showDiarySnackBar(
        tokens.length > 1
            ? 'Đã thu hồi ${tokens.length} liên kết chia sẻ của ảnh này.'
            : 'Đã thu hồi liên kết chia sẻ của ảnh này.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      _showDiarySnackBar(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể thu hồi liên kết lúc này. Vui lòng thử lại sau.',
        ).message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> _showMemoryViewerActions(
    BuildContext dialogContext,
    Map<String, dynamic> item,
  ) async {
    final activeTokens = await _findActiveMemoryShareTokensForPhoto(item);
    if (!mounted) {
      return;
    }

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
                title: const Text('Lưu ảnh'),
                onTap: () => Navigator.of(sheetContext).pop('save'),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Chia sẻ ảnh'),
                onTap: () => Navigator.of(sheetContext).pop('share'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Chi tiết ảnh'),
                onTap: () => Navigator.of(sheetContext).pop('info'),
              ),
              if (activeTokens.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.link_off_rounded,
                    color: Color(0xFFFF7043),
                  ),
                  title: Text(
                    activeTokens.length > 1
                        ? 'Thu hồi ${activeTokens.length} liên kết'
                        : 'Thu hồi liên kết',
                    style: SLTheme.quicksand(
                      color: const Color(0xFFFF7043),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('revoke_share'),
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B),
                ),
                title: Text(
                  'Xóa ảnh',
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
      case 'revoke_share':
        await _revokeMemoryShareLinksForPhoto(dialogContext, item);
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

  @override
  void initState() {
    super.initState();
    _isTabActive = widget.isActive;
    _feedController.addListener(_handleFeedControllerChange);
    _memoryController.addListener(_handleControllerChange);
    _guardController.addListener(_handleControllerChange);

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

    final canPreloadContent = await _guardController.prepareAccessState(
      houseId: resolvedHouseId,
    );
    if (!mounted) {
      return;
    }

    if (_isTabActive) {
      await _activateDiaryTab();
    } else if (canPreloadContent) {
      await _fetchDiaryPosts(allowInactive: true);
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
    await _interactionMetricsService.recordDiaryView(
      houseId: houseId,
      role: role,
    );
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
        title: Text(L10nService().translate('Xác nhận xóa')),
        content: Text(
          L10nService().translate('Bạn có chắc muốn xóa tâm sự này không?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10nService().translate('Hủy')),
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
      _showDiarySnackBar(L10nService().translate('Đã xóa tâm sự.'));
    } catch (error) {
      _showDiarySnackBar(
        AppErrorMapper.resolve(
          error,
          fallbackMessage:
              'Không xóa được tâm sự: bài viết có thể đã bị xóa, bạn không còn quyền hoặc mạng đang lỗi.',
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

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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

            transformationController.addListener(handleTransformChanged);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _showMemoryViewerActions(dialogContext, item),
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
                        errorBuilder: (context, error, stackTrace) => const Icon(
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

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(color: Colors.black.withOpacity(0.92)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.42),
                            Colors.transparent,
                            Colors.black.withOpacity(0.28),
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
                  top: MediaQuery.of(context).padding.top + 14,
                  right: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      tooltip: 'Tùy chọn ảnh',
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
                                'Lưu ảnh',
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
                                Icons.ios_share_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Chia sẻ ảnh',
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
                                'Chi tiết ảnh',
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if ((currentItem['id']?.toString().trim() ?? '').isNotEmpty)
                          PopupMenuItem<String>(
                            value: 'revoke_share',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link_off_rounded,
                                  color: Color(0xFFFFB074),
                                  size: 19,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Thu hồi liên kết',
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFFFFB074),
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
                                'Xóa ảnh',
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
                            await _downloadSingleImage(currentItem['url']);
                            break;
                          case 'share':
                            Navigator.pop(dialogContext);
                            await _shareSingleMemory(currentItem);
                            break;
                          case 'info':
                            await _showMemoryInfoSheet(
                                dialogContext, currentItem);
                            break;
                          case 'revoke_share':
                            await _revokeMemoryShareLinksForPhoto(
                              dialogContext,
                              currentItem,
                            );
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
                color: const Color(0xFF15181F).withOpacity(0.98),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
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
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chi tiết ảnh',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MemoryInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Người đăng',
                    value:
                        authorName.isEmpty ? 'Chưa có thông tin' : authorName,
                  ),
                  const SizedBox(height: 12),
                  _MemoryInfoTile(
                    icon: Icons.schedule_rounded,
                    label: 'Ngày đăng',
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
    return ((mediaQuery.size.width / 3) * mediaQuery.devicePixelRatio)
        .round()
        .clamp(360, 1080);
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
    return _DiaryTabShell(state: this);
  }
}
