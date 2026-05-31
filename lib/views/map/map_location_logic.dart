part of 'map_screen.dart';

final Expando<_MapMemoryPipelineState> _memoryPipelineStateExpando =
    Expando<_MapMemoryPipelineState>('map_memory_pipeline_state');

extension _MapLocationLogicExt on _MapScreenState {
  _MapMemoryPipelineState get _memoryPipelineState =>
      _memoryPipelineStateExpando[this] ??= _MapMemoryPipelineState();

  void _setRoleLocationState(String role, _LocationNodeState state) {
    if (role == widget.myRole) {
      _myCurrentGps = state.current;
      _myLastKnownGps = state.lastKnown;
      _myIsLive = state.isLive;
      _myHasLocationHistory = state.hasHistory;
      return;
    }
    _partnerCurrentGps = state.current;
    _partnerLastKnownGps = state.lastKnown;
    _partnerIsLive = state.isLive;
    _partnerHasLocationHistory = state.hasHistory;
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  // ignore: unused_element
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
      title: (map['title'] ?? map['name'] ?? context.tr('map_knim_4f6aeb')).toString(),
      note: (map['note'] ?? map['desc'] ?? '').toString(),
      author: (map['author'] ?? map['uid'] ?? '').toString(),
      ts: _readInt(map['ts'] ?? map['timestamp']),
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? '').toString(),
    );
  }

  double? _readDouble(dynamic val) {
    double? result;
    if (val is double) {
      result = val;
    } else if (val is int) {
      result = val.toDouble();
    } else if (val is String) {
      result = double.tryParse(val);
    }
    if (result != null && (result.isNaN || result.isInfinite)) return null;
    return result;
  }

  int? _readInt(dynamic val) {
    if (val is int) return val;
    if (val is double) {
      if (val.isNaN || val.isInfinite) return null;
      return val.toInt();
    }
    if (val is String) return int.tryParse(val);
    return null;
  }

  String _buildCheckinSignature(List<_MapCheckinItem> items) {
    if (items.isEmpty) return '';
    final buf = StringBuffer();
    for (final i in items.take(10)) {
      buf.write('${i.id}_${i.lat}_${i.lng}_${i.ts}|');
    }
    return buf.toString();
  }

  String _buildMemorySignature(List<_MapMemoryItem> items) {
    if (items.isEmpty) return '';
    final buf = StringBuffer();
    for (final item in items.take(20)) {
      buf.write('${item.id}_${item.lat}_${item.lng}_${item.ts ?? 0}|');
    }
    return buf.toString();
  }

  String _buildMarkerSignature(List<_MapMarkerSpec> markers) {
    if (markers.isEmpty) return '';
    final buf = StringBuffer();
    for (final marker in markers) {
      buf.write(
        '${marker.id}_${marker.point.latitude.toStringAsFixed(5)}_'
        '${marker.point.longitude.toStringAsFixed(5)}_'
        '${marker.icon.codePoint}_${marker.color.toARGB32()}_${marker.title}_'
        '${marker.subtitle}_${marker.pulse ? 1 : 0}|',
      );
    }
    return buf.toString();
  }

  String _buildPolylineSignature(List<fm.Polyline> polylines) {
    if (polylines.isEmpty) return '';
    final buf = StringBuffer();
    for (final polyline in polylines) {
      final gradientKey = polyline.gradientColors == null
          ? 'none'
          : polyline.gradientColors!.map((color) => color.toARGB32()).join('-');
      buf.write(
        '${polyline.color.toARGB32()}_${polyline.strokeWidth.toStringAsFixed(1)}_'
        '${polyline.borderColor.toARGB32()}_${polyline.borderStrokeWidth.toStringAsFixed(1)}_'
        '${gradientKey}_${polyline.points.length}_',
      );
      if (polyline.points.isNotEmpty) {
        final first = polyline.points.first;
        final last = polyline.points.last;
        buf.write(
          '${first.latitude.toStringAsFixed(5)}_${first.longitude.toStringAsFixed(5)}_'
          '${last.latitude.toStringAsFixed(5)}_${last.longitude.toStringAsFixed(5)}',
        );
      }
      buf.write('|');
    }
    return buf.toString();
  }

  String _buildLiveUiSignature() {
    final myPoint = _effectiveGpsForRole(widget.myRole);
    final partnerPoint = _effectiveGpsForRole(widget.partnerRole);
    String pointSig(_GpsPoint? point) {
      if (point == null) return 'none';
      return [
        point.lat.toStringAsFixed(5),
        point.lng.toStringAsFixed(5),
        point.ts ?? 0,
        point.accuracy?.toStringAsFixed(0) ?? '-',
      ].join('_');
    }

    return [
      _myAddressText,
      _partnerAddressText,
      _lastUpdatedLabel(myPoint?.ts),
      _lastUpdatedLabel(partnerPoint?.ts),
      _distanceText,
      _routeDistanceText,
      _etaText,
      _mapInsightText,
      _mapAlert ?? '',
      _isFetchingRoute ? '1' : '0',
      _isRoleLive(widget.myRole) ? '1' : '0',
      _isRoleLive(widget.partnerRole) ? '1' : '0',
      _hasRoleLocationHistory(widget.myRole) ? '1' : '0',
      _hasRoleLocationHistory(widget.partnerRole) ? '1' : '0',
      pointSig(myPoint),
      pointSig(partnerPoint),
    ].join('|');
  }

  void _notifyLiveUiIfNeeded() {
    final uiSignature = _buildLiveUiSignature();
    if (uiSignature == _liveUiSignature) return;
    _liveUiSignature = uiSignature;
    _emitLiveUiSnapshot();
  }

  _LocationNodeState _parseLocationNodeState(dynamic value) {
    final map = _toStringDynamicMap(value);
    final liveMap = _toStringDynamicMap(map['live']);
    final legacyLastMap = _toStringDynamicMap(map['last_known']);
    final lastMap = legacyLastMap.isNotEmpty
        ? legacyLastMap
        : _toStringDynamicMap(map['lastKnown']);

    _GpsPoint? current;
    _GpsPoint? lastKnown;

    final activeLiveMap = liveMap.isNotEmpty ? liveMap : map;
    final currentLat = _readDouble(activeLiveMap['lat'] ?? activeLiveMap['lt']);
    final currentLng = _readDouble(activeLiveMap['lng'] ?? activeLiveMap['lg']);
    final currentTs = _readInt(activeLiveMap['ts'] ?? map['lastSeenAt']);
    final hasLiveFlag = map['isLive'] == true ||
        map['sharingEnabled'] == true ||
        liveMap.isNotEmpty;
    final isLive = hasLiveFlag && _isGpsFresh(currentTs);

    if (currentLat != null &&
        currentLng != null &&
        _isValidCoordinate(currentLat, currentLng) &&
        isLive) {
      current = _GpsPoint(
        lat: currentLat,
        lng: currentLng,
        ts: currentTs,
        accuracy: _readDouble(activeLiveMap['acc']),
      );
    }

    if (lastMap.isNotEmpty) {
      final lat = _readDouble(lastMap['lat'] ?? lastMap['lt']);
      final lng = _readDouble(lastMap['lng'] ?? lastMap['lg']);
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        lastKnown = _GpsPoint(
          lat: lat,
          lng: lng,
          ts: _readInt(lastMap['ts']),
          accuracy: _readDouble(lastMap['acc']),
        );
      }
    } else if (currentLat != null &&
        currentLng != null &&
        _isValidCoordinate(currentLat, currentLng)) {
      lastKnown = _GpsPoint(
        lat: currentLat,
        lng: currentLng,
        ts: currentTs,
        accuracy: _readDouble(activeLiveMap['acc']),
      );
    }

    return _LocationNodeState(
      current: current,
      lastKnown: lastKnown,
      isLive: current != null,
      hasHistory: current != null ||
          lastKnown != null ||
          map['everShared'] == true ||
          map['sharingEnabled'] == true ||
          map['isLive'] == true,
    );
  }

  _GpsPoint? _effectiveGpsForRole(String role) {
    if (role == widget.myRole) {
      if (_myIsLive && _myCurrentGps != null) return _myCurrentGps;
      return _myLastKnownGps ?? _myCurrentGps;
    }
    if (_partnerIsLive && _partnerCurrentGps != null) return _partnerCurrentGps;
    return _partnerLastKnownGps ?? _partnerCurrentGps;
  }

  _GpsPoint? _effectiveLiveGpsForRole(String role) {
    if (role == widget.myRole) {
      return _myIsLive ? _myCurrentGps : null;
    }
    return _partnerIsLive ? _partnerCurrentGps : null;
  }

  bool _hasRoleLocationHistory(String role) {
    if (role == widget.myRole) {
      return _myHasLocationHistory;
    }
    return _partnerHasLocationHistory;
  }

  bool _isRoleLive(String role) {
    if (role == widget.myRole) {
      return _myIsLive;
    }
    return _partnerIsLive;
  }

  String _locationLabel({
    String? explicitAddress,
    double? lat,
    double? lng,
    int? ts,
    required bool isLive,
  }) {
    if (explicitAddress != null && explicitAddress.isNotEmpty) {
      return explicitAddress;
    }
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    return isLive ? context.tr('map_angcpnht_f4c117') : context.tr('map_khngcdliu_89903b');
  }

  String _formatDistanceMeters(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _handleProximityNotifications({
    required _GpsPoint? myLivePoint,
    required _GpsPoint? partnerLivePoint,
    required double? partnerDistanceMeters,
  }) {
    final bothLive = myLivePoint != null && partnerLivePoint != null;
    _handlePartnerNearbyNotification(
      bothLive: bothLive,
      partnerDistanceMeters: partnerDistanceMeters,
    );

    _handlePinnedPlaceNearbyNotification(
      role: widget.myRole,
      actorLabel: context.tr('map_bn_1fd75b'),
      livePoint: myLivePoint,
    );

    if (_isSingleRelationship) {
      _setActiveNearbyPinKeyForRole(widget.partnerRole, null);
      return;
    }

    _handlePinnedPlaceNearbyNotification(
      role: widget.partnerRole,
      actorLabel: widget.partnerName,
      livePoint: partnerLivePoint,
    );
  }

  void _handlePartnerNearbyNotification({
    required bool bothLive,
    required double? partnerDistanceMeters,
  }) {
    if (!bothLive || partnerDistanceMeters == null) {
      _didNotifyPartnerNearby = false;
      return;
    }

    if (partnerDistanceMeters > _kPartnerNearbyExitMeters) {
      _didNotifyPartnerNearby = false;
      return;
    }

    if (_didNotifyPartnerNearby ||
        partnerDistanceMeters > _kPartnerNearbyEnterMeters) {
      return;
    }

    _didNotifyPartnerNearby = true;
    _dispatchMapProximityNotice(
      key: 'partner_nearby',
      title: context.tr('map_haibnanggn_b5a8a9'),
      body:
          'Khoảng cách hiện tại chỉ còn ${_formatDistanceMeters(partnerDistanceMeters)}.',
    );
  }

  void _handlePinnedPlaceNearbyNotification({
    required String role,
    required String actorLabel,
    required _GpsPoint? livePoint,
  }) {
    if (livePoint == null) {
      _setActiveNearbyPinKeyForRole(role, null);
      return;
    }

    final activeKey = _activeNearbyPinKeyForRole(role);
    if (activeKey != null) {
      final activePin = _findPinnedLocationByKey(activeKey);
      if (activePin == null ||
          _distanceFromPin(livePoint, activePin) >
              _kPinnedPlaceNearbyExitMeters) {
        _setActiveNearbyPinKeyForRole(role, null);
      }
    }

    final nearestPin = _findNearestPinnedLocation(livePoint);
    if (nearestPin == null ||
        nearestPin.distanceMeters > _kPinnedPlaceNearbyEnterMeters) {
      return;
    }

    final nextKey = nearestPin.key;
    if (_activeNearbyPinKeyForRole(role) == nextKey) {
      return;
    }

    _setActiveNearbyPinKeyForRole(role, nextKey);
    _dispatchMapProximityNotice(
      key: '${role}_$nextKey',
      title: '$actorLabel đang tới gần địa điểm ghim',
      body:
          '${nearestPin.displayTitle} chỉ còn cách khoảng ${_formatDistanceMeters(nearestPin.distanceMeters)}.',
    );
  }

  _NearbyMapPinCandidate? _findNearestPinnedLocation(_GpsPoint livePoint) {
    _NearbyMapPinCandidate? nearestPin;

    void consider({
      required String key,
      required String title,
      required String kindLabel,
      required double lat,
      required double lng,
    }) {
      final distanceMeters = _distance
          .as(
            ll.LengthUnit.Meter,
            ll.LatLng(livePoint.lat, livePoint.lng),
            ll.LatLng(lat, lng),
          )
          .toDouble();

      if (nearestPin == null || distanceMeters < nearestPin!.distanceMeters) {
        nearestPin = _NearbyMapPinCandidate(
          key: key,
          title: title,
          kindLabel: kindLabel,
          lat: lat,
          lng: lng,
          distanceMeters: distanceMeters,
        );
      }
    }

    for (final memory in _memories) {
      consider(
        key: 'memory_${memory.id}',
        title: memory.title,
        kindLabel: context.tr('map_ghimknim_8f50a6'),
        lat: memory.lat,
        lng: memory.lng,
      );
    }

    for (final checkin in _checkins) {
      consider(
        key: 'checkin_${checkin.id}',
        title: checkin.title,
        kindLabel: 'Check-in',
        lat: checkin.lat,
        lng: checkin.lng,
      );
    }

    return nearestPin;
  }

  _NearbyMapPinCandidate? _findPinnedLocationByKey(String key) {
    if (key.startsWith('memory_')) {
      final memoryId = key.substring('memory_'.length);
      for (final memory in _memories) {
        if (memory.id != memoryId) continue;
        return _NearbyMapPinCandidate(
          key: key,
          title: memory.title,
          kindLabel: context.tr('map_ghimknim_8f50a6'),
          lat: memory.lat,
          lng: memory.lng,
          distanceMeters: 0,
        );
      }
      return null;
    }

    if (key.startsWith('checkin_')) {
      final checkinId = key.substring('checkin_'.length);
      for (final checkin in _checkins) {
        if (checkin.id != checkinId) continue;
        return _NearbyMapPinCandidate(
          key: key,
          title: checkin.title,
          kindLabel: 'Check-in',
          lat: checkin.lat,
          lng: checkin.lng,
          distanceMeters: 0,
        );
      }
    }

    return null;
  }

  double _distanceFromPin(_GpsPoint point, _NearbyMapPinCandidate pin) {
    return _distance
        .as(
          ll.LengthUnit.Meter,
          ll.LatLng(point.lat, point.lng),
          ll.LatLng(pin.lat, pin.lng),
        )
        .toDouble();
  }

  String? _activeNearbyPinKeyForRole(String role) {
    if (role == widget.myRole) {
      return _myActiveNearbyPinKey;
    }
    return _partnerActiveNearbyPinKey;
  }

  void _setActiveNearbyPinKeyForRole(String role, String? value) {
    if (role == widget.myRole) {
      _myActiveNearbyPinKey = value;
      return;
    }
    _partnerActiveNearbyPinKey = value;
  }

  void _dispatchMapProximityNotice({
    required String key,
    required String title,
    required String body,
  }) {
    final now = DateTime.now();
    final canShowBanner = _lastProximityBannerKey != key ||
        _lastProximityBannerAt == null ||
        now.difference(_lastProximityBannerAt!) > const Duration(seconds: 6);
    _lastProximityBannerKey = key;
    _lastProximityBannerAt = now;

    unawaited(
      _notificationService.showLocalNotification(
        title: title,
        body: body,
        data: {'screen': 'map'},
        dedupeKey: key,
      ),
    );

    if (!mounted || !canShowBanner) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(body),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _listenLiveGps() {
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

    Timer? myGpsDebounce;
    Timer? partnerGpsDebounce;

    final msgMyGpsListenFail = context.tr('map_khngththeo_b5b716');
    final msgPartnerGpsListenFail = context.tr('map_khngththeo_cd61b1');
    _myLocSub =
        _dbRef.child('gps/${widget.houseId}/${widget.myRole}').onValue.listen(
      (event) {
        myGpsDebounce?.cancel();
        myGpsDebounce = Timer(const Duration(milliseconds: 140), () {
          _setRoleLocationState(
            widget.myRole,
            _parseLocationNodeState(event.snapshot.value),
          );
          _scheduleLiveRefresh();
        });
      },
      onError: (Object error) {
        final message = AppErrorMapper.resolve(
          error,
          fallbackMessage: msgMyGpsListenFail,
        ).message;
        debugPrint('Map live GPS listen failed: $message');
      },
    );

    _partnerLocSub = _dbRef
        .child('gps/${widget.houseId}/${widget.partnerRole}')
        .onValue
        .listen(
      (event) {
        partnerGpsDebounce?.cancel();
        partnerGpsDebounce = Timer(const Duration(milliseconds: 140), () {
          _setRoleLocationState(
            widget.partnerRole,
            _parseLocationNodeState(event.snapshot.value),
          );
          _scheduleLiveRefresh();
        });
      },
      onError: (Object error) {
        final message = AppErrorMapper.resolve(
          error,
          fallbackMessage: msgPartnerGpsListenFail,
        ).message;
        debugPrint('Map partner GPS listen failed: $message');
      },
    );
  }

  void _listenMemoryNodes() {
    _disposeMemoryPipeline();
    final state = _memoryPipelineState;
    final publicHouseBucketQuery = _dbRef
        .child('map_memories/${widget.houseId}')
        .orderByChild('ts')
        .limitToLast(_kMapMemoryQueryLimit);
    final houseMemoriesQuery = _dbRef
        .child('houses/${widget.houseId}/memories')
        .orderByChild('ts')
        .limitToLast(_kMapMemoryQueryLimit);

    void syncMemorySource(
      _MapMemorySourceKind kind,
      Map<String, _MapMemoryItem> nextItems,
    ) {
      final didChange = _replaceMemorySourceKindFromItems(kind, nextItems);
      if (didChange) {
        _emitMergedMemoryState();
      }
    }

    syncMemorySource(_MapMemorySourceKind.publicDirect, const {});

    final msgPublicMemFail = context.tr('map_khngthtigh_1162c8');
    final msgHouseMemFail = context.tr('map_khngthtigh_2b4b7f');
    state.subscriptions.addAll([
      publicHouseBucketQuery.onValue.listen(
        (event) => syncMemorySource(
          _MapMemorySourceKind.publicHouseBucket,
          _extractHouseScopedMemoryItems(event.snapshot.value),
        ),
        onError: (Object error) {
          final message = AppErrorMapper.resolve(
            error,
            fallbackMessage: msgPublicMemFail,
          ).message;
          debugPrint('Map public memory listen failed: $message');
        },
      ),
      houseMemoriesQuery.onValue.listen(
        (event) => syncMemorySource(
          _MapMemorySourceKind.houseScoped,
          _extractHouseScopedMemoryItems(event.snapshot.value),
        ),
        onError: (Object error) {
          final message = AppErrorMapper.resolve(
            error,
            fallbackMessage: msgHouseMemFail,
          ).message;
          debugPrint('Map house memory listen failed: $message');
        },
      ),
    ]);
  }

  Future<void> _primeMemoryPipeline() async {
    final msgFail = context.tr('map_khngthtidl_876664');
    try {
      final publicSnapshot = await _dbRef
          .child('map_memories/${widget.houseId}')
          .orderByChild('ts')
          .limitToLast(_kMapMemoryQueryLimit)
          .get();
      final houseSnapshot = await _dbRef
          .child('houses/${widget.houseId}/memories')
          .orderByChild('ts')
          .limitToLast(_kMapMemoryQueryLimit)
          .get();

      final didChangePublicDirect = _replaceMemorySourceKindFromItems(
          _MapMemorySourceKind.publicDirect, const {});
      final didChangePublicBucket = _replaceMemorySourceKindFromItems(
        _MapMemorySourceKind.publicHouseBucket,
        _extractHouseScopedMemoryItems(publicSnapshot.value),
      );
      final didChangeHouseScoped = _replaceMemorySourceKindFromItems(
        _MapMemorySourceKind.houseScoped,
        _extractHouseScopedMemoryItems(houseSnapshot.value),
      );

      if (didChangePublicDirect ||
          didChangePublicBucket ||
          didChangeHouseScoped) {
        _emitMergedMemoryState();
      }
    } catch (error) {
      final message = AppErrorMapper.resolve(
        error,
        fallbackMessage: msgFail,
      ).message;
      debugPrint('Map memory bootstrap failed: $message');
    }
  }

  void _disposeMemoryPipeline() {
    final state = _memoryPipelineState;
    for (final sub in state.subscriptions) {
      unawaited(sub.cancel());
    }
    state.subscriptions.clear();
  }

  void _listenCheckins() {
    final checkinsSub = _checkinsSub;
    _checkinsSub = null;
    if (checkinsSub != null) {
      unawaited(checkinsSub.cancel());
    }

    final msgCheckinFail = context.tr('map_khngthtida_ed38df');
    _checkinsSub = _dbRef
        .child('checkins/${widget.houseId}')
        .orderByChild('ts')
        .limitToLast(_kMapCheckinQueryLimit)
        .onValue
        .listen(
      (event) {
        final items = <_MapCheckinItem>[];
        final raw = _toStringDynamicMap(event.snapshot.value);
        for (final entry in raw.entries) {
          final map = _toStringDynamicMap(entry.value);
          final lat = _readDouble(map['lat']) ?? _readDouble(map['lt']);
          final lng = _readDouble(map['lng']) ?? _readDouble(map['lg']);
          if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
            continue;
          }
          items.add(
            _MapCheckinItem(
              id: entry.key,
              lat: lat,
              lng: lng,
              title: (map['name'] ?? 'Check-in').toString(),
              note: (map['note'] ?? '').toString(),
              imageUrl: (map['imageUrl'] ?? map['photoUrl'] ?? '').toString(),
              role: (map['role'] ?? '').toString(),
              author: (map['author'] ?? map['uid'] ?? '').toString(),
              ts: _readInt(map['ts']),
            ),
          );
        }
        items.sort((a, b) => (b.ts ?? 0).compareTo(a.ts ?? 0));
        final signature = _buildCheckinSignature(items);
        if (signature == _checkinSignature) return;
        _checkinSignature = signature;
        if (!mounted) return;
        _applyPanelStateUpdate(() {
          _checkins = items;
          _checkinSummary = items.isEmpty
              ? context.tr('map_chacchecki_51b108')
              : '${items.length} check-in gần đây';
          _checkinSummary = _buildCheckinSummaryLabel(items.length);
        });
        _rebuildStaticMarkersCached(
          rebuildMemories: false,
          rebuildCheckins: true,
        );
      },
      onError: (Object error) {
        final message = AppErrorMapper.resolve(
          error,
          fallbackMessage: msgCheckinFail,
        ).message;
        debugPrint('Map check-in listen failed: $message');
      },
    );
  }

  void _scheduleLiveRefresh() {
    _liveRefreshDebounce?.cancel();
    _liveRefreshDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _refreshLiveDataSmart();
    });
  }

  bool _replaceMemorySourceKindFromItems(
    _MapMemorySourceKind kind,
    Map<String, _MapMemoryItem> nextItems,
  ) {
    final state = _memoryPipelineState;
    final previousScopedKeys = Set<String>.from(
      state.scopedKeysByKind[kind] ?? const <String>{},
    );
    var didChange = false;

    for (final entry in nextItems.entries) {
      didChange = _upsertMemorySourceItem(
            kind,
            rawKey: entry.key,
            item: entry.value,
            emitNow: false,
          ) ||
          didChange;
      previousScopedKeys.remove(_memoryScopedKey(kind, entry.key));
    }

    for (final scopedKey in previousScopedKeys) {
      didChange = _removeMemorySourceByScopedKey(
            scopedKey,
            emitNow: false,
          ) ||
          didChange;
    }

    return didChange;
  }

  Map<String, _MapMemoryItem> _extractHouseScopedMemoryItems(dynamic raw) {
    final result = <String, _MapMemoryItem>{};
    final map = _toStringDynamicMap(raw);
    for (final entry in map.entries) {
      final item = _parseMemoryItemForPipeline(entry.key, entry.value);
      if (item != null) {
        result[entry.key] = item;
      }
    }
    return result;
  }

  _MapMemoryItem? _parseMemoryItemForPipeline(String id, dynamic raw) {
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
      title: (map['text'] ?? map['title'] ?? context.tr('map_knim_4f6aeb')).toString(),
      note: (map['desc'] ?? map['note'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? map['url'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      ts: _readInt(map['ts']),
    );
  }

  // ignore: unused_element
  bool _upsertMemorySource(
    _MapMemorySourceKind kind, {
    required String rawKey,
    required dynamic raw,
  }) {
    final item = _parseMemoryItemForPipeline(rawKey, raw);
    if (item == null) {
      return _removeMemorySource(kind, rawKey: rawKey);
    }
    return _upsertMemorySourceItem(kind, rawKey: rawKey, item: item);
  }

  bool _upsertMemorySourceItem(
    _MapMemorySourceKind kind, {
    required String rawKey,
    required _MapMemoryItem item,
    bool emitNow = true,
  }) {
    final state = _memoryPipelineState;
    final scopedKey = _memoryScopedKey(kind, rawKey);
    final nextRecord = _MapMemorySourceRecord(
      scopedKey: scopedKey,
      kind: kind,
      rawKey: rawKey,
      dedupeKey: _memoryDedupKey(item),
      contentKey: _memoryContentKey(item),
      item: item,
    );

    final previousRecord = state.recordsByScopedKey[scopedKey];
    if (previousRecord != null &&
        previousRecord.dedupeKey == nextRecord.dedupeKey &&
        previousRecord.contentKey == nextRecord.contentKey) {
      return false;
    }

    final affectedKeys = <String>{};
    if (previousRecord != null) {
      _detachMemoryRecord(state, previousRecord);
      affectedKeys.add(previousRecord.dedupeKey);
    }

    _attachMemoryRecord(state, nextRecord);
    affectedKeys.add(nextRecord.dedupeKey);

    if (emitNow) {
      _applyAffectedMemoryKeys(state, affectedKeys);
    }
    return true;
  }

  bool _removeMemorySource(
    _MapMemorySourceKind kind, {
    required String rawKey,
  }) {
    return _removeMemorySourceByScopedKey(
      _memoryScopedKey(kind, rawKey),
      emitNow: true,
    );
  }

  bool _removeMemorySourceByScopedKey(
    String scopedKey, {
    required bool emitNow,
  }) {
    final state = _memoryPipelineState;
    final previousRecord = state.recordsByScopedKey[scopedKey];
    if (previousRecord == null) return false;

    _detachMemoryRecord(state, previousRecord);
    if (emitNow) {
      _applyAffectedMemoryKeys(state, {previousRecord.dedupeKey});
    }
    return true;
  }

  void _attachMemoryRecord(
    _MapMemoryPipelineState state,
    _MapMemorySourceRecord record,
  ) {
    state.recordsByScopedKey[record.scopedKey] = record;
    state.scopedKeysByDedupKey
        .putIfAbsent(record.dedupeKey, () => <String>{})
        .add(record.scopedKey);
    state.scopedKeysByKind
        .putIfAbsent(record.kind, () => <String>{})
        .add(record.scopedKey);
  }

  void _detachMemoryRecord(
    _MapMemoryPipelineState state,
    _MapMemorySourceRecord record,
  ) {
    state.recordsByScopedKey.remove(record.scopedKey);

    final dedupeKeys = state.scopedKeysByDedupKey[record.dedupeKey];
    if (dedupeKeys != null) {
      dedupeKeys.remove(record.scopedKey);
      if (dedupeKeys.isEmpty) {
        state.scopedKeysByDedupKey.remove(record.dedupeKey);
      }
    }

    final kindKeys = state.scopedKeysByKind[record.kind];
    if (kindKeys != null) {
      kindKeys.remove(record.scopedKey);
      if (kindKeys.isEmpty) {
        state.scopedKeysByKind.remove(record.kind);
      }
    }
  }

  void _applyAffectedMemoryKeys(
    _MapMemoryPipelineState state,
    Set<String> affectedKeys,
  ) {
    var didChange = false;

    for (final dedupeKey in affectedKeys) {
      final previousCanonical = state.canonicalByDedupKey[dedupeKey];
      final nextCanonical = _pickCanonicalMemoryRecord(state, dedupeKey);

      if (previousCanonical == null && nextCanonical == null) {
        continue;
      }

      if (previousCanonical == null) {
        state.canonicalByDedupKey[dedupeKey] = nextCanonical!;
        _insertOrderedMemoryKey(state, dedupeKey, nextCanonical);
        didChange = true;
        continue;
      }

      if (nextCanonical == null) {
        state.canonicalByDedupKey.remove(dedupeKey);
        state.orderedDedupKeys.remove(dedupeKey);
        didChange = true;
        continue;
      }

      final sameRecord =
          previousCanonical.scopedKey == nextCanonical.scopedKey &&
              previousCanonical.contentKey == nextCanonical.contentKey &&
              previousCanonical.item.ts == nextCanonical.item.ts;
      if (sameRecord) {
        continue;
      }

      state.canonicalByDedupKey[dedupeKey] = nextCanonical;
      state.orderedDedupKeys.remove(dedupeKey);
      _insertOrderedMemoryKey(state, dedupeKey, nextCanonical);
      didChange = true;
    }

    if (didChange) {
      _emitMergedMemoryState();
    }
  }

  _MapMemorySourceRecord? _pickCanonicalMemoryRecord(
    _MapMemoryPipelineState state,
    String dedupeKey,
  ) {
    final scopedKeys = state.scopedKeysByDedupKey[dedupeKey];
    if (scopedKeys == null || scopedKeys.isEmpty) return null;

    _MapMemorySourceRecord? bestRecord;
    for (final scopedKey in scopedKeys) {
      final record = state.recordsByScopedKey[scopedKey];
      if (record == null) continue;
      if (bestRecord == null ||
          record.priority > bestRecord.priority ||
          (record.priority == bestRecord.priority &&
              (record.rawKey.compareTo(bestRecord.rawKey) < 0 ||
                  (record.rawKey == bestRecord.rawKey &&
                      scopedKey.compareTo(bestRecord.scopedKey) < 0)))) {
        bestRecord = record;
      }
    }
    return bestRecord;
  }

  void _insertOrderedMemoryKey(
    _MapMemoryPipelineState state,
    String dedupeKey,
    _MapMemorySourceRecord record,
  ) {
    var insertIndex = state.orderedDedupKeys.length;
    for (var i = 0; i < state.orderedDedupKeys.length; i++) {
      final current = state.canonicalByDedupKey[state.orderedDedupKeys[i]];
      if (current == null) continue;
      if (_compareMemoryItems(record.item, current.item) < 0) {
        insertIndex = i;
        break;
      }
    }
    state.orderedDedupKeys.insert(insertIndex, dedupeKey);
  }

  int _compareMemoryItems(_MapMemoryItem left, _MapMemoryItem right) {
    final timeCompare = (right.ts ?? 0).compareTo(left.ts ?? 0);
    if (timeCompare != 0) return timeCompare;
    return left.id.compareTo(right.id);
  }

  String _memoryScopedKey(_MapMemorySourceKind kind, String rawKey) {
    return '${kind.prefix}:$rawKey';
  }

  String _memoryDedupKey(_MapMemoryItem item) {
    return [
      item.id,
      item.lat.toStringAsFixed(5),
      item.lng.toStringAsFixed(5),
      item.ts ?? 0,
    ].join('|');
  }

  String _memoryContentKey(_MapMemoryItem item) {
    return [
      item.id,
      item.lat.toStringAsFixed(5),
      item.lng.toStringAsFixed(5),
      item.ts ?? 0,
      item.title,
      item.note,
      item.imageUrl,
      item.author,
    ].join('|');
  }

  void _emitMergedMemoryState() {
    final state = _memoryPipelineState;
    final merged = <_MapMemoryItem>[
      for (final dedupeKey in state.orderedDedupKeys)
        state.canonicalByDedupKey[dedupeKey]!.item,
    ];

    final signature = _buildMemorySignature(merged);
    if (signature == _memorySignature) return;

    _memorySignature = signature;
    if (!mounted) return;

    _applyPanelStateUpdate(() {
      _memories = merged;
      _memorySummary = _buildMemorySummaryLabel(merged.length);
    });
    _rebuildStaticMarkersCached(
      rebuildMemories: true,
      rebuildCheckins: false,
    );
  }

  void _resolveAddressForPoint(_GpsPoint point, bool isMyRole) async {
    try {
      final address = await _reverseGeocode(point.lat, point.lng);
      if (!mounted || address == null || address.trim().isEmpty) return;

      final updated = point.copyWith(address: address);
      if (isMyRole) {
        if (_myCurrentGps?.lat == point.lat &&
            _myCurrentGps?.lng == point.lng) {
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

      _refreshLiveDataSmart();
    } catch (_) {}
  }

  Future<_RouteSnapshot?> _fetchRouteSnapshot(
      ll.LatLng start, ll.LatLng end) async {
    final cacheKey = _buildRouteCacheLookupKey(start, end);
    if (_isCacheEntryFresh(_routeCacheTs, cacheKey, _kMapRouteCacheTtl)) {
      return _routeCache[cacheKey];
    }

    final pending = _routeInFlight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = () async {
      try {
        final uri = Uri.parse(
          '${AppConfig.osrmRouteBaseUrl}/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=simplified&steps=false&geometries=geojson',
        );
        final response = await http.get(
          uri,
          headers: const {'User-Agent': 'SoulLocket-App'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return null;

        final map = jsonDecode(response.body) as Map<String, dynamic>;
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
    }();

    _routeInFlight[cacheKey] = future;
    final result = await future;
    _routeInFlight.remove(cacheKey);
    _routeCache[cacheKey] = result;
    _routeCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch;
    _trimRouteCache();
    return result;
  }

  String _buildRouteKey(_GpsPoint myPoint, _GpsPoint partnerPoint) {
    String round4(double value) => value.toStringAsFixed(4);
    return '${round4(myPoint.lat)}_${round4(myPoint.lng)}_'
        '${round4(partnerPoint.lat)}_${round4(partnerPoint.lng)}';
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

  void _refreshLiveData() {
    _refreshLiveDataSmart();
  }

  void _scheduleAddressRefresh() {
    final myPoint = _effectiveGpsForRole(widget.myRole);
    final partnerPoint =
        _isSingleRelationship ? null : _effectiveGpsForRole(widget.partnerRole);

    final myKey = myPoint == null
        ? null
        : '${myPoint.lat.toStringAsFixed(4)}_${myPoint.lng.toStringAsFixed(4)}';
    final partnerKey = partnerPoint == null
        ? null
        : '${partnerPoint.lat.toStringAsFixed(4)}_${partnerPoint.lng.toStringAsFixed(4)}';

    if (myPoint != null && myKey != _myAddressKey) {
      _myAddressKey = myKey;
      _resolveAddressForPoint(myPoint, true);
    }
    if (partnerPoint != null && partnerKey != _partnerAddressKey) {
      _partnerAddressKey = partnerKey;
      _resolveAddressForPoint(partnerPoint, false);
    }
  }

  String _lastUpdatedLabel(int? ts) {
    if (ts == null || ts <= 0) return context.tr('map_chacthigia_2ba794');
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    if (age.inSeconds < 45) return context.tr('map_vacpnht_e8745a');
    if (age.inMinutes < 60) return '${age.inMinutes} phút trước';
    if (age.inHours < 24) return '${age.inHours} giờ trước';
    return '${age.inDays} ngày trước';
  }

  void _refreshLiveDataSmart() {
    final myPoint = _effectiveGpsForRole(widget.myRole);
    final partnerPoint =
        _isSingleRelationship ? null : _effectiveGpsForRole(widget.partnerRole);
    final myLivePoint = _effectiveLiveGpsForRole(widget.myRole);
    final partnerLivePoint = _isSingleRelationship
        ? null
        : _effectiveLiveGpsForRole(widget.partnerRole);
    final myLive = myLivePoint != null;
    final partnerLive = partnerLivePoint != null;
    final myHasHistory = _hasRoleLocationHistory(widget.myRole);
    final partnerHasHistory = _isSingleRelationship
        ? false
        : _hasRoleLocationHistory(widget.partnerRole);

    final myAddressText = _locationLabel(
      explicitAddress: myPoint?.address,
      lat: myPoint?.lat,
      lng: myPoint?.lng,
      ts: myPoint?.ts,
      isLive: myLive,
    );
    final partnerAddressText = partnerPoint == null
        ? context.tr('map_chacvtr_a02989')
        : _locationLabel(
            explicitAddress: partnerPoint.address,
            lat: partnerPoint.lat,
            lng: partnerPoint.lng,
            ts: partnerPoint.ts,
            isLive: partnerLive,
          );

    String distanceText;
    String routeDistanceText = '--';
    String etaText = '--';
    String mapInsightText;
    String? mapAlert;
    double? partnerDistanceMeters;

    if (_isSingleRelationship) {
      if (myPoint != null && myLive) {
        distanceText = context.tr('map_angchias_51b41c');
        mapInsightText = context.tr('map_bnanghinth_85b060');
      } else if (myPoint != null || myHasHistory) {
        distanceText = context.tr('map_vtrlu_7f955b');
        mapInsightText =
            context.tr('map_bnanghinth_652b9f');
        mapAlert =
            context.tr('map_angdngvtrc_9a3510');
      } else {
        distanceText = context.tr('map_chabtgps_aa3568');
        mapInsightText = context.tr('map_btgpsbnhin_4d7d3f');
        mapAlert = context.tr('map_chabtgpsbm_b329bb');
      }
    } else if (myPoint != null && partnerPoint != null) {
      final directMeters = _distance
          .as(
            ll.LengthUnit.Meter,
            ll.LatLng(myPoint.lat, myPoint.lng),
            ll.LatLng(partnerPoint.lat, partnerPoint.lng),
          )
          .toDouble();
      partnerDistanceMeters = directMeters;
      final hasExactRoute =
          _routeSnapshot != null && _routeSnapshot!.points.length >= 2;

      distanceText = _formatDistanceMeters(directMeters);
      routeDistanceText = hasExactRoute
          ? _formatDistanceMeters(_routeSnapshot!.distanceMeters)
          : (_isFetchingRoute
              ? context.tr('map_angtnhqung_7529aa')
              : context.tr('map_chacqungng_38c097'));
      etaText = hasExactRoute ? '${_routeSnapshot!.etaMinutes} phút' : '--';

      if (myLive && partnerLive) {
        mapInsightText = hasExactRoute
            ? 'Quãng đường hiện tại là $routeDistanceText, thời gian dự kiến $etaText.'
            : context.tr('map_chaiangbtv_4c3308');
      } else if (!myLive && !partnerLive) {
        mapInsightText = hasExactRoute
            ? 'Đang dùng vị trí cuối cùng đã lưu của cả hai. Quãng đường khoảng $routeDistanceText.'
            : context.tr('map_angdngvtrc_e2f616');
        mapAlert =
            context.tr('map_gpscachaia_8a5ecd');
      } else if (!partnerLive) {
        mapInsightText =
            '${widget.partnerName} đang ở vị trí cuối cùng đã lưu. Khoảng cách vẫn được giữ để bạn tiện theo dõi.';
        mapAlert = 'Đang dùng vị trí cuối của ${widget.partnerName}.';
      } else {
        mapInsightText =
            'Bản đồ đang dùng vị trí cuối cùng đã lưu của bạn để tính khoảng cách với ${widget.partnerName}.';
        mapAlert = context.tr('map_gpscabnang_a6da92');
      }

      if (directMeters <= 120) {
        mapAlert = context.tr('map_haibnangrt_0b7f41');
      } else if (directMeters <= 1500) {
        mapAlert =
            'Hai bạn chỉ cách nhau ${_formatDistanceMeters(directMeters)}.';
      } else {
        mapAlert ??= myLive && partnerLive
            ? context.tr('map_qungngtrnb_5fc7ae')
            : context.tr('map_khongcchan_3d172e');
      }
    } else if (myPoint != null || partnerPoint != null) {
      if (!partnerHasHistory) {
        distanceText = context.tr('map_ngiychabtg_defe08');
        mapInsightText =
            '${widget.partnerName} chưa bật vị trí nên bản đồ chưa thể đo khoảng cách của hai bạn.';
        mapAlert =
            '${widget.partnerName} chưa bật GPS. Chờ người ấy bật để xem khoảng cách.';
      } else if (!myHasHistory) {
        distanceText = context.tr('map_bnchabtgps_fc6f46');
        mapInsightText =
            'Bạn chưa bật vị trí nên bản đồ chưa đủ dữ liệu để đo khoảng cách với ${widget.partnerName}.';
        mapAlert = context.tr('map_bnchabtgps_2de829');
      } else if (!partnerLive) {
        distanceText = context.tr('map_vtrcuilu_b4c8ee');
        mapInsightText =
            '${widget.partnerName} đã tắt vị trí. Bản đồ đang giữ lại vị trí cuối cùng đã lưu.';
        mapAlert = '${widget.partnerName} đã tắt GPS. Bản đồ giữ vị trí cuối.';
      } else if (!myLive) {
        distanceText = context.tr('map_vtrcuilu_b4c8ee');
        mapInsightText =
            context.tr('map_bnangdngvt_3c6c9e');
        mapAlert = context.tr('map_gpscabnang_6101f9');
      } else {
        distanceText = context.tr('map_angcpnht_f4c117');
        mapInsightText =
            context.tr('map_bnangngbli_a9747b');
      }
    } else {
      distanceText = context.tr('map_angnhv_ea3669');
      mapInsightText =
          context.tr('map_btgpsbnhin_b8be56');
      mapAlert = context.tr('map_btgpsbtucp_89df3c');
    }

    _myAddressText = myAddressText;
    _partnerAddressText = partnerAddressText;
    _distanceText = distanceText;
    _routeDistanceText = routeDistanceText;
    _etaText = etaText;
    _mapInsightText = mapInsightText;
    _mapAlert = mapAlert;

    _handleProximityNotifications(
      myLivePoint: myLivePoint,
      partnerLivePoint: partnerLivePoint,
      partnerDistanceMeters: partnerDistanceMeters,
    );
    _scheduleAddressRefresh();
    _scheduleRouteRefreshSmart();

    _notifyLiveUiIfNeeded();
    _rebuildMapObjects(fitToData: !_didAutoFit);
  }

  void _scheduleRouteRefreshSmart() {
    if (_isSingleRelationship) {
      _routeDebounce?.cancel();
      _routeRequestToken++;
      if (_routeSnapshot != null || _isFetchingRoute) {
        _routeSnapshot = null;
        _isFetchingRoute = false;
        _notifyLiveUiIfNeeded();
      }
      _lastRouteKey = null;
      return;
    }

    final myPoint = _effectiveGpsForRole(widget.myRole);
    final partnerPoint = _effectiveGpsForRole(widget.partnerRole);
    if (myPoint == null || partnerPoint == null) {
      _routeDebounce?.cancel();
      _routeRequestToken++;
      if (_routeSnapshot != null || _isFetchingRoute) {
        _routeSnapshot = null;
        _isFetchingRoute = false;
        _notifyLiveUiIfNeeded();
      }
      _lastRouteKey = null;
      return;
    }

    final routeKey = _buildRouteKey(myPoint, partnerPoint);
    if (routeKey == _lastRouteKey) return;

    _routeDebounce?.cancel();
    final requestToken = ++_routeRequestToken;
    _routeDebounce = Timer(const Duration(milliseconds: 1200), () async {
      _lastRouteKey = routeKey;
      _isFetchingRoute = true;
      _notifyLiveUiIfNeeded();
      final snapshot = await _fetchRouteSnapshot(
        ll.LatLng(myPoint.lat, myPoint.lng),
        ll.LatLng(partnerPoint.lat, partnerPoint.lng),
      );
      if (!mounted || requestToken != _routeRequestToken) return;
      _routeSnapshot = snapshot;
      _isFetchingRoute = false;
      _notifyLiveUiIfNeeded();
      _refreshLiveDataSmart();
      _rebuildMapObjects(fitToData: false);
    });
  }

  void _rebuildMapObjects({required bool fitToData}) {
    final liveMarkerSpecs = <_MapMarkerSpec>[];
    final livePolylines = <fm.Polyline>[];

    final myPoint = _effectiveGpsForRole(widget.myRole);
    final partnerPoint =
        _isSingleRelationship ? null : _effectiveGpsForRole(widget.partnerRole);
    final myLive = _isRoleLive(widget.myRole);
    final partnerLive =
        _isSingleRelationship ? false : _isRoleLive(widget.partnerRole);

    ll.LatLng? partnerLatLng;
    if (partnerPoint != null) {
      partnerLatLng = partnerPoint.latLng;
    }

    if (myPoint != null &&
        partnerPoint != null &&
        partnerLatLng != null &&
        _distance.as(ll.LengthUnit.Meter, myPoint.latLng, partnerPoint.latLng) <
            10) {
      final accent = myLive ? _kMapBlue : const Color(0xFF64748B);
      liveMarkerSpecs.add(
        _MapMarkerSpec(
          id: 'couple_same_position',
          point: myPoint.latLng,
          icon: myLive
              ? Icons.person_pin_circle_rounded
              : Icons.history_toggle_off_rounded,
          color: accent,
          title: '${widget.myName} & ${widget.partnerName}',
          subtitle: _myAddressText,
          pulse: myLive || partnerLive,
          avatarUrl: widget.myAvatarUrl,
          secondaryAvatarUrl: widget.partnerAvatarUrl,
          secondaryIcon: partnerLive
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          secondaryColor: partnerLive ? _kMapPinkDeep : _kMapPink,
          onTap: () => _showMapPointDialog(
            title: '${widget.myName} & ${widget.partnerName}',
            subtitle: _myAddressText,
            accent: accent,
            icon: Icons.favorite_rounded,
            coordinateText:
                '${myPoint.lat.toStringAsFixed(5)}, ${myPoint.lng.toStringAsFixed(5)}',
            timestamp: myPoint.ts,
          ),
        ),
      );
    } else {
      if (myPoint != null) {
        final accent = myLive ? _kMapBlue : const Color(0xFF64748B);
        liveMarkerSpecs.add(
          _MapMarkerSpec(
            id: myLive ? 'my_live' : 'my_last_known',
            point: myPoint.latLng,
            icon: myLive
                ? Icons.person_pin_circle_rounded
                : Icons.history_toggle_off_rounded,
            color: accent,
            title: widget.myName,
            subtitle: _myAddressText,
            pulse: myLive,
            avatarUrl: widget.myAvatarUrl,
            onTap: () => _showMapPointDialog(
              title: widget.myName,
              subtitle: _myAddressText,
              accent: accent,
              icon: myLive
                  ? Icons.person_pin_circle_rounded
                  : Icons.history_toggle_off_rounded,
              coordinateText:
                  '${myPoint.lat.toStringAsFixed(5)}, ${myPoint.lng.toStringAsFixed(5)}',
              timestamp: myPoint.ts,
            ),
          ),
        );
      }

      if (partnerPoint != null && partnerLatLng != null) {
        final accent = partnerLive ? _kMapPinkDeep : _kMapPink;
        liveMarkerSpecs.add(
          _MapMarkerSpec(
            id: partnerLive ? 'partner_live' : 'partner_last_known',
            point: partnerLatLng,
            icon: partnerLive
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: accent,
            title: widget.partnerName,
            subtitle: _partnerAddressText,
            pulse: partnerLive,
            avatarUrl: widget.partnerAvatarUrl,
            onTap: () => _showMapPointDialog(
              title: widget.partnerName,
              subtitle: _partnerAddressText,
              accent: accent,
              icon: partnerLive
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              coordinateText:
                  '${partnerPoint.lat.toStringAsFixed(5)}, ${partnerPoint.lng.toStringAsFixed(5)}',
              timestamp: partnerPoint.ts,
            ),
          ),
        );
      }
    }

    if (!_isSingleRelationship &&
        _routeSnapshot != null &&
        _routeSnapshot!.points.length >= 2) {
      livePolylines.add(
        _buildGlowPolyline(
          points: _routeSnapshot!.points,
          color: _kMapRouteGlow,
          strokeWidth: 9.5,
        ),
      );
      livePolylines.add(
        _buildSharpPolyline(
          points: _routeSnapshot!.points,
          color: _kMapPinkDeep,
          gradientColors: const [_kMapPinkSoft, _kMapPinkDeep],
          strokeWidth: 5.8,
          borderStrokeWidth: 2.3,
        ),
      );
    }

    if (!mounted) return;

    final markerSignature = _buildMarkerSignature(liveMarkerSpecs);
    if (markerSignature != _liveMarkerSignature) {
      _liveMarkerSignature = markerSignature;
      _liveMarkersVN.value =
          liveMarkerSpecs.map(_buildOsmMarker).toList(growable: false);
    }

    final polylineSignature = _buildPolylineSignature(livePolylines);
    if (polylineSignature != _livePolylineSignature) {
      _livePolylineSignature = polylineSignature;
      _livePolylinesVN.value = livePolylines;
    }

    if (fitToData && !_didAutoFit && !_isFitting) {
      _fitDebounce?.cancel();
      _fitDebounce = Timer(const Duration(milliseconds: 500), () {
        _focusCameraNearMe();
      });
    }
  }
}
