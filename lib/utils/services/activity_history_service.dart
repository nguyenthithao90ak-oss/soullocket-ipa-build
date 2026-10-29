import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/utils/activity_history_restore_policy.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'presence_service.dart';
import 'house_service.dart';
import 'storage/storage_service.dart';
import 'offline_cache_service.dart';
import 'l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/core/service_locator.dart';
import 'notebook/notebook_d1_client.dart';
import 'activity_history_remote.dart';
import 'infrastructure/cloudflare_data_service.dart';

class ActivityHistoryEntry {
  final String id;
  final int seq;
  final int ts;
  final String role;
  final String text;
  final String title;
  final String subtitle;
  final String action;
  final String module;
  final String entityType;
  final String entityId;
  final String sourceLabel;
  final String previewUrl;
  final String previewType;
  final String restorePath;
  final Map<String, dynamic> restorePayload;
  final int restoreExpiresAt;
  final bool isPrivate;
  final String placeholder;
  final bool revealed;
  final String key;
  final String houseId;
  final String syncStatus;
  final String authorUid;

  const ActivityHistoryEntry({
    required this.id,
    required this.seq,
    required this.ts,
    required this.role,
    required this.text,
    required this.houseId,
    this.title = '',
    this.subtitle = '',
    this.action = '',
    this.module = '',
    this.entityType = '',
    this.entityId = '',
    this.sourceLabel = '',
    this.previewUrl = '',
    this.previewType = '',
    this.restorePath = '',
    this.restorePayload = const <String, dynamic>{},
    this.restoreExpiresAt = 0,
    this.isPrivate = false,
    this.placeholder = '',
    this.revealed = false,
    this.key = '',
    this.syncStatus = 'synced',
    this.authorUid = '',
  });

  factory ActivityHistoryEntry.fromJson(Map<String, dynamic> j) {
    return ActivityHistoryEntry(
      id: j['id']?.toString() ?? '',
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      ts: (j['ts'] as num?)?.toInt() ?? 0,
      role: j['role']?.toString() ?? 'user1',
      text: j['text']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      subtitle: j['subtitle']?.toString() ?? '',
      action: j['action']?.toString() ?? '',
      module: j['module']?.toString() ?? '',
      entityType: j['entityType']?.toString() ?? '',
      entityId: j['entityId']?.toString() ?? '',
      sourceLabel: j['sourceLabel']?.toString() ?? '',
      previewUrl: j['previewUrl']?.toString() ?? '',
      previewType: j['previewType']?.toString() ?? '',
      restorePath: j['restorePath']?.toString() ?? '',
      restorePayload: j['restorePayload'] is Map
          ? Map<String, dynamic>.from(j['restorePayload'] as Map)
          : const <String, dynamic>{},
      restoreExpiresAt: (j['restoreExpiresAt'] as num?)?.toInt() ?? 0,
      isPrivate: j['private'] == true,
      placeholder: j['placeholder']?.toString() ?? '',
      revealed: j['revealed'] == true,
      key: j['key']?.toString() ?? '',
      houseId: j['houseId']?.toString() ?? '',
      syncStatus: j['syncStatus']?.toString() ?? 'synced',
      authorUid: j['authorUid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seq': seq,
    'ts': ts,
    'role': role,
    'text': text,
    'title': title,
    'subtitle': subtitle,
    'action': action,
    'module': module,
    'entityType': entityType,
    'entityId': entityId,
    'sourceLabel': sourceLabel,
    'previewUrl': previewUrl,
    'previewType': previewType,
    'restorePath': restorePath,
    'restorePayload': restorePayload,
    'restoreExpiresAt': restoreExpiresAt,
    'private': isPrivate,
    'placeholder': placeholder,
    'revealed': revealed,
    'key': key,
    'houseId': houseId,
    'syncStatus': syncStatus,
    'authorUid': authorUid,
  };

  ActivityHistoryEntry copyWith({
    String? id,
    int? seq,
    int? ts,
    String? role,
    String? text,
    String? title,
    String? subtitle,
    String? action,
    String? module,
    String? entityType,
    String? entityId,
    String? sourceLabel,
    String? previewUrl,
    String? previewType,
    String? restorePath,
    Map<String, dynamic>? restorePayload,
    int? restoreExpiresAt,
    bool? isPrivate,
    String? placeholder,
    bool? revealed,
    String? key,
    String? houseId,
    String? syncStatus,
    String? authorUid,
  }) {
    return ActivityHistoryEntry(
      id: id ?? this.id,
      seq: seq ?? this.seq,
      ts: ts ?? this.ts,
      role: role ?? this.role,
      text: text ?? this.text,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      action: action ?? this.action,
      module: module ?? this.module,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      previewUrl: previewUrl ?? this.previewUrl,
      previewType: previewType ?? this.previewType,
      restorePath: restorePath ?? this.restorePath,
      restorePayload: restorePayload ?? this.restorePayload,
      restoreExpiresAt: restoreExpiresAt ?? this.restoreExpiresAt,
      isPrivate: isPrivate ?? this.isPrivate,
      placeholder: placeholder ?? this.placeholder,
      revealed: revealed ?? this.revealed,
      key: key ?? this.key,
      houseId: houseId ?? this.houseId,
      syncStatus: syncStatus ?? this.syncStatus,
      authorUid: authorUid ?? this.authorUid,
    );
  }

  String get displayLine {
    final who = role == 'user2'
        ? L10nService().translate('female_role_default')
        : L10nService().translate('male_role_default');
    if (isPrivate && !revealed) {
      return '$who ${placeholder.isNotEmpty ? placeholder : L10nService().translate('home_activity_performed')}';
    }
    final base = title.trim().isNotEmpty ? title.trim() : text.trim();
    return base.isEmpty ? who : '$who $base';
  }

  bool get hasPreview => !isPrivate && previewUrl.trim().isNotEmpty;
  bool get isImagePreview =>
      !isPrivate && previewType.trim().toLowerCase() == 'image';
  bool get isVoicePreview =>
      !isPrivate && previewType.trim().toLowerCase() == 'audio';
  bool get isRestoreExpired =>
      restoreExpiresAt > 0 &&
      DateTime.now().millisecondsSinceEpoch > restoreExpiresAt;
  bool get canRestore {
    if (isRestoreExpired) {
      return false;
    }

    final moduleKey = module.trim().toLowerCase();
    // Các danh sách đã gỡ khỏi app chỉ giữ lịch sử đọc, không tạo lại dữ liệu.
    if (moduleKey == 'secret_vault' ||
        isRetiredListRestore(module, restorePath)) {
      return false;
    }
    if (moduleKey == 'diary_memory') {
      return entityId.trim().isNotEmpty && houseId.trim().isNotEmpty;
    }
    return restorePath.trim().isNotEmpty && restorePayload.isNotEmpty;
  }

  String get effectiveSourceLabel =>
      sourceLabel.trim().isNotEmpty ? sourceLabel.trim() : module.trim();
}

class ActivityHistoryService {
  static final ActivityHistoryService instance = ActivityHistoryService._();
  ActivityHistoryService._()
    : _uidForTesting = null,
      _remoteForTesting = null,
      _queueForTesting = null,
      _onlineForTesting = null;

  @visibleForTesting
  ActivityHistoryService.forTesting({
    required String? Function() currentUid,
    ActivityHistoryRemote? remote,
    LocalDatabaseService? queue,
    bool Function()? isOnline,
  }) : _uidForTesting = currentUid,
       _remoteForTesting = remote,
       _queueForTesting = queue,
       _onlineForTesting = isOnline;
  final String? Function()? _uidForTesting;
  final ActivityHistoryRemote? _remoteForTesting;
  final LocalDatabaseService? _queueForTesting;
  final bool Function()? _onlineForTesting;
  bool get _online =>
      _onlineForTesting?.call() ?? ConnectivityService().isOnline;
  int _epoch = 0;
  int _mutations = 0;
  Future<void> _cacheSerial = Future.value();
  bool _webSyncing = false;

  Future<T> _withCache<T>(Future<T> Function() action) {
    final future = _cacheSerial.then((_) => action());
    _cacheSerial = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return future;
  }

  late final ActivityHistoryRemote _remote =
      _remoteForTesting ?? ActivityHistoryRemote();
  late final LocalDatabaseService _queue =
      _queueForTesting ?? LocalDatabaseService();
  String? get _currentUid {
    if (_uidForTesting != null) return _uidForTesting();
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static const _legacyKey = 'il_activity_history_v1';
  static const _legacySeqKey = 'il_activity_history_seq_v1';
  static const _cachePrefix = 'il_activity_history_cache_v3_';
  static const _seqPrefix = 'il_activity_history_seq_v3_';
  static const _migratedPrefix = 'il_activity_history_migrated_v2_';
  static const maxItems = 20;
  static const _max = maxItems;
  static const int restoreWindowMs = 3 * 24 * 60 * 60 * 1000;

  // Khởi tạo lazy để đọc cache cục bộ không cần chờ Firebase App.
  // Điều này giúp màn lịch sử dựng dữ liệu tức thì ngay cả khi bootstrap mạng
  // vẫn đang chạy ở nền.
  late final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final HouseService _houseService = HouseService();

  /// Đọc bản sao cục bộ mà không chờ Auth, RTDB hay đồng bộ nền.
  ///
  /// Màn lịch sử dùng bước này trước khi tải mạng để nội dung gần
  /// nhất xuất hiện ngay khi người dùng mở màn hình.
  Future<List<ActivityHistoryEntry>> loadCached({String? houseId}) async {
    final uid = _currentUid;
    final house = houseId?.trim() ?? '';
    if (uid == null || house.isEmpty) return [];
    return _loadCache(house, ownerUid: uid);
  }

  Future<List<ActivityHistoryEntry>> loadAll({String? houseId}) async {
    final uid = _currentUid;
    if (uid == null) return [];
    final house = await _resolveHouseId(houseId);
    if (house == null || house.isEmpty || _currentUid != uid) return [];
    final epoch = _epoch;
    try {
      if (_online) {
        // Đọc queue trước và sau GET để không mất lệnh vừa được ACK trong lúc tải.
        final before = await _pendingActivity(house, uid);
        if (kIsWeb) await _drainWeb(house, uid);
        final snapshot = await _remote.read(house);
        if (_currentUid != uid) return [];
        var entries = snapshot.entries
            .map(
              (item) => ActivityHistoryEntry.fromJson({
                ...item,
                'syncStatus': 'synced',
              }),
            )
            .toList();
        final after = await _pendingActivity(house, uid);
        if (_currentUid != uid) return [];
        final pending =
            <String, Map<String, Object?>>{
              for (final task in [...before, ...after])
                task['operationId'].toString(): task,
            }.values.toList()..sort(
              (a, b) =>
                  (a['createdAt'] as int).compareTo(b['createdAt'] as int),
            );
        final oldest =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(days: 7).inMilliseconds;
        for (final task in pending) {
          if ((task['createdAt'] as int) < oldest) continue;
          final data = jsonDecode(task['payload'] as String) as Map;
          if (task['action'] == 'DELETE') {
            final through =
                (data['through'] as num?)?.toInt() ??
                (task['createdAt'] as int);
            entries.removeWhere((entry) => entry.ts <= through);
          } else {
            final entry = ActivityHistoryEntry.fromJson(
              Map<String, dynamic>.from(data),
            );
            if (snapshot.includes(entry.toJson(), house) &&
                entry.authorUid == uid) {
              entries.removeWhere((other) => other.id == entry.id);
              entries.add(entry.copyWith(syncStatus: 'pending'));
            }
          }
        }
        if (_epoch != epoch || _mutations > 0) {
          return _loadCache(house, ownerUid: uid);
        }
        final normalized = _normalizeEntries(entries);
        await _saveCache(
          house,
          normalized,
          ownerUid: uid,
          expectedEpoch: epoch,
        );
        if (_currentUid != uid) return [];
        return _epoch == epoch ? normalized : _loadCache(house, ownerUid: uid);
      }
    } catch (e) {
      debugPrint(
        'ActivityHistory refresh failed: ${AppErrorMapper.resolve(e).kind.name}',
      );
      if (e is ActivityScopeChanged || e is FirebaseAuthException) return [];
      if ((e is FirebaseException && e.code == 'permission-denied') ||
          (e is CloudflareDataException && [401, 403].contains(e.statusCode))) {
        await _saveCache(house, [], ownerUid: uid);
        return [];
      }
    }
    return _currentUid == uid ? _loadCache(house, ownerUid: uid) : [];
  }

  Future<void> add(
    String text, {
    String? houseId,
    String role = 'user1',
    String title = '',
    String subtitle = '',
    String action = '',
    String module = '',
    String entityType = '',
    String entityId = '',
    String sourceLabel = '',
    String previewUrl = '',
    String previewType = '',
    String restorePath = '',
    Map<String, dynamic> restorePayload = const <String, dynamic>{},
    int? restoreExpiresAt,
    bool isPrivate = false,
    String placeholder = '',
    String key = '',
  }) async {
    final uid = _currentUid;
    if (uid == null) return;
    final resolvedHouseId = await _resolveHouseId(houseId);
    if (_currentUid != uid) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seq = await _nextSeq(resolvedHouseId);
    if (_currentUid != uid) return;
    final entryId =
        '${now}_${seq}_${Random.secure().nextInt(1 << 32).toRadixString(16)}';
    final moduleKey = module.trim().toLowerCase();
    final entityTypeKey = entityType.trim().toLowerCase();
    final isSecretVaultEntry =
        moduleKey == 'secret_vault' ||
        entityTypeKey == 'secret_photo' ||
        restorePath.contains('/private_secure/');
    final safeSubtitle = isSecretVaultEntry ? '' : subtitle;
    final safePreviewUrl = isSecretVaultEntry ? '' : previewUrl;
    final safePreviewType = isSecretVaultEntry ? 'private' : previewType;
    final safeRestorePayload = isSecretVaultEntry
        ? (Map<String, dynamic>.from(restorePayload)
            ..remove('url')
            ..remove('downloadUrl')
            ..remove('previewUrl')
            ..remove('caption_plain'))
        : restorePayload;
    final safeIsPrivate = isPrivate || isSecretVaultEntry;
    final safePlaceholder = isSecretVaultEntry && placeholder.trim().isEmpty
        ? L10nService().translate('home_activity_vault_interaction')
        : placeholder;
    final entry = ActivityHistoryEntry(
      id: entryId,
      seq: seq,
      ts: now,
      role: role,
      text: text,
      title: title,
      subtitle: safeSubtitle,
      action: action,
      module: module,
      entityType: entityType,
      entityId: entityId,
      sourceLabel: sourceLabel,
      previewUrl: safePreviewUrl,
      previewType: safePreviewType,
      restorePath: restorePath,
      restorePayload: safeRestorePayload,
      restoreExpiresAt:
          restoreExpiresAt ??
          (restorePath.trim().isNotEmpty && safeRestorePayload.isNotEmpty
              ? now + restoreWindowMs
              : 0),
      isPrivate: safeIsPrivate,
      placeholder: safePlaceholder,
      key: key,
      houseId: resolvedHouseId ?? '',
      authorUid: uid,
      syncStatus: 'pending',
    );

    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      await _appendLegacyLocal(entry);
      return;
    }

    if (_currentUid != uid) return;
    final payload = entry.toJson()..remove('syncStatus');
    // Lưu lệnh bền vững trước cache; retry giữ ID/body và UID gốc.
    _epoch++;
    _mutations++;
    try {
      await _enqueueActivity(
        resolvedHouseId,
        uid,
        'SET',
        payload,
        now,
        'activity_${entry.id}',
      );
      if (_currentUid != uid) return;
      await _appendCache(
        resolvedHouseId,
        entry,
        replaceExisting: true,
        ownerUid: uid,
      );
    } finally {
      _mutations--;
      _epoch++;
    }
    if (kIsWeb && _online) unawaited(_drainWeb(resolvedHouseId, uid));
    try {
      await PresenceService().markActiveNow();
    } catch (_) {}
  }

  Future<bool> restoreEntry(ActivityHistoryEntry entry) async {
    final uid = _currentUid;
    final house = await _resolveHouseId(null);
    if (uid == null ||
        _currentUid != uid ||
        house != entry.houseId ||
        (entry.restorePath.isNotEmpty &&
            !entry.restorePath.startsWith('houses/${entry.houseId}/'))) {
      return false;
    }
    if (!entry.canRestore) {
      return false;
    }

    final moduleKey = entry.module.trim().toLowerCase();

    if (moduleKey == 'diary_memory') {
      try {
        await StorageService().restoreMemoryImageFromTrash(
          houseId: entry.houseId,
          memoryId: entry.entityId,
        );
      } catch (e) {
        final errorText = AppErrorMapper.resolve(e).message;
        final isNotFound =
            errorText.contains('firebase_functions/not-found') ||
            errorText.contains('not-found') ||
            errorText.contains('NOT_FOUND') ||
            errorText.contains(
              L10nService().translate('home_activity_memory_not_found'),
            );
        final payload = Map<String, dynamic>.from(entry.restorePayload);
        final payloadPurgeAt = (payload['purgeAt'] as num?)?.toInt() ?? 0;
        final effectiveExpiry = entry.restoreExpiresAt > 0
            ? entry.restoreExpiresAt
            : payloadPurgeAt;
        final isExpired =
            effectiveExpiry > 0 &&
            DateTime.now().millisecondsSinceEpoch > effectiveExpiry;
        if (!isNotFound ||
            payload.isEmpty ||
            entry.houseId.isEmpty ||
            isExpired) {
          debugPrint(
            'ActivityHistory diary memory restore failed: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('home_activity_memory_restore_error')).message}',
          );
          return false;
        }

        try {
          final memoryId = entry.entityId.trim();
          if (memoryId.isEmpty) {
            return false;
          }
          payload['id'] = memoryId;
          payload.remove('deletedAt');
          payload.remove('purgeAt');
          payload['restoredAt'] = DateTime.now().millisecondsSinceEpoch;
          await _db.ref().update({
            'houses/${entry.houseId}/memories/$memoryId': payload,
            'houses/${entry.houseId}/memories_trash/$memoryId': null,
            'houses/${entry.houseId}/memoriesCount': ServerValue.increment(1),
          });
        } catch (fallbackError) {
          debugPrint(
            'ActivityHistory diary memory fallback restore failed: ${AppErrorMapper.resolve(fallbackError, fallbackMessage: L10nService().translate('home_activity_backup_restore_error')).message}',
          );
          return false;
        }
      }

      await add(
        L10nService().format('home_activity_restored', {
          'label': entry.effectiveSourceLabel.toLowerCase(),
        }),
        houseId: entry.houseId,
        role: entry.role,
        title: L10nService().translate('home_activity_restored_title'),
        subtitle: entry.title.isNotEmpty ? entry.title : entry.text,
        action: 'restore',
        module: entry.module,
        entityType: entry.entityType,
        entityId: entry.entityId,
        sourceLabel: entry.sourceLabel,
        previewUrl: entry.previewUrl,
        previewType: entry.previewType,
      );
      return true;
    }

    final payload = Map<String, dynamic>.from(entry.restorePayload);
    if (payload.isEmpty) {
      return false;
    }

    if (entry.module.trim().toLowerCase() == 'shared_notes' &&
        payload['backend'] == 'd1') {
      // Sổ tay đã chuyển sang D1: khôi phục qua API (kiểm tra revision và cửa sổ 3 ngày),
      // không ghi lại cây RTDB mà rules đã chặn.
      if (!await _restoreD1Note(entry, payload)) return false;
    } else {
      await _db.ref(entry.restorePath).set(payload);
    }

    await add(
      L10nService().format('home_activity_restored', {
        'label': entry.effectiveSourceLabel.toLowerCase(),
      }),
      houseId: entry.houseId,
      role: entry.role,
      title: L10nService().translate('home_activity_restored_title'),
      subtitle: entry.title.isNotEmpty ? entry.title : entry.text,
      action: 'restore',
      module: entry.module,
      entityType: entry.entityType,
      entityId: entry.entityId,
      sourceLabel: entry.sourceLabel,
      previewUrl: entry.previewUrl,
      previewType: entry.previewType,
    );
    return true;
  }

  Future<bool> _restoreD1Note(
    ActivityHistoryEntry entry,
    Map<String, dynamic> payload,
  ) async {
    final revision = (payload['restoreRevision'] as num?)?.toInt() ?? 0;
    if (entry.houseId.isEmpty || entry.entityId.isEmpty || revision <= 0) {
      return false;
    }
    try {
      await locator<NotebookD1Client>().restore(
        houseId: entry.houseId,
        noteId: entry.entityId,
        expectedRevision: revision,
      );
    } catch (e) {
      debugPrint(
        'ActivityHistory notebook restore failed: ${AppErrorMapper.resolve(e).kind.name}',
      );
      return false;
    }
    try {
      await _db
          .ref('houses/${entry.houseId}/metadata/last_updated_notes')
          .set(DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      /* Ghi chú đã khôi phục; máy kia thấy ở lần tải sau. */
    }
    return true;
  }

  Future<void> clear({String? houseId}) async {
    final uid = _currentUid;
    if (uid == null) return;
    final house = await _resolveHouseId(houseId);
    if (house == null || house.isEmpty || _currentUid != uid) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final operation =
        'activity_clear_${now}_${Random.secure().nextInt(1 << 32).toRadixString(16)}';
    _epoch++;
    _mutations++;
    try {
      await _enqueueActivity(
        house,
        uid,
        'DELETE',
        {'through': now},
        now,
        operation,
      );
      await _saveCache(house, [], ownerUid: uid);
    } finally {
      _mutations--;
      _epoch++;
    }
    if (kIsWeb && _online) unawaited(_drainWeb(house, uid));
  }

  Future<void> _enqueueActivity(
    String house,
    String uid,
    String action,
    Map<String, dynamic> payload,
    int issuedAt,
    String operation,
  ) async {
    if (_currentUid != uid) throw const ActivityScopeChanged();
    final path =
        'houses/$house/activity_history${action == 'SET' ? '/${payload['id']}' : ''}';
    if (!kIsWeb) {
      await _queue.enqueueSync(
        path,
        action,
        jsonEncode(payload),
        operationId: operation,
        entityType: 'activity_history',
        expectedOwnerUid: uid,
        issuedAt: issuedAt,
      );
      return;
    }
    await _withCache(() async {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUid != uid) throw const ActivityScopeChanged();
      final key = 'il_activity_outbox_v1_${uid.length}:$uid:$house';
      final tasks = jsonDecode(prefs.getString(key) ?? '[]') as List;
      tasks.removeWhere((task) => (task as Map)['operationId'] == operation);
      tasks.add({
        'path': path,
        'action': action,
        'payload': jsonEncode(payload),
        'operationId': operation,
        'createdAt': issuedAt,
      });
      await prefs.setString(key, jsonEncode(tasks));
    });
  }

  Future<List<Map<String, Object?>>> _pendingActivity(
    String house,
    String uid,
  ) async {
    if (_currentUid != uid) return [];
    if (!kIsWeb) return _queue.pendingActivity(house);
    final prefs = await SharedPreferences.getInstance();
    if (_currentUid != uid) return [];
    final key = 'il_activity_outbox_v1_${uid.length}:$uid:$house';
    return (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .map((task) => Map<String, Object?>.from(task as Map))
        .toList();
  }

  Future<void> _drainWeb(String house, String uid) async {
    if (_webSyncing || _currentUid != uid) return;
    _webSyncing = true;
    try {
      final tasks = await _pendingActivity(house, uid);
      for (final task in tasks) {
        if (_currentUid != uid) return;
        final data = Map<String, dynamic>.from(
          jsonDecode(task['payload'] as String) as Map,
        );
        final clear = task['action'] == 'DELETE';
        await _remote.send(
          houseId: house,
          action: clear ? 'clear' : 'append',
          entry: clear ? null : data,
          through: clear ? (data['through'] as num).toInt() : null,
          issuedAt: task['createdAt'] as int,
          operationId: task['operationId'] as String,
          expectedUid: uid,
        );
        await _withCache(() async {
          final prefs = await SharedPreferences.getInstance();
          final key = 'il_activity_outbox_v1_${uid.length}:$uid:$house';
          final remaining = jsonDecode(prefs.getString(key) ?? '[]') as List;
          remaining.removeWhere(
            (item) => (item as Map)['operationId'] == task['operationId'],
          );
          await prefs.setString(key, jsonEncode(remaining));
        });
      }
    } catch (e) {
      debugPrint(
        'Activity outbox deferred: ${AppErrorMapper.resolve(e).kind.name}',
      );
    } finally {
      _webSyncing = false;
    }
  }

  Future<void> migrateLegacyLocalData({String? houseId}) async {
    final uid = _currentUid;
    if (uid == null) return;
    final house = await _resolveHouseId(houseId);
    if (house == null || house.isEmpty || _currentUid != uid) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final marker = '$_migratedPrefix$uid:$house';
    if (prefs.getBool(marker) == true) return;
    // Không tự gán lịch sử chưa rõ chủ cho tài khoản đang đăng nhập.
    final legacy = await _loadLegacyLocalEntries();
    final owned = legacy
        .where((entry) => entry.authorUid == uid && entry.houseId == house)
        .toList();
    for (final entry in owned) {
      if (_currentUid != uid) return;
      final payload = entry.toJson()..remove('syncStatus');
      await _enqueueActivity(
        house,
        uid,
        'SET',
        payload,
        entry.ts,
        'activity_legacy_${entry.id}',
      );
    }
    if (_currentUid == uid) await prefs.setBool(marker, true);
    // Giữ kho legacy để đối soát các mục không đủ bằng chứng sở hữu.
  }

  String exportAsTxt(List<ActivityHistoryEntry> list) {
    final lines = list.asMap().entries.map((e) {
      final idx = (e.key + 1).toString().padLeft(3, '0');
      final time = LocaleDateFormat.dateTime(
        DateTime.fromMillisecondsSinceEpoch(e.value.ts),
      );
      return '$idx. $time • ${e.value.displayLine}';
    }).toList();
    return lines.join('\n');
  }

  String exportAsHtml(List<ActivityHistoryEntry> list) {
    final rows = list
        .asMap()
        .entries
        .map((e) {
          final idx = (e.key + 1).toString().padLeft(3, '0');
          final time = LocaleDateFormat.dateTime(
            DateTime.fromMillisecondsSinceEpoch(e.value.ts),
          );
          final line = '$idx. $time • ${e.value.displayLine}';
          return '<div class="row">$line</div>';
        })
        .join('');

    final locale = L10nService().localeCode;
    final title = L10nService().translate('util_lchshotng_de1bcb');
    return '''<!doctype html><html lang="$locale"><head><meta charset="utf-8">
<title>$title</title>
<style>
  body{font-family:Arial,sans-serif;padding:16px;background:#fff}
  h1{font-size:18px;margin-bottom:10px}
  .row{padding:6px 0;border-bottom:1px dashed #eee;font-size:13px;line-height:1.5}
</style></head><body>
<h1>$title</h1>
<div class="meta">${LocaleDateFormat.dateTime(DateTime.now())} • ${list.length}/$_max</div>
$rows
</body></html>''';
  }

  Future<List<ActivityHistoryEntry>> _loadCache(
    String houseId, {
    String? ownerUid,
  }) async {
    final uid = ownerUid ?? _currentUid;
    if (uid == null || _currentUid != uid) return [];
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (_currentUid != uid) return [];
      final raw = prefs.getString(_cacheKey(houseId, uid));
      if (raw == null || raw.isEmpty) {
        return const <ActivityHistoryEntry>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return _normalizeEntries(
        list
            .whereType<Map>()
            .map(
              (item) => ActivityHistoryEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return const <ActivityHistoryEntry>[];
    }
  }

  Future<List<ActivityHistoryEntry>> _loadLegacyLocalEntries() async {
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      if (raw == null || raw.isEmpty) {
        return const <ActivityHistoryEntry>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return _normalizeEntries(
        list.whereType<Map>().map((item) {
          final map = Map<String, dynamic>.from(item);
          map['id'] ??=
              '${map['ts'] ?? 0}_${map['seq'] ?? 0}_${map['role'] ?? 'legacy'}';
          map['syncStatus'] ??= 'legacy_local';
          return ActivityHistoryEntry.fromJson(map);
        }).toList(),
      );
    } catch (_) {
      return const <ActivityHistoryEntry>[];
    }
  }

  Future<void> _saveCache(
    String houseId,
    List<ActivityHistoryEntry> list, {
    String? ownerUid,
    int? expectedEpoch,
  }) => _withCache(
    () => _saveCacheNow(
      houseId,
      list,
      ownerUid: ownerUid,
      expectedEpoch: expectedEpoch,
    ),
  );

  Future<void> _saveCacheNow(
    String houseId,
    List<ActivityHistoryEntry> list, {
    String? ownerUid,
    int? expectedEpoch,
  }) async {
    final uid = ownerUid ?? _currentUid;
    if (uid == null || _currentUid != uid) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (_currentUid != uid ||
        (expectedEpoch != null && expectedEpoch != _epoch)) {
      return;
    }
    await prefs.setString(
      _cacheKey(houseId, uid),
      jsonEncode(
        _normalizeEntries(list).map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  Future<List<ActivityHistoryEntry>> _appendCache(
    String houseId,
    ActivityHistoryEntry entry, {
    bool replaceExisting = false,
    String? ownerUid,
  }) async {
    return _withCache(() async {
      final existing = await _loadCache(houseId, ownerUid: ownerUid);
      final merged = <ActivityHistoryEntry>[
        if (!replaceExisting) entry,
        ...existing,
        if (replaceExisting) entry,
      ];
      final normalized = _normalizeEntries(merged);
      await _saveCacheNow(houseId, normalized, ownerUid: ownerUid);
      return normalized;
    });
  }

  Future<void> _appendLegacyLocal(ActivityHistoryEntry entry) async {
    final list = await _loadLegacyLocalEntries();
    final merged = _normalizeEntries([...list, entry]);
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(
      _legacyKey,
      jsonEncode(merged.map((item) => item.toJson()).toList()),
    );
    await prefs.setInt(_legacySeqKey, entry.seq);
  }

  List<ActivityHistoryEntry> _normalizeEntries(
    List<ActivityHistoryEntry> list,
  ) {
    final byId = <String, ActivityHistoryEntry>{};
    for (final entry in list) {
      final resolvedId = entry.id.isNotEmpty
          ? entry.id
          : '${entry.ts}_${entry.seq}_${entry.role}';
      byId[resolvedId] = entry.copyWith(id: resolvedId);
    }

    final values = byId.values.toList()
      ..sort((a, b) {
        final time = a.ts.compareTo(b.ts);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    if (values.length > _max) {
      return values.sublist(values.length - _max);
    }
    return values;
  }

  Future<String?> _resolveHouseId(String? houseId) async {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final resolved = await _houseService.getCurrentHouseId();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }

    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final cached = prefs.getString('il_house_id')?.trim() ?? '';
    final cachedAuthUid = prefs.getString('il_auth_uid')?.trim() ?? '';
    if (cached.isNotEmpty) {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null && cachedAuthUid == currentUid) {
        return cached;
      }
      await prefs.remove('il_house_id');
      await prefs.remove('il_role');
    }

    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final snapshot = await _db.ref('users/${user.uid}/houseId').get();
      final remote = snapshot.value?.toString().trim() ?? '';
      if (remote.isNotEmpty) {
        await prefs.setString('il_house_id', remote);
        await prefs.setString('il_auth_uid', user.uid);
        return remote;
      }
    } catch (error) {
      debugPrint('[ActivityHistory] Không khôi phục được houseId: $error');
    }
    return null;
  }

  Future<int> _nextSeq(String? houseId) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final key = houseId == null || houseId.isEmpty
        ? _legacySeqKey
        : _seqKey(houseId);
    int next = prefs.getInt(key) ?? 0;
    next = (next + 1) > 100000 ? 1 : next + 1;
    await prefs.setInt(key, next);
    return next;
  }

  String _cacheKey(String houseId, String uid) =>
      '$_cachePrefix${uid.length}:$uid:$houseId';
  String _seqKey(String houseId) => '$_seqPrefix${_currentUid ?? ''}:$houseId';
}
