// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:lottie/lottie.dart';
import '../../utils/services/offline_cache_service.dart';

import '../../core/constants/app_config.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/daily_quest_service.dart';
import '../../utils/services/gps_tracker_service.dart';
import '../../utils/services/location_service.dart';
import '../../utils/services/map_pin_limit_service.dart';
import '../../utils/services/nominatim_service.dart';
import '../../utils/services/notification_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';

part 'dialogs/map_checkin_sheet.dart';
part 'dialogs/map_detail_dialogs.dart';
part 'dialogs/map_search_sheet.dart';
part 'map_location_logic.dart';
part 'map_location_marker_pipeline.dart';
part 'map_screen_helpers.dart';
part 'sections/map_panel_sections.dart';
part 'sections/map_surface_sections.dart';

/// Parses JSON on a background isolate to avoid blocking the UI thread for
/// large payloads (e.g. OSRM route responses).
dynamic _parseRouteMap(String raw) => jsonDecode(raw);

const Color _kMapBlue = Color(0xFF2E8BFF);
const Color _kMapBlueSoft = Color(0xFFAED7FF);
const Color _kMapPink = Color(0xFFFF5C93);
const Color _kMapPinkSoft = Color(0xFFFFB4CC);
const Color _kMapPinkDeep = Color(0xFFFF3F7C);
const Color _kMapRouteBorder = Color(0xF2FFFFFF);
const Color _kMapRouteGlow = Color(0x33FF5C93);
const Color _kMapPanelBorder = Color(0xFF303643);
const Color _kMapTextMuted = Color(0xFF64748B);
const Color _kMapTextSoft = Color(0xFFE2E8F0);
const Color _kMapTileSurface = Color(0xFF171C25);
const Color _kMapSummaryStart = Color(0xFF182132);
const Color _kMapSummaryEnd = Color(0xFF301C2B);
const int _kMaxMapPins = MapPinLimitService.maxPins;
const int _kMaxRenderedMemoryMarkers = 24;
const int _kMaxRenderedCheckinMarkers = 28;
const int _kMaxRenderedCheckinPathPoints = 140;
const int _kMapMemoryQueryLimit = 48;
const int _kMapCheckinQueryLimit = 64;
const int _kGpsHistoryFetchLimit = 600;
const int _kMapRouteCacheMaxEntries = 24;
const int _kMapReverseGeocodeCacheMaxEntries = 48;
const double _kMapMaxLiveAccuracyMeters = 100;
const double _kMapGoodAccuracyMeters = 30;
const double _kMapFairAccuracyMeters = 75;
const Duration _kMapRouteCacheTtl = Duration(minutes: 10);
const Duration _kMapReverseGeocodeCacheTtl = Duration(hours: 12);
const double _kPartnerNearbyEnterMeters = 150;
const double _kPartnerNearbyExitMeters = 220;
const double _kPinnedPlaceNearbyEnterMeters = 140;
const double _kPinnedPlaceNearbyExitMeters = 220;

class MapScreen extends StatefulWidget {
  final String houseId;
  final String myRole;
  final String partnerRole;
  final String relationshipMode;
  final String myName;
  final String partnerName;
  final String myAvatarUrl;
  final String partnerAvatarUrl;

  static final ValueNotifier<bool> isMapScreenActive =
      ValueNotifier<bool>(false);

  const MapScreen({
    super.key,
    required this.houseId,
    required this.myRole,
    required this.partnerRole,
    required this.relationshipMode,
    required this.myName,
    required this.partnerName,
    required this.myAvatarUrl,
    required this.partnerAvatarUrl,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final fm.MapController _mapController = fm.MapController();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final MapPinLimitService _mapPinLimitService = MapPinLimitService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ll.Distance _distance = const ll.Distance();
  final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _prettyDayFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  final ValueNotifier<List<fm.Marker>> _staticMarkersVN =
      ValueNotifier<List<fm.Marker>>(const []);
  final ValueNotifier<List<fm.Polyline>> _historyPolylinesVN =
      ValueNotifier<List<fm.Polyline>>(const []);
  final ValueNotifier<List<fm.Polyline>> _checkinPolylinesVN =
      ValueNotifier<List<fm.Polyline>>(const []);
  final ValueNotifier<List<fm.Marker>> _liveMarkersVN =
      ValueNotifier<List<fm.Marker>>(const []);
  final ValueNotifier<List<fm.Polyline>> _livePolylinesVN =
      ValueNotifier<List<fm.Polyline>>(const []);
  final ValueNotifier<_LiveUiSnapshot> _liveUiVN =
      ValueNotifier<_LiveUiSnapshot>(_LiveUiSnapshot.empty());

  bool _isLoading = true;
  bool _isFetchingRoute = false;
  bool _didAutoFit = false;
  bool _isMapReady = false;
  bool _isBootstrappingLocation = false;
  bool _didQueueMapIntroNotice = false;
  bool _isSelectingCheckinLocation = false;
  String? _mapInitError;
  String? _locationStatusMessage;

  _GpsPoint? _myCurrentGps;
  _GpsPoint? _myLastKnownGps;
  _GpsPoint? _partnerCurrentGps;
  _GpsPoint? _partnerLastKnownGps;
  bool _myIsLive = false;
  bool _partnerIsLive = false;
  bool _myHasLocationHistory = false;
  bool _partnerHasLocationHistory = false;

  DateTime _selectedHistoryDate = DateTime.now();
  _HistoryBundle _historyBundle = _HistoryBundle.empty();
  _RouteSnapshot? _routeSnapshot;

  List<_MapMemoryItem> _memories = [];
  List<_MapCheckinItem> _checkins = [];

  String _distanceText = L10nService().translate('map_angnhv_ea3669');
  String _routeDistanceText = '--';
  String _etaText = '--';
  String _mapInsightText = L10nService().translate('map_angqutdliu_8eeb1b');
  String? _mapAlert;
  String _memorySummary = L10nService().translate('map_chacghimkn_c6823f');
  String _checkinSummary = L10nService().translate('map_chacchecki_51b108');
  String _myAddressText = L10nService().translate('map_chacvtr_a02989');
  String _partnerAddressText = L10nService().translate('map_chacvtr_a02989');

  StreamSubscription<DatabaseEvent>? _myLocSub;
  StreamSubscription<DatabaseEvent>? _partnerLocSub;
  StreamSubscription<DatabaseEvent>? _memoriesRootSub;
  StreamSubscription<DatabaseEvent>? _memoriesHouseSub;
  StreamSubscription<DatabaseEvent>? _checkinsSub;

  Timer? _routeDebounce;
  Timer? _liveRefreshDebounce;
  Timer? _memoryReloadDebounce;
  Timer? _checkinsDebounce;
  Timer? _mapReadyTimeout;
  Timer? _fitDebounce;
  bool _realtimePipelinesActive = false;
  bool _partnerListenerActive = false;
  bool _isFitting = false;
  String? _lastRouteKey;
  int _routeRequestToken = 0;
  String _memorySignature = '';
  String _checkinSignature = '';
  String _liveMarkerSignature = '';
  String _livePolylineSignature = '';
  String _liveUiSignature = '';
  String _historyPolylineSignature = '';
  String? _myAddressKey;
  String? _partnerAddressKey;
  dynamic _latestPublicMemoriesRaw;
  dynamic _latestHouseMemoriesRaw;
  final Map<String, _RouteSnapshot?> _routeCache = <String, _RouteSnapshot?>{};
  final Map<String, int> _routeCacheTs = <String, int>{};
  final Map<String, Future<_RouteSnapshot?>> _routeInFlight =
      <String, Future<_RouteSnapshot?>>{};
  final Map<String, String?> _reverseGeocodeCache = <String, String?>{};
  final Map<String, int> _reverseGeocodeCacheTs = <String, int>{};
  final Map<String, Future<String?>> _reverseGeocodeInFlight =
      <String, Future<String?>>{};
  bool _didNotifyPartnerNearby = false;
  String? _myActiveNearbyPinKey;
  String? _partnerActiveNearbyPinKey;
  String? _lastProximityBannerKey;
  DateTime? _lastProximityBannerAt;

  ll.LatLng? get _myLocation => _effectiveGpsForRole(widget.myRole)?.latLng;
  ll.LatLng? get _partnerLocation => _isSingleRelationship
      ? null
      : _effectiveGpsForRole(widget.partnerRole)?.latLng;
  ll.LatLng? get _myLiveLocation =>
      _effectiveLiveGpsForRole(widget.myRole)?.latLng;
  bool get _isSingleRelationship =>
      widget.relationshipMode.trim().toLowerCase() == 'single';
  String get _mapScreenTitle => _isSingleRelationship
      ? context.tr('map_vtrhinti_f5956d')
      : context.tr('map_vtrcachngm_07f765');
  String get _mapScreenSubtitle => _isSingleRelationship
      ? context.tr('map_bnvtrcabn_fdf5bc')
      : context.tr('map_bnkhongcch_486245');

  void _setViewingMap(bool active) {
    try {
      FirebaseDatabase.instance
          .ref(
              'houses/${widget.houseId}/presence/${widget.myRole}/isViewingMap')
          .set(active ? true : null);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    MapScreen.isMapScreenActive.value = true;
    _setViewingMap(true);
    WidgetsBinding.instance.addObserver(this);
    _setPartnerListenerActive(true);
    _initMap();
  }

  @override
  void dispose() {
    MapScreen.isMapScreenActive.value = false;
    _setViewingMap(false);
    WidgetsBinding.instance.removeObserver(this);
    _cancelTransientMapWork(resetRouteFetch: true);
    _setRealtimePipelinesActive(false);
    _setPartnerListenerActive(false);
    _mapReadyTimeout?.cancel();
    _myLocSub?.cancel();
    _partnerLocSub?.cancel();
    _memoriesRootSub?.cancel();
    _memoriesHouseSub?.cancel();
    _checkinsSub?.cancel();
    _mapController.dispose();
    _staticMarkersVN.dispose();
    _historyPolylinesVN.dispose();
    _checkinPolylinesVN.dispose();
    _liveMarkersVN.dispose();
    _livePolylinesVN.dispose();
    _liveUiVN.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MapScreen.isMapScreenActive.value = true;
      _setViewingMap(true);
      _setPartnerListenerActive(true);
      _setRealtimePipelinesActive(true);
      if (!_isMapReady && _isLoading) {
        _scheduleMapReadyWatchdog();
      }
      _scheduleLiveRefresh();
      unawaited(
        _locationService.startTracking(
          widget.houseId,
          widget.myRole,
          context: context,
          forcePrompt: false,
        ),
      );
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      MapScreen.isMapScreenActive.value = false;
      _setViewingMap(false);
      if (AppLifecyclePresenceGuard.shouldKeepPresenceOnline) {
        return;
      }
      _cancelTransientMapWork(resetRouteFetch: true);
      _setRealtimePipelinesActive(false);
      _setPartnerListenerActive(false);
      if (!mounted) return;
      setState(() {
        _isBootstrappingLocation = false;
        _locationStatusMessage = context.tr('map_soullocket_ece6e9');
      });
    }
  }

  void _setPartnerListenerActive(bool active) {
    if (active) {
      if (_partnerListenerActive) return;
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) return;
      GpsTrackerService().startListeningPartner(widget.houseId, myUid);
      _partnerListenerActive = true;
      return;
    }

    if (!_partnerListenerActive) return;
    GpsTrackerService().stopListeningPartner();
    _partnerListenerActive = false;
  }

  void _setRealtimePipelinesActive(bool active) {
    if (active) {
      if (_realtimePipelinesActive) return;
      _realtimePipelinesActive = true;
      _listenLiveGps();
      _listenMemoryNodes();
      _listenCheckins();
      return;
    }

    _realtimePipelinesActive = false;

    final myLocSub = _myLocSub;
    _myLocSub = null;
    if (myLocSub != null) {
      unawaited(myLocSub.cancel());
    }

    final partnerLocSub = _partnerLocSub;
    _partnerLocSub = null;
    if (partnerLocSub != null) {
      unawaited(partnerLocSub.cancel());
    }

    final memoriesRootSub = _memoriesRootSub;
    _memoriesRootSub = null;
    if (memoriesRootSub != null) {
      unawaited(memoriesRootSub.cancel());
    }

    final memoriesHouseSub = _memoriesHouseSub;
    _memoriesHouseSub = null;
    if (memoriesHouseSub != null) {
      unawaited(memoriesHouseSub.cancel());
    }

    final checkinsSub = _checkinsSub;
    _checkinsSub = null;
    if (checkinsSub != null) {
      unawaited(checkinsSub.cancel());
    }

    _disposeMemoryPipeline();
  }

  void _cancelTransientMapWork({required bool resetRouteFetch}) {
    _routeDebounce?.cancel();
    _routeDebounce = null;
    _liveRefreshDebounce?.cancel();
    _liveRefreshDebounce = null;
    _memoryReloadDebounce?.cancel();
    _memoryReloadDebounce = null;
    _mapReadyTimeout?.cancel();
    _fitDebounce?.cancel();
    _fitDebounce = null;

    if (!resetRouteFetch) return;

    _routeRequestToken++;
    if (_isFetchingRoute) {
      _isFetchingRoute = false;
      _notifyLiveUiIfNeeded();
    }
  }

  bool _isGpsFresh(int? ts) {
    if (ts == null) return false;
    final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    return ageMs >= 0 && ageMs <= 3 * 60 * 1000;
  }

  _GpsPoint? _effectiveGpsForRole(String role) {
    if (role == widget.myRole) {
      if (_myIsLive && _isGpsPointAccurateEnough(_myCurrentGps)) {
        return _myCurrentGps;
      }
      if (_myHasLocationHistory) return _myLastKnownGps ?? _myCurrentGps;
      return null;
    }
    if (_partnerIsLive && _isGpsPointAccurateEnough(_partnerCurrentGps)) {
      return _partnerCurrentGps;
    }
    if (_partnerHasLocationHistory) {
      return _partnerLastKnownGps ?? _partnerCurrentGps;
    }
    return null;
  }

  _GpsPoint? _effectiveLiveGpsForRole(String role) {
    if (role == widget.myRole) {
      return _myIsLive ? _myCurrentGps : null;
    }
    return _partnerIsLive ? _partnerCurrentGps : null;
  }

  bool _isRoleLive(String role) {
    return role == widget.myRole ? _myIsLive : _partnerIsLive;
  }

  bool _hasRoleLocationHistory(String role) {
    return role == widget.myRole
        ? _myHasLocationHistory
        : _partnerHasLocationHistory;
  }

  _LocationNodeState _parseLocationNodeState(dynamic raw) {
    final map = _toStringDynamicMap(raw);
    final parsedCurrent = _parseGpsPoint(map);
    final lastKnown = _parseGpsPoint(map['lastKnown']);
    final current =
        _isStableLiveGpsPoint(parsedCurrent, lastKnown) ? parsedCurrent : null;
    final isLive = (map['isLive'] == true || map['sharingEnabled'] == true) &&
        current != null &&
        _isGpsFresh(_readInt(map['ts']) ?? current.ts);
    final hasHistory = map['everShared'] == true ||
        map['sharingEnabled'] == true ||
        map['isLive'] == true ||
        lastKnown != null;
    return _LocationNodeState(
      current: current,
      lastKnown: lastKnown,
      isLive: isLive,
      hasHistory: hasHistory,
    );
  }

  Future<void> _initMap() async {
    try {
      _setRealtimePipelinesActive(true);

      // Automatically bootstrap location when entering the map screen
      unawaited(_bootstrapLocationTracking());

      await Future.wait([
        _primeMemoryPipeline().timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        ),
        _loadHistoryForDate(_selectedHistoryDate, fitToHistory: false)
            .timeout(const Duration(seconds: 8), onTimeout: () {}),
      ]);
    } catch (e) {
      debugPrint(
        'Map init failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService().translate('map_bntmthicha_687e4b'),
        ).message}',
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _scheduleMapReadyWatchdog();
    _queueMapIntroNotice();
  }

  void triggerMapStateUpdate() {
    if (mounted) setState(() {});
  }

  void _applyPanelStateUpdate(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) {
      return false;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }
    if (lat.abs() < 0.000001 && lng.abs() < 0.000001) {
      return false;
    }
    return true;
  }

  bool _isGpsPointAccurateEnough(_GpsPoint? point) {
    if (point == null) return false;
    final accuracy = point.accuracy;
    return accuracy != null &&
        accuracy.isFinite &&
        accuracy <= _kMapMaxLiveAccuracyMeters;
  }

  bool _isStableLiveGpsPoint(_GpsPoint? current, _GpsPoint? lastKnown) {
    if (!_isGpsPointAccurateEnough(current)) return false;
    if (lastKnown == null) return true;
    final distanceMeters = _distance.as(
      ll.LengthUnit.Meter,
      current!.latLng,
      lastKnown.latLng,
    );
    return distanceMeters <= 1500;
  }

  ({String label, Color color, bool isLow}) _gpsAccuracyPresentation(
      double? accuracy) {
    if (accuracy == null || !accuracy.isFinite) {
      return (
        label: context.tr('map_angogps_61d784'),
        color: _kMapTextMuted,
        isLow: false,
      );
    }
    if (accuracy <= _kMapGoodAccuracyMeters) {
      return (
        label: 'GPS tốt ±${accuracy.toStringAsFixed(0)} m',
        color: const Color(0xFF22C55E),
        isLow: false,
      );
    }
    if (accuracy <= _kMapFairAccuracyMeters) {
      return (
        label: 'GPS tạm ổn ±${accuracy.toStringAsFixed(0)} m',
        color: const Color(0xFFF59E0B),
        isLow: false,
      );
    }
    return (
      label: 'GPS yếu ±${accuracy.toStringAsFixed(0)} m',
      color: const Color(0xFFF97316),
      isLow: true,
    );
  }

  String? _gpsAccuracyHint(double? accuracy) {
    if (accuracy == null ||
        !accuracy.isFinite ||
        accuracy <= _kMapFairAccuracyMeters) {
      return null;
    }
    return context.tr('map_btvtrchnhx_dbd0e8');
  }

  Future<void> _bootstrapLocationTracking() async {
    if (_isBootstrappingLocation) return;
    if (mounted) {
      setState(() {
        _isBootstrappingLocation = true;
        _locationStatusMessage = context.tr('map_angxinquyn_ef9d31');
      });
    }

    final hasPerm = await _locationService
        .requestPermission(context: context)
        .timeout(const Duration(seconds: 15), onTimeout: () => false);
    if (!mounted) return;
    if (!hasPerm) {
      setState(() {
        _isBootstrappingLocation = false;
        _locationStatusMessage = kIsWeb
            ? context.tr('map_chacpquynl_36c63d')
            : context.tr('map_chacpquynv_efd5c3');
      });
      return;
    }

    setState(() {
      _locationStatusMessage = context.tr('map_angbtcpnht_1f1aeb');
    });

    final started = await _locationService
        .startTracking(
          widget.houseId,
          widget.myRole,
          context: context,
        )
        .timeout(const Duration(seconds: 12), onTimeout: () => false);

    if (!mounted) return;

    if (!started) {
      // Kiểm tra xem thực sự là do tắt GPS hay do lỗi khác
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _isBootstrappingLocation = false;
        _locationStatusMessage = serviceEnabled
            ? context.tr('map_gpschasnsn_4ffc6e')
            : context.tr('map_bnchabtnhv_df0da5');
      });
      return;
    }

    setState(() {
      _isBootstrappingLocation = false;
      _locationStatusMessage = null;
    });

    // Thêm hiệu ứng zoom nhẹ tới vị trí của mình khi vừa bật thành công
    _fitToVisibleData(includeHistory: false);
  }

  void _scheduleMapReadyWatchdog() {
    _mapReadyTimeout?.cancel();
    _mapReadyTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted || _isMapReady) return;
      setState(() {
        _mapInitError = context.tr('map_bnopenstre_1e6bc7');
      });
    });
  }

  Future<void> _reloadMemories() async {
    await _primeMemoryPipeline();
    return;

    final merged = <_MapMemoryItem>[];
    final seen = <String>{};

    Future<void> collectFrom(
      String path, {
      required bool allowDirectEntriesWithoutHouseId,
    }) async {
      final snap = await _dbRef.child(path).get();
      _extractMemoriesFromNode(
        snap.value,
        merged,
        seen,
        allowDirectEntriesWithoutHouseId: allowDirectEntriesWithoutHouseId,
      );
    }

    await collectFrom(
      'map_memories',
      allowDirectEntriesWithoutHouseId: false,
    );
    await collectFrom(
      'houses/${widget.houseId}/memories',
      allowDirectEntriesWithoutHouseId: true,
    );

    merged.sort((a, b) => (b.ts ?? 0).compareTo(a.ts ?? 0));
    final signature = _buildMemorySignature(merged);
    if (signature == _memorySignature) return;
    _memorySignature = signature;
    if (!mounted) return;
    setState(() {
      _memories = merged;
      _memorySummary = merged.isEmpty
          ? context.tr('map_chacghimkn_c6823f')
          : '${merged.length} ghim kỷ niệm trên bản đồ';
    });
    _memorySummary = _buildMemorySummaryLabel(merged.length);
    _rebuildStaticMarkers();
  }

  _MapMemoryItem? _memoryItemFromMap(String id, dynamic raw) {
    final map = _toStringDynamicMap(raw);
    final lat = _readDouble(map['lat']) ?? _readDouble(map['lt']);
    final lng = _readDouble(map['lng']) ?? _readDouble(map['lg']);
    if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
      return null;
    }

    final houseId = (map['houseId'] ?? map['hid'] ?? '').toString().trim();
    if (houseId.isNotEmpty && houseId != widget.houseId) return null;

    return _MapMemoryItem(
      id: id,
      lat: lat,
      lng: lng,
      title: (map['text'] ?? map['title'] ?? context.tr('map_knim_4f6aeb'))
          .toString(),
      note: (map['desc'] ?? map['note'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? map['url'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      ts: _readInt(map['ts']),
    );
  }

  void _extractMemoriesFromNode(
    dynamic raw,
    List<_MapMemoryItem> sink,
    Set<String> seen, {
    required bool allowDirectEntriesWithoutHouseId,
  }) {
    final map = _toStringDynamicMap(raw);
    if (map.isEmpty) return;

    final nestedHouseBucket = _toStringDynamicMap(map[widget.houseId]);
    if (nestedHouseBucket.isNotEmpty) {
      for (final entry in nestedHouseBucket.entries) {
        final item = _memoryItemFromMap(entry.key, entry.value);
        if (item == null) continue;
        final key = '${item.id}_${item.lat}_${item.lng}_${item.ts ?? 0}';
        if (seen.add(key)) {
          sink.add(item);
        }
      }
    }

    for (final entry in map.entries) {
      final entryMap = _toStringDynamicMap(entry.value);
      final directHouseId =
          (entryMap['houseId'] ?? entryMap['hid'] ?? '').toString().trim();
      if (!allowDirectEntriesWithoutHouseId && directHouseId.isEmpty) {
        continue;
      }

      final item = _memoryItemFromMap(entry.key, entry.value);
      if (item == null) continue;
      final key = '${item.id}_${item.lat}_${item.lng}_${item.ts ?? 0}';
      if (seen.add(key)) {
        sink.add(item);
      }
    }
  }

  _GpsPoint? _parseGpsPoint(dynamic raw) {
    final map = _toStringDynamicMap(raw);
    final lat = _readDouble(map['lt']) ?? _readDouble(map['lat']);
    final lng = _readDouble(map['lg']) ?? _readDouble(map['lng']);
    if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
      return null;
    }
    return _GpsPoint(
      lat: lat,
      lng: lng,
      ts: _readInt(map['ts']),
      accuracy: _readDouble(map['acc']),
      address: map['address']?.toString(),
    );
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  double? _readDouble(dynamic value) {
    double? result;
    if (value is num) {
      result = value.toDouble();
    } else {
      result = double.tryParse(value?.toString() ?? '');
    }
    if (result != null && (result.isNaN || result.isInfinite)) return null;
    return result;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _resolveAddressForPoint(_GpsPoint point, bool isMine) async {
    final address = await _reverseGeocode(point.lat, point.lng);
    if (!mounted || address == null || address.trim().isEmpty) return;

    final updated = point.copyWith(address: address);
    if (isMine) {
      if (_myCurrentGps?.lat == point.lat && _myCurrentGps?.lng == point.lng) {
        _myCurrentGps = updated;
      }
      if (_myLastKnownGps?.lat == point.lat &&
          _myLastKnownGps?.lng == point.lng) {
        _myLastKnownGps = updated;
      }
    } else {
      if (_partnerCurrentGps?.lat == point.lat &&
          _partnerCurrentGps?.lng == point.lng) {
        _partnerCurrentGps = updated;
      }
      if (_partnerLastKnownGps?.lat == point.lat &&
          _partnerLastKnownGps?.lng == point.lng) {
        _partnerLastKnownGps = updated;
      }
    }
    _refreshLiveData();
  }

  Future<_RouteSnapshot?> _fetchRouteSnapshot(
    _GpsPoint myPoint,
    _GpsPoint partnerPoint,
  ) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.osrmRouteBaseUrl}/'
        '${myPoint.lng},${myPoint.lat};${partnerPoint.lng},${partnerPoint.lat}'
        '?overview=full&steps=false&alternatives=false&geometries=geojson',
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'SoulLocket-App'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final decoded = response.body.length > 20000
          ? await compute(jsonDecode, response.body)
          : jsonDecode(response.body);
      final map = decoded as Map<String, dynamic>;
      final routes = map['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'];
      final coords =
          geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
      final points = <ll.LatLng>[];
      if (coords is List) {
        for (final item in coords) {
          if (item is List && item.length >= 2) {
            final lng = _readDouble(item[0]);
            final lat = _readDouble(item[1]);
            if (lat != null && lng != null) {
              points.add(ll.LatLng(lat, lng));
            }
          }
        }
      }
      if (points.length < 2) return null;

      return _RouteSnapshot(
        distanceMeters:
            (_readDouble(route['distance']) ?? 0).clamp(0, double.infinity),
        etaMinutes: (((_readDouble(route['duration']) ?? 0) / 60)
            .clamp(0, 9999)
            .ceil()),
        points: points,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    final cacheKey = _buildCoordinateCacheKey(lat, lng, precision: 4);
    if (_isCacheEntryFresh(
      _reverseGeocodeCacheTs,
      cacheKey,
      _kMapReverseGeocodeCacheTtl,
    )) {
      return _reverseGeocodeCache[cacheKey];
    }

    final pending = _reverseGeocodeInFlight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = () async {
      try {
        final uri = Uri.parse(
          '${AppConfig.nominatimReverseUrl}'
          '?format=jsonv2&lat=$lat&lon=$lng&accept-language=vi',
        );
        final response = await http.get(
          uri,
          headers: const {'User-Agent': 'SoulLocket-App'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return null;
        final decoded = response.body.length > 12000
            ? await compute(jsonDecode, response.body)
            : jsonDecode(response.body);
        final map = decoded as Map<String, dynamic>;
        final displayName = map['display_name']?.toString().trim();
        return displayName == null || displayName.isEmpty ? null : displayName;
      } catch (_) {
        return null;
      }
    }();

    _reverseGeocodeInFlight[cacheKey] = future;
    final result = await future;
    _reverseGeocodeInFlight.remove(cacheKey);
    _reverseGeocodeCache[cacheKey] = result;
    _reverseGeocodeCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch;
    _trimReverseGeocodeCache();
    return result;
  }

  Future<void> _loadHistoryForDate(
    DateTime date, {
    bool fitToHistory = true,
  }) async {
    final dateKey = _dayFormat.format(date);
    final myPoints = await _fetchRoleHistory(widget.myRole, dateKey);
    final partnerPoints = _isSingleRelationship
        ? const <_HistoryPoint>[]
        : await _fetchRoleHistory(widget.partnerRole, dateKey);

    final history = _HistoryBundle(
      dateKey: dateKey,
      myPoints: myPoints,
      partnerPoints: partnerPoints,
      myDistanceMeters: _calculatePathDistance(myPoints),
      partnerDistanceMeters: _calculatePathDistance(partnerPoints),
    );

    if (!mounted) return;
    setState(() {
      _selectedHistoryDate = date;
      _historyBundle = history;
    });
    _setHistoryPolylines(_buildHistoryPolylines(history));

    if (history.isEmpty) {
      _mapInsightText = _isSingleRelationship
          ? 'Ngày ${_prettyDayFormat.format(date)} chưa có dữ liệu di chuyển của bạn.'
          : 'Ngày ${_prettyDayFormat.format(date)} chưa có dữ liệu di chuyển của hai bạn.';
    } else {
      _mapInsightText = _isSingleRelationship
          ? 'Ngày ${_prettyDayFormat.format(date)}: Đang hiển thị lịch sử di chuyển của bạn.'
          : 'Ngày ${_prettyDayFormat.format(date)}: Đang hiển thị lịch sử di chuyển của hai bạn.';
    }

    _emitLiveUiSnapshot();
    _maybeScheduleAutoFit(fitToData: fitToHistory);
  }

  void _emitLiveUiSnapshot() {
    _liveUiVN.value = _LiveUiSnapshot(
      myPoint: _effectiveGpsForRole(widget.myRole),
      partnerPoint: _effectiveGpsForRole(widget.partnerRole),
      myIsLive: _isRoleLive(widget.myRole),
      partnerIsLive: _isRoleLive(widget.partnerRole),
      myHasHistory: _hasRoleLocationHistory(widget.myRole),
      partnerHasHistory: _hasRoleLocationHistory(widget.partnerRole),
      isFetchingRoute: _isFetchingRoute,
      myAddressText: _myAddressText,
      partnerAddressText: _partnerAddressText,
      myUpdatedText: _lastUpdatedLabel(_effectiveGpsForRole(widget.myRole)?.ts),
      partnerUpdatedText:
          _lastUpdatedLabel(_effectiveGpsForRole(widget.partnerRole)?.ts),
      distanceText: _distanceText,
      routeDistanceText: _routeDistanceText,
      etaText: _etaText,
      mapInsightText: _mapInsightText,
      mapAlert: _mapAlert,
    );
  }

  void _setStaticMarkers(List<fm.Marker> markers) {
    _staticMarkersVN.value = markers;
  }

  void _setCheckinPolylines(List<fm.Polyline> polylines) {
    _checkinPolylinesVN.value = polylines;
  }

  void _setHistoryPolylines(List<fm.Polyline> polylines) {
    final signature = _buildPolylineSignature(polylines);
    if (signature == _historyPolylineSignature) return;
    _historyPolylineSignature = signature;
    _historyPolylinesVN.value = polylines;
  }

  void _maybeScheduleAutoFit({required bool fitToData}) {
    if (!fitToData || _didAutoFit || _isFitting) return;
    _fitDebounce?.cancel();
    _fitDebounce = Timer(const Duration(milliseconds: 500), () {
      _fitToVisibleData(includeHistory: true);
    });
  }

  Future<List<_HistoryPoint>> _fetchRoleHistory(
    String role,
    String dateKey,
  ) async {
    final merged = <_HistoryPoint>[];
    final seen = <String>{};

    Future<void> collect(String path) async {
      final snap = await _dbRef
          .child(path)
          .orderByChild('ts')
          .limitToLast(_kGpsHistoryFetchLimit)
          .get();
      final raw = _toStringDynamicMap(snap.value);
      for (final entry in raw.entries) {
        final item = _toStringDynamicMap(entry.value);
        final lat = _readDouble(item['lt']) ?? _readDouble(item['lat']);
        final lng = _readDouble(item['lg']) ?? _readDouble(item['lng']);
        final ts = _readInt(item['ts']);
        if (lat == null || lng == null || ts == null) continue;
        final key = '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}_$ts';
        if (!seen.add(key)) continue;
        merged.add(
          _HistoryPoint(
            lat: lat,
            lng: lng,
            ts: ts,
            acc: _readDouble(item['acc']) ?? 0,
          ),
        );
      }
    }

    await collect('gps_history/${widget.houseId}/$role/$dateKey');

    merged.sort((a, b) => a.ts.compareTo(b.ts));
    final sanitized = _sanitizeHistoryPoints(merged);
    if (sanitized.length > 600) {
      return sanitized.sublist(sanitized.length - 600);
    }
    return sanitized;
  }

  List<_HistoryPoint> _sanitizeHistoryPoints(List<_HistoryPoint> points) {
    if (points.length < 2) return points;

    final cleaned = <_HistoryPoint>[];
    for (final point in points) {
      if (point.acc > 150) continue;
      if (cleaned.isEmpty) {
        cleaned.add(point);
        continue;
      }

      final previous = cleaned.last;
      final deltaMs = point.ts - previous.ts;
      if (deltaMs <= 0) continue;

      final distanceMeters = _distance
          .as(
            ll.LengthUnit.Meter,
            previous.latLng,
            point.latLng,
          )
          .toDouble();

      if (distanceMeters < 8 && deltaMs < 2 * 60 * 1000) {
        continue;
      }

      final speedMps = distanceMeters / (deltaMs / 1000);
      if (speedMps > 70 && point.acc > 40) {
        continue;
      }

      cleaned.add(point);
    }

    if (cleaned.isEmpty && points.isNotEmpty) {
      return [points.last];
    }
    return cleaned;
  }

  double _calculatePathDistance(List<_HistoryPoint> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += _distance
          .as(
            ll.LengthUnit.Meter,
            ll.LatLng(points[i - 1].lat, points[i - 1].lng),
            ll.LatLng(points[i].lat, points[i].lng),
          )
          .toDouble();
    }
    return total;
  }

  List<_HistoryPoint> _compressHistoryPoints(
    List<_HistoryPoint> points, {
    int maxPoints = 180,
  }) {
    if (points.length <= maxPoints || maxPoints < 3) {
      return points;
    }

    final sampled = <_HistoryPoint>[points.first];
    final step = (points.length - 1) / (maxPoints - 1);
    var cursor = step;
    var lastIndex = 0;

    while (sampled.length < maxPoints - 1) {
      final nextIndex = cursor.round().clamp(1, points.length - 2);
      if (nextIndex > lastIndex) {
        sampled.add(points[nextIndex]);
        lastIndex = nextIndex;
      }
      cursor += step;
    }

    if (!identical(sampled.last, points.last)) {
      sampled.add(points.last);
    }
    return sampled;
  }

  List<ll.LatLng> _compressLatLngPoints(
    List<ll.LatLng> points, {
    int maxPoints = _kMaxRenderedCheckinPathPoints,
  }) {
    if (points.length <= maxPoints || maxPoints < 3) {
      return points;
    }

    final sampled = <ll.LatLng>[points.first];
    final step = (points.length - 1) / (maxPoints - 1);
    var cursor = step;
    var lastIndex = 0;

    while (sampled.length < maxPoints - 1) {
      final nextIndex = cursor.round().clamp(1, points.length - 2);
      if (nextIndex > lastIndex) {
        sampled.add(points[nextIndex]);
        lastIndex = nextIndex;
      }
      cursor += step;
    }

    if (!identical(sampled.last, points.last)) {
      sampled.add(points.last);
    }
    return sampled;
  }

  fm.Polyline _buildSharpPolyline({
    required List<ll.LatLng> points,
    required Color color,
    List<Color>? gradientColors,
    double strokeWidth = 5,
    double borderStrokeWidth = 2,
    Color borderColor = _kMapRouteBorder,
  }) {
    return fm.Polyline(
      points: points,
      color: color,
      gradientColors: gradientColors,
      strokeWidth: strokeWidth,
      borderStrokeWidth: borderStrokeWidth,
      borderColor: borderColor,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    );
  }

  fm.Polyline _buildGlowPolyline({
    required List<ll.LatLng> points,
    required Color color,
    double strokeWidth = 10,
  }) {
    return fm.Polyline(
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    );
  }

  List<fm.Polyline> _buildHistoryPolylines(_HistoryBundle history) {
    final polylines = <fm.Polyline>[];
    if (history.myPoints.length >= 2) {
      final myRenderPoints = _compressHistoryPoints(history.myPoints)
          .map((e) => e.latLng)
          .toList();
      polylines.add(
        _buildSharpPolyline(
          points: myRenderPoints,
          color: _kMapBlue,
          gradientColors: const [_kMapBlueSoft, _kMapBlue],
          strokeWidth: 4.8,
          borderStrokeWidth: 1.8,
        ),
      );
    }
    if (history.partnerPoints.length >= 2) {
      final partnerRenderPoints = _compressHistoryPoints(history.partnerPoints)
          .map((e) => e.latLng)
          .toList();
      polylines.add(
        _buildSharpPolyline(
          points: partnerRenderPoints,
          color: _kMapPinkDeep,
          gradientColors: const [_kMapPinkSoft, _kMapPinkDeep],
          strokeWidth: 4.8,
          borderStrokeWidth: 1.8,
        ),
      );
    }
    return polylines;
  }

  ll.LatLng? _preferredFocusPoint() {
    if (_myLocation != null) return _myLocation;
    if (_partnerLocation != null) return _partnerLocation;
    if (_historyBundle.myPoints.isNotEmpty) {
      return _historyBundle.myPoints.last.latLng;
    }
    if (_historyBundle.partnerPoints.isNotEmpty) {
      return _historyBundle.partnerPoints.last.latLng;
    }
    return null;
  }

  Future<void> _focusCameraNearMe() async {
    if (_isFitting || !_isMapReady) return;

    final focusPoint = _preferredFocusPoint();
    if (focusPoint == null) return;

    _isFitting = true;
    try {
      final zoom = _myLocation != null
          ? (_isRoleLive(widget.myRole) ? 16.2 : 15.6)
          : (_partnerLocation != null ? 15.2 : 14.8);
      _mapController.move(focusPoint, zoom);
      _didAutoFit = true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
    } finally {
      _isFitting = false;
    }
  }

  Future<void> _fitToVisibleData({required bool includeHistory}) async {
    if (_isFitting || !_isMapReady) return;

    final points = <ll.LatLng>[];
    if (_myLocation != null) points.add(_myLocation!);
    if (_partnerLocation != null) points.add(_partnerLocation!);
    if (_routeSnapshot != null && _routeSnapshot!.points.isNotEmpty) {
      points.addAll(
        _compressLatLngPoints(_routeSnapshot!.points, maxPoints: 80),
      );
    }
    if (includeHistory) {
      points.addAll(
        _compressHistoryPoints(_historyBundle.myPoints, maxPoints: 120)
            .map((e) => e.latLng),
      );
      points.addAll(
        _compressHistoryPoints(_historyBundle.partnerPoints, maxPoints: 120)
            .map((e) => e.latLng),
      );
    }

    final uniquePoints = points
        .where((point) => _isValidCoordinate(point.latitude, point.longitude))
        .toSet()
        .toList();
    if (uniquePoints.isEmpty) {
      await _focusCameraNearMe();
      return;
    }

    _isFitting = true;
    try {
      if (uniquePoints.length == 1) {
        _mapController.move(uniquePoints.first, 15.8);
      } else {
        final size = MediaQuery.sizeOf(context);
        final bottomPadding = (size.height * 0.32).clamp(210.0, 310.0);
        final horizontalPadding = (size.width * 0.10).clamp(34.0, 56.0);
        _mapController.fitCamera(
          fm.CameraFit.coordinates(
            coordinates: uniquePoints,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              118,
              horizontalPadding,
              bottomPadding,
            ),
            maxZoom: 15.4,
          ),
        );
      }
      _didAutoFit = true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    } finally {
      _isFitting = false;
    }
  }

  Future<void> _showCheckinSheet() async {
    await _startCheckinPlacementFlow();
  }

  Future<void> _startCheckinPlacementFlow() async {
    if (_isSelectingCheckinLocation) return;
    final prefs = await OfflineCacheService.getPrefs();
    final shownCount = prefs.getInt('il_map_pin_hint_shown_count') ?? 0;
    if (shownCount < 3) {
      await prefs.setInt('il_map_pin_hint_shown_count', shownCount + 1);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.tr('map_bncthghimv_4c0adc'),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
    if (!mounted) return;
    setState(() {
      _isSelectingCheckinLocation = true;
    });
  }

  Future<void> _handleMapTapForCheckin(ll.LatLng point) async {
    if (!_isSelectingCheckinLocation) return;
    if (mounted) {
      setState(() {
        _isSelectingCheckinLocation = false;
      });
    }
    await _showCheckinSheetDialog(selectedPoint: point);
  }

  Future<void> _handleMapLongPress(ll.LatLng point) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(context.tr('map_anglychia_d19a1e') ?? 'Đang tải địa chỉ...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final addressName = await NominatimService.reverseGeocode(point);

    if (!mounted) return;
    messenger?.hideCurrentSnackBar();

    await _showCheckinSheetDialog(
      selectedPoint: point,
      initialName: addressName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: SLColors.bgMain,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SLColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: SLColors.textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        toolbarHeight: 62,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: SLColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SLColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: 'Tìm kiếm địa điểm',
                onPressed: _showSearchSheet,
                color: SLColors.textPrimary,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SLColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: context.tr('map_vvtrcabn_bc0bdb'),
                onPressed: _focusCameraNearMe,
                color: SLColors.textPrimary,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading ? _buildMapLoadingState() : _buildMapBodySection(),
    );
  }

  Widget _buildMapSurface() {
    return _buildMapSurfaceSection();
  }

  fm.Marker _buildOsmMarker(_MapMarkerSpec marker) {
    final markerSize = marker.compact ? 48.0 : 72.0;
    final markerWidth = marker.compact ? 62.0 : 92.0;
    final markerHeight = marker.compact ? 62.0 : 100.0;
    final avatarSize = marker.compact ? 26.0 : 50.0;
    final hasAvatar = marker.avatarUrl != null && marker.avatarUrl!.isNotEmpty;
    final hasSecondaryAvatar = marker.secondaryAvatarUrl != null &&
        marker.secondaryAvatarUrl!.isNotEmpty;

    return fm.Marker(
      key: ValueKey(marker.id),
      point: marker.point,
      width: markerWidth,
      height: markerHeight,
      alignment: Alignment.center,
      rotate: false,
      child: GestureDetector(
        onTap: marker.onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: Offset(0, -markerHeight / 2),
          child: SizedBox(
            width: markerWidth,
            height: markerHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                if (marker.pulse)
                  Positioned(
                    bottom: marker.compact ? 7 : 12,
                    child: marker.compact
                        ? Container(
                            width: markerSize,
                            height: markerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: marker.color.withValues(alpha: 0.18),
                            ),
                          )
                        : _PulseGlowCircle(
                            size: 68.0,
                            color: marker.color,
                          ),
                  ),
                if (marker.compact) ...[
                  SizedBox(
                    width: markerSize,
                    height: markerSize,
                    child: CustomPaint(
                      painter: _MapPinPainter(color: marker.color),
                    ),
                  ),
                  Positioned(
                    bottom: 22,
                    child: _buildPinnedMarkerFace(
                      size: avatarSize,
                      avatarUrl: marker.avatarUrl,
                      icon: marker.icon,
                      color: marker.color,
                      isCompact: true,
                    ),
                  ),
                ] else ...[
                  // Premium pointer tip at the bottom of the rounded rectangle pin
                  Positioned(
                    bottom: 12,
                    child: Transform.rotate(
                      angle: 45 * 3.141592653589793 / 180,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            right: BorderSide(color: marker.color, width: 2.5),
                            bottom: BorderSide(color: marker.color, width: 2.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Premium Rounded Square pin body
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: marker.color, width: 3.0),
                        boxShadow: [
                          BoxShadow(
                            color: marker.color.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPinnedMarkerFace(
                            size: avatarSize,
                            avatarUrl: marker.avatarUrl,
                            icon: marker.icon,
                            color: marker.color,
                            isCompact: false,
                          ),
                          if (hasSecondaryAvatar) ...[
                            const SizedBox(width: 4),
                            _buildPinnedMarkerFace(
                              size: avatarSize,
                              avatarUrl: marker.secondaryAvatarUrl,
                              icon: marker.secondaryIcon ??
                                  Icons.favorite_rounded,
                              color: marker.secondaryColor ?? _kMapPinkDeep,
                              isCompact: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (!marker.compact)
                  () {
                    var displayText = marker.title;
                    if (marker.battery != null) {
                      final pct = marker.battery!;
                      final isCharging = marker.isCharging == true;
                      final batteryEmoji =
                          isCharging ? '⚡' : (pct > 20 ? '🔋' : '🪫');
                      displayText += ' $batteryEmoji $pct%';
                    }

                    if (marker.speed != null && marker.speed! > 0) {
                      final speedKmh = (marker.speed! * 3.6).round();
                      if (speedKmh > 20) {
                        displayText += '\n🚗 $speedKmh km/h';
                      } else if (speedKmh > 2) {
                        displayText += '\n🚶 $speedKmh km/h';
                      } else {
                        displayText += '\nĐứng yên';
                      }
                    } else if (marker.speed != null) {
                      displayText += '\nĐứng yên';
                    }

                    return Positioned(
                      bottom: markerHeight - 4,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF18191A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: marker.color.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          displayText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedMarkerFace({
    required double size,
    required String? avatarUrl,
    required IconData icon,
    required Color color,
    bool isCompact = true,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final borderRadius =
        isCompact ? BorderRadius.circular(999) : BorderRadius.circular(16);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.95), width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(
                  icon,
                  color: Colors.white,
                  size: size * 0.54,
                ),
              )
            : Icon(
                icon,
                color: Colors.white,
                size: size * 0.54,
              ),
      ),
    );
  }

  Widget _buildMapFallbackSurface() {
    return _buildMapFallbackSection();
  }

  void _retryMapSurface() {
    setState(() {
      _mapInitError = null;
      _isMapReady = false;
    });
    _scheduleMapReadyWatchdog();
  }

  Widget _buildMapMarkerBubble({
    required _MapMarkerSpec marker,
    required double size,
    required String? avatarUrl,
    required IconData icon,
    required Color color,
    required bool compact,
    required bool pulse,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: compact ? color : null,
        gradient: compact
            ? null
            : LinearGradient(
                colors: [Color.lerp(color, Colors.white, 0.16)!, color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        boxShadow: compact
            ? const []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: pulse
              ? color.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: compact ? 0.78 : 0.88),
          width: pulse ? 2.2 : (compact ? 1.2 : 1.6),
        ),
        image: hasAvatar
            ? DecorationImage(
                image: CachedNetworkImageProvider(avatarUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasAvatar
          ? null
          : Icon(
              icon,
              color: Colors.white,
              size: compact ? 16 : 20,
            ),
    );
  }

  void _queueMapIntroNotice() {
    if (_didQueueMapIntroNotice) return;
    _didQueueMapIntroNotice = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeShowFirstMapNotice());
    });
  }
}

class _LiveUiSnapshot {
  final _GpsPoint? myPoint;
  final _GpsPoint? partnerPoint;
  final bool myIsLive;
  final bool partnerIsLive;
  final bool myHasHistory;
  final bool partnerHasHistory;
  final bool isFetchingRoute;
  final String myAddressText;
  final String partnerAddressText;
  final String myUpdatedText;
  final String partnerUpdatedText;
  final String distanceText;
  final String routeDistanceText;
  final String etaText;
  final String mapInsightText;
  final String? mapAlert;

  const _LiveUiSnapshot({
    required this.myPoint,
    required this.partnerPoint,
    required this.myIsLive,
    required this.partnerIsLive,
    required this.myHasHistory,
    required this.partnerHasHistory,
    required this.isFetchingRoute,
    required this.myAddressText,
    required this.partnerAddressText,
    required this.myUpdatedText,
    required this.partnerUpdatedText,
    required this.distanceText,
    required this.routeDistanceText,
    required this.etaText,
    required this.mapInsightText,
    required this.mapAlert,
  });

  factory _LiveUiSnapshot.empty() => _LiveUiSnapshot(
        myPoint: null,
        partnerPoint: null,
        myIsLive: false,
        partnerIsLive: false,
        myHasHistory: false,
        partnerHasHistory: false,
        isFetchingRoute: false,
        myAddressText: L10nService().translate('map_chacvtr_a02989'),
        partnerAddressText: L10nService().translate('map_chacvtr_a02989'),
        myUpdatedText: L10nService().translate('map_chacthigia_2ba794'),
        partnerUpdatedText: L10nService().translate('map_chacthigia_2ba794'),
        distanceText: L10nService().translate('map_angnhv_ea3669'),
        routeDistanceText: '--',
        etaText: '--',
        mapInsightText: L10nService().translate('map_angqutdliu_8eeb1b'),
        mapAlert: null,
      );
}

class _LocationNodeState {
  final _GpsPoint? current;
  final _GpsPoint? lastKnown;
  final bool isLive;
  final bool hasHistory;

  const _LocationNodeState({
    required this.current,
    required this.lastKnown,
    required this.isLive,
    required this.hasHistory,
  });
}

class _GpsPoint {
  final double lat;
  final double lng;
  final int? ts;
  final double? accuracy;
  final String? address;
  final int? battery;
  final bool? isCharging;
  final double? speed;

  const _GpsPoint({
    required this.lat,
    required this.lng,
    this.ts,
    this.accuracy,
    this.address,
    this.battery,
    this.isCharging,
    this.speed,
  });

  ll.LatLng get latLng => ll.LatLng(lat, lng);

  _GpsPoint copyWith({
    String? address,
    int? battery,
    bool? isCharging,
    double? speed,
  }) {
    return _GpsPoint(
      lat: lat,
      lng: lng,
      ts: ts,
      accuracy: accuracy,
      address: address ?? this.address,
      battery: battery ?? this.battery,
      isCharging: isCharging ?? this.isCharging,
      speed: speed ?? this.speed,
    );
  }
}

class _HistoryPoint {
  final double lat;
  final double lng;
  final int ts;
  final double acc;

  const _HistoryPoint({
    required this.lat,
    required this.lng,
    required this.ts,
    required this.acc,
  });

  ll.LatLng get latLng => ll.LatLng(lat, lng);
}

class _HistoryBundle {
  final String dateKey;
  final List<_HistoryPoint> myPoints;
  final List<_HistoryPoint> partnerPoints;
  final double myDistanceMeters;
  final double partnerDistanceMeters;

  const _HistoryBundle({
    required this.dateKey,
    required this.myPoints,
    required this.partnerPoints,
    required this.myDistanceMeters,
    required this.partnerDistanceMeters,
  });

  factory _HistoryBundle.empty() => const _HistoryBundle(
        dateKey: '',
        myPoints: <_HistoryPoint>[],
        partnerPoints: <_HistoryPoint>[],
        myDistanceMeters: 0,
        partnerDistanceMeters: 0,
      );

  bool get isEmpty => myPoints.isEmpty && partnerPoints.isEmpty;
  int get totalPoints => myPoints.length + partnerPoints.length;
  double get totalDistanceMeters => myDistanceMeters + partnerDistanceMeters;
}

class _RouteSnapshot {
  final double distanceMeters;
  final int etaMinutes;
  final List<ll.LatLng> points;

  const _RouteSnapshot({
    required this.distanceMeters,
    required this.etaMinutes,
    required this.points,
  });
}

class _MapMarkerSpec {
  final String id;
  final ll.LatLng point;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;
  final bool pulse;
  final String? avatarUrl;
  final String? secondaryAvatarUrl;
  final IconData? secondaryIcon;
  final Color? secondaryColor;
  final int? battery;
  final bool? isCharging;
  final double? speed;

  const _MapMarkerSpec({
    required this.id,
    required this.point,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
    this.pulse = false,
    this.avatarUrl,
    this.secondaryAvatarUrl,
    this.secondaryIcon,
    this.secondaryColor,
    this.battery,
    this.isCharging,
    this.speed,
  });
}

class _MapMemoryItem {
  final String id;
  final double lat;
  final double lng;
  final String title;
  final String note;
  final String imageUrl;
  final String author;
  final int? ts;

  const _MapMemoryItem({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    required this.note,
    required this.imageUrl,
    required this.author,
    required this.ts,
  });
}

class _MapCheckinItem {
  final String id;
  final double lat;
  final double lng;
  final String title;
  final String note;
  final String imageUrl;
  final String role;
  final String author;
  final int? ts;

  const _MapCheckinItem({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    required this.note,
    this.imageUrl = '',
    required this.role,
    required this.author,
    required this.ts,
  });
}

class _NearbyMapPinCandidate {
  final String key;
  final String title;
  final String kindLabel;
  final double lat;
  final double lng;
  final double distanceMeters;

  const _NearbyMapPinCandidate({
    required this.key,
    required this.title,
    required this.kindLabel,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  String get displayTitle {
    final trimmed = title.trim();
    return trimmed.isEmpty ? kindLabel : trimmed;
  }
}

class _MapPinPainter extends CustomPainter {
  const _MapPinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final circleRadius = size.width * 0.34;
    final circleCenter = Offset(centerX, size.height * 0.36);
    final tip = Offset(centerX, size.height);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final shadowPath = _pinPath(circleCenter, circleRadius, tip)
      ..shift(const Offset(0, 3));
    canvas.drawPath(shadowPath, shadowPaint);

    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pinPath = _pinPath(circleCenter, circleRadius, tip);
    canvas.drawPath(pinPath, pinPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(pinPath, strokePaint);
  }

  Path _pinPath(Offset circleCenter, double radius, Offset tip) {
    return Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: radius))
      ..moveTo(circleCenter.dx - radius * 0.62, circleCenter.dy + radius * 0.64)
      ..quadraticBezierTo(
        circleCenter.dx - radius * 0.16,
        circleCenter.dy + radius * 1.48,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        circleCenter.dx + radius * 0.16,
        circleCenter.dy + radius * 1.48,
        circleCenter.dx + radius * 0.62,
        circleCenter.dy + radius * 0.64,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PulseGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _PulseGlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
