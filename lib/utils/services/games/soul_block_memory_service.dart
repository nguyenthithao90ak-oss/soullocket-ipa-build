import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_error_mapper.dart';

import '../../../views/home/tabs/diary/utils/diary_memory_media.dart';
import '../../../views/home/tabs/diary/utils/private_memory_link_policy.dart';
import '../private_media_url_service.dart';

class SoulBlockMemory {
  const SoulBlockMemory({required this.id, required this.url});
  final String id;
  final String url;
}

/// Chỉ lấy ảnh trong Nhật ký của ngôi nhà hiện tại; không lưu URL đã ký.
class SoulBlockMemoryService {
  final _urls = PrivateMediaUrlService();
  final _random = Random();
  Future<void> _historyWrite = Future<void>.value();

  String _historyKey(String uid, String houseId) =>
      'soul_block_photo_history_v1:${jsonEncode([uid, houseId])}';

  Future<List<Map<String, dynamic>>> candidates(
    String houseId, {
    String? preferredId,
    bool next = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || houseId.trim().isEmpty) return const [];
    final snapshot = await FirebaseDatabase.instance
        .ref('houses/$houseId/memories')
        .orderByChild('ts')
        .limitToLast(80)
        .get()
        .timeout(const Duration(seconds: 12));
    if (FirebaseAuth.instance.currentUser?.uid != uid) return const [];
    final raw = snapshot.value;
    if (raw is! Map) return const [];
    final source = Map<dynamic, dynamic>.from(raw);
    final items = <Map<String, dynamic>>[];
    for (final entry in source.entries) {
      if (entry.value is! Map) continue;
      final data = _photoCandidate(entry.key.toString(), entry.value);
      if (data != null) items.add(data);
    }
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
      return order != 0
          ? order
          : shuffledOrder[a['id']]!.compareTo(shuffledOrder[b['id']]!);
    });
    return items;
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
