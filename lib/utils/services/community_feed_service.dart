import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class CommunityFeedService {
  static final CommunityFeedService _instance =
      CommunityFeedService._internal();
  factory CommunityFeedService() => _instance;
  CommunityFeedService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Database? _localCache;
  final LinkedHashSet<String> _resolvedMediaUrls = LinkedHashSet<String>();
  final Set<String> _pendingMediaUrls = <String>{};
  Timer? _preloadDebounce;

  static const Duration _preloadDebounceDelay = Duration(milliseconds: 250);
  static const int _maxTrackedResolvedUrls = 400;
  static const int _visibleItemsPreload = 5;
  static const int _defaultFeedPageSize = 10;
  static const int _maxFeedPageSize = 15;

  Future<void> initCache() async {
    final path = join(await getDatabasesPath(), 'love_feed_cache.db');
    _localCache = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cached_posts (
            id TEXT PRIMARY KEY,
            content TEXT,
            avatarUrl TEXT,
            imageUrl TEXT,
            hearts INTEGER,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadOfflineFeedFirst() async {
    if (_localCache == null) return const <Map<String, dynamic>>[];

    try {
      return await _localCache!.query(
        'cached_posts',
        orderBy: 'timestamp DESC',
        limit: 20,
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Stream<List<Map<dynamic, dynamic>>> listenToFeed({
    String feedType = 'global',
    int pageSize = _defaultFeedPageSize,
    int? afterTimestamp,
    int? endBeforeTimestamp,
    bool isActive = true,
    bool attachRealtime = true,
  }) {
    if (!isActive) {
      return const Stream<List<Map<dynamic, dynamic>>>.empty();
    }

    final query = _buildFeedQuery(
      pageSize: pageSize,
      afterTimestamp: afterTimestamp,
      endBeforeTimestamp: endBeforeTimestamp,
    );

    if (!attachRealtime || endBeforeTimestamp != null) {
      return query.get().asStream().map(
            (snapshot) => _mapFeedSnapshot(
              snapshot,
              feedType: feedType,
            ),
          );
    }

    return query.onValue.map(
      (event) => _mapFeedSnapshot(
        event.snapshot,
        feedType: feedType,
      ),
    );
  }

  Future<List<Map<dynamic, dynamic>>> fetchFeedPage({
    String feedType = 'global',
    int pageSize = _defaultFeedPageSize,
    int? endBeforeTimestamp,
  }) async {
    final snapshot = await _buildFeedQuery(
      pageSize: pageSize,
      endBeforeTimestamp: endBeforeTimestamp,
    ).get();
    return _mapFeedSnapshot(snapshot, feedType: feedType);
  }

  Query _buildFeedQuery({
    required int pageSize,
    int? afterTimestamp,
    int? endBeforeTimestamp,
  }) {
    final safePageSize = pageSize.clamp(1, _maxFeedPageSize).toInt();
    Query query = _db.ref('social_feed').orderByChild('ts');

    if (afterTimestamp != null) {
      query = query.startAt(afterTimestamp + 1);
    }

    if (endBeforeTimestamp != null) {
      query = query.endAt(endBeforeTimestamp - 1);
    }

    return query.limitToLast(safePageSize);
  }

  List<Map<dynamic, dynamic>> _mapFeedSnapshot(
    DataSnapshot snapshot, {
    required String feedType,
  }) {
    if (!snapshot.exists || snapshot.value == null) {
      return const <Map<dynamic, dynamic>>[];
    }

    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final feedItems = <Map<dynamic, dynamic>>[];

    raw.forEach((key, value) {
      if (value is! Map) return;

      final item = Map<String, dynamic>.from(value);
      item['id'] = key;
      feedItems.add(item);
      _cacheSinglePost(item);
    });

    if (feedType == 'tophot') {
      feedItems.sort((a, b) {
        final heartsA = (a['hearts'] as num?)?.toInt() ?? 0;
        final heartsB = (b['hearts'] as num?)?.toInt() ?? 0;
        if (heartsA != heartsB) {
          return heartsB.compareTo(heartsA);
        }

        final timeA = (a['timestamp'] as num?)?.toInt() ?? 0;
        final timeB = (b['timestamp'] as num?)?.toInt() ?? 0;
        return timeB.compareTo(timeA);
      });
    } else {
      feedItems.sort((a, b) {
        final timeA = (a['timestamp'] as num?)?.toInt() ?? 0;
        final timeB = (b['timestamp'] as num?)?.toInt() ?? 0;
        return timeB.compareTo(timeA);
      });
    }

    _preloadFeedImages(feedItems);
    return feedItems;
  }

  void _preloadFeedImages(List<Map<dynamic, dynamic>> items) {
    final visibleCount = _visibleItemsPreload.clamp(3, 8);
    final visibleItems = items.take(visibleCount).toList(growable: false);

    for (final item in visibleItems) {
      _queueFeedItemMediaForPreload(item);
    }

    if (_pendingMediaUrls.isEmpty) {
      return;
    }

    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(_preloadDebounceDelay, _flushPendingPreloads);
  }

  void preloadMoreImages(int startIndex, List<Map<dynamic, dynamic>> allItems) {
    final endIndex =
        (startIndex + _visibleItemsPreload).clamp(0, allItems.length);
    final itemsToPreload = allItems.sublist(startIndex, endIndex);

    for (final item in itemsToPreload) {
      _queueFeedItemMediaForPreload(item);
    }

    if (_pendingMediaUrls.isEmpty) {
      return;
    }

    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(_preloadDebounceDelay, _flushPendingPreloads);
  }

  void _queueFeedItemMediaForPreload(Map<dynamic, dynamic> item) {
    _queueMediaForPreload(item['avatarUrl']);
    _queueMediaForPreload(item['authorAvt']);
    _queueMediaForPreload(item['houseAvt']);
    _queueMediaForPreload(item['imageUrl']);
    _queueMediaForPreload(item['thumbUrl']);
    _queueMediaForPreload(item['thumbnailUrl']);
    _queueMediaForPreload(item['livePhotoUrl']);
  }

  void _queueMediaForPreload(dynamic rawUrl) {
    final url = rawUrl?.toString().trim() ?? '';
    if (url.isEmpty || !url.startsWith('http')) {
      return;
    }
    if (_resolvedMediaUrls.contains(url) || _pendingMediaUrls.contains(url)) {
      return;
    }
    _pendingMediaUrls.add(url);
  }

  void _flushPendingPreloads() {
    if (_pendingMediaUrls.isEmpty) {
      return;
    }

    final urls = List<String>.from(_pendingMediaUrls);
    _pendingMediaUrls.clear();

    for (final url in urls) {
      final provider = CachedNetworkImageProvider(url);
      provider.resolve(const ImageConfiguration());
      _resolvedMediaUrls.add(url);
    }

    while (_resolvedMediaUrls.length > _maxTrackedResolvedUrls) {
      _resolvedMediaUrls.remove(_resolvedMediaUrls.first);
    }
  }

  Future<void> _cacheSinglePost(Map<String, dynamic> post) async {
    if (_localCache == null) return;

    try {
      await _localCache!.insert(
        'cached_posts',
        <String, Object?>{
          'id': post['id'],
          'content': post['content'] ?? '',
          'avatarUrl': post['avatarUrl'] ?? '',
          'imageUrl': post['imageUrl'] ?? '',
          'hearts': post['hearts'] ?? 0,
          'timestamp': post['timestamp'] ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Cache Post Failed: $e');
    }
  }

  Future<void> sendHeartToPost(String postId) async {
    final ref = _db.ref('community_posts/$postId/hearts');
    await ref.set(ServerValue.increment(1));
  }
}
