part of 'community_tab.dart';
// ignore_for_file: dead_code

extension _CommunityTabFeedLogic on _CommunityTabState {
  static const String _communityUsageWindowStartPrefsKey =
      'community_usage_window_start_ms_v1';
  static const String _communityUsageAccumulatedPrefsKey =
      'community_usage_accumulated_ms_v1';
  static const int _communityAdThresholdMs = 60 * 60 * 1000;
  static const int _communityUsageWindowMs = 24 * 60 * 60 * 1000;

  void _listenToCommunityMaintenance() {
    final maintenanceFallback = _ct(
      context.tr('home_tnhnngmngx_a56b2f'),
      'The community feature is temporarily closed for an upgrade.',
    );
    final errorFallback = context.tr('home_khngthtitr_091925');

    _communityMaintenanceSub?.cancel();
    _communityMaintenanceSub = _dbRef.child('sys_settings').onValue.listen(
      (event) {
        final settings = event.snapshot.value;
        final map = settings is Map
            ? settings.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{};
        final fallbackMessage = maintenanceFallback;
        final nextMaintenance = map['community_maintenance_mode'] == true;
        final nextMessage =
            map['community_maintenance_msg']?.toString().trim() ?? '';
        final nextEta =
            map['community_maintenance_eta']?.toString().trim() ?? '';
        final hasChanges = _isCommunityMaintenance != nextMaintenance ||
            _communityMaintenanceMsg !=
                (nextMessage.isNotEmpty ? nextMessage : fallbackMessage) ||
            _communityMaintenanceEta != nextEta;

        if (!hasChanges) {
          _syncRealtimeFeedSubscription();
          return;
        }

        _updateState(() {
          _isCommunityMaintenance = nextMaintenance;
          _communityMaintenanceMsg =
              nextMessage.isNotEmpty ? nextMessage : fallbackMessage;
          _communityMaintenanceEta = nextEta;
        });
        _syncRealtimeFeedSubscription();
      },
      onError: (Object error) {
        debugPrint(
          'Community maintenance listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: errorFallback,
          ).message}',
        );
      },
    );
    _loadBannedWords();
  }

  Future<void> _loadBannedWords() async {
    try {
      final snap = await _dbRef.child('admin_system/banned_words').get();
      if (!snap.exists || snap.value is! List) return;
      final list = (snap.value as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isEmpty) return;
      _blockedCommunityTerms = list;
    } catch (_) {}
  }

  bool _shouldListenForLatestFeed() {
    if (_isCommunityMaintenance) return false;
    return _currentFeedType != 'mine';
  }

  Future<int> _readCommunityUsageAccumulatedMs() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowStartMs =
        prefs.getInt(_communityUsageWindowStartPrefsKey) ?? nowMs;
    if (nowMs - windowStartMs >= _communityUsageWindowMs) {
      await prefs.setInt(_communityUsageWindowStartPrefsKey, nowMs);
      await prefs.setInt(_communityUsageAccumulatedPrefsKey, 0);
      return 0;
    }
    return prefs.getInt(_communityUsageAccumulatedPrefsKey) ?? 0;
  }

  Future<void> _persistCommunityUsageSession() async {
    final startedAt = _communityUsageStartedAt;
    if (startedAt == null) return;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowStartMs =
        prefs.getInt(_communityUsageWindowStartPrefsKey) ?? nowMs;
    if (nowMs - windowStartMs >= _communityUsageWindowMs) {
      await prefs.setInt(_communityUsageWindowStartPrefsKey, nowMs);
      await prefs.setInt(_communityUsageAccumulatedPrefsKey, 0);
    }
    final current = prefs.getInt(_communityUsageAccumulatedPrefsKey) ?? 0;
    final elapsed = nowMs - startedAt.millisecondsSinceEpoch;
    await prefs.setInt(
      _communityUsageAccumulatedPrefsKey,
      current + math.max(elapsed, 0),
    );
    _communityUsageStartedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
  }

  Future<void> _resetCommunityUsageWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_communityUsageWindowStartPrefsKey, nowMs);
    await prefs.setInt(_communityUsageAccumulatedPrefsKey, 0);
    _communityUsageStartedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
  }

  void _startAdLogic() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isPro = await _adMob.isProUser();
      if (isPro) return;
      _communityUsageStartedAt = DateTime.now();
      final accumulatedMs = await _readCommunityUsageAccumulatedMs();
      final remainingMs = math.max(0, _communityAdThresholdMs - accumulatedMs);
      _sessionTimer?.cancel();
      _sessionTimer = Timer(Duration(milliseconds: remainingMs), () async {
        final proCheck = await _adMob.isProUser();
        if (proCheck || !mounted) return;
        await _handleTimedCommunityInterruption();
      });
    });
  }

  Future<void> _handleTimedCommunityInterruption() async {
    if (!mounted || _isCheckingAd) return;
    await _persistCommunityUsageSession();
    final accumulatedMs = await _readCommunityUsageAccumulatedMs();
    if (accumulatedMs < _communityAdThresholdMs) {
      _startAdLogic();
      return;
    }

    final showedImageCard = await _showRandomCommunityBreakCard();
    if (!mounted) return;
    if (showedImageCard) {
      _startAdLogic();
      return;
    }

    await _showForcedRewardedAdNoPrompt();
  }

  DateTime? _communityAnniversaryDate() {
    final raw = _houseSettings['startDate']?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  bool _isCommunityAnniversaryToday(DateTime today, DateTime anniversaryDate) {
    return today.year > anniversaryDate.year &&
        today.month == anniversaryDate.month &&
        today.day == anniversaryDate.day;
  }

  String _communityAnniversaryMemorySeenKey({
    required String houseId,
    required DateTime anniversaryDate,
    required int year,
  }) {
    return '${_communityAnniversaryMemoryShownPrefsKey}_${houseId}_${anniversaryDate.month}_${anniversaryDate.day}_$year';
  }

  int _communityMemoryTimestamp(Map<String, dynamic> memory) {
    final ts = memory['ts'];
    final timestamp = memory['timestamp'];
    final date = memory['date'];
    if (ts is int) return ts;
    if (timestamp is int) return timestamp;
    if (date is int) return date;
    if (ts is num) return ts.toInt();
    if (timestamp is num) return timestamp.toInt();
    if (date is num) return date.toInt();
    return 0;
  }

  void _collectAnniversaryMemoryCandidates(
    List<Map<String, dynamic>> out,
    Object? rawSource, {
    required DateTime anniversaryDate,
    required DateTime today,
  }) {
    if (rawSource is Map) {
      final source = Map<dynamic, dynamic>.from(rawSource);
      source.forEach((key, value) {
        if (value is! Map) {
          return;
        }
        final memory =
            Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
        memory['id'] = key.toString();
        final imageUrl = (memory['url'] ?? '').toString().trim();
        if (imageUrl.isEmpty) {
          return;
        }
        final timestamp = _communityMemoryTimestamp(memory);
        if (timestamp <= 0) {
          return;
        }
        final memoryDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (memoryDate.year >= today.year ||
            memoryDate.month != anniversaryDate.month ||
            memoryDate.day != anniversaryDate.day) {
          return;
        }
        out.add(memory);
      });
      return;
    }

    if (rawSource is List) {
      for (final value in rawSource) {
        if (value is! Map) {
          continue;
        }
        final memory = Map<String, dynamic>.from(value);
        final imageUrl = (memory['url'] ?? '').toString().trim();
        if (imageUrl.isEmpty) {
          continue;
        }
        final timestamp = _communityMemoryTimestamp(memory);
        if (timestamp <= 0) {
          continue;
        }
        final memoryDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (memoryDate.year >= today.year ||
            memoryDate.month != anniversaryDate.month ||
            memoryDate.day != anniversaryDate.day) {
          continue;
        }
        out.add(memory);
      }
    }
  }

  Future<Map<String, dynamic>?> _pickRandomCommunityBreakPost() async {
    final anniversaryMsg = context.tr('home_ngngynynmt_16b9cc');
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) {
      return null;
    }

    final anniversaryDate = _communityAnniversaryDate();
    if (anniversaryDate == null) {
      return null;
    }

    final today = DateTime.now();
    if (!_isCommunityAnniversaryToday(today, anniversaryDate)) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenKey = _communityAnniversaryMemorySeenKey(
      houseId: houseId,
      anniversaryDate: anniversaryDate,
      year: today.year,
    );
    if (prefs.getBool(seenKey) == true) {
      return null;
    }

    final candidates = <Map<String, dynamic>>[];
    try {
      final snap = await _dbRef.child('houses/$houseId/memories').get();
      _collectAnniversaryMemoryCandidates(
        candidates,
        snap.value,
        anniversaryDate: anniversaryDate,
        today: today,
      );
    } catch (_) {}

    if (candidates.isEmpty) {
      final cached = OfflineCacheService.loadCacheSync('memories_$houseId');
      _collectAnniversaryMemoryCandidates(
        candidates,
        cached,
        anniversaryDate: anniversaryDate,
        today: today,
      );
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort(
      (a, b) => _communityMemoryTimestamp(b).compareTo(
        _communityMemoryTimestamp(a),
      ),
    );

    final memory = candidates.first;
    final timestamp = _communityMemoryTimestamp(memory);
    final memoryDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final yearsAgo = today.year - memoryDate.year;
    final authorName =
        (memory['authorName']?.toString().trim().isNotEmpty ?? false)
            ? memory['authorName'].toString().trim()
            : (memory['author']?.toString().trim().isNotEmpty ?? false)
                ? memory['author'].toString().trim()
                : _defaultHouseName;

    return <String, dynamic>{
      'id': memory['id'] ?? 'anniversary_$timestamp',
      'imageUrl': (memory['url'] ?? '').toString().trim(),
      'ts': timestamp,
      'timestamp': timestamp,
      'houseName': authorName,
      'isAnon': false,
      'isDeletedAuthor': false,
      'content': yearsAgo <= 1
          ? _ct(
              anniversaryMsg,
              'On this exact day last year, you saved this memory in your diary.',
            )
          : _ct(
              L10nService().format('home_memory_years_ago', {'years': yearsAgo}),
              'On this exact day $yearsAgo years ago, you saved this memory in your diary.',
            ),
    };
  }

  Future<bool> _showRandomCommunityBreakCard() async {
    if (!mounted) return false;

    final post = await _pickRandomCommunityBreakPost();
    if (!mounted || post == null) {
      return false;
    }

    final imageUrl = (post['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isEmpty) {
      return false;
    }

    final isAnon =
        (post['isAnon'] == true) || (post['isAnon']?.toString() == 'true');
    final isDeletedAuthor = post['isDeletedAuthor'] == true ||
        (post['isDeletedAuthor']?.toString() == 'true') ||
        (post['houseId'] ?? '').toString().trim().isEmpty;
    final authorName = isDeletedAuthor
        ? _ct(context.tr('home_khonhkhccl_6f79f9'), 'Saved moment')
        : isAnon
            ? _ct(context.tr('home_khonhkhcnd_f34507'), 'Anonymous moment')
            : (post['houseName']?.toString().trim().isNotEmpty ?? false)
                ? post['houseName'].toString().trim()
                : _defaultHouseName;
    final previewText = _sanitizedPostContent(post).trim();
    final helperText = previewText.isNotEmpty
        ? previewText
        : _ct(
            context.tr('home_dngmtvigiy_87a237'),
            'Pause for a few seconds with a cute photo from the community.',
          );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final dialogWidth =
            (screenWidth > 440 ? 388.0 : screenWidth - 28).clamp(280.0, 388.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth.toDouble()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFEFF),
                    Color(0xFFF6F8FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 1.35,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111827).withValues(alpha: 0.16),
                    blurRadius: 34,
                    spreadRadius: -12,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ct(
                                context.tr('home_knimhmnayc_d3f63f'),
                                'Your anniversary memory today',
                              ),
                              style: SLTheme.quicksand(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF172033),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$authorName • ${_formattedPostDate(post)}',
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF687387),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        splashRadius: 20,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF596579),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    height: 320,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ColoredBox(
                        color: const Color(0xFFF4F6FB),
                        child: ManualRetryCachedImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          backgroundColor: const Color(0xFFF4F6FB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    helperText,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 13.4,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC5A7B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _ct(context.tr('home_tiptclt_7afbbc'), 'Continue browsing'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final anniversaryDate = _communityAnniversaryDate();
    final houseId = (_houseId ?? '').trim();
    if (anniversaryDate != null && houseId.isNotEmpty) {
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      final seenKey = _communityAnniversaryMemorySeenKey(
        houseId: houseId,
        anniversaryDate: anniversaryDate,
        year: DateTime.now().year,
      );
      await prefs.setBool(seenKey, true);
    }

    return true;
  }

  Future<void> _showForcedRewardedAdNoPrompt() async {
    if (!mounted) return;

    _updateState(() => _isCheckingAd = true);
    final worked = await _adMob.showRewardedAd();
    if (!mounted) return;

    _updateState(() => _isCheckingAd = false);

    if (!worked) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _ct(
              context.tr('home_qungcochas_1bacaa'),
              'The ad was not ready or was dismissed. It will try again later.',
            ),
          ),
        ),
      );
      _startAdLogic();
      return;
    }

    _CommunityTabState._adShowCount++;
    await _resetCommunityUsageWindow();
    _startAdLogic();
  }

  Future<void> _init() async {
    if (!widget.isActive) return;

    _cancelFeedFilterSubscriptions();
    _updateState(() {
      _isLoading = true;
      _currentLimit = _CommunityTabState._feedPageSize;
      _hasMoreFeed = true;
      _isLoadingMoreFeed = false;
      _oldestLoadedTs = null;
      _allPosts = [];
      _feedIndexById.clear();
      _postFormattedDateCache.clear();
      _postSanitizedTextCache.clear();
      _lastFeedPreloadStartIndex = -1;
      _feedRevision++;
      _filteredPostsCache = null;
      _filteredPostsCacheKey = null;
      _likeSyncHoldUntilByPostId.clear();
      _friendsRevision = 0;
      _blockedUsersRevision = 0;
      _hiddenPostsRevision = 0;
    });

    // Tải từ cache trước để hiển thị ngay lập tức (giống Facebook)
    final cachedData =
        await OfflineCacheService.loadCache('community_unified_feed');
    if (cachedData != null && mounted) {
      final cachedPosts = List<Map<String, dynamic>>.from(cachedData as List);
      cachedPosts.sort((a, b) => _getTimestamp(b).compareTo(_getTimestamp(a)));
      _updateState(() {
        _replaceAllPosts(cachedPosts);
        _oldestLoadedTs =
            cachedPosts.isEmpty ? null : _getTimestamp(cachedPosts.last);
        _isLoading = false; // Hiện cache ngay
      });
    }

    try {
      final maintenanceSnap = await _dbRef
          .child('sys_settings/community_maintenance_mode')
          .get()
          .timeout(const Duration(seconds: 3));
      final isMaintenance = maintenanceSnap.value == true;
      if (isMaintenance) {
        /*
        _updateState(() {
          _isCommunityMaintenance = true;
          _communityMaintenanceMsg = msgSnap.value?.toString() ?? '';
          _communityMaintenanceEta = etaSnap.value?.toString() ?? '';
          _isLoading = false;
        });
        return;
        */
        _isCommunityMaintenance = false;
      } else {
        _isCommunityMaintenance = false;
      }
    } catch (_) {}

    await _loadBookmarks();
    await _loadHiddenPosts();

    final user = _auth.currentUser;
    if (user == null) {
      _updateState(() => _isLoading = false);
      return;
    }

    final houseId = await _houseService.getCurrentHouseId();
    _houseId = houseId;

    if (houseId != null && houseId.isNotEmpty) {
      // Auto migrate old RTDB social posts and comments to Firestore in the background
      unawaited(_socialService.migrateSocialFeedFromRTDB(houseId));

      final settings = await _houseService.getHouseSettings(houseId);
      if (settings != null) {
        _houseSettings = settings;
        _houseName =
            (settings['houseName']?.toString().trim().isNotEmpty ?? false)
                ? settings['houseName'].toString()
                : _defaultHouseName;
        _houseAvatar = settings['houseAvatar']?.toString() ??
            settings['avtUser1']?.toString() ??
            '';
      }
      if (widget.isActive) {
        _subscribeToRealtimeData();
      }
    } else {
      _communityMessengerPreviewSubscription?.cancel();
      _updateState(() {
        _friends = const <String, dynamic>{};
        _blockedUsers = const <String, dynamic>{};
        _sentFriendRequestIds = const <String, String>{};
        _receivedFriendRequestIds = const <String, String>{};
        _communityMessengerUnreadCount = 0;
        _communityMessengerPreviewText = '';
        _friendsRevision++;
        _blockedUsersRevision++;
        _friendRequestsRevision++;
        _invalidateFilteredPostsCache();
      });
    }

    if (_houseName.trim().isEmpty) {
      _houseName = _defaultHouseName;
    }

    unawaited(_promptPendingCommunityUploadRetryIfNeeded());
    await _loadFeed(reset: true);
  }

  Future<void> _loadFeed({required bool reset}) async {
    if (reset) {
      _feedSub?.cancel();
      _updateState(() {
        _isLoading = true;
        _isLoadingMoreFeed = false;
        _hasMoreFeed = true;
        _oldestLoadedTs = null;
        _currentLimit = _CommunityTabState._feedPageSize;
        if (_allPosts.isEmpty) {
          _allPosts = [];
        }
      });
      _syncRealtimeFeedSubscription(forceRestart: true);
      await _loadMoreFeed(reset: true);
      return;
    }
    await _loadMoreFeed();
  }

  void _syncRealtimeFeedSubscription({bool forceRestart = false}) {
    final errorFallback = context.tr('home_clixyra_775791');
    if (!widget.isActive) {
      _feedSub?.cancel();
      _feedSub = null;
      return;
    }

    if (_isCommunityPreviewFeed(_currentFeedType)) {
      _feedSub?.cancel();
      _feedSub = null;
      return;
    }

    if (!_shouldListenForLatestFeed()) {
      _feedSub?.cancel();
      _feedSub = null;
      return;
    }

    if (_feedSub != null && !forceRestart) {
      return;
    }

    _feedSub?.cancel();
    final afterTs =
        _allPosts.isNotEmpty ? _getTimestamp(_allPosts.first) : null;
    _feedSub = _socialService.streamUnifiedFeed(afterTs: afterTs).listen(
      (post) {
        if (!mounted) return;
        final map = post.toJson();
        map['id'] = post.id;
        _mergeFeedPosts([map], markLoaded: false);
        _persistFeedCache();
      },
      onError: (e) {
        debugPrint(
          '[CommunityTab] Error loading unified feed: ${AppErrorMapper.resolve(
            e,
            fallbackMessage: errorFallback,
          ).message}',
        );
        _updateState(() => _isLoading = false);
      },
    );
  }

  Future<void> _loadMoreFeed({bool reset = false}) async {
    final errorFallback = context.tr('home_clixyra_775791');
    if (_isCommunityPreviewFeed(_currentFeedType)) {
      _updateState(() {
        _isLoading = false;
        _isLoadingMoreFeed = false;
      });
      return;
    }

    if (_isLoadingMoreFeed) return;
    if (!reset && !_hasMoreFeed) return;

    _updateState(() {
      if (reset) {
        _isLoading = true;
      }
      _isLoadingMoreFeed = true;
    });

    try {
      final olderPosts = await _socialService.fetchUnifiedFeedPage(
        limit: _CommunityTabState._feedPageSize,
        endBeforeTs: reset ? null : _oldestLoadedTs,
      );

      final mapped = olderPosts.map((p) {
        final map = p.toJson();
        map['id'] = p.id;
        return map;
      }).toList();

      _mergeFeedPosts(mapped, markLoaded: true);
      _updateState(() {
        _currentLimit = _allPosts.length;
        _hasMoreFeed = mapped.length >= _CommunityTabState._feedPageSize;
      });
      _persistFeedCache();
    } catch (e) {
      debugPrint(
        '[CommunityTab] Error loading feed page: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: errorFallback,
        ).message}',
      );
    } finally {
      _updateState(() {
        _isLoading = false;
        _isLoadingMoreFeed = false;
      });
    }
  }

  void _mergeFeedPosts(
    List<Map<String, dynamic>> incoming, {
    required bool markLoaded,
  }) {
    final normalized = _normalizeIncomingPosts(incoming);
    if (normalized.isEmpty) return;

    final merged = List<Map<String, dynamic>>.from(_allPosts);
    var changed = false;

    for (final post in normalized) {
      final id = post['id']!.toString();
      final existingIndex = _findPostIndexById(merged, id);
      final nextPost = existingIndex == -1
          ? post
          : _mergeHeldLikeState(
              postId: id,
              incoming: post,
              local: merged[existingIndex],
            );
      if (existingIndex != -1) {
        final existing = merged[existingIndex];
        if (_sameFeedPost(existing, nextPost)) {
          continue;
        }
        merged.removeAt(existingIndex);
      }

      final insertIndex = _findInsertIndexByTimestamp(
        merged,
        _getTimestamp(nextPost),
      );
      merged.insert(insertIndex, nextPost);
      changed = true;
    }

    if (!changed && !markLoaded) {
      return;
    }

    _updateState(() {
      _replaceAllPosts(merged);
      _oldestLoadedTs = merged.isEmpty ? null : _getTimestamp(merged.last);
      if (markLoaded && normalized.length < _CommunityTabState._feedPageSize) {
        _hasMoreFeed = false;
      }
    });
  }

  void _persistFeedCache() {
    _feedCachePersistTimer?.cancel();
    final cache =
        _allPosts.take(40).map(_compactFeedCachePost).toList(growable: false);
    _feedCachePersistTimer =
        Timer(_CommunityTabState._feedCachePersistDelay, () {
      unawaited(OfflineCacheService.saveCache('community_unified_feed', cache));
    });
  }

  Map<String, dynamic> _compactFeedCachePost(Map<String, dynamic> post) {
    final compact = <String, dynamic>{
      'id': (post['id'] ?? '').toString(),
      'content': (post['content'] ?? '').toString(),
      'houseId': (post['houseId'] ?? '').toString(),
      'houseName': (post['houseName'] ?? '').toString(),
      'houseAvt': (post['houseAvt'] ?? post['authorAvt'] ?? '').toString(),
      'authorAvt': (post['authorAvt'] ?? post['houseAvt'] ?? '').toString(),
      'imageUrl': (post['imageUrl'] ?? '').toString(),
      'videoUrl': (post['videoUrl'] ?? '').toString(),
      'livePhotoUrl': (post['livePhotoUrl'] ?? '').toString(),
      'thumbUrl': (post['thumbUrl'] ?? '').toString(),
      'privacy': (post['privacy'] ?? post['visibility'] ?? 'public').toString(),
      'visibility':
          (post['visibility'] ?? post['privacy'] ?? 'public').toString(),
      'likes': _getLikes(post),
      'commentCount': _getCommentCount(post),
      'shareCount': _getShareCount(post),
      'views': post['views'] is num ? (post['views'] as num).toInt() : 0,
      'timestamp': _getTimestamp(post),
      'ts': _getTimestamp(post),
      'verified': post['verified'] == true,
      'isAnon': post['isAnon'] == true || post['isAnon']?.toString() == 'true',
      'isDeletedAuthor': post['isDeletedAuthor'] == true ||
          post['isDeletedAuthor']?.toString() == 'true',
      'isLocket': post['isLocket'] == true || post['is_locket'] == true,
    };
    final likedByMe = post['likedByMe'];
    if (likedByMe is bool) {
      compact['likedByMe'] = likedByMe;
    }
    return compact;
  }

  void _replaceAllPosts(List<Map<String, dynamic>> posts) {
    _allPosts = posts;
    _feedIndexById
      ..clear()
      ..addEntries(
        posts.indexed.map((entry) {
          final id = (entry.$2['id'] ?? '').toString();
          return MapEntry(id, entry.$1);
        }).where((entry) => entry.key.isNotEmpty),
      );
    if (posts.isEmpty) {
      _postFormattedDateCache.clear();
      _postSanitizedTextCache.clear();
      _lastFeedPreloadStartIndex = -1;
    }
    _feedRevision++;
    _invalidateFilteredPostsCache();
  }

  void _invalidateFilteredPostsCache() {
    _filteredPostsCache = null;
    _filteredPostsCacheKey = null;
  }

  List<Map<String, dynamic>> _normalizeIncomingPosts(
    List<Map<String, dynamic>> incoming,
  ) {
    final normalized = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (final post in incoming) {
      final normalizedPost = _normalizeFeedPost(post);
      final id = (normalizedPost['id'] ?? '').toString();
      if (id.isEmpty || !seenIds.add(id)) {
        continue;
      }
      normalized.add(normalizedPost);
    }
    normalized.sort((a, b) => _getTimestamp(b).compareTo(_getTimestamp(a)));
    return normalized;
  }

  Map<String, dynamic> _normalizeFeedPost(Map<String, dynamic> post) {
    final normalized = Map<String, dynamic>.from(post);
    final timestamp = _resolveFeedTimestamp(post);
    final privacy =
        (post['privacy'] ?? post['visibility'] ?? 'public').toString().trim();
    normalized['id'] = (post['id'] ?? '').toString().trim();
    normalized['timestamp'] = timestamp;
    normalized['ts'] = timestamp;
    normalized['privacy'] = privacy.isEmpty ? 'public' : privacy;
    normalized['visibility'] =
        (post['visibility'] ?? normalized['privacy']).toString().trim().isEmpty
            ? normalized['privacy']
            : (post['visibility'] ?? normalized['privacy']).toString().trim();
    normalized['imageUrl'] = _firstNonEmptyFeedString(post, const [
      'imageUrl',
      'image',
      'image_url',
      'photoUrl',
    ]);
    normalized['videoUrl'] = _firstNonEmptyFeedString(post, const [
      'videoUrl',
      'video',
      'video_url',
    ]);
    normalized['livePhotoUrl'] = _firstNonEmptyFeedString(post, const [
      'livePhotoUrl',
      'livePhoto',
      'live_photo_url',
    ]);
    normalized['thumbUrl'] = _firstNonEmptyFeedString(post, const [
      'thumbUrl',
      'thumbnailUrl',
      'thumbnail',
      'thumb',
    ]);
    normalized['likes'] = _resolveFeedCount(post['likes']);
    normalized['commentCount'] = _resolveFeedCount(
      post['commentCount'] ?? post['commentsCount'] ?? post['comments_count'],
    );
    normalized['shareCount'] = _resolveFeedCount(
      post['shareCount'] ?? post['reposts'] ?? post['shares'],
    );
    normalized['views'] = _resolveFeedCount(post['views']);
    return normalized;
  }

  int _resolveFeedTimestamp(Map<String, dynamic> post) {
    final ts = post['ts'];
    final timestamp = post['timestamp'];
    if (ts is int) return ts;
    if (timestamp is int) return timestamp;
    if (ts is num) return ts.toInt();
    if (timestamp is num) return timestamp.toInt();
    return 0;
  }

  int _resolveFeedCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _firstNonEmptyFeedString(
    Map<String, dynamic> post,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = post[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  int _findPostIndexById(List<Map<String, dynamic>> posts, String id) {
    final cachedIndex = _feedIndexById[id];
    if (cachedIndex != null &&
        cachedIndex >= 0 &&
        cachedIndex < posts.length &&
        (posts[cachedIndex]['id'] ?? '').toString() == id) {
      return cachedIndex;
    }
    return posts.indexWhere((post) => (post['id'] ?? '').toString() == id);
  }

  int _findInsertIndexByTimestamp(
    List<Map<String, dynamic>> posts,
    int timestamp,
  ) {
    var low = 0;
    var high = posts.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_getTimestamp(posts[mid]) < timestamp) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  bool _sameFeedPost(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!_sameFeedValue(right[entry.key], entry.value)) {
        return false;
      }
    }
    return true;
  }

  bool _sameFeedValue(Object? left, Object? right) {
    if (identical(left, right) || left == right) {
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!_sameFeedValue(right[entry.key], entry.value)) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameFeedValue(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  int _getTimestamp(Map<String, dynamic> post) {
    final ts = post['ts'];
    final timestamp = post['timestamp'];
    if (ts is int) return ts;
    if (timestamp is int) return timestamp;
    if (ts is num) return ts.toInt();
    if (timestamp is num) return timestamp.toInt();
    return 0;
  }

  Map<String, dynamic> _readPostLikeMap(Map<String, dynamic> post) {
    final raw = post['likes_map'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  bool _hasAuthoritativeLikeMap(Map<String, dynamic> post) {
    final raw = post['likes_map'];
    if (raw is! Map) return false;
    final likes = post['likes'];
    final likeCount = likes is num ? likes.toInt() : 0;
    if (raw.isEmpty) {
      return likeCount == 0;
    }
    return raw.length >= likeCount;
  }

  bool _isLikedByMe(
    Map<String, dynamic> post, {
    String? houseId,
  }) {
    final override = post['likedByMe'];
    if (override is bool) {
      return override;
    }

    final resolvedHouseId = (houseId ?? _houseId ?? '').trim();
    if (resolvedHouseId.isEmpty) return false;
    return _readPostLikeMap(post).containsKey(resolvedHouseId);
  }

  bool _isLikePending(Map<String, dynamic> post) {
    final postId = (post['id'] ?? '').toString();
    return postId.isNotEmpty && _pendingLikePostIds.contains(postId);
  }

  void _holdLikeSync(String postId) {
    if (postId.trim().isEmpty) return;
    _likeSyncHoldUntilByPostId[postId] = DateTime.now().millisecondsSinceEpoch +
        _CommunityTabState._likeSyncHoldDuration.inMilliseconds;
  }

  void _clearLikeSyncHold(String postId) {
    if (postId.trim().isEmpty) return;
    _likeSyncHoldUntilByPostId.remove(postId);
  }

  bool _isLikeSyncHeld(String postId) {
    final holdUntil = _likeSyncHoldUntilByPostId[postId];
    if (holdUntil == null) return false;
    if (holdUntil < DateTime.now().millisecondsSinceEpoch) {
      _likeSyncHoldUntilByPostId.remove(postId);
      return false;
    }
    return true;
  }

  bool _hasSameResolvedLikeState(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final resolvedHouseId = (_houseId ?? '').trim();
    return _getLikes(left) == _getLikes(right) &&
        _isLikedByMe(left, houseId: resolvedHouseId) ==
            _isLikedByMe(right, houseId: resolvedHouseId);
  }

  Map<String, dynamic> _mergeHeldLikeState({
    required String postId,
    required Map<String, dynamic> incoming,
    required Map<String, dynamic> local,
  }) {
    if (!_isLikeSyncHeld(postId)) {
      return incoming;
    }
    if (_hasSameResolvedLikeState(incoming, local)) {
      _clearLikeSyncHold(postId);
      return incoming;
    }

    final patched = Map<String, dynamic>.from(incoming);
    if (local.containsKey('likedByMe')) {
      patched['likedByMe'] = local['likedByMe'];
    }
    if (local.containsKey('likes')) {
      patched['likes'] = local['likes'];
    }
    if (local['likes_map'] is Map) {
      patched['likes_map'] = _readPostLikeMap(local);
    }
    return patched;
  }

  void _applyLocalLikeState({
    required Map<String, dynamic> post,
    required String houseId,
    required bool isLiked,
  }) {
    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return;

    void patch(Map<String, dynamic> target) {
      final currentLikes = _getLikes(target);
      final alreadyLiked = _isLikedByMe(target, houseId: houseId);
      if (alreadyLiked == isLiked) {
        target['likedByMe'] = isLiked;
        return;
      }

      if (_hasAuthoritativeLikeMap(target)) {
        final likesMap = _readPostLikeMap(target);
        if (isLiked) {
          likesMap[houseId] = <String, dynamic>{
            'by': houseId,
            'ts': DateTime.now().millisecondsSinceEpoch,
          };
        } else {
          likesMap.remove(houseId);
        }
        target['likes_map'] = likesMap;
      }

      target['likedByMe'] = isLiked;
      target['likes'] = math.max(0, currentLikes + (isLiked ? 1 : -1));
    }

    patch(post);

    final cachedIndex = _findPostIndexById(_allPosts, postId);
    if (cachedIndex != -1 && !identical(_allPosts[cachedIndex], post)) {
      patch(_allPosts[cachedIndex]);
    }
  }

  int _getLikes(Map<String, dynamic> post) {
    final map = post['likes_map'];
    final likes = post['likes'];
    final numericLikes = likes is int
        ? likes
        : likes is num
            ? likes.toInt()
            : 0;
    if (map is Map) {
      return math.max(map.length, numericLikes);
    }
    return numericLikes;
  }

  int _getCommentCount(Map<String, dynamic> post) {
    final count = post['commentCount'];
    final primaryCount = count is int
        ? count
        : count is num
            ? count.toInt()
            : 0;
    final legacyCount = post['comments'];
    final legacyNumeric = legacyCount is int
        ? legacyCount
        : legacyCount is num
            ? legacyCount.toInt()
            : 0;
    final commentsMap = post['comments'];
    final mapCount = commentsMap is Map ? commentsMap.length : 0;
    return math.max(primaryCount, math.max(legacyNumeric, mapCount));
  }

  int _getShareCount(Map<String, dynamic> post) {
    final count = post['shareCount'];
    final primaryCount = count is int
        ? count
        : count is num
            ? count.toInt()
            : 0;
    final legacyCount = post['reposts'];
    final legacyNumeric = legacyCount is int
        ? legacyCount
        : legacyCount is num
            ? legacyCount.toInt()
            : 0;
    return math.max(primaryCount, legacyNumeric);
  }

  int _getHotScore(Map<String, dynamic> post) {
    return _getLikes(post) +
        (_getCommentCount(post) * 2) +
        (_getShareCount(post) * 3);
  }

  bool _isFriend(String otherHouseId) {
    if (otherHouseId.isEmpty) return false;
    return _friends.containsKey(otherHouseId);
  }

  bool _canSeeByPrivacy(Map<String, dynamic> post) {
    final hid = _houseId;
    final postHouseId = (post['houseId'] ?? '').toString();
    final privacy =
        (post['privacy'] ?? post['visibility'] ?? 'public').toString();

    if (privacy == 'private') return hid != null && postHouseId == hid;
    if (privacy == 'friends') {
      if (hid != null && postHouseId == hid) return true;
      return _isFriend(postHouseId);
    }
    return true;
  }

  List<Map<String, dynamic>> _filteredPosts() {
    final cacheKey = [
      _feedRevision,
      _currentFeedType,
      _houseId ?? '',
      _friendsRevision,
      _blockedUsersRevision,
      _hiddenPostsRevision,
    ].join('|');
    final cachedPosts = _filteredPostsCache;
    if (_filteredPostsCacheKey == cacheKey && cachedPosts != null) {
      return cachedPosts;
    }

    final hid = _houseId;
    final list = _allPosts.where((p) {
      if (!_canSeeByPrivacy(p)) return false;

      final postId = (p['id'] ?? '').toString();
      if (postId.isNotEmpty && _hiddenPostIds.contains(postId)) {
        return false;
      }

      final postHouseId = (p['houseId'] ?? '').toString();

      // Lọc các bài viết từ những người dùng đã bị chặn
      if (_blockedUsers.containsKey(postHouseId) &&
          _blockedUsers[postHouseId] == true) {
        return false;
      }

      final isLocket = p['isLocket'] == true || p['is_locket'] == true;

      if (_currentFeedType == 'mine') {
        // Nếu là tab context.tr('home_trangcnhn_554200') ở feed, ta có thể ẩn locket đi để lưu riêng ở Profile
        if (isLocket) return false;
        return hid != null && postHouseId == hid;
      }
      if (_currentFeedType == 'locket') {
        // Khoảnh khắc: chỉ hiện bài locket
        return isLocket;
      }

      // Các feed khác không hiện bài locket (riêng biệt)
      if (isLocket) return false;

      if (_currentFeedType == 'friends') {
        if (hid != null && postHouseId == hid) return true;
        return _isFriend(postHouseId);
      }
      return true;
    }).toList();

    if (_currentFeedType == 'hot') {
      list.sort((a, b) => _getHotScore(b).compareTo(_getHotScore(a)));
      return _cacheFilteredPosts(cacheKey, list);
    }

    if (_currentFeedType == 'foryou' || _currentFeedType == 'locket') {
      final now = DateTime.now().millisecondsSinceEpoch;
      final recService = RecommendationService();
      final scores = <String, double>{};
      double scoreOf(Map<String, dynamic> post) {
        final id = (post['id'] ?? '').toString();
        return scores[id] ??= recService.getPostScore(post, now);
      }

      list.sort((a, b) {
        final scoreA = scoreOf(a);
        final scoreB = scoreOf(b);
        return scoreB.compareTo(scoreA); // Giảm dần
      });
      return _cacheFilteredPosts(cacheKey, list);
    }

    list.sort((a, b) => _getTimestamp(b).compareTo(_getTimestamp(a)));
    return _cacheFilteredPosts(cacheKey, list);
  }

  List<Map<String, dynamic>> _cacheFilteredPosts(
    String cacheKey,
    List<Map<String, dynamic>> posts,
  ) {
    final cached = List<Map<String, dynamic>>.unmodifiable(posts);
    _filteredPostsCache = cached;
    _filteredPostsCacheKey = cacheKey;
    return cached;
  }

  List<Map<String, dynamic>> _searchablePostsForSearch() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recService = RecommendationService();
    final list = _allPosts
        .where((post) {
          if (!_canSeeByPrivacy(post)) return false;
          final postHouseId = (post['houseId'] ?? '').toString();
          if (_blockedUsers.containsKey(postHouseId) &&
              _blockedUsers[postHouseId] == true) {
            return false;
          }
          return true;
        })
        .map((post) => Map<String, dynamic>.from(post))
        .toList();

    list.sort((a, b) {
      final scoreA = recService.getPostScore(a, now);
      final scoreB = recService.getPostScore(b, now);
      return scoreB.compareTo(scoreA);
    });
    return list;
  }

  String _primaryFeedImageUrl(Map<String, dynamic> post) {
    for (final key in const [
      'thumbUrl',
      'thumbnailUrl',
      'livePhotoUrl',
      'imageUrl',
    ]) {
      final value = post[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _feedLabel() {
    if (_currentFeedType == 'mine') {
      return _ct(context.tr('home_trangcnhn_554200'), 'Profile');
    }
    if (_currentFeedType == 'locket') {
      return _ct(context.tr('home_khonhkhc_cc3973'), 'Moments');
    }
    return _communityFeedLabel(_currentFeedType);
  }

  IconData _feedIcon() {
    if (_currentFeedType == 'mine') {
      return Icons.favorite;
    }
    return _communityFeedIcon(_currentFeedType);
  }

  void _toggleInlineFeedSelector() {
    _updateState(
      () => _isFeedSelectorExpanded = !_isFeedSelectorExpanded,
    );
  }

  void _closeInlineFeedSelector() {
    if (!_isFeedSelectorExpanded) return;
    _updateState(() => _isFeedSelectorExpanded = false);
  }

  void _selectInlineFeedType(String value) {
    final shouldSync =
        _currentFeedType != value && !_isCommunityPreviewFeed(value);
    _updateState(() {
      _currentFeedType = value;
      _isFeedSelectorExpanded = false;
    });
    if (shouldSync) {
      _syncRealtimeFeedSubscription();
    }
  }

  void _showFeedInDevelopmentMessage() {
    final message = _ctf(
      '{feed} đang trong giai đoạn phát triển. Nội dung phía dưới sẽ sớm mở lại.',
      '{feed} is still in development. The content area below will open soon.',
      <String, Object?>{'feed': _feedLabel()},
    );
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ignore: unused_element
  Future<void> _openFeedSelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF18191A),
      builder: (ctx) {
        return Container(
          padding: SLSpacing.all20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: SLRadius.smAll),
              ),
              _buildFeedOption(ctx,
                  value: 'foryou',
                  icon: Icons.explore_rounded,
                  label: _ct(context.tr('home_dnhchobn_ad2f6f'), 'For You')),
              _buildFeedOption(ctx,
                  value: 'locket',
                  icon: Icons.camera_alt_rounded,
                  label: _ct(context.tr('home_khonhkhclo_385edf'), 'Moments (Locket)')),
              _buildFeedOption(ctx,
                  value: 'global',
                  icon: Icons.public,
                  label: _ct(context.tr('home_toncu_bd85e4'), 'Global')),
              _buildFeedOption(ctx,
                  value: 'friends',
                  icon: Icons.people,
                  label: _ct(context.tr('home_bnb_d45c5b'), 'Friends')),
              _buildFeedOption(ctx,
                  value: 'hot',
                  icon: Icons.local_fire_department,
                  label: _ct('Top Hot 🔥', 'Top Hot 🔥')),
              SLSpacing.h8,
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    if (!mounted) return;
    _updateState(() => _currentFeedType = selected);
    if (!_isCommunityPreviewFeed(selected)) {
      _syncRealtimeFeedSubscription();
    }
  }

  // ignore: unused_element
  Widget _buildFeedOption(BuildContext ctx,
      {required String value, required IconData icon, required String label}) {
    final active = _currentFeedType == value;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
      leading: Container(
        padding: SLSpacing.all8,
        decoration: BoxDecoration(
            color: active
                ? const Color(0xFFD81B60).withValues(alpha: 0.1)
                : Colors.grey[100],
            shape: BoxShape.circle),
        child: Icon(icon,
            color: active ? const Color(0xFFD81B60) : Colors.grey[700],
            size: 20),
      ),
      title: Text(label,
          style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color:
                  active ? const Color(0xFFD81B60) : const Color(0xFF222222))),
      trailing: active
          ? const Icon(Icons.check_circle, color: Color(0xFFD81B60))
          : null,
      onTap: () => Navigator.of(ctx).pop(value),
    );
  }

  Future<void> _openFeedSearch() async {
    _closeInlineFeedSelector();
    if (_isCommunityPreviewFeed(_currentFeedType)) {
      _showFeedInDevelopmentMessage();
      return;
    }
    final selectedPost = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CommunitySearchScreen(
          posts: _searchablePostsForSearch(),
          houseId: _houseId,
          friendHouseIds: _friends.keys.map((key) => key.toString()).toSet(),
        ),
      ),
    );

    if (!mounted || selectedPost == null) return;
    await _openComments(selectedPost);
  }

  void _subscribeToRealtimeData() {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return;

    _listenToCommunityMaintenance();
    _listenCommunityMessengerPreview(houseId);

    final friendsErrorFallback = context.tr('home_khngthtida_063ede');
    final blockedErrorFallback = context.tr('home_khngthtida_87cfa9');

    _friendsRequestSubscription?.cancel();
    _friendsRequestSubscription =
        _friendsService.streamFriendRequests(houseId).listen((requests) {
      final sent = Map<String, String>.from(requests.sent);
      final received = Map<String, String>.from(requests.received);
      _updateState(() {
        _sentFriendRequestIds = sent;
        _receivedFriendRequestIds = received;
        _friendRequestsRevision++;
      });
    });

    _friendsSubscription?.cancel();
    _friendsSubscription = _dbRef.child('friends/$houseId').onValue.listen(
      (event) {
        _friendsDebounce?.cancel();
        _friendsDebounce = Timer(const Duration(milliseconds: 200), () {
          final v = event.snapshot.value;
          final next = <String, dynamic>{};
          if (v is Map) {
            v.forEach((k, val) => next[k.toString()] = val);
          }
          _updateState(() {
            _friends = next;
            _friendsRevision++;
            _invalidateFilteredPostsCache();
          });
        });
      },
      onError: (Object error) {
        debugPrint(
          'Community friends listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: friendsErrorFallback,
          ).message}',
        );
      },
    );

    _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription =
        _dbRef.child('houses/$houseId/blocked_users').onValue.listen(
      (event) {
        _blockedUsersDebounce?.cancel();
        _blockedUsersDebounce = Timer(const Duration(milliseconds: 200), () {
          final v = event.snapshot.value;
          final next = <String, dynamic>{};
          if (v is Map) {
            v.forEach((k, val) => next[k.toString()] = val);
          }
          _updateState(() {
            _blockedUsers = next;
            _blockedUsersRevision++;
            _invalidateFilteredPostsCache();
          });
        });
      },
      onError: (Object error) {
        debugPrint(
          'Community blocked-users listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: blockedErrorFallback,
          ).message}',
        );
      },
    );
  }

  void _unsubscribeFromRealtimeData() {
    _communityMaintenanceSub?.cancel();
    _communityMaintenanceSub = null;

    _communityMessengerPreviewSubscription?.cancel();
    _communityMessengerPreviewSubscription = null;

    _cancelFeedFilterSubscriptions();
  }

  void _activateTab() {
    if (!_isInitialized) {
      _isInitialized = true;
      _init();
    } else {
      _subscribeToRealtimeData();
      _syncRealtimeFeedSubscription(forceRestart: true);
    }
    _startAdLogic();
  }

  void _deactivateTab() {
    _feedSub?.cancel();
    _feedSub = null;
    _feedPreloadThrottleTimer?.cancel();
    _unsubscribeFromRealtimeData();
    unawaited(_persistCommunityUsageSession());
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _communityUsageStartedAt = null;
  }
}
