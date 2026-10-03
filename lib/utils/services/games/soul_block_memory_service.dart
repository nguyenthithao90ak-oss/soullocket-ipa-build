import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_error_mapper.dart';

import '../../../views/home/tabs/diary/utils/diary_memory_media.dart';
import '../../../views/home/tabs/diary/utils/private_memory_link_policy.dart';
import '../private_media_url_service.dart';
import 'soul_block_image_cache.dart';

class SoulBlockMemory {
  const SoulBlockMemory({required this.id, required this.url});
  final String id;
  final String url;
}

class SoulBlockPhoto {
  const SoulBlockPhoto({required this.id, required this.image});
  final String id;
  final ui.Image image;
}

class _SoulCandidateCache {
  _SoulCandidateCache(this.items) : age = Stopwatch()..start();
  final List<Map<String, dynamic>> items;
  final Stopwatch age;
}

/// Chỉ lấy ảnh trong Nhật ký của ngôi nhà hiện tại; không lưu URL đã ký.
class SoulBlockMemoryService {
  final _urls = PrivateMediaUrlService(cacheCompletedUrls: true);
  static final _candidateCache = <String, _SoulCandidateCache>{};
  static final _candidateLoads = <String, Future<List<Map<String, dynamic>>>>{};
  final _random = Random();
  Future<void> _historyWrite = Future<void>.value();

  String _historyKey(String uid, String houseId) =>
      'soul_block_photo_history_v1:${jsonEncode([uid, houseId])}';

  Future<List<Map<String, dynamic>>> candidates(
    String houseId, {
    String? preferredId,
    bool next = false,
    int diaryWidth = 640,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || houseId.trim().isEmpty) return const [];
    final key = jsonEncode([uid, houseId]);
    final cached = _candidateCache[key];
    final items =
        cached != null && cached.age.elapsed < const Duration(minutes: 3)
        ? cached.items.map(Map<String, dynamic>.from).toList()
        : await _readCandidates(uid, houseId, key);
    if (FirebaseAuth.instance.currentUser?.uid != uid) return const [];
    // Ván đang lưu giữ đúng ảnh, kể cả ảnh đã nằm ngoài 80 nhật ký mới nhất.
    if (!next &&
        preferredId != null &&
        !items.any((item) => item['id'] == preferredId)) {
      try {
        final saved = await FirebaseDatabase.instance
            .ref('houses/$houseId/memories/$preferredId')
            .get()
            .timeout(const Duration(seconds: 8));
        final data = _photoCandidate(preferredId, saved.value);
        if (data != null) items.add(data);
      } catch (error) {
        debugPrint(AppErrorMapper.resolve(error).message);
      }
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) return const [];
    items.shuffle(_random);
    await _historyWrite;
    final prefs = await SharedPreferences.getInstance();
    final recent =
        prefs.getStringList(_historyKey(uid, houseId)) ?? const <String>[];
    final cachedIds = await SoulBlockImageCache.instance.cachedIds(
      uid: uid,
      houseId: houseId,
      ids: items.map((item) => item['id'] as String),
      diaryWidth: diaryWidth,
    );
    if (FirebaseAuth.instance.currentUser?.uid != uid) return const [];
    final shuffledOrder = <String, int>{
      for (var i = 0; i < items.length; i++) items[i]['id'] as String: i,
    };
    int rank(Map<String, dynamic> item) {
      final id = item['id'] as String;
      if (id == preferredId) return next ? 1000 : -1;
      final index = recent.indexOf(id);
      return index < 0 ? 0 : recent.length - index;
    }

    items.sort((a, b) {
      final order = rank(a).compareTo(rank(b));
      if (order != 0) return order;
      final aCached = cachedIds.contains(a['id']) ? 0 : 1;
      final bCached = cachedIds.contains(b['id']) ? 0 : 1;
      return aCached != bCached
          ? aCached.compareTo(bCached)
          : shuffledOrder[a['id']]!.compareTo(shuffledOrder[b['id']]!);
    });
    return items;
  }

  Future<List<Map<String, dynamic>>> _readCandidates(
    String uid,
    String houseId,
    String key,
  ) async {
    final pending = _candidateLoads.putIfAbsent(key, () async {
      final snapshot = await FirebaseDatabase.instance
          .ref('houses/$houseId/memories')
          .orderByChild('ts')
          .limitToLast(80)
          .get()
          .timeout(const Duration(seconds: 12));
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        return <Map<String, dynamic>>[];
      }
      final items = <Map<String, dynamic>>[];
      final raw = snapshot.value;
      if (raw is Map) {
        for (final entry in raw.entries) {
          final data = _photoCandidate(entry.key.toString(), entry.value);
          if (data != null) {
            items.add(
              PrivateMemoryLinkPolicy.isPrivate(data)
                  ? PrivateMemoryLinkPolicy.offlineMetadata(data)
                  : data,
            );
          }
        }
      }
      _candidateCache[key] = _SoulCandidateCache(items);
      while (_candidateCache.length > 2) {
        _candidateCache.remove(_candidateCache.keys.first);
      }
      return items;
    });
    try {
      return (await pending).map(Map<String, dynamic>.from).toList();
    } catch (_) {
      final stale = _candidateCache[key];
      if (stale != null && FirebaseAuth.instance.currentUser?.uid == uid) {
        return stale.items.map(Map<String, dynamic>.from).toList();
      }
      rethrow;
    } finally {
      if (identical(_candidateLoads[key], pending)) _candidateLoads.remove(key);
    }
  }

  Future<SoulBlockPhoto?> loadPhoto(
    String houseId,
    Map<String, dynamic> data, {
    int diaryWidth = 640,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = data['id'] as String;
    final image = await SoulBlockImageCache.instance.load(
      uid: uid,
      houseId: houseId,
      id: id,
      diaryWidth: diaryWidth,
      resolveUrl: () async => (await resolve(houseId, data))?.url,
    );
    return image == null ? null : SoulBlockPhoto(id: id, image: image);
  }

  Map<String, dynamic>? _photoCandidate(String id, Object? raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw)..['id'] = id;
    if (isDiaryMemoryVideo(Map<Object?, Object?>.from(data)) ||
        data['deletedAt'] != null ||
        data['isDeleted'] == true) {
      return null;
    }
    if (!PrivateMemoryLinkPolicy.isPrivate(data) &&
        _publicPhotoUrl(data) == null) {
      return null;
    }
    return data;
  }

  String? _publicPhotoUrl(Map<String, dynamic> data) {
    final candidates = [
      resolveDiaryMemoryMediaUrl(Map<Object?, Object?>.from(data)),
      data['imageUrl']?.toString(),
      data['photoUrl']?.toString(),
    ];
    for (final raw in candidates) {
      final url = raw?.trim();
      final uri = Uri.tryParse(url ?? '');
      if (uri != null &&
          const ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          !isDiaryMemoryVideoUrl(url)) {
        return url;
      }
    }
    return null;
  }

  Future<void> remember(String houseId, String id, {required String uid}) {
    _historyWrite = _historyWrite.then((_) async {
      try {
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        final prefs = await SharedPreferences.getInstance();
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        final key = _historyKey(uid, houseId);
        final recent = prefs.getStringList(key) ?? <String>[];
        await prefs.setStringList(
          key,
          [id, ...recent.where((previous) => previous != id)].take(80).toList(),
        );
      } catch (error) {
        debugPrint(AppErrorMapper.resolve(error).message);
      }
    });
    return _historyWrite;
  }

  Future<SoulBlockMemory?> resolve(
    String houseId,
    Map<String, dynamic> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = data['id'] as String;
    String? url;
    if (PrivateMemoryLinkPolicy.isPrivate(data)) {
      url = (await _urls.resolve(
        houseId: houseId,
        mediaId: id,
        kind: 'memory_image',
      )).url;
    } else {
      url = _publicPhotoUrl(data);
    }
    final uri = Uri.tryParse(url ?? '');
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        isDiaryMemoryVideoUrl(url)) {
      return null;
    }
    return SoulBlockMemory(id: id, url: url!);
  }

  void dispose() => _urls.dispose();
}
