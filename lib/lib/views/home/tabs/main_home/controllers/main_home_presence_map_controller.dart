// ignore_for_file: unused_element, use_build_context_synchronously

part of '../../main_home_tab.dart';

extension _MainHomePresenceMapController on _MainHomeTabState {
  static const Duration _kWeatherCareCooldown = Duration(hours: 3);

  String _resolvePartnerName() => _resolveNameForRole(_partnerRole);

  String _resolveAvatarForRole(String role) {
    final field = role == 'user1' ? 'avtUser1' : 'avtUser2';
    return _houseSettings?[field]?.toString().trim() ?? '';
  }

  String _resolveRoleBadge(String role) {
    return _resolveNameForRole(role);
  }

  bool _shouldDisplayIncomingAlert(
    _MissYouAlertPayload payload, {
    required String currentUid,
  }) {
    if (payload.fromUid.isNotEmpty && payload.fromUid == currentUid) {
      return false;
    }
    if (payload.fromRole.isNotEmpty && payload.fromRole == _currentRole) {
      return false;
    }
    if (payload.toRole.isNotEmpty && payload.toRole != _currentRole) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final sentAt = payload.sentAtMs;
    if (sentAt > 0 && now - sentAt > const Duration(hours: 24).inMilliseconds) {
      return false;
    }

    final fingerprint =
        '${payload.fromUid}|${payload.fromRole}|${payload.sentAtMs}|${payload.title}|${payload.message}';
    if (_lastMissEventFingerprint == fingerprint &&
        now - _lastMissEventShownAt < 5000) {
      return false;
    }

    _lastMissEventFingerprint = fingerprint;
    _lastMissEventShownAt = now;
    return true;
  }

  Map<String, dynamic>? _presenceForRole(String role) {
    final raw = _presenceData[role];
    if (raw is Map) {
      return _toStringDynamicMap(raw);
    }
    return null;
  }

  String? _ignoredPresenceUidForRole(String role) {
    return null;
  }

  bool _isPresenceDataOnlineForRole(
    String role,
    Map<dynamic, dynamic>? data,
  ) {
    return data != null &&
        PresenceService.isPresenceOnline(
          data,
          ignoreUid: _ignoredPresenceUidForRole(role),
        );
  }

  bool _isRoleOnline(String role) {
    final data = _presenceForRole(role);
    return _isPresenceDataOnlineForRole(role, data);
  }

  bool _isCurrentForegroundRole(String role) {
    return role == _currentRole && _auth.currentUser != null;
  }

  bool _isIgnoredUidOnlyPresence(
    String role,
    Map<dynamic, dynamic>? data,
  ) {
    final ignoredUid = _ignoredPresenceUidForRole(role);
    if (data == null || ignoredUid == null || ignoredUid.isEmpty) {
      return false;
    }

    final sessions = data['sessions'];
    if (sessions is Map && sessions.isNotEmpty) {
      var hasIgnoredUidSession = false;
      for (final value in sessions.values) {
        if (value is! Map) continue;
        final uid = value['uid']?.toString().trim();
        if (uid == null || uid.isEmpty) continue;
        if (uid != ignoredUid) {
          return false;
        }
        hasIgnoredUidSession = true;
      }
      return hasIgnoredUidSession;
    }

    final uid = data['uid']?.toString().trim();
    return uid == ignoredUid;
  }

/*

    final now = DateTime.now().millisecondsSinceEpoch;
    const ghostThreshold = 12 * 3600 * 1000;

    final sessions = data['sessions'];
    if (sessions is Map && sessions.isNotEmpty) {
      for (final value in sessions.values) {
        final ts = _readEpochMs(value);
        if (ts != null && (now - ts) < ghostThreshold) {
          return true;
        }
      }
    }

    final status = data['status']?.toString();
    if (status == 'online') {
      final lastSeen = _readEpochMs(data['lastSeen']) ?? now;
      if ((now - lastSeen) < ghostThreshold) {
        return true;
      }
    }
    return false;
*/
  String _presenceStatusText(String role) {
    if (!_showStatus) return '';
    final data = _presenceForRole(role);
    if (_isCurrentForegroundRole(role)) {
      return context.tr('home_anghotng_cfaecd');
    }
    final relMode =
        _houseSettings?['relationshipMode']?.toString().trim() ?? 'single';
    if (relMode != 'single' && role != _currentRole && data == null) {
      return context.tr('home_chatngmapp_e085d0');
    }
    return PresenceService.formatStatusLabel(
      data,
      ignoreUid: _ignoredPresenceUidForRole(role),
    );
  }

  Color _presenceStatusColor(String role) {
    final data = _presenceForRole(role);
    if (_isCurrentForegroundRole(role)) {
      return const Color(0xFF00C853);
    }
    if (_isIgnoredUidOnlyPresence(role, data)) {
      return const Color(0xFF94A3B8);
    }
    if ((_houseSettings?['relationshipMode']?.toString() ?? 'single') ==
            'single' &&
        role == _currentRole) {
      return const Color(0xFFD81B60);
    }
    if (_isPresenceDataOnlineForRole(role, data)) {
      return const Color(0xFF00C853);
    }
    if (PresenceService.isTemporarilyDisconnected(data)) {
      return const Color(0xFFFF9800);
    }
    return PresenceService.hasEverConnected(data)
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF94A3B8);
  }

  String _weatherTextForRole(String role, {required bool isUser1}) {
    if (!_showWeather) return '';
    final data = _presenceForRole(role);
    final weatherRaw = data?['weather'];
    if (weatherRaw is Map) {
      final weather = _toStringDynamicMap(weatherRaw);
      final temp = _readDouble(weather['temp']);
      final code = (weather['code'] is num)
          ? (weather['code'] as num).toInt()
          : int.tryParse(weather['code']?.toString() ?? '') ?? -1;
      final icon = _weatherVisualIcon(code: code, temp: temp);
      final condition = _weatherLabelFromCode(code, temp: temp);

      if (temp != null) {
        return '$icon ${temp.round()}℃'.trim();
      }

      if (condition.isNotEmpty) {
        return '$icon $condition'.trim();
      }
    }
    return '';
  }

  String _widgetLocationTextForRole(String role) {
    return _weatherTextForRole(role, isUser1: role == 'user1');
  }

  Map<String, dynamic>? _weatherMapForRole(String role) {
    final data = _presenceForRole(role);
    final weatherRaw = data?['weather'];
    if (weatherRaw is! Map) return null;
    final weather = _toStringDynamicMap(weatherRaw);
    return weather.isEmpty ? null : weather;
  }

  int? _weatherLastUpdateMsForRole(String role) {
    final weather = _weatherMapForRole(role);
    if (weather == null) return null;
    return _readEpochMs(weather['lastUpdate']);
  }

  bool _isWeatherFreshForRole(
    String role, {
    required Duration maxAge,
  }) {
    final lastUpdateMs = _weatherLastUpdateMsForRole(role);
    if (lastUpdateMs == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - lastUpdateMs <=
        maxAge.inMilliseconds;
  }

  String _weatherPayloadSignature(Map<String, dynamic>? weather) {
    if (weather == null || weather.isEmpty) {
      return '';
    }
    final temp = _readDouble(weather['temp'])?.round();
    final condition = weather['cond']?.toString().trim() ?? '';
    final city =
        (weather['city'] ?? weather['locLabel'] ?? weather['loc'] ?? '')
            .toString()
            .trim();
    final code = _readEpochMs(weather['code']) ?? -1;
    return '$temp|$condition|$city|$code';
  }

  bool _shouldSkipWeatherPresenceWrite(Map<String, dynamic> nextWeather) {
    final currentWeather = _weatherMapForRole(_currentRole);
    if (currentWeather == null) {
      return false;
    }
    if (_weatherPayloadSignature(currentWeather) !=
        _weatherPayloadSignature(nextWeather)) {
      return false;
    }
    return _isWeatherFreshForRole(
      _currentRole,
      maxAge: _kWeatherDuplicateWriteSkipTtl,
    );
  }

  bool _weatherMatchesRain(Map<String, dynamic>? weather) {
    if (weather == null) return false;
    final rawFlag = weather['isRain'];
    if (rawFlag is bool) return rawFlag;
    final condition = weather['cond']?.toString().toLowerCase() ?? '';
    return condition.contains(context.tr('home_ma_38e202')) ||
        condition.contains(context.tr('home_bo_ca7ab1')) ||
        condition.contains(context.tr('home_dng_c94712'));
  }

  bool _weatherMatchesCold(Map<String, dynamic>? weather) {
    if (weather == null) return false;
    final rawFlag = weather['isCold'];
    if (rawFlag is bool) return rawFlag;
    final temp = _readDouble(weather['temp']);
    return temp != null && temp < 20;
  }

  bool _weatherMatchesHot(Map<String, dynamic>? weather) {
    if (weather == null) return false;
    final rawFlag = weather['isHot'];
    if (rawFlag is bool) return rawFlag;
    final temp = _readDouble(weather['temp']);
    return temp != null && temp > 32;
  }

  Future<void> _maybeSendAutomaticWeatherCare(
    Map<String, dynamic> weather,
  ) async {
    final houseId = _houseId;
    final user = _auth.currentUser;
    if (houseId == null || houseId.isEmpty || user == null) return;
    if (!_isCoupleConnected || _partnerRole.isEmpty) return;

    final type = _weatherMatchesHot(weather)
        ? 'hot'
        : (_weatherMatchesCold(weather) ? 'warmth' : '');
    if (type.isEmpty) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final currentBucket = _weatherCareBucket(weather);
    final bucketKey = 'il_weather_care_bucket_${houseId}_$_currentRole';
    final lastBucket = prefs.getString(bucketKey) ?? '';
    final now = DateTime.now();
    if (lastBucket == currentBucket) {
      final sentAtStr =
          prefs.getString('il_weather_care_sent_at_${houseId}_$_currentRole');
      final sentAt = sentAtStr == null ? null : DateTime.tryParse(sentAtStr);
      if (sentAt != null && now.difference(sentAt) < _kWeatherCareCooldown) {
        return;
      }
    }

    final message = _pickWeatherCareMessage(type, prefs: prefs);
    final title = _pickWeatherCareTitle(type);
    await prefs.setString(bucketKey, currentBucket);
    await prefs.setString(
      'il_weather_care_sent_at_${houseId}_$_currentRole',
      now.toIso8601String(),
    );
    await prefs.setString(
      'il_weather_care_last_msg_${houseId}_${_currentRole}_$type',
      message,
    );

    _sendPartnerInteraction(
      type,
      showSentNotice: false,
      emoji: _pickWeatherCareEmoji(type),
      customTitle: title,
      customMessage: message,
    );
  }

  String _weatherCareBucket(Map<String, dynamic> weather) {
    final temp = _readDouble(weather['temp'])?.round() ?? 0;
    final band = temp ~/ 2;
    final type = _weatherMatchesHot(weather)
        ? 'hot'
        : (_weatherMatchesCold(weather) ? 'warmth' : 'normal');
    return '$type|$band';
  }

  String _pickWeatherCareTitle(String type) {
    final options = type == 'hot'
        ? <String>[
            '${_resolveMyName()} phát hiện bạn đang nóng quá trời',
            '${_resolveMyName()} gửi cảnh báo thời tiết level đổ mồ hôi',
            '${_resolveMyName()} nhắc bạn hạ nhiệt liền nha',
            '${_resolveMyName()} thấy bên bạn nóng quá nên réo ngay',
          ]
        : <String>[
            '${_resolveMyName()} thấy bên bạn lạnh quá rồi',
            '${_resolveMyName()} gửi báo động giữ ấm khẩn cấp',
            '${_resolveMyName()} nhắc bạn mặc ấm ngay nha',
            '${_resolveMyName()} thấy trời bên bạn lạnh nên lo liền',
          ];
    return options[_random.nextInt(options.length)];
  }

  String _pickWeatherCareEmoji(String type) {
    final options = type == 'hot'
        ? const <String>['🔥', '🥵', '☀️', '🌡️', '💦']
        : const <String>['🥶', '🧥', '🧣', '❄️', '☁️'];
    return options[_random.nextInt(options.length)];
  }

  String _pickWeatherCareMessage(
    String type, {
    required SharedPreferences prefs,
  }) {
    final options = type == 'hot'
        ? <String>[
            context.tr('home_bnbnangnng_0bc538'),
            context.tr('home_nhitbnkiac_26ffcf'),
            context.tr('home_trinymkhng_e4a732'),
            context.tr('home_mibnbnnngm_514584'),
            context.tr('home_cnhbodthng_6e0684'),
            context.tr('home_nngvylphit_882dfb'),
          ]
        : <String>[
            context.tr('home_bnbnangrtl_c4a8fc'),
            context.tr('home_trilnhghri_e581f2'),
            context.tr('home_nhitxungth_b9038b'),
            context.tr('home_bnkialnhqu_fed2a5'),
            context.tr('home_cnhbortdth_8cc7b9'),
            context.tr('home_lnhkiunynh_10b3eb'),
          ];
    final lastMessage = prefs.getString(
      'il_weather_care_last_msg_${_houseId ?? ''}_${_currentRole}_$type',
    );
    if (options.length <= 1) return options.first;
    var next = options[_random.nextInt(options.length)];
    var guard = 0;
    while (next == lastMessage && guard < 8) {
      next = options[_random.nextInt(options.length)];
      guard++;
    }
    return next;
  }

  String _centerInteractionType({required bool isSingle}) {
    if (isSingle || !_isCoupleConnected) return 'connect';
    final partnerWeather = _weatherMapForRole(_partnerRole);
    if (_weatherMatchesHot(partnerWeather)) return 'hot';
    if (_weatherMatchesRain(partnerWeather) ||
        _weatherMatchesCold(partnerWeather)) {
      return 'warmth';
    }
    return 'miss';
  }

  String _weatherConditionFromCode(int code) {
    return _weatherLabelFromCode(code);
  }

  String _weatherLabelFromCode(int code, {double? temp}) {
    if (temp != null && temp < 15) {
      if (code >= 61 && code <= 67) return context.tr('home_malnh_ebbbe7');
      if (code >= 71 && code <= 77) return context.tr('home_tuytlnh_cf0a54');
      if (code == 85 || code == 86) return context.tr('home_tuytri_28f697');
      if (code == 45 || code == 48) return context.tr('home_snglnh_9b1852');
      if (code == 3) return context.tr('home_mylnh_0d749e');
      if (code == 1 || code == 2) return context.tr('home_lnhcnng_3b3c3b');
      if (code == 0) return context.tr('home_nnglnh_09b54a');
    }

    if (code == 0) return context.tr('home_nng_e07b37');
    if (code == 1) return context.tr('home_nngnh_c22e13');
    if (code == 2) return context.tr('home_nngmy_a24fd5');
    if (code == 3) return context.tr('home_nhiumy_c6b818');
    if (code == 45 || code == 48) return context.tr('home_sngm_4ee050');
    if (code >= 51 && code <= 53) return context.tr('home_maphn_66d1d7');
    if (code >= 54 && code <= 55) return context.tr('home_maphnnng_056627');
    if (code >= 56 && code <= 57) return context.tr('home_maphnlnh_814e0a');
    if (code >= 61 && code <= 63) return context.tr('home_mava_d90411');
    if (code >= 64 && code <= 65) return context.tr('home_mato_e8af54');
    if (code >= 66 && code <= 67) return context.tr('home_mart_0e4130');
    if (code >= 71 && code <= 73) return context.tr('home_tuyt_dae70c');
    if (code >= 74 && code <= 77) return context.tr('home_tuytdy_371f68');
    if (code == 80) return context.tr('home_maronh_b054a5');
    if (code == 81) return context.tr('home_maro_d5d5c5');
    if (code == 82) return context.tr('home_maroto_15ae5e');
    if (code == 85 || code == 86) return context.tr('home_tuytri_28f697');
    if (code == 95) return context.tr('home_dng_c363ff');
    if (code == 96 || code == 99) return context.tr('home_dngbo_616b69');
    return context.tr('home_mu_8b685f');
  }

  String _weatherVisualIcon({required int code, double? temp}) {
    if (temp != null && temp < 15) {
      if (code == 45 || code == 48) return '🌫️';
      if (code >= 71 && code <= 77) return '🌨️';
      if (code == 85 || code == 86) return '❄️';
      if (code >= 61 && code <= 67) return '🌧️';
      if (code == 3) return '☁️';
      return '🥶';
    }

    if (code == 0) return '☀️';
    if (code == 1) return '🌤️';
    if (code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 57) return '🌦️';
    if (code >= 61 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '🌨️';
    if (code >= 80 && code <= 82) return '🌦️';
    if (code == 85 || code == 86) return '❄️';
    if (code == 95) return '⛈️';
    if (code == 96 || code == 99) return '🌩️';
    return '🌥️';
  }

  String _compactLocationLabel(String raw) {
    final parts = raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return context.tr('home_vtrhinti_f5956d');
    if (parts.length == 1) return parts.first;
    return '${parts.first}, ${parts[1]}';
  }

  Future<String?> _reverseGeocodeForWeather(double lat, double lng) async {
    final cacheKey = _buildWeatherReverseGeocodeCacheKey(lat, lng);
    if (_isWeatherReverseGeocodeCacheFresh(cacheKey)) {
      return _weatherReverseGeocodeCache[cacheKey];
    }

    final pending = _weatherReverseGeocodeInFlight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = () async {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2&lat=$lat&lon=$lng&accept-language=vi',
        );
        final response = await http.get(
          uri,
          headers: const {'User-Agent': 'SoulLocket-App'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return null;
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = map['display_name']?.toString().trim();
        if (displayName == null || displayName.isEmpty) return null;
        return _compactLocationLabel(displayName);
      } catch (e) {
        debugPrint('[PresenceMap] reverseGeocode error: $e');
        return null;
      }
    }();

    _weatherReverseGeocodeInFlight[cacheKey] = future;
    final result = await future;
    _weatherReverseGeocodeInFlight.remove(cacheKey);
    _weatherReverseGeocodeCache[cacheKey] = result;
    _weatherReverseGeocodeCacheTs[cacheKey] =
        DateTime.now().millisecondsSinceEpoch;
    _trimWeatherReverseGeocodeCache();
    return result;
  }

  String _buildWeatherReverseGeocodeCacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  bool _isWeatherReverseGeocodeCacheFresh(String key) {
    final cachedAt = _weatherReverseGeocodeCacheTs[key];
    if (cachedAt == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - cachedAt <=
        _kWeatherReverseGeocodeCacheTtl.inMilliseconds;
  }

  void _trimWeatherReverseGeocodeCache() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredKeys = <String>[
      for (final entry in _weatherReverseGeocodeCacheTs.entries)
        if (now - entry.value > _kWeatherReverseGeocodeCacheTtl.inMilliseconds)
          entry.key,
    ];
    for (final key in expiredKeys) {
      _weatherReverseGeocodeCacheTs.remove(key);
      _weatherReverseGeocodeCache.remove(key);
    }

    if (_weatherReverseGeocodeCacheTs.length <=
        _kWeatherReverseGeocodeCacheMaxEntries) {
      return;
    }

    final sortedEntries = _weatherReverseGeocodeCacheTs.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final overflowCount = _weatherReverseGeocodeCacheTs.length -
        _kWeatherReverseGeocodeCacheMaxEntries;
    for (final entry in sortedEntries.take(overflowCount)) {
      _weatherReverseGeocodeCacheTs.remove(entry.key);
      _weatherReverseGeocodeCache.remove(entry.key);
    }
  }

  Future<Map<String, dynamic>?> _fetchCurrentWeatherSnapshot({
    required double lat,
    required double lng,
    required String locLabel,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,weather_code'
        '&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final current = body['current'];
      if (current is! Map<String, dynamic>) return null;
      final temp = _readDouble(current['temperature_2m']) ?? 30;
      final weatherCode = (current['weather_code'] is num)
          ? (current['weather_code'] as num).toInt()
          : int.tryParse(current['weather_code']?.toString() ?? '') ?? 0;
      final cond = _weatherConditionFromCode(weatherCode);
      final city = _compactLocationLabel(locLabel);
      return {
        'temp': temp,
        'cond': cond,
        'code': weatherCode,
        'isRain': cond.contains(context.tr('home_ma_a464da')) ||
            cond.contains(context.tr('home_dng_c363ff')),
        'isCold': temp < 20,
        'isHot': temp > 32,
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
        'locLabel': city,
        'loc': city,
        'city': city,
      };
    } catch (e) {
      debugPrint('[PresenceMap] geocode fetch error: $e');
      return null;
    }
  }

  void _startWeatherRefreshLoop(String houseId) {
    if (!_isTabActive || !_showWeather) {
      _weatherRefreshTimer?.cancel();
      _weatherRefreshTimer = null;
      return;
    }
    _weatherRefreshTimer?.cancel();
    _refreshCurrentRoleWeather();
    _weatherRefreshTimer = Timer.periodic(
        const Duration(minutes: 15), (_) => _refreshCurrentRoleWeather());
  }

  Future<void> _refreshCurrentRoleWeather() async {
    if (_houseId == null ||
        _weatherSyncInFlight ||
        !_isTabActive ||
        !_showWeather) {
      return;
    }
    _weatherSyncInFlight = true;

    try {
      if (_isWeatherFreshForRole(
        _currentRole,
        maxAge: _kWeatherRefreshSkipTtl,
      )) {
        return;
      }

      double lat = 10.8231;
      double lng = 106.6297;
      String locLabel = 'TP.HCM';
      bool isUsingDefaultHCM = false;

      try {
        final hasLocationPermission =
            await _locationService.requestPermission(context: context);
        final isLocationServiceEnabled =
            await Geolocator.isLocationServiceEnabled();

        if (hasLocationPermission && isLocationServiceEnabled) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy:
                  kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
            ),
          );
          lat = position.latitude;
          lng = position.longitude;
          final resolved = await _reverseGeocodeForWeather(lat, lng);
          if (resolved != null && resolved.trim().isNotEmpty) {
            locLabel = resolved.trim();
          }
        } else {
          isUsingDefaultHCM = true;
        }
      } catch (e) {
        debugPrint('[PresenceMap] default HCM fallback error: $e');
        isUsingDefaultHCM = true;
      }

      if (isUsingDefaultHCM) {
        lat = 10.8231;
        lng = 106.6297;
        locLabel = 'TP.HCM';

        try {
          final prefs = OfflineCacheService.getPrefsSync() ??
              await SharedPreferences.getInstance();
          final lastShownStr = prefs.getString('il_weather_perm_notice_ts');
          final now = DateTime.now();
          bool shouldShow = true;
          if (lastShownStr != null) {
            final lastShown = DateTime.tryParse(lastShownStr);
            if (lastShown != null && now.difference(lastShown).inDays < 3) {
              shouldShow = false;
            }
          }
          if (shouldShow && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('home_vtrttnhitm_906e2c')),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: context.tr('home_btngay_5ebb69'),
                  onPressed: () async {
                    final granted = await _locationService.requestPermission(
                      context: context,
                    );
                    if (!granted || !mounted) return;
                    await _refreshCurrentRoleWeather();
                  },
                ),
                duration: const Duration(seconds: 4),
              ),
            );
            await prefs.setString(
                'il_weather_perm_notice_ts', now.toIso8601String());
          }
        } catch (e) {
          debugPrint('[PresenceMap] weather permission notice error: $e');
        }
      }

      final weather = await _fetchCurrentWeatherSnapshot(
        lat: lat,
        lng: lng,
        locLabel: locLabel,
      );
      if (weather == null || _houseId == null || !_isTabActive) return;
      if (_shouldSkipWeatherPresenceWrite(weather)) {
        return;
      }

      await _dbRef.child('houses/${_houseId!}/presence/$_currentRole').update({
        'weather': weather,
        'city': weather['city'],
      });
    } catch (e) {
      debugPrint('[PresenceMap] weather presence write error: $e');
    } finally {
      _weatherSyncInFlight = false;
    }
  }

  String _formatDistanceMeters(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    if (distanceMeters < 100000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${(distanceMeters / 1000).round()} km';
  }

  String get _relationshipMode =>
      _houseSettings?['relationshipMode']?.toString().trim().toLowerCase() ??
      'single';

  bool get _isSingleRelationship => _relationshipMode == 'single';

  bool _isFreshGpsTs(int? ts) {
    if (ts == null) return false;
    final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    return ageMs >= 0 && ageMs <= 3 * 60 * 1000;
  }

  Map<String, dynamic>? _gpsPreviewStateForRole(
      Map<String, dynamic> gpsData, String role) {
    final raw = gpsData[role];
    if (raw is! Map) return null;
    final node = _toStringDynamicMap(raw);
    final currentLat = _readDouble(node['lt']) ?? _readDouble(node['lat']);
    final currentLng = _readDouble(node['lg']) ?? _readDouble(node['lng']);
    final currentTs = _readEpochMs(node['ts']);
    final lastKnown = _toStringDynamicMap(node['lastKnown']);
    final lastLat =
        _readDouble(lastKnown['lt']) ?? _readDouble(lastKnown['lat']);
    final lastLng =
        _readDouble(lastKnown['lg']) ?? _readDouble(lastKnown['lng']);
    final isLive = (node['isLive'] == true || node['sharingEnabled'] == true) &&
        currentLat != null &&
        currentLng != null &&
        _isFreshGpsTs(currentTs);
    final hasHistory = node['everShared'] == true ||
        node['sharingEnabled'] == true ||
        node['isLive'] == true ||
        (lastLat != null && lastLng != null);
    final effectiveLat =
        isLive ? currentLat : (lastLat ?? (hasHistory ? currentLat : null));
    final effectiveLng =
        isLive ? currentLng : (lastLng ?? (hasHistory ? currentLng : null));
    if (!hasHistory || effectiveLat == null || effectiveLng == null) {
      return null;
    }
    return {
      'lt': effectiveLat,
      'lg': effectiveLng,
      'isLive': isLive,
      'hasHistory': hasHistory,
    };
  }

  Future<void> _ensureAppWideLocationTracking(String houseId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = _currentRole.trim();
    if (!_isTabActive ||
        normalizedHouseId.isEmpty ||
        normalizedRole.isEmpty ||
        !mounted) {
      return;
    }

    final started = await _locationService.startTracking(
      normalizedHouseId,
      normalizedRole,
      context: null,
    );
    if (!started) {
      if (mounted) {
        final status = await Geolocator.checkPermission();
        if (status == LocationPermission.denied ||
            status == LocationPermission.deniedForever) {
          _updateHomeMapPreview(
            distanceText: 'Chưa cấp quyền vị trí',
            alertText: 'Vui lòng cấp quyền vị trí để xem bản đồ.',
          );
        }
      }
      return;
    }

    // Do not auto-open background permission settings during startup.
    // Keep this for explicit user-triggered actions only.
  }

  void _bindHomeMapPreview(String houseId) {
    _gpsSubscription?.cancel();
    _gpsSubscription = _dbRef.child('gps/$houseId').onValue.listen(
      (event) {
        final isSingle = _isSingleRelationship;
        final gpsData = _toStringDynamicMap(event.snapshot.value);
        final myPoint = _gpsPreviewStateForRole(gpsData, _currentRole);
        final partnerPoint = _gpsPreviewStateForRole(gpsData, _partnerRole);
        final myLive = myPoint?['isLive'] == true;
        final partnerLive = partnerPoint?['isLive'] == true;
        final myHasHistory = myPoint?['hasHistory'] == true;
        final partnerHasHistory = partnerPoint?['hasHistory'] == true;

        final partnerNode = gpsData[_partnerRole];
        if (partnerNode is Map) {
          final partnerNodeMap = _toStringDynamicMap(partnerNode);
          final battery = partnerNodeMap['battery'] ?? partnerNodeMap['batteryPct'];
          final isCharging = partnerNodeMap['isCharging'] == true;
          if (battery is num) {
            _homePartnerBatteryNotifier.value = {
              'level': battery.toInt(),
              'isCharging': isCharging,
            };
          } else {
            final lastKnown = partnerNodeMap['lastKnown'];
            if (lastKnown is Map) {
              final lastKnownMap = _toStringDynamicMap(lastKnown);
              final lkBattery = lastKnownMap['battery'] ?? lastKnownMap['batteryPct'];
              final lkIsCharging = lastKnownMap['isCharging'] == true;
              if (lkBattery is num) {
                _homePartnerBatteryNotifier.value = {
                  'level': lkBattery.toInt(),
                  'isCharging': lkIsCharging,
                };
              } else {
                _homePartnerBatteryNotifier.value = null;
              }
            } else {
              _homePartnerBatteryNotifier.value = null;
            }
          }
        } else {
          _homePartnerBatteryNotifier.value = null;
        }

        var nextDistance = context.tr('home_angnhv_ea3669');
        String? nextAlert = isSingle
            ? context.tr('home_btvtrbnhin_5f5891')
            : context.tr('home_btvtrtheod_b09bba');

        if (isSingle) {
          if (myPoint != null && myLive) {
            nextDistance = context.tr('home_angchias_51b41c');
            nextAlert = context.tr('home_bmxemvtrhi_e4d474');
          } else if (myPoint != null || myHasHistory) {
            nextDistance = context.tr('home_vtrlu_7f955b');
            nextAlert = context.tr('home_bnanghinth_652b9f');
          } else {
            nextDistance = context.tr('home_chabtvtr_5f7a9a');
          }
        } else if (myLive &&
            partnerLive &&
            myPoint != null &&
            partnerPoint != null) {
          final meters = const ll.Distance().as(
            ll.LengthUnit.Meter,
            ll.LatLng(myPoint['lt']!, myPoint['lg']!),
            ll.LatLng(partnerPoint['lt']!, partnerPoint['lg']!),
          );
          nextDistance = _formatDistanceMeters(meters);
          nextAlert = context.tr('home_bmxembnyca_b88207');
        } else if (!partnerHasHistory) {
          nextDistance = context.tr('home_ngiychabt_4fbd8d');
          nextAlert = context.tr('home_ngiychabtv_a26a9a');
        } else if (!myHasHistory) {
          nextDistance = context.tr('home_bnchabt_4d6ead');
          nextAlert =
              L10nService().format('home_location_not_enabled_action', {'button': context.tr('home_btvtr_4d948b')});
        } else if (!myLive || !partnerLive) {
          nextDistance = context.tr('home_vtrcuilu_b4c8ee');
          nextAlert = context.tr('home_cpnhtvtran_6aea3c');
        }

        if (!mounted) return;
        _updateHomeMapPreview(
          distanceText: nextDistance,
          alertText: nextAlert,
        );
      },
      onError: (Object error) {
        debugPrint(
          'Home GPS preview listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: context.tr('home_khngthtidl_d524ab'),
          ).message}',
        );
        if (!mounted) return;
        _updateHomeMapPreview(
          distanceText: context.tr('home_angnhv_ea3669'),
          alertText: context.tr('home_khngthtidl_d524ab'),
        );
      },
    );
  }

  Future<void> _openMapScreen() async {
    if (!mounted) return;

    final hasPermission =
        await _locationService.requestPermission(context: context);
    if (!hasPermission) {
      if (mounted) {
        final status = await Geolocator.checkPermission();
        if (status == LocationPermission.deniedForever) {
          showDialog(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Quyền vị trí',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                content: Text(
                  'Ứng dụng cần quyền vị trí để định vị và chia sẻ bản đồ. Bạn đã từ chối quyền này vĩnh viễn, vui lòng mở Cài đặt để bật lại.',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Hủy',
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SLColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await Geolocator.openAppSettings();
                    },
                    child: Text(
                      'Mở Cài đặt',
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      }
      return;
    }

    final navigator = Navigator.of(context);
    final houseId = _houseId ?? await _houseService.getCurrentHouseId();
    if (!mounted || houseId == null) return;
    navigator.push(MaterialPageRoute(
      builder: (_) => MapScreen(
        houseId: houseId,
        relationshipMode: _relationshipMode,
        myRole: _currentRole,
        partnerRole: _partnerRole,
        myName: _resolveMyName(),
        partnerName: _resolvePartnerName(),
        myAvatarUrl: _resolveAvatarForRole(_currentRole),
        partnerAvatarUrl: _resolveAvatarForRole(_partnerRole),
      ),
    ));
  }
}
