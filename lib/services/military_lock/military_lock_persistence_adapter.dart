part of '../military_lock_service.dart';

extension _MilitaryLockPersistenceAdapter on MilitaryLockService {
  Future<String?> _resolveHouseId({String? houseId}) async {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      _rememberResolvedHouseId(trimmed, uid: _auth.currentUser?.uid);
      return trimmed;
    }

    final currentUid = _auth.currentUser?.uid.trim() ?? '';
    final memoryHouseId = _cachedResolvedHouseId?.trim() ?? '';
    if (memoryHouseId.isNotEmpty &&
        currentUid.isNotEmpty &&
        _cachedResolvedHouseAuthUid == currentUid &&
        _isCacheFresh(
          _cachedResolvedHouseIdAtMs,
          MilitaryLockService._resolvedHouseIdCacheTtl,
        )) {
      return memoryHouseId;
    }

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final cachedHouseId =
        prefs.getString(MilitaryLockService._prefHouseId)?.trim() ?? '';
    final cachedAuthUid =
        prefs.getString(MilitaryLockService._prefAuthUid)?.trim() ?? '';
    if (cachedHouseId.isNotEmpty) {
      if (currentUid.isNotEmpty && cachedAuthUid == currentUid) {
        _rememberResolvedHouseId(cachedHouseId, uid: currentUid);
        return cachedHouseId;
      }
      await prefs.remove(MilitaryLockService._prefHouseId);
      await prefs.remove(MilitaryLockService._prefAuthUid);
      await prefs.remove('il_role');
    }

    final user = _auth.currentUser;
    if (user == null) return null;

    final pendingFuture = _resolveHouseIdFuture;
    if (pendingFuture != null) {
      return pendingFuture;
    }

    final future = _resolveHouseIdFromRemote(user.uid, prefs);
    _resolveHouseIdFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_resolveHouseIdFuture, future)) {
        _resolveHouseIdFuture = null;
      }
    }
  }

  Future<EffectiveLockSettings> _getEffectiveLockSettings({
    String? houseId,
  }) async {
    final cacheKey = _effectiveLockSettingsCacheKey(houseId);
    final cachedEntry = _effectiveLockSettingsCache[cacheKey];
    if (cachedEntry != null &&
        _isCacheFresh(
          cachedEntry.fetchedAtMs,
          MilitaryLockService._effectiveLockSettingsCacheTtl,
        )) {
      return cachedEntry.settings;
    }

    final inFlight = _effectiveLockSettingsInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadEffectiveLockSettings(
      cacheKey: cacheKey,
      houseId: houseId,
    );
    _effectiveLockSettingsInFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_effectiveLockSettingsInFlight[cacheKey], future)) {
        _effectiveLockSettingsInFlight.remove(cacheKey);
      }
    }
  }

  Future<EffectiveLockSettings> _loadEffectiveLockSettings({
    required String cacheKey,
    String? houseId,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final localSecret = _buildLockSecretRecord(
      prefs.getString(MilitaryLockService._prefCustomLock),
      rawSalt: prefs.getString(MilitaryLockService._prefCustomLockSalt),
      rawPinLength: prefs.getInt(MilitaryLockService._prefCustomLockLength),
      rawConfiguredAt: prefs.getInt(
        MilitaryLockService._prefCustomLockConfiguredAt,
      ),
    );
    final localEnabled =
        (prefs.getBool(MilitaryLockService._prefAppLockEnabled) ?? false) &&
            localSecret != null &&
            localSecret.secret.trim().isNotEmpty;
    final localScopes = MilitaryLockService.normalizeScopeStorageConfig(
      {
        'app': prefs.getBool(_scopePrefKey(LockScope.app)) ??
            _defaultScopeValue(LockScope.app),
        'security': prefs.getBool(_scopePrefKey(LockScope.security)) ??
            _defaultScopeValue(LockScope.security),
        'diary': prefs.getBool(_scopePrefKey(LockScope.diary)) ??
            _defaultScopeValue(LockScope.diary),
        'chat': prefs.getBool(_scopePrefKey(LockScope.chat)) ??
            _defaultScopeValue(LockScope.chat),
        'private': prefs.getBool(_scopePrefKey(LockScope.privateArea)) ??
            _defaultScopeValue(LockScope.privateArea),
      },
      enabled: localEnabled,
    );
    final localSettings = EffectiveLockSettings(
      enabled: localEnabled,
      useBiometrics: localEnabled &&
          (prefs.getBool(MilitaryLockService._prefUseBiometrics) ?? false),
      timeoutMinutes: prefs.getInt(MilitaryLockService._prefLockTimeout) ?? 0,
      militaryMode: localEnabled &&
          (prefs.getBool(MilitaryLockService._prefMilitaryMode) ?? false),
      scopes: localScopes,
      secretRecord: localSecret,
    );

    _rememberEffectiveLockSettings(cacheKey, localSettings);

    final resolvedHouseId =
        houseId?.trim().isNotEmpty == true ? houseId!.trim() : '';
    if (resolvedHouseId.isNotEmpty) {
      _rememberEffectiveLockSettings(
        _effectiveLockSettingsCacheKey(resolvedHouseId),
        localSettings,
      );
      return localSettings;
    }

    final cachedHouseId =
        prefs.getString(MilitaryLockService._prefHouseId)?.trim() ?? '';
    final cachedAuthUid =
        prefs.getString(MilitaryLockService._prefAuthUid)?.trim() ?? '';
    final currentUid = _auth.currentUser?.uid.trim() ?? '';
    if (cachedHouseId.isNotEmpty &&
        currentUid.isNotEmpty &&
        cachedAuthUid == currentUid) {
      _rememberResolvedHouseId(cachedHouseId, uid: currentUid);
      _rememberEffectiveLockSettings(
        _effectiveLockSettingsCacheKey(cachedHouseId),
        localSettings,
      );
    }
    return localSettings;
  }

  Future<LockSecretRecord?> _getEffectiveLockSecretData({
    String? houseId,
  }) async {
    final settings = await _getEffectiveLockSettings(houseId: houseId);
    return settings.secretRecord;
  }

  LockSecretRecord _createStoredLockSecret(String customLock) {
    final trimmedLock = customLock.trim();
    if (trimmedLock.isEmpty) {
      return const LockSecretRecord(secret: '');
    }

    return LockSecretRecord(
      secret: _hashSecretV2(trimmedLock),
      salt: null,
      pinLength: trimmedLock.length,
    );
  }

  bool _canRevealPlaintextLock({
    required String secret,
    String? salt,
  }) {
    final trimmedSecret = secret.trim();
    final trimmedSalt = salt?.trim() ?? '';
    if (trimmedSecret.isEmpty) {
      return false;
    }
    if (trimmedSalt.isNotEmpty) {
      return false;
    }
    return !_isStoredSha256(trimmedSecret);
  }

  Future<void> _saveLocalLockSettings({
    required bool enabled,
    required bool useBiometrics,
    required int timeoutMinutes,
    required bool militaryMode,
    required String customLock,
    String? customLockSalt,
    int? customLockLength,
    int? configuredAtEpochMs,
    required Map<String, bool> scopeMap,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final trimmedLock = customLock.trim();
    final trimmedSalt = customLockSalt?.trim() ?? '';
    final normalizedPinLength =
        _normalizeLockSecretLength(customLockLength, secret: trimmedLock);
    final normalizedEnabled = enabled && _hasConfiguredSecret(trimmedLock);
    final existingConfiguredAt = prefs.getInt(
      MilitaryLockService._prefCustomLockConfiguredAt,
    );
    final normalizedConfiguredAt = normalizedEnabled
        ? (configuredAtEpochMs ?? existingConfiguredAt)
        : null;
    final normalizedScopes = MilitaryLockService.normalizeScopeStorageConfig(
      scopeMap,
      enabled: normalizedEnabled,
    );
    final normalizedSettings = EffectiveLockSettings(
      enabled: normalizedEnabled,
      useBiometrics: normalizedEnabled && useBiometrics,
      timeoutMinutes: timeoutMinutes,
      militaryMode: normalizedEnabled && militaryMode,
      scopes: normalizedScopes,
      secretRecord: _buildLockSecretRecord(
        normalizedEnabled ? trimmedLock : '',
        rawSalt: normalizedEnabled ? trimmedSalt : null,
        rawPinLength: normalizedPinLength,
        rawConfiguredAt: normalizedConfiguredAt,
      ),
    );

    await prefs.setBool(
      MilitaryLockService._prefAppLockEnabled,
      normalizedEnabled,
    );
    await prefs.setBool(
      MilitaryLockService._prefUseBiometrics,
      normalizedEnabled && useBiometrics,
    );
    await prefs.setInt(
      MilitaryLockService._prefLockTimeout,
      timeoutMinutes,
    );
    await prefs.setBool(
      MilitaryLockService._prefMilitaryMode,
      normalizedEnabled && militaryMode,
    );
    await prefs.setString(
      MilitaryLockService._prefCustomLock,
      normalizedEnabled ? trimmedLock : '',
    );
    if (normalizedEnabled && trimmedSalt.isNotEmpty) {
      await prefs.setString(
        MilitaryLockService._prefCustomLockSalt,
        trimmedSalt,
      );
    } else {
      await prefs.remove(MilitaryLockService._prefCustomLockSalt);
    }
    if (normalizedEnabled && normalizedPinLength != null) {
      await prefs.setInt(
        MilitaryLockService._prefCustomLockLength,
        normalizedPinLength,
      );
    } else {
      await prefs.remove(MilitaryLockService._prefCustomLockLength);
    }
    if (normalizedConfiguredAt != null && normalizedConfiguredAt > 0) {
      await prefs.setInt(
        MilitaryLockService._prefCustomLockConfiguredAt,
        normalizedConfiguredAt,
      );
    } else {
      await prefs.remove(MilitaryLockService._prefCustomLockConfiguredAt);
    }
    await prefs.setBool(
      _scopePrefKey(LockScope.app),
      normalizedScopes['app'] ?? _defaultScopeValue(LockScope.app),
    );
    await prefs.setBool(
      _scopePrefKey(LockScope.security),
      normalizedScopes['security'] ?? _defaultScopeValue(LockScope.security),
    );
    await prefs.setBool(
      _scopePrefKey(LockScope.diary),
      normalizedScopes['diary'] ?? _defaultScopeValue(LockScope.diary),
    );
    await prefs.setBool(
      _scopePrefKey(LockScope.chat),
      normalizedScopes['chat'] ?? _defaultScopeValue(LockScope.chat),
    );
    await prefs.setBool(
      _scopePrefKey(LockScope.privateArea),
      normalizedScopes['private'] ?? _defaultScopeValue(LockScope.privateArea),
    );
    _rememberEffectiveLockSettings(
      _effectiveLockSettingsCacheKey(null),
      normalizedSettings,
    );
    final cachedHouseId =
        prefs.getString(MilitaryLockService._prefHouseId)?.trim() ?? '';
    final cachedAuthUid =
        prefs.getString(MilitaryLockService._prefAuthUid)?.trim() ?? '';
    final currentUid = _auth.currentUser?.uid.trim() ?? '';
    if (cachedHouseId.isNotEmpty &&
        currentUid.isNotEmpty &&
        cachedAuthUid == currentUid) {
      _rememberResolvedHouseId(cachedHouseId, uid: currentUid);
      _rememberEffectiveLockSettings(
        _effectiveLockSettingsCacheKey(cachedHouseId),
        normalizedSettings,
      );
    }
    await _clearUnlockGuard();

    try {
      await SettingsSyncService().backupSettingsToCloud();
    } catch (_) {}
  }

  Future<void> _resetLocalLockSettings({int timeoutMinutes = 0}) async {
    await _saveLocalLockSettings(
      enabled: false,
      useBiometrics: false,
      timeoutMinutes: timeoutMinutes,
      militaryMode: false,
      customLock: '',
      customLockSalt: null,
      customLockLength: null,
      scopeMap: MilitaryLockService.defaultScopeStorageConfig,
    );
  }

  Future<void> _clearRemoteLockSyncArtifacts(String houseId) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      return;
    }

    await _db.update({
      'houses/$resolvedHouseId/security/lock': null,
      'houses/$resolvedHouseId/settings/appLocked': null,
      'houses/$resolvedHouseId/settings/customLock': null,
      'houses/$resolvedHouseId/settings/customLockSalt': null,
      'houses/$resolvedHouseId/settings/customLockLength': null,
      'houses/$resolvedHouseId/settings/appLockConfiguredAt': null,
      'houses/$resolvedHouseId/settings/appLockFaceId': null,
      'houses/$resolvedHouseId/settings/appLockScopes': null,
    });
  }

  Future<PinRecoveryOptions> _getPinRecoveryOptions({
    String? houseId,
  }) async {
    final resolvedHouseId = await _resolveHouseId(houseId: houseId);
    final security = resolvedHouseId == null || resolvedHouseId.isEmpty
        ? null
        : await _authService.getHouseSecurityData(resolvedHouseId);
    final question = (security?['question'] ?? '').toString().trim();
    final answerHash = (security?['answerHash'] ?? security?['answer'] ?? '')
        .toString()
        .trim();
    final canQuickDelete =
        await _canChangePinWithoutCurrentAuth(houseId: houseId);
    final emails = <PinRecoveryEmailRecord>[];
    final seen = <String>{};

    void addEmail(String label, String rawEmail) {
      final normalized = rawEmail.trim().toLowerCase();
      if (!normalized.contains('@') || !seen.add(normalized)) {
        return;
      }
      emails.add(
        PinRecoveryEmailRecord(
          label: label,
          email: normalized,
          maskedEmail: _authService.maskEmail(normalized),
        ),
      );
    }

    addEmail(
      'Email phụ',
      (security?['backupEmail'] ?? security?['secondaryEmail'] ?? '')
          .toString(),
    );
    addEmail(
      'Email chính',
      (security?['email'] ?? _auth.currentUser?.email ?? '').toString(),
    );

    return PinRecoveryOptions(
      securityQuestion:
          question.isNotEmpty && answerHash.isNotEmpty ? question : null,
      emails: emails,
      canQuickDelete: canQuickDelete,
    );
  }

  Future<int?> _getPinConfiguredAtEpochMs({String? houseId}) async {
    final settings = await _getEffectiveLockSettings(houseId: houseId);
    return settings.secretRecord?.configuredAtEpochMs;
  }

  Future<bool> _canChangePinWithoutCurrentAuth({String? houseId}) async {
    final configuredAt = await _getPinConfiguredAtEpochMs(houseId: houseId);
    if (configuredAt == null || configuredAt <= 0) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - configuredAt) <
        MilitaryLockService.pinFlexibleChangeWindow.inMilliseconds;
  }

  Future<void> _disableLockPin({String? houseId}) async {
    final effective = await _getEffectiveLockSettings(houseId: houseId);
    final resolvedHouseId = await _resolveHouseId(houseId: houseId);

    await _saveLocalLockSettings(
      enabled: false,
      useBiometrics: false,
      timeoutMinutes: effective.timeoutMinutes,
      militaryMode: false,
      customLock: '',
      customLockSalt: null,
      customLockLength: null,
      configuredAtEpochMs: null,
      scopeMap: MilitaryLockService.defaultScopeStorageConfig,
    );

    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      await _clearRemoteLockSyncArtifacts(resolvedHouseId);
    }

    lockAllScopes();
    await _clearUnlockGuard(houseId: houseId);
  }

  Future<void> _updateLockPin({
    required String newPin,
    String? houseId,
  }) async {
    final validationError = validateCustomLock(newPin);
    if (validationError != null) {
      throw validationError;
    }

    final effective = await _getEffectiveLockSettings(houseId: houseId);
    final resolvedHouseId = await _resolveHouseId(houseId: houseId);
    final secretRecord = _createStoredLockSecret(newPin);
    final configuredAt = DateTime.now().millisecondsSinceEpoch;
    final normalizedScopes = MilitaryLockService.normalizeScopeStorageConfig(
      effective.scopes,
      enabled: true,
    );

    await _saveLocalLockSettings(
      enabled: true,
      useBiometrics: effective.useBiometrics,
      timeoutMinutes: effective.timeoutMinutes,
      militaryMode: effective.militaryMode,
      customLock: secretRecord.secret,
      customLockSalt: secretRecord.salt,
      customLockLength: secretRecord.pinLength,
      configuredAtEpochMs: configuredAt,
      scopeMap: normalizedScopes,
    );

    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      await _clearRemoteLockSyncArtifacts(resolvedHouseId);
    }

    lockAllScopes();
    await _clearUnlockGuard(houseId: houseId);
  }

  Future<String?> _resolveHouseIdFromRemote(
    String uid,
    SharedPreferences prefs,
  ) async {
    try {
      final primarySnap = await _db
          .child('users/$uid/houseId')
          .get()
          .timeout(const Duration(seconds: 3));
      final primaryValue = primarySnap.value?.toString().trim() ?? '';
      if (primaryValue.isNotEmpty) {
        _rememberResolvedHouseId(primaryValue, uid: uid);
        await prefs.setString(MilitaryLockService._prefHouseId, primaryValue);
        await prefs.setString(MilitaryLockService._prefAuthUid, uid);
        return primaryValue;
      }

      final legacySnap = await _db
          .child('users/$uid/house_id')
          .get()
          .timeout(const Duration(seconds: 2));
      final legacyValue = legacySnap.value?.toString().trim() ?? '';
      if (legacyValue.isNotEmpty) {
        _rememberResolvedHouseId(legacyValue, uid: uid);
        await prefs.setString(MilitaryLockService._prefHouseId, legacyValue);
        await prefs.setString(MilitaryLockService._prefAuthUid, uid);
        try {
          await _db.child('users/$uid').update({'houseId': legacyValue});
        } catch (_) {}
        return legacyValue;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _effectiveLockSettingsCacheKey(String? houseId) {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'current';
    }
    return 'house:$trimmed';
  }

  void _rememberResolvedHouseId(String? houseId, {String? uid}) {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isEmpty) {
      _cachedResolvedHouseId = null;
      _cachedResolvedHouseAuthUid = null;
      _cachedResolvedHouseIdAtMs = 0;
      return;
    }

    _cachedResolvedHouseId = trimmed;
    final trimmedUid = uid?.trim() ?? _auth.currentUser?.uid.trim() ?? '';
    _cachedResolvedHouseAuthUid = trimmedUid.isEmpty ? null : trimmedUid;
    _cachedResolvedHouseIdAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _rememberEffectiveLockSettings(
    String cacheKey,
    EffectiveLockSettings settings,
  ) {
    _effectiveLockSettingsCache[cacheKey] = _EffectiveLockSettingsCacheEntry(
      settings: settings,
      fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isCacheFresh(int fetchedAtMs, Duration ttl) {
    if (fetchedAtMs <= 0) {
      return false;
    }

    final age = DateTime.now().millisecondsSinceEpoch - fetchedAtMs;
    return age <= ttl.inMilliseconds;
  }

  bool _isStoredSha256(String value) {
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim());
  }

  bool _isStoredKdfV2(String value) {
    return value.trim().startsWith('v2\$pbkdf2_sha256\$');
  }

  bool _shouldUpgradeStoredSecret(LockSecretRecord secretRecord) {
    return !_isStoredKdfV2(secretRecord.secret);
  }

  Future<void> _upgradeStoredLockSecret({
    required LockSecretRecord previousSecret,
    required String plainPin,
    String? houseId,
  }) async {
    if (!_shouldUpgradeStoredSecret(previousSecret)) {
      return;
    }

    final effective = await _getEffectiveLockSettings(houseId: houseId);
    final upgradedSecret = _createStoredLockSecret(plainPin);
    await _saveLocalLockSettings(
      enabled: effective.enabled,
      useBiometrics: effective.useBiometrics,
      timeoutMinutes: effective.timeoutMinutes,
      militaryMode: effective.militaryMode,
      customLock: upgradedSecret.secret,
      customLockSalt: upgradedSecret.salt,
      customLockLength: upgradedSecret.pinLength ?? previousSecret.pinLength,
      configuredAtEpochMs: previousSecret.configuredAtEpochMs,
      scopeMap: effective.scopes,
    );
  }

  bool _secretsMatch(LockSecretRecord expectedSecret, String attempt) {
    final normalizedExpected = expectedSecret.secret.trim();
    final normalizedAttempt = attempt.trim();
    final normalizedSalt = expectedSecret.salt?.trim() ?? '';
    if (normalizedExpected.isEmpty || normalizedAttempt.isEmpty) {
      return false;
    }

    if (_isStoredKdfV2(normalizedExpected)) {
      return _verifySecretV2(normalizedExpected, normalizedAttempt);
    }

    if (normalizedSalt.isNotEmpty && _isStoredSha256(normalizedExpected)) {
      final attemptHash = _hashSecret(normalizedAttempt, normalizedSalt);
      return attemptHash == normalizedExpected.toLowerCase();
    }

    if (_isStoredSha256(normalizedExpected)) {
      final attemptHash =
          sha256.convert(utf8.encode(normalizedAttempt)).toString();
      return attemptHash == normalizedExpected.toLowerCase();
    }

    return normalizedAttempt == normalizedExpected;
  }

  LockSecretRecord? _buildLockSecretRecord(
    String? rawSecret, {
    String? rawSalt,
    dynamic rawPinLength,
    dynamic rawConfiguredAt,
  }) {
    final trimmedSecret = rawSecret?.trim() ?? '';
    if (trimmedSecret.isEmpty) {
      return null;
    }

    final trimmedSalt = rawSalt?.trim() ?? '';
    return LockSecretRecord(
      secret: trimmedSecret,
      salt: trimmedSalt.isEmpty ? null : trimmedSalt,
      pinLength: _normalizeLockSecretLength(
        rawPinLength is int
            ? rawPinLength
            : int.tryParse('${rawPinLength ?? ''}'),
        secret: trimmedSecret,
      ),
      configuredAtEpochMs: _parseInt(rawConfiguredAt),
    );
  }

  int? _normalizeLockSecretLength(int? rawLength, {required String secret}) {
    if (rawLength != null && rawLength >= 4) {
      return rawLength;
    }
    return RegExp(r'^\d{4,8}$').hasMatch(secret) ? secret.length : null;
  }

  String _hashSecret(String value, String salt) {
    return sha256.convert(utf8.encode('$value$salt')).toString();
  }

  String _hashSecretV2(String value) {
    const iterations = 120000;
    final salt = _generateSalt(bytes: 24);
    final hash = _pbkdf2Sha256(
      password: value,
      salt: salt,
      iterations: iterations,
      outputBytes: 32,
    );
    return 'v2\$pbkdf2_sha256\$$iterations\$$salt\$$hash';
  }

  bool _verifySecretV2(String storedSecret, String attempt) {
    final parts = storedSecret.split('\$');
    if (parts.length != 5 || parts[0] != 'v2' || parts[1] != 'pbkdf2_sha256') {
      return false;
    }

    final iterations = int.tryParse(parts[2]);
    final salt = parts[3];
    final expectedHash = parts[4].toLowerCase();
    if (iterations == null || iterations < 10000 || salt.isEmpty) {
      return false;
    }

    final attemptHash = _pbkdf2Sha256(
      password: attempt,
      salt: salt,
      iterations: iterations,
      outputBytes: expectedHash.length ~/ 2,
    );
    return attemptHash == expectedHash;
  }

  String _pbkdf2Sha256({
    required String password,
    required String salt,
    required int iterations,
    required int outputBytes,
  }) {
    const blockBytes = 32;
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    final blocks = (outputBytes / blockBytes).ceil();
    final derived = <int>[];

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      final blockSalt = <int>[
        ...saltBytes,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      var u = Hmac(sha256, passwordBytes).convert(blockSalt).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var j = 0; j < blockBytes; j++) {
          t[j] ^= u[j];
        }
      }
      derived.addAll(t);
    }

    return derived
        .take(outputBytes)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _generateSalt({int bytes = 16}) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  int? _parseInt(dynamic rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt();
    }
    return int.tryParse(rawValue?.toString() ?? '');
  }
}
