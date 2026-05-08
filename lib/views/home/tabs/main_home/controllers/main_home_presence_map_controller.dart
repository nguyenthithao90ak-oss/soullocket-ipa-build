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
    if (role == _currentRole) return null;
    final uid = _auth.currentUser?.uid.trim();
    return uid == null || uid.isEmpty ? null : uid;
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
    const ghostThreshold = 12 * 3600 * 1000; // 12 hours

    // Nếu có ít nhất 1 session đang kết nối và chưa quá cũ
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
    // Fallback cho app phiên bản cũ
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
      return 'Đang hoạt động';
    }
    final relMode =
        _houseSettings?['relationshipMode']?.toString().trim() ?? 'single';
    if (relMode != 'single' && role != _currentRole && data == null) {
      if (!_hasLoadedPresenceSnapshot) {
        return 'Đang cập nhật...';
      }
      return 'Chưa từng mở app';
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
    return condition.contains('mưa') ||
        condition.contains('bão') ||
        condition.contains('dông');
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

    final prefs = await SharedPreferences.getInstance();
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
            'Bên bạn đang nóng ghê đó, đi tắm cho mát rồi uống thêm nước nha.',
            'Nhiệt độ bên kia cao quá trời, kiếm chỗ mát ngồi chút đi nè.',
            'Trời này mà không uống nước là mình méc đó, lo hạ nhiệt liền nha.',
            'Má ơi bên bạn nóng muốn chảy pin rồi, nghỉ chút với uống nước đi.',
            'Cảnh báo dễ thương: người yêu của mình đang ở vùng siêu nóng, nhớ làm mát ngay.',
            'Nóng vậy là phải tự thưởng ly nước mát rồi đó, đừng lì nha.',
          ]
        : <String>[
            'Bên bạn đang rất lạnh đó, mặc ấm thêm chút cho mình yên tâm nha.',
            'Trời lạnh ghê rồi, nhớ khoác áo vào kẻo mình lo suốt đó.',
            'Nhiệt độ xuống thấp rồi nè, ôm chăn hoặc ôm áo ấm ngay đi nha.',
            'Bên kia lạnh quá đó, giữ ấm tay chân trước khi thành cục đá nha.',
            'Cảnh báo rét dễ thương: người yêu của mình cần được ủ ấm ngay lập tức.',
            'Lạnh kiểu này nhớ mặc ấm kỹ vào, đừng để mình phải nhắc thêm lần nữa nha.',
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
      if (code >= 61 && code <= 67) return 'Mưa lạnh';
      if (code >= 71 && code <= 77) return 'Tuyết lạnh';
      if (code == 85 || code == 86) return 'Tuyết rơi';
      if (code == 45 || code == 48) return 'Sương lạnh';
      if (code == 3) return 'Mây lạnh';
      if (code == 1 || code == 2) return 'Lạnh có nắng';
      if (code == 0) return 'Nắng lạnh';
    }

    if (code == 0) return 'Nắng';
    if (code == 1) return 'Nắng nhẹ';
    if (code == 2) return 'Nắng mây';
    if (code == 3) return 'Nhiều mây';
    if (code == 45 || code == 48) return 'Sương mù';
    if (code >= 51 && code <= 53) return 'Mưa phùn';
    if (code >= 54 && code <= 55) return 'Mưa phùn nặng';
    if (code >= 56 && code <= 57) return 'Mưa phùn lạnh';
    if (code >= 61 && code <= 63) return 'Mưa vừa';
    if (code >= 64 && code <= 65) return 'Mưa to';
    if (code >= 66 && code <= 67) return 'Mưa rét';
    if (code >= 71 && code <= 73) return 'Tuyết';
    if (code >= 74 && code <= 77) return 'Tuyết dày';
    if (code == 80) return 'Mưa rào nhẹ';
    if (code == 81) return 'Mưa rào';
    if (code == 82) return 'Mưa rào to';
    if (code == 85 || code == 86) return 'Tuyết rơi';
    if (code == 95) return 'Dông';
    if (code == 96 || code == 99) return 'Dông bão';
    return 'Âm u';
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
    if (parts.isEmpty) return 'Vị trí hiện tại';
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
      } catch (_) {
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
        'isRain': cond.contains('Mưa') || cond.contains('Dông'),
        'isCold': temp < 20,
        'isHot': temp > 32,
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
        'locLabel': city,
        'loc': city,
        'city': city,
      };
    } catch (_) {
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
            desiredAccuracy:
                kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
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
      } catch (_) {
        isUsingDefaultHCM = true;
      }

      if (isUsingDefaultHCM) {
        lat = 10.8231;
        lng = 106.6297;
        locLabel = 'TP.HCM';

        try {
          final prefs = await SharedPreferences.getInstance();
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
                content: const Text(
                    'Vị trí đã tắt, nhiệt độ mặc định tại TP.HCM. Bật GPS để cập nhật chính xác nhé!'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Bật ngay',
                  onPressed: _isBootstrappingLocation
                      ? () {}
                      : () => _bootstrapLocationTracking(),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
            await prefs.setString(
                'il_weather_perm_notice_ts', now.toIso8601String());
          }
        } catch (_) {}
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
    } catch (_) {
      // Keep silent; home weather should never block the screen.
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
      context: context,
    );
    if (!started || !mounted) {
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

        var nextDistance = 'Đang định vị...';
        String? nextAlert = isSingle
            ? 'Bật vị trí để bản đồ hiển thị vị trí hiện tại của bạn.'
            : 'Bật vị trí để theo dõi khoảng cách của hai bạn.';

        if (isSingle) {
          if (myPoint != null && myLive) {
            nextDistance = 'Đang chia sẻ';
            nextAlert = 'Bấm để xem vị trí hiện tại của bạn trên bản đồ.';
          } else if (myPoint != null || myHasHistory) {
            nextDistance = 'Vị trí đã lưu';
            nextAlert = 'Bản đồ đang hiển thị vị trí cuối cùng đã lưu của bạn.';
          } else {
            nextDistance = 'Chưa bật vị trí';
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
          nextAlert = 'Bấm để xem bản đồ đầy đủ của hai bạn.';
        } else if (!partnerHasHistory) {
          nextDistance = 'Người ấy chưa bật';
          nextAlert =
              'Người ấy chưa bật vị trí nên bản đồ không hiện vị trí của họ.';
        } else if (!myHasHistory) {
          nextDistance = 'Bạn chưa bật';
          nextAlert =
              'Bạn chưa bật vị trí. Mở bản đồ và bấm "Bật vị trí" để chia sẻ.';
        } else if (!myLive || !partnerLive) {
          nextDistance = 'Vị trí cuối đã lưu';
          nextAlert =
              'Cập nhật vị trí đang tạm dừng ở một người. Bản đồ sẽ hiển thị vị trí cuối cùng đã lưu.';
        }

        if (!mounted) return;
        _updateHomeMapPreview(
          distanceText: nextDistance,
          alertText: nextAlert,
        );
      },
      onError: (_) {
        if (!mounted) return;
        _updateHomeMapPreview(
          distanceText: 'Đang định vị...',
          alertText: 'Không thể tải dữ liệu vị trí lúc này.',
        );
      },
    );
  }

  Future<void> _openMapScreen() async {
    if (!mounted) return;

    final hasPermission = await _locationService.requestPermission(context: context);
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Vui lòng cấp quyền vị trí để xem bản đồ.')),
        );
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
