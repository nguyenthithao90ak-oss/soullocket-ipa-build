import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'album_service.dart';
import 'presence_service.dart';
import 'house_service.dart';
import 'storage_service.dart';

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
    final who = role == 'user2' ? 'Bạn nữ' : 'Bạn nam';
    if (isPrivate && !revealed) {
      return '$who ${placeholder.isNotEmpty ? placeholder : "đã thực hiện 1 thao tác (đang ẩn)"}';
    }
    final base = title.trim().isNotEmpty ? title.trim() : text.trim();
    return base.isEmpty ? who : '$who $base';
  }

  bool get hasPreview => previewUrl.trim().isNotEmpty;
  bool get isImagePreview => previewType.trim().toLowerCase() == 'image';
  bool get isVoicePreview => previewType.trim().toLowerCase() == 'audio';
  bool get isRestoreExpired =>
      restoreExpiresAt > 0 &&
      DateTime.now().millisecondsSinceEpoch > restoreExpiresAt;
  bool get canRestore {
    if (isRestoreExpired) {
      return false;
    }

    final moduleKey = module.trim().toLowerCase();
    if (moduleKey == 'secret_vault') {
      return false;
    }
    if (moduleKey == 'album' || moduleKey == 'diary_memory') {
      return entityId.trim().isNotEmpty && houseId.trim().isNotEmpty;
    }
    return restorePath.trim().isNotEmpty && restorePayload.isNotEmpty;
  }

  String get effectiveSourceLabel =>
      sourceLabel.trim().isNotEmpty ? sourceLabel.trim() : module.trim();
}

class ActivityHistoryService {
  static final ActivityHistoryService instance = ActivityHistoryService._();
  ActivityHistoryService._();

  static const _legacyKey = 'il_activity_history_v1';
  static const _legacySeqKey = 'il_activity_history_seq_v1';
  static const _cachePrefix = 'il_activity_history_cache_v2_';
  static const _seqPrefix = 'il_activity_history_seq_v2_';
  static const _migratedPrefix = 'il_activity_history_migrated_v2_';
  static const maxItems = 20;
  static const _max = maxItems;
  static const int restoreWindowMs = 3 * 24 * 60 * 60 * 1000;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();

  Future<List<ActivityHistoryEntry>> loadAll({String? houseId}) async {
    final resolvedHouseId = await _resolveHouseId(houseId);
    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      return _loadLegacyLocalEntries();
    }

    try {
      if (ConnectivityService().isOnline) {
        final remote = await _loadRemote(resolvedHouseId);
        await _trimRemote(resolvedHouseId);
        final cache = await _loadCache(resolvedHouseId);
        final merged = _normalizeEntries([
          ...remote,
          ...cache.where((entry) => entry.syncStatus != 'synced'),
        ]);
        if (merged.isNotEmpty) {
          await _saveCache(resolvedHouseId, merged);
          return merged;
        }
      }
    } catch (e) {
      debugPrint('ActivityHistory remote load failed: $e');
    }

    final cache = await _loadCache(resolvedHouseId);
    if (cache.isNotEmpty) {
      return cache;
    }

    return _loadLegacyLocalEntries();
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
    final resolvedHouseId = await _resolveHouseId(houseId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final seq = await _nextSeq(resolvedHouseId);
    final uid = _auth.currentUser?.uid ?? '';
    final entryId = '${now}_${seq}_${role.trim()}';
    final entry = ActivityHistoryEntry(
      id: entryId,
      seq: seq,
      ts: now,
      role: role,
      text: text,
      title: title,
      subtitle: subtitle,
      action: action,
      module: module,
      entityType: entityType,
      entityId: entityId,
      sourceLabel: sourceLabel,
      previewUrl: previewUrl,
      previewType: previewType,
      restorePath: restorePath,
      restorePayload: restorePayload,
      restoreExpiresAt: restoreExpiresAt ??
          (restorePath.trim().isNotEmpty && restorePayload.isNotEmpty
              ? now + restoreWindowMs
              : 0),
      isPrivate: isPrivate,
      placeholder: placeholder,
      key: key,
      houseId: resolvedHouseId ?? '',
      authorUid: uid,
      syncStatus: ConnectivityService().isOnline ? 'synced' : 'pending',
    );

    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      await _appendLegacyLocal(entry);
      return;
    }

    await PresenceService().markActiveNow();

    final next = await _appendCache(
      resolvedHouseId,
      entry,
      replaceExisting: true,
    );

    final payload = entry.copyWith(syncStatus: 'synced').toJson()
      ..remove('syncStatus');

    if (ConnectivityService().isOnline) {
      try {
        await _entryRef(resolvedHouseId, entry.id).set(payload);
        await _trimRemote(resolvedHouseId);
        await _saveCache(
          resolvedHouseId,
          next
              .map((item) => item.id == entry.id
                  ? item.copyWith(syncStatus: 'synced')
                  : item)
              .toList(),
        );
        return;
      } catch (e) {
        debugPrint('ActivityHistory direct sync failed: $e');
      }
    }

    await LocalDatabaseService().enqueueSync(
      'houses/$resolvedHouseId/activity_history/${entry.id}',
      'SET',
      jsonEncode(payload),
      operationId: 'activity_${entry.id}',
      entityType: 'activity_history',
    );
  }

  Future<bool> restoreEntry(ActivityHistoryEntry entry) async {
    if (!entry.canRestore) {
      return false;
    }

    final moduleKey = entry.module.trim().toLowerCase();
    if (moduleKey == 'album') {
      try {
        await AlbumService().restoreFromTrash(
          houseId: entry.houseId,
          itemId: entry.entityId,
        );
      } catch (e) {
        debugPrint('ActivityHistory album restore failed: $e');
        return false;
      }

      await add(
        'đã khôi phục ${entry.effectiveSourceLabel.toLowerCase()}',
        houseId: entry.houseId,
        role: entry.role,
        title: 'Đã khôi phục',
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

    if (moduleKey == 'diary_memory') {
      try {
        await StorageService().restoreMemoryImageFromTrash(
          houseId: entry.houseId,
          memoryId: entry.entityId,
        );
      } catch (e) {
        final errorText = e.toString();
        final isNotFound = errorText.contains('firebase_functions/not-found') ||
            errorText.contains('not-found') ||
            errorText.contains('NOT_FOUND') ||
            errorText.contains('Ảnh Kỷ niệm không còn trong thùng rác');
        final payload = Map<String, dynamic>.from(entry.restorePayload);
        final payloadPurgeAt = (payload['purgeAt'] as num?)?.toInt() ?? 0;
        final effectiveExpiry = entry.restoreExpiresAt > 0
            ? entry.restoreExpiresAt
            : payloadPurgeAt;
        final isExpired = effectiveExpiry > 0 &&
            DateTime.now().millisecondsSinceEpoch > effectiveExpiry;
        if (!isNotFound ||
            payload.isEmpty ||
            entry.houseId.isEmpty ||
            isExpired) {
          debugPrint('ActivityHistory diary memory restore failed: $e');
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
            'ActivityHistory diary memory fallback restore failed: $fallbackError',
          );
          return false;
        }
      }

      await add(
        'đã khôi phục ${entry.effectiveSourceLabel.toLowerCase()}',
        houseId: entry.houseId,
        role: entry.role,
        title: 'Đã khôi phục',
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

    await _db.ref(entry.restorePath).set(payload);

    await add(
      'đã khôi phục ${entry.effectiveSourceLabel.toLowerCase()}',
      houseId: entry.houseId,
      role: entry.role,
      title: 'Đã khôi phục',
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

  Future<void> clear({String? houseId}) async {
    final resolvedHouseId = await _resolveHouseId(houseId);
    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyKey);
      await prefs.remove(_legacySeqKey);
      return;
    }

    await _saveCache(resolvedHouseId, const <ActivityHistoryEntry>[]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seqKey(resolvedHouseId));

    if (ConnectivityService().isOnline) {
      await _db.ref('houses/$resolvedHouseId/activity_history').remove();
      return;
    }

    await LocalDatabaseService().enqueueSync(
      'houses/$resolvedHouseId/activity_history',
      'DELETE',
      jsonEncode(<String, dynamic>{}),
      operationId: 'activity_clear_$resolvedHouseId',
      entityType: 'activity_history',
    );
  }

  Future<void> migrateLegacyLocalData({String? houseId}) async {
    final resolvedHouseId = await _resolveHouseId(houseId);
    if (resolvedHouseId == null ||
        resolvedHouseId.isEmpty ||
        !ConnectivityService().isOnline) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_migratedPrefix$resolvedHouseId') == true) {
      return;
    }

    final legacyEntries = await _loadLegacyLocalEntries();
    if (legacyEntries.isEmpty) {
      await prefs.setBool('$_migratedPrefix$resolvedHouseId', true);
      return;
    }

    final remote = await _loadRemote(resolvedHouseId);
    final merged = <ActivityHistoryEntry>[
      ...remote,
      ...legacyEntries.map(
        (entry) => entry.copyWith(
          id: entry.id.isNotEmpty
              ? entry.id
              : '${entry.ts}_${entry.seq}_legacy',
          houseId: resolvedHouseId,
          syncStatus: 'synced',
        ),
      ),
    ];
    final deduped = _normalizeEntries(merged);

    final updates = <String, dynamic>{};
    for (final entry in deduped) {
      updates[entry.id] = entry.copyWith(syncStatus: 'synced').toJson()
        ..remove('syncStatus');
    }

    if (updates.isNotEmpty) {
      await _db.ref('houses/$resolvedHouseId/activity_history').update(updates);
      await _trimRemote(resolvedHouseId);
      await _saveCache(resolvedHouseId, deduped);
      final maxSeq = deduped.fold<int>(
        0,
        (current, item) => item.seq > current ? item.seq : current,
      );
      await prefs.setInt(_seqKey(resolvedHouseId), maxSeq);
    }

    await prefs.setBool('$_migratedPrefix$resolvedHouseId', true);
    await prefs.remove(_legacyKey);
    await prefs.remove(_legacySeqKey);
  }

  String exportAsTxt(List<ActivityHistoryEntry> list) {
    final lines = list.asMap().entries.map((e) {
      final idx = (e.key + 1).toString().padLeft(3, '0');
      final time = DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(e.value.ts));
      return '$idx. $time • ${e.value.displayLine}';
    }).toList();
    return lines.join('\n');
  }

  String exportAsHtml(List<ActivityHistoryEntry> list) {
    final rows = list.asMap().entries.map((e) {
      final idx = (e.key + 1).toString().padLeft(3, '0');
      final time = DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(e.value.ts));
      final line = '$idx. $time • ${e.value.displayLine}';
      return '<div class="row">$line</div>';
    }).join('');

    return '''<!doctype html><html lang="vi"><head><meta charset="utf-8">
<title>Lịch sử hoạt động</title>
<style>
  body{font-family:Arial,sans-serif;padding:16px;background:#fff}
  h1{font-size:18px;margin-bottom:10px}
  .row{padding:6px 0;border-bottom:1px dashed #eee;font-size:13px;line-height:1.5}
</style></head><body>
<h1>Lịch sử hoạt động</h1>
<div class="meta">${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} • ${list.length}/$_max</div>
$rows
</body></html>''';
  }

  Future<List<ActivityHistoryEntry>> _loadRemote(String houseId) async {
    final snapshot = await _db.ref('houses/$houseId/activity_history').get();
    if (!snapshot.exists || snapshot.value == null) {
      return const <ActivityHistoryEntry>[];
    }

    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return _normalizeEntries(
      raw.entries.map((entry) {
        final map = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        map['id'] ??= entry.key.toString();
        map['houseId'] ??= houseId;
        map['syncStatus'] = 'synced';
        return ActivityHistoryEntry.fromJson(map);
      }).toList(),
    );
  }

  Future<List<ActivityHistoryEntry>> _loadCache(String houseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(houseId));
      if (raw == null || raw.isEmpty) {
        return const <ActivityHistoryEntry>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return _normalizeEntries(
        list
            .whereType<Map>()
            .map((item) => ActivityHistoryEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
      );
    } catch (_) {
      return const <ActivityHistoryEntry>[];
    }
  }

  Future<List<ActivityHistoryEntry>> _loadLegacyLocalEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
    List<ActivityHistoryEntry> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(houseId),
      jsonEncode(
        _normalizeEntries(list).map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  Future<List<ActivityHistoryEntry>> _appendCache(
    String houseId,
    ActivityHistoryEntry entry, {
    bool replaceExisting = false,
  }) async {
    final existing = await _loadCache(houseId);
    final merged = <ActivityHistoryEntry>[
      if (!replaceExisting) entry,
      ...existing,
      if (replaceExisting) entry,
    ];
    final normalized = _normalizeEntries(merged);
    await _saveCache(houseId, normalized);
    return normalized;
  }

  Future<void> _appendLegacyLocal(ActivityHistoryEntry entry) async {
    final list = await _loadLegacyLocalEntries();
    final merged = _normalizeEntries([...list, entry]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _legacyKey,
      jsonEncode(merged.map((item) => item.toJson()).toList()),
    );
    await prefs.setInt(_legacySeqKey, entry.seq);
  }

  List<ActivityHistoryEntry> _normalizeEntries(
      List<ActivityHistoryEntry> list) {
    final byId = <String, ActivityHistoryEntry>{};
    for (final entry in list) {
      final resolvedId = entry.id.isNotEmpty
          ? entry.id
          : '${entry.ts}_${entry.seq}_${entry.role}';
      byId[resolvedId] = entry.copyWith(id: resolvedId);
    }

    final values = byId.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    if (values.length > _max) {
      return values.sublist(values.length - _max);
    }
    return values;
  }

  Future<void> _trimRemote(String houseId) async {
    try {
      final snapshot = await _db.ref('houses/$houseId/activity_history').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final list = raw.entries.where((entry) => entry.value is Map).map((entry) {
        final map = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        map['id'] ??= entry.key.toString();
        map['houseId'] ??= houseId;
        return ActivityHistoryEntry.fromJson(map);
      }).toList()
        ..sort((a, b) => a.ts.compareTo(b.ts));

      if (list.length <= _max) return;
      final overflow = list.take(list.length - _max).toList();
      final updates = <String, dynamic>{};
      for (final entry in overflow) {
        updates[entry.id] = null;
      }
      if (updates.isNotEmpty) {
        await _db.ref('houses/$houseId/activity_history').update(updates);
      }
    } catch (e) {
      debugPrint('ActivityHistory trim failed: $e');
    }
  }

  Future<String?> _resolveHouseId(String? houseId) async {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final resolved = await _houseService.getCurrentHouseId(preferFresh: true);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }

    final prefs = await SharedPreferences.getInstance();
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
    } catch (_) {}
    return null;
  }

  Future<int> _nextSeq(String? houseId) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        houseId == null || houseId.isEmpty ? _legacySeqKey : _seqKey(houseId);
    int next = prefs.getInt(key) ?? 0;
    next = (next + 1) > 100000 ? 1 : next + 1;
    await prefs.setInt(key, next);
    return next;
  }

  String _cacheKey(String houseId) => '$_cachePrefix$houseId';
  String _seqKey(String houseId) => '$_seqPrefix$houseId';
  DatabaseReference _entryRef(String houseId, String entryId) =>
      _db.ref('houses/$houseId/activity_history/$entryId');
}
