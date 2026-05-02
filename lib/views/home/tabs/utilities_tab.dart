import 'widgets/utilities_tab_body.dart';
// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../utils/sl_notice.dart';
import '../../../models/house_settings.dart';
import '../../../services/admob_service.dart';
import '../../../services/house_service.dart';
import '../../../services/military_lock_service.dart';
import '../../../services/utility_service.dart';
import '../../../services/offline_cache_service.dart';
import '../../../core/sl_theme.dart';
import '../../utilities/bucket_list_screen.dart';
import '../../utilities/shared_notes_screen.dart';
import '../../utilities/finance_screen.dart';
import '../../utilities/friendly_chat_screen.dart';
import '../../utilities/wishlist_screen.dart';
import '../../utilities/habit_screen.dart';
import '../../utilities/voice_screen.dart';
import '../../utilities/calendar_screen.dart';
import '../../utilities/capsule_screen.dart';
import '../../utilities/cinema_screen.dart';
import '../../utilities/wheel_screen.dart';
import '../../utilities/secret_vault_screen.dart';
import '../../utilities/gift_maker_screen.dart';
import '../../utilities/giftcode_screen.dart';
import '../../utilities/history_screen.dart';
import '../../utilities/drawing_studio_screen.dart';
import '../../utilities/diary_export_screen.dart';
import '../../utilities/reward_store_screen.dart';
import '../../utilities/tarot_screen.dart';
import '../../utilities/collage_maker_screen.dart';
import '../../utilities/age_zodiac_screen.dart';
import '../../utilities/love_card_screen.dart';
import '../../utilities/calculator_screen.dart';
import '../../utilities/creative_diary_screen.dart';
import '../../utilities/sticker_library_screen.dart';

// import '../../utils/sl_notice.dart';

// ─── Web-parity: Map ID -> Icon & Colors ───

class UtilitiesTab extends StatefulWidget {
  const UtilitiesTab({super.key});

  @override
  State<UtilitiesTab> createState() => _UtilitiesTabState();
}

class _UtilitiesTabState extends State<UtilitiesTab> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();
  final UtilityService _utilityService = UtilityService();
  final AdMobService _adMob = AdMobService();
  final MilitaryLockService _militaryLockService = MilitaryLockService();

  String? _houseId;
  String _myName = 'Bạn';
  List<String> _customOrder = [];
  String _relationshipMode = 'single';
  bool _isEditMode = false;
  StreamSubscription<DatabaseEvent>? _smartPanelSubscription;
  int _bucketCount = 0;
  int _pendingBucketCount = 0;
  int _noteCount = 0;
  int _voiceCount = 0;
  String _smartTip = 'Đang phân tích thói quen để gợi ý tiện ích phù hợp nhất.';
  String? _suggestedUtilityId;
  int _currentSegment = 0;
  BannerAd? _bottomBannerAd;
  bool _isBottomBannerReady = false;
  List<UtilityApp> _pinnedApps = const <UtilityApp>[];
  List<UtilityApp> _recentApps = const <UtilityApp>[];

  @override
  void initState() {
    super.initState();
    unawaited(_init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fetchUtilityStats());
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        _loadBottomBanner();
      });
    });
  }

  // Không khai báo lại dispose() ở dưới nữa

  Future<void> _init() async {
    final nextOrder = await _utilityService.getCustomOrder();
    final pinnedApps = await _utilityService.getPinnedApps();
    final recentApps = await _utilityService.getRecentApps();
    if (!mounted) return;
    final shouldUpdateOrder = !listEquals(_customOrder, nextOrder);
    final shouldUpdatePinned = !_sameAppIds(_pinnedApps, pinnedApps);
    final shouldUpdateRecent = !_sameAppIds(_recentApps, recentApps);
    if (!shouldUpdateOrder && !shouldUpdatePinned && !shouldUpdateRecent) {
      return;
    }
    setState(() {
      if (shouldUpdateOrder) {
        _customOrder = List<String>.from(nextOrder);
      }
      if (shouldUpdatePinned) {
        _pinnedApps = pinnedApps;
      }
      if (shouldUpdateRecent) {
        _recentApps = recentApps;
      }
    });
  }

  Future<void> _saveOrder() async {
    await _utilityService.saveCustomOrder(_customOrder);
  }

  List<String> _orderedIdsForApps(List<UtilityApp> apps) {
    final visibleIds = apps.map((app) => app.id).toSet();
    final ordered = <String>[];
    for (final appId in _customOrder) {
      if (visibleIds.remove(appId)) {
        ordered.add(appId);
      }
    }
    for (final app in apps) {
      if (visibleIds.remove(app.id)) {
        ordered.add(app.id);
      }
    }
    return ordered;
  }

  List<UtilityApp> _sortAppsByCurrentOrder(List<UtilityApp> apps) {
    final appById = <String, UtilityApp>{for (final app in apps) app.id: app};
    final orderedIds = _orderedIdsForApps(apps);
    if (!listEquals(_customOrder, orderedIds)) {
      _customOrder = List<String>.from(orderedIds);
    }
    return orderedIds
        .map((id) => appById[id])
        .whereType<UtilityApp>()
        .toList(growable: false);
  }

  Future<void> _reloadCustomOrder() async {
    final nextOrder = await _utilityService.getCustomOrder();
    if (!mounted) return;
    setState(() {
      _customOrder = List<String>.from(nextOrder);
    });
  }

  Future<void> _reorderAppAsync(String draggedId, String targetId) async {
    if (draggedId == targetId) return;
    if (!_customOrder.contains(draggedId) || !_customOrder.contains(targetId)) {
      await _reloadCustomOrder();
      return;
    }

    final nextOrder = List<String>.from(_customOrder);
    final oldIndex = nextOrder.indexOf(draggedId);
    final newIndex = nextOrder.indexOf(targetId);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) {
      return;
    }

    nextOrder.removeAt(oldIndex);
    nextOrder.insert(newIndex, draggedId);

    if (!mounted) return;
    setState(() {
      _customOrder = nextOrder;
    });
    await _saveOrder();
  }

  List<UtilityApp> _appsForCurrentSegment() {
    final visibleAppsAll = UtilityService.appsForMode(_relationshipMode);
    final filtered = _currentSegment == 1
        ? visibleAppsAll.where((app) => app.isTool).toList(growable: false)
        : visibleAppsAll.where((app) => !app.isTool).toList(growable: false);
    return _sortAppsByCurrentOrder(filtered);
  }

  void _handleOrderDrop(String draggedId, String targetId) {
    unawaited(_reorderAppAsync(draggedId, targetId));
  }

  Future<void> _resetOrderToDefault() async {
    if (!mounted) return;
    setState(() {
      _customOrder.clear();
    });
    await _utilityService.clearCustomOrder();
    await _reloadCustomOrder();
  }

  Future<void> _confirmResetLayout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: SLRadius.xlAll,
          ),
          title: Text(
            'Đặt lại bố cục',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          content: Text(
            'Bạn có chắc muốn đưa thứ tự icon về mặc định không?',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Hủy',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Đặt lại',
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await _resetOrderToDefault();
  }

  void _reorderApp(String draggedId, String targetId) {
    _handleOrderDrop(draggedId, targetId);
  }

  Future<void> _fetchUtilityStats() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      _houseId = await _houseService.getCurrentHouseId();
      if (_houseId != null) {
        _subscribeToSmartPanel(_houseId!);

        // Tải từ cache trước
        final cachedData =
            OfflineCacheService.loadCacheSync('utilities_settings_$_houseId');
        if (cachedData != null) {
          if (mounted) {
            setState(() {
              _myName = cachedData['nameU1'] ?? 'Bạn';
              _relationshipMode =
                  HouseSettings.inferRelationshipModeFromSettingsMap(
                      Map<dynamic, dynamic>.from(cachedData));
            });
          }
        }

        final settingsSnap = await _dbRef
            .child('houses/$_houseId/settings')
            .get()
            .timeout(const Duration(seconds: 3));
        if (settingsSnap.exists && settingsSnap.value is Map) {
          final map = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
          OfflineCacheService.saveCache('utilities_settings_$_houseId', map);
          if (mounted) {
            setState(() {
              _myName = map['nameU1'] ?? 'Bạn';
              _relationshipMode =
                  HouseSettings.inferRelationshipModeFromSettingsMap(map);
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _smartPanelSubscription?.cancel();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomBanner() async {
    if (kIsWeb || ModalRoute.of(context)?.isCurrent != true) return;

    await _adMob.initialize();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    // Nếu là tk Pro thì không hiển thị banner
    if (await _adMob.isProUser()) {
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      if (!mounted) return;
      setState(() => _isBottomBannerReady = false);
      return;
    }

    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _bottomBannerAd = await _adMob.createBannerAd(
      onAdLoaded: (_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        setState(() => _isBottomBannerReady = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleApps = _appsForCurrentSegment();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: UtilitiesTabBody(
        currentSegment: _currentSegment,
        onSegmentChanged: _handleSegmentChanged,
        onResetTap: _confirmResetLayout,
        apps: visibleApps,
        pinnedApps: _shortcutPinnedApps,
        recentApps: _shortcutRecentApps,
        onShortcutTap: _navigateToApp,
        showBottomBanner: _shouldShowBottomBanner,
        bottomBannerAd: _bottomBannerAd,
        isEditMode: _isEditMode,
        onAppTap: _navigateToApp,
        onReorder: _reorderApp,
        onEditModeChanged: _handleEditModeChanged,
      ),
    );
  }

  bool get _shouldShowBottomBanner =>
      _currentSegment == 0 && _isBottomBannerReady;

  List<UtilityApp> get _shortcutPinnedApps {
    return _pinnedApps
        .where((app) => UtilityService.isUtilityAllowed(app.id, _relationshipMode))
        .toList(growable: false);
  }

  List<UtilityApp> get _shortcutRecentApps {
    final pinnedIds = _shortcutPinnedApps.map((app) => app.id).toSet();
    return _recentApps
        .where((app) => UtilityService.isUtilityAllowed(app.id, _relationshipMode))
        .where((app) => !pinnedIds.contains(app.id))
        .toList(growable: false);
  }

  bool _sameAppIds(List<UtilityApp> left, List<UtilityApp> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id) {
        return false;
      }
    }
    return true;
  }

  void _handleSegmentChanged(int segment) {
    if (_currentSegment == segment) return;
    setState(() => _currentSegment = segment);
  }

  void _handleEditModeChanged(bool value) {
    if (_isEditMode == value) return;
    setState(() => _isEditMode = value);
  }

  // ── Header (giống .screen-header web) ─────────────────────────────────
  Widget _buildUtilitiesHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        12,
      ),
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
                      child: Text(
                        'UTILITIES HUB',
                        style: SLTheme.quicksand(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    SLSpacing.h4,
                    Container(
                      width: 100,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: SLRadius.pillAll,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44, // width 44 cho nút đặt lại
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildUtilitiesHeaderAction(
                      icon: Icons.restart_alt_rounded,
                      tooltip: 'Đặt lại',
                      onTap: _confirmResetLayout,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: SLSpacing.all4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: SLRadius.mdAll,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentSegment = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _currentSegment == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: SLRadius.smAll,
                          boxShadow:
                              _currentSegment == 0 ? SLShadow.subtle : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Vui Chơi',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _currentSegment == 0
                                ? SLColors.primary
                                : SLColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentSegment = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _currentSegment == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: SLRadius.smAll,
                          boxShadow:
                              _currentSegment == 1 ? SLShadow.subtle : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Công Cụ',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _currentSegment == 1
                                ? SLColors.primary
                                : SLColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilitiesHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? SLColors.primary : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: SLShadow.subtle,
          border: Border.all(
              color: active ? SLColors.primary : Colors.white.withOpacity(0.5)),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : SLColors.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildUtilitiesSmartPanel() {
    return SLTheme.glassCard(
      padding: SLSpacing.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SLColors.secondary.withOpacity(0.1),
                  borderRadius: SLRadius.mdAll,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: SLColors.secondary, size: 20),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRỢ LÝ THÔNG MINH',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SLColors.secondary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '$_pendingBucketCount Bucket mới',
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SLTheme.primaryButton(
                text: 'MỞ GỢI Ý',
                onPressed: _openSuggestedUtility,
                width: 118,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ],
          ),
          SLSpacing.h16,
          Text(
            _smartTip,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SLColors.textSecondary,
              height: 1.5,
            ),
          ),
          SLSpacing.h20,
          Row(
            children: [
              Expanded(child: _buildSmartStat('$_bucketCount', 'BUCKET')),
              SLSpacing.w12,
              Expanded(child: _buildSmartStat('$_noteCount', 'GHI CHÚ')),
              SLSpacing.w12,
              Expanded(child: _buildSmartStat('$_voiceCount', 'VOICE')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: SLRadius.mdAll,
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SLColors.primary,
            ),
          ),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: SLColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.of(context).padding.top + 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Tối ưu (Bỏ BackdropFilter gây lag trên web)
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFff6f91), Color(0xFFd81b60)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 22),
                      SLSpacing.w8,
                      Flexible(
                        child: Text(
                          'TIỆN ÍCH',
                          softWrap: true,
                          style: SLTheme.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SLSpacing.w8,
            ],
          ),
          SLSpacing.h12,
          // Nút sắp xếp
          Row(
            children: [
              _buildEditBtn(
                'Đặt lại',
                isReset: true,
                onTap: _confirmResetLayout,
              ),
            ],
          )
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSmartPanel() {
    final subject = _relationshipMode == 'single' ? 'bạn' : 'hai bạn';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFEFF), Color(0xFFFFF0F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD81B60).withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFFD81B60), size: 18),
                    SLSpacing.w8,
                    Text(
                      'Trợ lý Tiện ích',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _openSuggestedUtility,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: SLRadius.pillAll,
                  ),
                ),
                child: Text(
                  'Mở gợi ý',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Đang phân tích thói quen của $subject để gợi ý utility phù hợp nhất.',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF555555),
              height: 1.4,
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(child: _buildSmartStat('0', 'Bucket')),
              SLSpacing.w8,
              Expanded(child: _buildSmartStat('0', 'Ghi chú')),
              SLSpacing.w8,
              Expanded(child: _buildSmartStat('0', 'Voice')),
            ],
          ),
        ],
      ),
    );
  }

  void _openSuggestedUtility() {
    final suggestedId = _suggestedUtilityId;
    if (suggestedId != null &&
        UtilityService.isUtilityAllowed(suggestedId, _relationshipMode)) {
      _navigateToApp(suggestedId);
      return;
    }
    final preferredIds = _relationshipMode == 'single'
        ? ['history', 'note']
        : ['bucket', 'note', 'voice', 'calendar'];
    for (final id in preferredIds) {
      if (UtilityService.isUtilityAllowed(id, _relationshipMode)) {
        _navigateToApp(id);
        return;
      }
    }
    final visibleApps = UtilityService.appsForMode(_relationshipMode);
    if (visibleApps.isNotEmpty) {
      _navigateToApp(visibleApps.first.id);
    }
  }

  void _subscribeToSmartPanel(String houseId) {
    _smartPanelSubscription?.cancel();
    _smartPanelSubscription =
        _dbRef.child('houses/$houseId/utilities').onValue.listen((
      event,
    ) {
      final root = event.snapshot.value;
      if (root is! Map) {
        final defaultSuggestedUtilityId = _defaultSuggestedUtilityId();
        const defaultSmartTip =
            'Đang phân tích thói quen để gợi ý tiện ích phù hợp nhất.';
        final shouldUpdate = _bucketCount != 0 ||
            _pendingBucketCount != 0 ||
            _noteCount != 0 ||
            _voiceCount != 0 ||
            _smartTip != defaultSmartTip ||
            _suggestedUtilityId != defaultSuggestedUtilityId;
        if (!shouldUpdate || !mounted) return;
        setState(() {
          _bucketCount = 0;
          _pendingBucketCount = 0;
          _noteCount = 0;
          _voiceCount = 0;
          _smartTip = defaultSmartTip;
          _suggestedUtilityId = defaultSuggestedUtilityId;
        });
        return;
      }

      final utilities = Map<dynamic, dynamic>.from(root);
      final bucketRaw = utilities['bucket'];
      final notesRaw = utilities['notes'];
      final voicesRaw = utilities['voices'];

      final bucketMap = bucketRaw is Map
          ? Map<dynamic, dynamic>.from(bucketRaw)
          : <dynamic, dynamic>{};
      final notesMap = notesRaw is Map
          ? Map<dynamic, dynamic>.from(notesRaw)
          : <dynamic, dynamic>{};
      final voicesMap = voicesRaw is Map
          ? Map<dynamic, dynamic>.from(voicesRaw)
          : <dynamic, dynamic>{};

      final pendingBucketCount = bucketMap.values.where((item) {
        if (item is! Map) return false;
        final map = Map<dynamic, dynamic>.from(item);
        return map['isDone'] != true;
      }).length;

      final suggestion = _resolveSuggestedUtility(
        pendingBucketCount: pendingBucketCount,
        noteCount: notesMap.length,
        voiceCount: voicesMap.length,
      );
      final bucketCount = bucketMap.length;
      final noteCount = notesMap.length;
      final voiceCount = voicesMap.length;
      final shouldUpdate = _bucketCount != bucketCount ||
          _pendingBucketCount != pendingBucketCount ||
          _noteCount != noteCount ||
          _voiceCount != voiceCount ||
          _smartTip != suggestion.message ||
          _suggestedUtilityId != suggestion.utilityId;

      if (!shouldUpdate || !mounted) return;
      setState(() {
        _bucketCount = bucketCount;
        _pendingBucketCount = pendingBucketCount;
        _noteCount = noteCount;
        _voiceCount = voiceCount;
        _smartTip = suggestion.message;
        _suggestedUtilityId = suggestion.utilityId;
      });
    });
  }

  _UtilitySuggestion _resolveSuggestedUtility({
    required int pendingBucketCount,
    required int noteCount,
    required int voiceCount,
  }) {
    if (pendingBucketCount > 0 &&
        UtilityService.isUtilityAllowed('bucket', _relationshipMode)) {
      return _UtilitySuggestion(
        utilityId: 'bucket',
        message:
            'Bạn còn $pendingBucketCount việc Bucket chưa hoàn thành, mở ra xử lý nhanh nhé.',
      );
    }

    final hour = DateTime.now().hour;
    if ((hour >= 22 || hour <= 6) &&
        UtilityService.isUtilityAllowed('voice', _relationshipMode)) {
      return const _UtilitySuggestion(
        utilityId: 'voice',
        message:
            'Khung giờ này hợp gửi voice ngắn trước khi ngủ, giữ cảm xúc gần nhau hơn.',
      );
    }

    if (noteCount > 0 &&
        UtilityService.isUtilityAllowed('note', _relationshipMode)) {
      return const _UtilitySuggestion(
        utilityId: 'note',
        message:
            'Bạn đang có ghi chú lưu sẵn, vào rà lại để không quên kế hoạch quan trọng.',
      );
    }

    if (voiceCount == 0 &&
        UtilityService.isUtilityAllowed('voice', _relationshipMode)) {
      return const _UtilitySuggestion(
        utilityId: 'voice',
        message:
            'Chưa có lời nhắn thoại nào, thử gửi một voice ngắn để tab Tiện ích ấm hơn nhé.',
      );
    }

    if (UtilityService.isUtilityAllowed('love_card', _relationshipMode)) {
      return const _UtilitySuggestion(
        utilityId: 'love_card',
        message:
            'Gợi ý hôm nay: tạo một tấm thiệp tình yêu để tăng điểm kết nối tình cảm.',
      );
    }

    final fallbackId = _defaultSuggestedUtilityId();
    return _UtilitySuggestion(
      utilityId: fallbackId,
      message:
          'Đã sẵn sàng gợi ý tiện ích phù hợp với nhịp dùng hiện tại của bạn.',
    );
  }

  String? _defaultSuggestedUtilityId() {
    final preferredIds = _relationshipMode == 'single'
        ? ['history', 'note']
        : ['bucket', 'note', 'voice', 'calendar'];
    for (final id in preferredIds) {
      if (UtilityService.isUtilityAllowed(id, _relationshipMode)) {
        return id;
      }
    }
    final visibleApps = UtilityService.appsForMode(_relationshipMode);
    return visibleApps.isNotEmpty ? visibleApps.first.id : null;
  }

  Widget _buildEditBtn(String label,
      {bool isReset = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isReset
              ? Colors.white.withOpacity(0.5)
              : const Color(0xFFD81B60).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isReset
                ? Colors.white
                : const Color(0xFFD81B60).withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isReset ? const Color(0xFF555555) : const Color(0xFFD81B60),
          ),
        ),
      ),
    );
  }

  static DateTime? _lastUtilityAdTime;

  Future<void> _navigateToApp(String id) async {
    if (!UtilityService.isUtilityAllowed(id, _relationshipMode)) {
      final blockedMessage =
          UtilityService.blockedMessageForMode(id, _relationshipMode);
      if (blockedMessage.isNotEmpty) {
        SLNotice.showInfo(context, blockedMessage);
        return;
      }
      SLNotice.showInfo(context, 'Tiện ích này chỉ dành cho chế độ Couple.');
      return;
    }
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) {
      SLNotice.showInfo(context, 'Đang tải dữ liệu nhà, thử lại ngay nhé.');
      return;
    }

    final isPro = await _adMob.isProUser();
    if (!isPro && id != 'store') {
      final now = DateTime.now();
      if ((_lastUtilityAdTime == null ||
              now.difference(_lastUtilityAdTime!) >
                  const Duration(minutes: 15)) &&
          !_adMob.hasRecentFullscreenAd()) {
        await _adMob.showInterstitialAd();
        _lastUtilityAdTime = DateTime.now();
      }
    }

    if (!mounted) {
      return;
    }

    await _utilityService.markAppAsRecentlyUsed(id);
    final updatedRecentApps = await _utilityService.getRecentApps();
    if (mounted && !_sameAppIds(_recentApps, updatedRecentApps)) {
      setState(() {
        _recentApps = updatedRecentApps;
      });
    }

    Widget? screen;
    switch (id) {
      case 'bucket':
        screen = BucketListScreen(houseId: houseId, myName: _myName);
        break;
      case 'note':
        screen = SharedNotesScreen(houseId: houseId, myName: _myName);
        break;
      case 'friendly_chat':
        screen = FriendlyChatScreen(houseId: houseId, myName: _myName);
        break;
      case 'finance':
        screen = FinanceScreen(houseId: houseId, myName: _myName);
        break;
      case 'wish':
        screen = WishlistScreen(houseId: houseId, myName: _myName);
        break;
      case 'habit':
        screen = HabitScreen(houseId: houseId, myName: _myName);
        break;
      case 'drawing':
        screen = DrawingStudioScreen(houseId: houseId, myName: _myName);
        break;
      case 'sticker_library':
        screen = const StickerLibraryScreen();
        break;
      case 'voice':
        screen = VoiceScreen(houseId: houseId, myName: _myName);
        break;
      case 'calendar':
        screen = CalendarScreen(houseId: houseId, myName: _myName);
        break;
      case 'calculator':
        screen = const CalculatorScreen();
        break;
      case 'capsule':
        screen = CapsuleScreen(houseId: houseId, myName: _myName);
        break;
      case 'cinema':
        screen = CinemaScreen(houseId: houseId, myName: _myName);
        break;
      case 'wheel':
        screen = WheelScreen(houseId: houseId);
        break;
      case 'vault':
        if (kIsWeb) {
          // Buộc khóa lại trước khi vào để yêu cầu mật khẩu mỗi lần F5 hoặc thoát
          _militaryLockService.lockScope(LockScope.privateArea);
        }
        final unlocked = await _militaryLockService.requestUnlock(
          context: context,
          scope: LockScope.privateArea,
          houseId: houseId,
          title: MilitaryLockService.getScopeTitle(LockScope.privateArea),
          reason: MilitaryLockService.scopeReason(LockScope.privateArea),
        );
        if (!unlocked || !mounted) {
          return;
        }
        screen = SecretVaultScreen(houseId: houseId);
        break;
      case 'gift':
        screen = GiftMakerScreen(houseId: houseId, myName: _myName);
        break;
      case 'giftcode':
        screen = GiftcodeScreen(houseId: houseId, myName: _myName);
        break;
      case 'history':
        screen = HistoryScreen(houseId: houseId);
        break;
      case 'diary_export':
        screen = DiaryExportScreen(houseId: houseId);
        break;
      case 'tarot':
        screen = TarotScreen(
          houseId: houseId,
          relationshipMode: _relationshipMode,
          myName: _myName,
        );
        break;
      case 'collage':
        screen = CollageMakerScreen(houseId: houseId);
        break;
      case 'store':
        screen = const RewardStoreScreen();
        break;
      case 'age_zodiac':
        screen = AgeZodiacScreen(houseId: houseId);
        break;
      case 'love_card':
        screen = LoveCardScreen(
          houseId: houseId,
          myUid: _auth.currentUser!.uid,
        );
        break;
      case 'creative_diary':
        screen = CreativeDiaryScreen(houseId: houseId);
        break;
    }
    if (screen != null) {
      if (!mounted) {
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    } else {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiện ích này đang được hoàn thiện.')));
    }
  }
}

class _UtilitySuggestion {
  final String? utilityId;
  final String message;

  const _UtilitySuggestion({
    required this.utilityId,
    required this.message,
  });
}
