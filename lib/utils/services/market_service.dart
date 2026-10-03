import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../app_error_mapper.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/market_catalog.dart';
import '../calendar/calendar_time_zone.dart';

/// Tùy chọn khu vực thuộc từng tài khoản trên thiết bị, độc lập ngôn ngữ.
class MarketPreferences {
  const MarketPreferences({
    this.marketCode,
    this.holidayPacks,
    this.firstWeekday,
    this.use24HourFormat,
    this.secondaryCalendar,
    this.timeZoneId,
    this.holidayRemindersEnabled = false,
  });

  /// Ngày trong tuần dùng cho cột đầu tiên của lưới: DateTime.monday,
  /// DateTime.saturday hoặc DateTime.sunday. null nghĩa là theo hồ sơ vùng.
  static const supportedFirstWeekdays = <int>{
    DateTime.monday,
    DateTime.saturday,
    DateTime.sunday,
  };

  static const supportedSecondaryCalendars = <String>{
    'buddhist',
    'islamic-civil',
  };

  final String? marketCode;
  final List<String>? holidayPacks;
  final int? firstWeekday;
  final bool? use24HourFormat;
  final String? secondaryCalendar;
  final String? timeZoneId;
  final bool holidayRemindersEnabled;

  factory MarketPreferences.fromJson(Object? raw) {
    if (raw is! Map) {
      return const MarketPreferences();
    }
    final schema = int.tryParse(raw['schemaVersion']?.toString() ?? '');
    // V1 chỉ có marketCode/holidayPacks. Đọc được cả V1 và V2 để nâng cấp
    // dần trên thiết bị và cloud, không làm mất lựa chọn cũ.
    if (schema != 1 && schema != 2) return const MarketPreferences();
    final code = MarketCatalog.find(raw['marketCode']?.toString())?.code;
    final packs = raw['holidayPacks'];
    final rawWeekday = raw['firstWeekday'];
    final weekday = int.tryParse(rawWeekday?.toString() ?? '');
    final normalizedWeekday = supportedFirstWeekdays.contains(weekday)
        ? weekday
        : null;
    final rawSecondary = raw['secondaryCalendar']?.toString().trim();
    final secondary = supportedSecondaryCalendars.contains(rawSecondary)
        ? rawSecondary
        : null;
    final rawTimeZone = raw['timeZoneId']?.toString().trim();
    return MarketPreferences(
      marketCode: code,
      holidayPacks: packs is List
          ? List.unmodifiable(
              packs
                  .whereType<String>()
                  .where(MarketCatalog.holidayPackCodes.contains)
                  .toSet(),
            )
          : raw['useDefaultHolidayPacks'] == false
          ? const []
          : null,
      firstWeekday: normalizedWeekday,
      use24HourFormat: raw['use24HourFormat'] is bool
          ? raw['use24HourFormat'] as bool
          : null,
      secondaryCalendar: secondary,
      timeZoneId: isValidTimeZoneId(rawTimeZone) ? rawTimeZone : null,
      holidayRemindersEnabled: raw['holidayRemindersEnabled'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'useDefaultHolidayPacks': holidayPacks == null,
    if (marketCode != null) 'marketCode': marketCode,
    if (holidayPacks != null) 'holidayPacks': holidayPacks,
    if (firstWeekday != null) 'firstWeekday': firstWeekday,
    if (use24HourFormat != null) 'use24HourFormat': use24HourFormat,
    if (secondaryCalendar != null) 'secondaryCalendar': secondaryCalendar,
    if (timeZoneId != null) 'timeZoneId': timeZoneId,
    'holidayRemindersEnabled': holidayRemindersEnabled,
  };

  static bool isValidTimeZoneId(String? value) => CalendarTimeZone.isValidId(value);
}

enum MarketSyncState { localOnly, syncing, synced, pending }

class MarketService extends ChangeNotifier with WidgetsBindingObserver {
  MarketService._();
  static final instance = MarketService._();

  @visibleForTesting
  MarketService.forTesting({required String? Function() accountId})
    : _accountIdOverride = accountId;

  String? Function()? _accountIdOverride;
  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  Future<void> _writes = Future.value();
  final Random _random = Random.secure();
  StreamSubscription<DatabaseEvent>? _cloudSubscription;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  DatabaseReference? _cloudRef;
  String? _cloudUid;
  int _cloudSession = 0;
  final Set<String> _uploads = {};
  MarketSyncState _syncState = MarketSyncState.localOnly;
  bool _disposed = false;
  bool _observingLocale = false;

  String? get _accountId {
    if (_accountIdOverride != null) return _accountIdOverride!();
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String get accountScope => _key;

  String get _key {
    final uid = _accountId;
    return uid == null
        ? 'sl_market_v1_guest'
        : 'sl_market_v1_user_${Uri.encodeComponent(uid)}';
  }

  Future<void> init({SharedPreferences? preferences}) async {
    if (!_observingLocale && !_disposed) {
      WidgetsBinding.instance.addObserver(this);
      _observingLocale = true;
    }
    try {
      _prefs = preferences ?? await SharedPreferences.getInstance();
    } catch (_) {
      // Cho phép ứng dụng mở với mặc định khi bộ nhớ tùy chọn chưa sẵn sàng.
    }
    attachAuthListener();
    _bindCloud();
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (!_disposed) notifyListeners();
  }

  void attachAuthListener() {
    if (_disposed) return;
    if (_accountIdOverride == null && _authSubscription == null) {
      try {
        _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
          _,
        ) {
          if (!_disposed) {
            _bindCloud();
            notifyListeners();
          }
        });
      } catch (_) {
        // Bootstrap Firebase có thể được thử lại; getter vẫn đọc đúng tài khoản.
      }
    }
  }

  MarketPreferences get preferences {
    final raw = _prefs?.get(_key);
    if (raw is! String) return const MarketPreferences();
    try {
      return MarketPreferences.fromJson(jsonDecode(raw));
    } catch (_) {
      return const MarketPreferences();
    }
  }

  String get deviceMarketCode =>
      MarketCatalog.find(
        WidgetsBinding.instance.platformDispatcher.locale.countryCode,
      )?.code ??
      'ALL';

  String get marketCode => preferences.marketCode ?? deviceMarketCode;

  MarketProfile get profile => MarketCatalog.find(marketCode)!;

  List<String> holidayPacks({required String languageCode}) {
    final saved = preferences;
    if (saved.holidayPacks != null) return saved.holidayPacks!;
    return defaultHolidayPacks(
      marketCode: saved.marketCode,
      languageCode: languageCode,
    );
  }

  List<String> defaultHolidayPacks({
    String? marketCode,
    required String languageCode,
  }) {
    final result = MarketCatalog.defaultHolidayPacks(
      marketCode ?? deviceMarketCode,
    ).toSet();
    // Giữ hành vi Việt Nam cũ cho người chưa chọn khu vực/gói lễ.
    if (marketCode == null) {
      result.remove('VN');
      if (languageCode == 'vi') result.add('VN');
    }
    return result.toList(growable: false);
  }

  Future<void> save(MarketPreferences value) {
    final targetKey = _key;
    final normalized = MarketPreferences.fromJson(value.toJson());
    final encoded = jsonEncode({
      ...normalized.toJson(),
      if (_accountId != null && _accountIdOverride == null)
        '_pendingToken': _newMutationId(),
    });
    return _enqueueLocal(() async {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      if (!await prefs.setString(targetKey, encoded)) {
        throw StateError('Market preferences could not be saved');
      }
      if (!_disposed && targetKey == _key) {
        notifyListeners();
        _bindCloud();
        unawaited(_uploadPending(_cloudSession, targetKey));
      }
    });
  }

  MarketSyncState get syncState {
    if (_accountId == null || _accountIdOverride != null) {
      return MarketSyncState.localOnly;
    }
    return _syncState;
  }

  Map<String, dynamic>? _localRecord(String key) {
    final raw = _prefs?.get(key);
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _newMutationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';

  Future<void> _enqueueLocal(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _setSyncState(MarketSyncState value, String key) {
    if (_disposed || key != _key) return;
    _syncState = value;
    notifyListeners();
  }

  void _bindCloud() {
    if (_disposed || _accountIdOverride != null) return;
    final uid = _accountId;
    if (_cloudUid == uid && _cloudSubscription != null) return;
    final session = ++_cloudSession;
    _cloudUid = uid;
    unawaited(_cloudSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    _cloudSubscription = null;
    _connectionSubscription = null;
    _cloudRef = null;
    _syncState = uid == null
        ? MarketSyncState.localOnly
        : MarketSyncState.syncing;
    if (uid == null) {
      notifyListeners();
      return;
    }
    final key = _key;
    try {
      final database = FirebaseDatabase.instance;
      final reference = database.ref('users/$uid/settings/_market');
      _cloudRef = reference;
      _cloudSubscription = reference.onValue.listen(
        (event) {
          if (!_cloudActive(session, key)) return;
          unawaited(_acceptCloud(event.snapshot.value, session, key));
        },
        onError: (Object error) {
          if (_cloudActive(session, key)) {
            _setSyncState(MarketSyncState.pending, key);
          }
        },
      );
      _connectionSubscription = database
          .ref('.info/connected')
          .onValue
          .listen(
            (event) {
              if (!_cloudActive(session, key)) return;
              if (event.snapshot.value == true) {
                unawaited(retryCloudSync());
              } else {
                _setSyncState(MarketSyncState.pending, key);
              }
            },
            onError: (Object error) {
              if (_cloudActive(session, key)) {
                _setSyncState(MarketSyncState.pending, key);
              }
            },
          );
    } catch (_) {
      _setSyncState(MarketSyncState.pending, key);
    }
  }

  bool _cloudActive(int session, String key) =>
      !_disposed && session == _cloudSession && key == _key;

  Future<void> _acceptCloud(Object? raw, int session, String key) async {
    try {
      await _enqueueLocal(() async {
        if (!_cloudActive(session, key)) return;
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        if (!_cloudActive(session, key)) return;
        final local = _localRecord(key);
        if (local?['_pendingToken'] != null) return;
        if (raw == null) {
          // Di trú lựa chọn cũ của chính tài khoản này; không sao chép từ guest.
          if (local != null) {
            final pending = {...local, '_pendingToken': _newMutationId()};
            if (!await prefs.setString(key, jsonEncode(pending))) {
              throw StateError('Cannot retain pending market preferences');
            }
          } else {
            _setSyncState(MarketSyncState.synced, key);
          }
          return;
        }
        final schema = raw is Map
            ? int.tryParse(raw['schemaVersion']?.toString() ?? '')
            : null;
        if (raw is! Map || (schema != 1 && schema != 2)) {
          _setSyncState(MarketSyncState.pending, key);
          return;
        }
        final restored = MarketPreferences.fromJson(raw).toJson();
        if (!await prefs.setString(key, jsonEncode(restored))) {
          throw StateError('Cannot cache market preferences');
        }
        _setSyncState(MarketSyncState.synced, key);
      });
      if (_cloudActive(session, key)) await _uploadPending(session, key);
    } catch (error) {
      _setSyncState(MarketSyncState.pending, key);
      debugPrint('[MarketService] ${AppErrorMapper.resolve(error).message}');
    }
  }

  Future<void> _uploadPending(int session, String key) async {
    final reference = _cloudRef;
    if (!_cloudActive(session, key) ||
        reference == null ||
        !_uploads.add(key)) {
      return;
    }
    String? sentToken;
    try {
      final local = _localRecord(key);
      final token = local?['_pendingToken'];
      if (local == null || token is! String) return;
      sentToken = token;
      _setSyncState(MarketSyncState.syncing, key);
      await reference
          .set({
            ...MarketPreferences.fromJson(local).toJson(),
            'mutationId': token,
            'updatedAt': ServerValue.timestamp,
          })
          .timeout(const Duration(seconds: 12));
      await _enqueueLocal(() async {
        if (!_cloudActive(session, key)) return;
        final latest = _localRecord(key);
        if (latest?['_pendingToken'] != token) return;
        latest!.remove('_pendingToken');
        if (!await _prefs!.setString(key, jsonEncode(latest))) {
          throw StateError('Cannot acknowledge market preferences');
        }
        _setSyncState(MarketSyncState.synced, key);
      });
    } catch (error) {
      if (_cloudActive(session, key)) {
        _setSyncState(MarketSyncState.pending, key);
        debugPrint('[MarketService] ${AppErrorMapper.resolve(error).message}');
      }
    } finally {
      _uploads.remove(key);
      final next = _localRecord(key)?['_pendingToken'];
      if (_cloudActive(session, key) && next is String && next != sentToken) {
        unawaited(_uploadPending(session, key));
      } else if (!_disposed && key == _key && session != _cloudSession) {
        unawaited(_uploadPending(_cloudSession, key));
      }
    }
  }

  Future<void> retryCloudSync() async {
    _bindCloud();
    if (_accountId == null) return;
    final session = _cloudSession;
    final key = _key;
    if (_localRecord(key)?['_pendingToken'] != null) {
      await _uploadPending(session, key);
      return;
    }
    try {
      final snapshot = await _cloudRef?.get().timeout(
        const Duration(seconds: 12),
      );
      if (snapshot != null && _cloudActive(session, key)) {
        await _acceptCloud(snapshot.value, session, key);
      }
    } catch (_) {
      _setSyncState(MarketSyncState.pending, key);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(retryCloudSync());
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudSession++;
    unawaited(_cloudSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    if (_observingLocale) WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
