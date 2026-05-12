import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/skeleton_container.dart';

import '../controllers/diary_memory_controller.dart';
import 'diary_tab_shell_sections.dart';

const Color _diaryMemoryAccentColor = Color(0xFFD81B60);

typedef DiaryPrepareMemoryFeedCallback = PreparedDiaryMemoryFeed Function({
  required Object? liveSource,
  required Object? cacheSource,
  required bool useLiveSource,
  required bool isOffline,
  required bool waitingForLive,
});

class DiaryMemorySection extends StatefulWidget {
  final String? houseId;
  final Future<ConnectivityResult>? connectivityFuture;
  final Stream<DatabaseEvent>? memoriesStream;
  final Future<dynamic> memoriesCacheFuture;
  final dynamic initialMemoriesCache;
  final void Function(bool waitingForLive) onFinishLoadingMore;
  final DiaryPrepareMemoryFeedCallback prepareMemoryFeed;
  final Future<void> Function() onRetry;
  final Future<void> Function() onAddMemory;
  final bool hasPendingUploadRetry;
  final String pendingUploadMessage;
  final Future<void> Function() onRetryPendingUpload;
  final int thumbnailCacheWidth;
  final ValueListenable<int> selectionListenable;
  final Map<String, Map<String, dynamic>> selectedMemories;
  final bool isSelectionMode;
  final void Function(Map<String, dynamic> photo) onToggleSelection;
  final void Function(
    Map<String, dynamic> photo,
    List<Map<String, dynamic>> allPhotos,
  ) onOpenMemory;
  final bool isLoadingMoreMemories;
  final VoidCallback onLoadMore;
  final Future<void> Function(Map<String, dynamic> photo) onEnsurePhotoUrl;

  const DiaryMemorySection({
    super.key,
    required this.houseId,
    required this.connectivityFuture,
    required this.memoriesStream,
    required this.memoriesCacheFuture,
    required this.initialMemoriesCache,
    required this.onFinishLoadingMore,
    required this.prepareMemoryFeed,
    required this.onRetry,
    required this.onAddMemory,
    required this.hasPendingUploadRetry,
    required this.pendingUploadMessage,
    required this.onRetryPendingUpload,
    required this.thumbnailCacheWidth,
    required this.selectionListenable,
    required this.selectedMemories,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onOpenMemory,
    required this.isLoadingMoreMemories,
    required this.onLoadMore,
    required this.onEnsurePhotoUrl,
  });

  @override
  State<DiaryMemorySection> createState() => _DiaryMemorySectionState();
}

class _DiaryMemorySectionState extends State<DiaryMemorySection> {
  static const int _thumbnailWarmupCount = 18;
  PreparedDiaryMemoryFeed? _lastPreparedFeed;
  String _thumbnailWarmupSignature = '';
  bool _isUploadingMemory = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAddMemory() async {
    if (_isUploadingMemory) {
      return;
    }
    setState(() => _isUploadingMemory = true);
    try {
      await widget.onAddMemory();
    } finally {
      if (mounted) {
        setState(() => _isUploadingMemory = false);
      }
    }
  }

  Future<void> _handleRetryPendingUpload() async {
    if (_isUploadingMemory) {
      return;
    }
    setState(() => _isUploadingMemory = true);
    try {
      await widget.onRetryPendingUpload();
    } finally {
      if (mounted) {
        setState(() => _isUploadingMemory = false);
      }
    }
  }

  void _scheduleThumbnailWarmup(List<Map<String, dynamic>> photos) {
    if (!mounted || photos.isEmpty) {
      return;
    }
    final urls = <String>[
      for (final photo in photos.take(_thumbnailWarmupCount))
        (photo['url']?.toString() ?? '').trim(),
    ]..removeWhere((url) => url.isEmpty);
    if (urls.isEmpty) {
      return;
    }
    final signature = '${widget.thumbnailCacheWidth}|${urls.join('|')}';
    if (_thumbnailWarmupSignature == signature) {
      return;
    }
    _thumbnailWarmupSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final url in urls) {
        unawaited(
          precacheImage(
            _DiaryMemoryImageProviders.thumbnail(
                url, widget.thumbnailCacheWidth),
            context,
            onError: (error, stackTrace) {
              debugPrint(
                '[DiaryMemory] thumbnail warmup failed: ${AppErrorMapper.resolve(error).message}',
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.houseId == null) {
      return DiaryHouseSetupCard(
        title: 'CHƯA TẢI ĐƯỢC KỶ NIỆM',
        message: 'Không tìm thấy mã nhà. Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: widget.onRetry,
      );
    }

    return Stack(
      key: const ValueKey('memory_content_shell'),
      children: [
        Positioned.fill(
          child: FutureBuilder<ConnectivityResult>(
            future: widget.connectivityFuture,
            builder: (context, connSnapshot) {
              final isOffline = connSnapshot.hasData &&
                  connSnapshot.data == ConnectivityResult.none;

              if (isOffline && widget.initialMemoriesCache == null) {
                return DiaryHouseSetupCard(
                  title: 'KHÔNG CÓ KẾT NỐI',
                  message: 'Vui lòng kiểm tra internet để tải kỷ niệm mới nhất.',
                  onRetry: widget.onRetry,
                );
              }

              if (widget.memoriesStream == null || widget.houseId == null) {
                return const _DiaryMemoryInlineLoading();
              }

              return StreamBuilder<DatabaseEvent>(
                stream: widget.memoriesStream,
                builder: (context, snapshot) {
                  return FutureBuilder<dynamic>(
                    future: widget.memoriesCacheFuture,
                    initialData: widget.initialMemoriesCache,
                    builder: (context, cacheSnapshot) {
                      final bodySlivers = <Widget>[];
                      var visiblePhotoCount = 0;
                      var showingCache = false;

                      final waitingForLive = !isOffline &&
                          snapshot.connectionState == ConnectionState.waiting;
                      widget.onFinishLoadingMore(waitingForLive);
                      final hasUsableCache =
                          cacheSnapshot.hasData && cacheSnapshot.data is List;

                      if (waitingForLive &&
                          !hasUsableCache &&
                          _lastPreparedFeed == null) {
                        bodySlivers.add(
                          const SliverToBoxAdapter(
                            child: _DiaryMemoryInlineLoading(),
                          ),
                        );
                      } else {
                        try {
                          final useLiveSource = !isOffline &&
                              snapshot.hasData &&
                              snapshot.data?.snapshot.value != null &&
                              snapshot.data!.snapshot.value is Map;
                          final canReuseLastFeed = waitingForLive &&
                              !hasUsableCache &&
                              _lastPreparedFeed != null;
                          final preparedFeed = canReuseLastFeed
                              ? _lastPreparedFeed!
                              : widget.prepareMemoryFeed(
                                  liveSource: useLiveSource
                                      ? snapshot.data!.snapshot.value
                                      : null,
                                  cacheSource: hasUsableCache
                                      ? cacheSnapshot.data
                                      : null,
                                  useLiveSource: useLiveSource,
                                  isOffline: isOffline,
                                  waitingForLive: waitingForLive,
                                );
                          if (!canReuseLastFeed) {
                            _lastPreparedFeed = preparedFeed;
                          }
                          final photos = preparedFeed.photos;
                          final flattenedItems = preparedFeed.flattenedItems;
                          visiblePhotoCount = photos.length;
                          showingCache = preparedFeed.showingCache;
                          _scheduleThumbnailWarmup(photos);

                          if (photos.isEmpty) {
                            bodySlivers.add(
                              const SliverToBoxAdapter(
                                child: DiaryMemoryEmptyStateCard(),
                              ),
                            );
                          } else {
                            bodySlivers.add(
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = flattenedItems[index];

                                    if (item.isHeader) {
                                      final highlights = item.highlights;
                                      if (highlights.isNotEmpty) {
                                        return _DiaryMemorySpecialHeader(
                                          icon:
                                              highlights.first['icon'] ?? '💖',
                                          title: highlights.first['text'] ?? '',
                                          dateString: item.dateString ?? '',
                                          totalPhotos: item.totalPhotos ?? 0,
                                        );
                                      }

                                      return _DiaryMemoryDateHeader(
                                        dateString: item.dateString ?? '',
                                        totalPhotos: item.totalPhotos ?? 0,
                                      );
                                    }

                                    return _DiaryMemoryPhotoRow(
                                      rowPhotos: item.photosRow ?? const [],
                                      thumbnailCacheWidth:
                                          widget.thumbnailCacheWidth,
                                      selectionListenable:
                                          widget.selectionListenable,
                                      selectedMemories: widget.selectedMemories,
                                      isSelectionMode: widget.isSelectionMode,
                                      onToggleSelection:
                                          widget.onToggleSelection,
                                      onOpenMemory: widget.onOpenMemory,
                                      allPhotos: photos,
                                      onEnsurePhotoUrl: widget.onEnsurePhotoUrl,
                                    );
                                  },
                                  childCount: flattenedItems.length,
                                ),
                              ),
                            );

                            if (preparedFeed.canLoadMore) {
                              bodySlivers.add(
                                SliverToBoxAdapter(
                                  child: _DiaryMemoryLoadMoreCard(
                                    loadedCount: visiblePhotoCount,
                                    isLoading: widget.isLoadingMoreMemories,
                                    onTap: widget.onLoadMore,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (error) {
                          bodySlivers.add(
                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  L10nService().format(
                                    'diary_load_data_error',
                                    {'error': error},
                                  ),
                                  style:
                                      const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      return RawScrollbar(
                        controller: _scrollController,
                        thumbColor: const Color(0xFFD81B60).withValues(alpha: 0.6),
                        radius: const Radius.circular(8),
                        thickness: 6,
                        interactive: true,
                        mainAxisMargin: 32,
                        crossAxisMargin: 2,
                        child: CustomScrollView(
                          key: const ValueKey('memory_content'),
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _DiaryMemoryHeroCard(
                                totalPhotos: visiblePhotoCount,
                                isOffline: isOffline,
                                isSyncing: waitingForLive,
                                showingCache: showingCache,
                                onAdd: _handleAddMemory,
                                hasPendingUploadRetry:
                                    widget.hasPendingUploadRetry,
                                pendingUploadMessage: widget.pendingUploadMessage,
                                onRetryPendingUpload: _handleRetryPendingUpload,
                                isUploading: _isUploadingMemory,
                              ),
                            ),
                            ...bodySlivers,
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 128),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class DiaryMemoryFixedBackground extends StatelessWidget {
  const DiaryMemoryFixedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFF8FC),
            Color(0xFFEAFBFF),
            Color(0xFFFFF6E7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const RepaintBoundary(
        child: CustomPaint(
          painter: _DiaryMemoryPatternPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DiaryMemoryDateHeader extends StatelessWidget {
  final String dateString;
  final int totalPhotos;

  const _DiaryMemoryDateHeader({
    required this.dateString,
    required this.totalPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 10, right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C8BFF).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFEEF7), Color(0xFFEAFBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.collections_bookmark_rounded,
                size: 18,
                color: Color(0xFFD81B60),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Album ngày',
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF7C6D83),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateString,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2E2740),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EEFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE9D7FF)),
              ),
              child: Text(
                '$totalPhotos ảnh',
                style: SLTheme.quicksand(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C5CE6),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryMemorySpecialHeader extends StatelessWidget {
  final String icon;
  final String title;
  final String dateString;
  final int totalPhotos;

  const _DiaryMemorySpecialHeader({
    required this.icon,
    required this.title,
    required this.dateString,
    required this.totalPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEEF7), Color(0xFFF3F0FF), Color(0xFFEAFBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7FB2).withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Story đặc biệt',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7C5CE6),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2E2740),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateString,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C6D83),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE9D7FF)),
            ),
            child: Text(
              '$totalPhotos ảnh',
              style: SLTheme.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _diaryMemoryAccentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryMemoryPhotoRow extends StatefulWidget {
  final List<Map<String, dynamic>> rowPhotos;
  final int thumbnailCacheWidth;
  final ValueListenable<int> selectionListenable;
  final Map<String, Map<String, dynamic>> selectedMemories;
  final bool isSelectionMode;
  final void Function(Map<String, dynamic> photo) onToggleSelection;
  final void Function(
    Map<String, dynamic> photo,
    List<Map<String, dynamic>> allPhotos,
  ) onOpenMemory;
  final List<Map<String, dynamic>> allPhotos;
  final Future<void> Function(Map<String, dynamic> photo) onEnsurePhotoUrl;

  const _DiaryMemoryPhotoRow({
    required this.rowPhotos,
    required this.thumbnailCacheWidth,
    required this.selectionListenable,
    required this.selectedMemories,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onOpenMemory,
    required this.allPhotos,
    required this.onEnsurePhotoUrl,
  });

  @override
  State<_DiaryMemoryPhotoRow> createState() => _DiaryMemoryPhotoRowState();
}

class _DiaryMemoryPhotoRowState extends State<_DiaryMemoryPhotoRow> {
  final Map<String, int> _retryCount = {};

  @override
  void initState() {
    super.initState();
    _refreshUrlsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _DiaryMemoryPhotoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rowPhotos != oldWidget.rowPhotos) {
      _refreshUrlsIfNeeded();
    }
  }

  Future<void> _refreshUrlsIfNeeded() async {
    for (final photo in widget.rowPhotos) {
      if (_needsSignedRefresh(photo)) {
        await _refreshPhotoUrl(photo);
      }
    }
  }

  Future<void> _refreshPhotoUrl(Map<String, dynamic> photo) async {
    await widget.onEnsurePhotoUrl(photo);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshStalePhotoUrl(Map<String, dynamic> photo) async {
    photo['url'] = '';
    photo['urlExpiresAt'] = 0;
    await _refreshPhotoUrl(photo);
  }

  bool _needsSignedRefresh(Map<String, dynamic> photo) {
    if (photo['privateMedia'] != true && photo['storageAccess'] != 'signed') {
      return false;
    }
    final expiresAt = (photo['urlExpiresAt'] as num?)?.toInt() ?? 0;
    return (photo['url']?.toString().trim().isEmpty ?? true) ||
        expiresAt <= DateTime.now().millisecondsSinceEpoch + 60000;
  }

  bool _isLikelyTemporarySignedUrl(String url) {
    return url.contains('X-Goog-Expires=') || url.contains('X-Goog-Signature=');
  }

  String _stableFallbackPhotoUrl(Map<String, dynamic> photo) {
    final resolvedUrl = photo['resolvedUrl']?.toString().trim() ?? '';
    if (resolvedUrl.isNotEmpty) return resolvedUrl;
    final downloadUrl = photo['downloadUrl']?.toString().trim() ?? '';
    if (downloadUrl.isNotEmpty) return downloadUrl;
    final previewUrl = photo['previewUrl']?.toString().trim() ?? '';
    if (previewUrl.isNotEmpty) return previewUrl;
    return photo['thumbUrl']?.toString().trim() ?? '';
  }

  String _resolvePhotoUrl(Map<String, dynamic> photo) {
    final fallbackUrl = _stableFallbackPhotoUrl(photo);
    final url = photo['url']?.toString().trim() ?? '';
    if (fallbackUrl.isNotEmpty &&
        (_needsSignedRefresh(photo) || _isLikelyTemporarySignedUrl(url))) {
      return fallbackUrl;
    }
    if (url.isNotEmpty) return url;
    return fallbackUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 10),
      child: Row(
        children: List.generate(3, (colIndex) {
          if (colIndex >= widget.rowPhotos.length) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: colIndex < 2 ? 8.0 : 10.0),
                child: const AspectRatio(aspectRatio: 1.0),
              ),
            );
          }

          final photo = widget.rowPhotos[colIndex];
          final photoUrl = _resolvePhotoUrl(photo);
          final photoId = photo['id']?.toString() ?? 'unknown_$colIndex';

          // URL rỗng → hiện placeholder tĩnh, thử refresh 1 lần
          if (photoUrl.isEmpty) {
            final retries = _retryCount[photoId] ?? 0;
            if (retries < 1) {
              _retryCount[photoId] = retries + 1;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                try {
                  await _refreshStalePhotoUrl(photo);
                } catch (_) {}
              });
            }
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: colIndex < 2 ? 8.0 : 10.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chưa có URL',
                          style: SLTheme.quicksand(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final imageProvider = _DiaryMemoryImageProviders.thumbnail(
            photoUrl,
            widget.thumbnailCacheWidth,
          );
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: colIndex < 2 ? 8.0 : 10.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ValueListenableBuilder<int>(
                  valueListenable: widget.selectionListenable,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5C71D8).withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.72),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Hero(
                        tag: 'memory_image_${photo['id']}',
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) =>
                                  child,
                              errorBuilder: (context, error, stackTrace) {
                            final retries = _retryCount[photoId] ?? 0;
                            if (retries < 2) {
                              _retryCount[photoId] = retries + 1;
                              debugPrint(
                                '[DiaryMemory] image load failed id=$photoId retry=${retries + 1} message=${AppErrorMapper.resolve(error).message}',
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) async {
                                if (!mounted) return;
                                try {
                                  await _refreshStalePhotoUrl(photo);
                                } catch (refreshError) {
                                  debugPrint(
                                    '[DiaryMemory] refresh url failed id=$photoId message=${AppErrorMapper.resolve(refreshError).message}',
                                  );
                                }
                              });
                            }
                            return Container(
                              color: const Color(0xFFF8FAFC),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    retries >= 2
                                        ? Icons.broken_image_outlined
                                        : Icons.refresh_rounded,
                                    color: const Color(0xFF94A3B8),
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    retries >= 2 ? 'Không tải được' : 'Đang nạp lại...',
                                    style: SLTheme.quicksand(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  builder: (context, _, imageChild) {
                    final isSelected = widget.selectedMemories.containsKey(photoId);

                    return GestureDetector(
                      onLongPress: () => widget.onToggleSelection(photo),
                      onTap: () async {
                        if (widget.isSelectionMode) {
                          widget.onToggleSelection(photo);
                        } else {
                          if (_needsSignedRefresh(photo)) {
                            await _refreshPhotoUrl(photo);
                          }
                          widget.onOpenMemory(photo, widget.allPhotos);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageChild!,
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.18),
                                  ],
                                  begin: Alignment.center,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: Color(0xFFFF6F91),
                              ),
                            ),
                          ),
                          if (widget.isSelectionMode)
                            Positioned.fill(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.2),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 32,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

abstract final class _DiaryMemoryImageProviders {
  static ImageProvider<Object> thumbnail(String url, int maxWidth) {
    return _provider(url, maxWidth: maxWidth);
  }

  static ImageProvider<Object> _provider(String url, {int? maxWidth}) {
    if (kIsWeb) {
      return NetworkImage(url);
    }
    return CachedNetworkImageProvider(url, maxWidth: maxWidth);
  }
}

class _DiaryMemoryPatternPainter extends CustomPainter {
  const _DiaryMemoryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final washPaint = Paint()..style = PaintingStyle.fill;

    washPaint.color = const Color(0xFFFF7FB2).withValues(alpha: 0.14);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.08),
      size.width * 0.32,
      washPaint,
    );

    washPaint.color = const Color(0xFF69D2E7).withValues(alpha: 0.16);
    canvas.drawCircle(
      Offset(size.width * 0.06, size.height * 0.28),
      size.width * 0.24,
      washPaint,
    );

    washPaint.color = const Color(0xFFFFD166).withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.76),
      size.width * 0.30,
      washPaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dots = <({double x, double y, double r, Color color})>[
      (x: 0.16, y: 0.10, r: 3.0, color: const Color(0xFFFF7FB2)),
      (x: 0.34, y: 0.18, r: 2.3, color: const Color(0xFF62C7B5)),
      (x: 0.72, y: 0.22, r: 2.8, color: const Color(0xFFFFC857)),
      (x: 0.24, y: 0.46, r: 2.5, color: const Color(0xFFFF7FB2)),
      (x: 0.66, y: 0.52, r: 3.4, color: const Color(0xFF7C8BFF)),
      (x: 0.14, y: 0.78, r: 2.6, color: const Color(0xFF62C7B5)),
      (x: 0.52, y: 0.88, r: 2.7, color: const Color(0xFFFF7FB2)),
    ];
    for (final dot in dots) {
      dotPaint.color = dot.color.withValues(alpha: 0.28);
      canvas.drawCircle(
        Offset(size.width * dot.x, size.height * dot.y),
        dot.r,
        dotPaint,
      );
    }

    _drawHeart(
      canvas,
      Offset(size.width * 0.88, size.height * 0.34),
      0.72,
      const Color(0xFFFF7FB2).withValues(alpha: 0.16),
    );
    _drawHeart(
      canvas,
      Offset(size.width * 0.18, size.height * 0.62),
      0.55,
      const Color(0xFF7C8BFF).withValues(alpha: 0.14),
    );

    final labelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.44)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, size.height * 0.58, 86, 30),
        const Radius.circular(18),
      ),
      labelPaint,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double scale, Color color) {
    final path = Path()
      ..moveTo(0, 10)
      ..cubicTo(-26, -10, -38, 22, 0, 44)
      ..cubicTo(38, 22, 26, -10, 0, 10)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiaryMemoryHeroCard extends StatelessWidget {
  final int totalPhotos;
  final bool isOffline;
  final bool isSyncing;
  final bool showingCache;
  final Future<void> Function() onAdd;
  final bool hasPendingUploadRetry;
  final String pendingUploadMessage;
  final Future<void> Function() onRetryPendingUpload;
  final bool isUploading;

  const _DiaryMemoryHeroCard({
    required this.totalPhotos,
    required this.isOffline,
    required this.isSyncing,
    required this.showingCache,
    required this.onAdd,
    required this.hasPendingUploadRetry,
    required this.pendingUploadMessage,
    required this.onRetryPendingUpload,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    final statusChips = <Widget>[
      _DiaryMemoryHeroChip(
        icon: Icons.photo_rounded,
        label: '$totalPhotos ảnh',
        color: const Color(0xFFD81B60),
        background: const Color(0xFFFFEEF5),
      ),
      _DiaryMemoryHeroChip(
        icon: _statusIcon,
        label: _statusLabel,
        color: _statusColor,
        background: _statusBackground,
        minWidth: 126,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.96),
            const Color(0xFFFFF0F7).withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7FB2).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF62C7B5).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -8,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 50,
              color: const Color(0xFFFFC857).withValues(alpha: 0.18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6F91), Color(0xFF62C7B5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6F91).withValues(alpha: 0.24),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.collections_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kỷ niệm của chúng mình',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 19,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2E2740),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lưu ảnh, mở lại như album tình yêu và kéo dần về những khoảnh khắc cũ hơn.',
                          style: SLTheme.quicksand(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C6D83),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            _DiaryMemoryMiniBadge(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Memory Wall',
                            ),
                            SizedBox(width: 6),
                            _DiaryMemoryMiniBadge(
                              icon: Icons.swipe_rounded,
                              label: 'Chạm để xem',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFEADCF4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF0F7),
                                      Color(0xFFEAFBFF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFD81B60),
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  totalPhotos > 0
                                      ? 'Có $totalPhotos ảnh đang được lưu trong album này.'
                                      : 'Album này đang chờ ảnh đầu tiên để trở nên sống động hơn.',
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6F5D74),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...statusChips,
                  _DiaryMemoryAddButton(
                    onTap: onAdd,
                    isLoading: isUploading,
                  ),
                ],
              ),
              if (hasPendingUploadRetry) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 300;
                    final message = Text(
                      pendingUploadMessage,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A5200),
                        height: 1.35,
                      ),
                    );
                    final retryButton = TextButton(
                      onPressed: isUploading ? null : () => onRetryPendingUpload(),
                      child: Text(
                        'Thử lại',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF8E5B00),
                        ),
                      ),
                    );

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF0C36A),
                        ),
                      ),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFF8E5B00),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: message),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: retryButton,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFF8E5B00),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: message),
                                const SizedBox(width: 8),
                                retryButton,
                              ],
                            ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    if (isOffline) {
      return Icons.cloud_off_rounded;
    }
    if (showingCache) {
      return Icons.history_rounded;
    }
    if (isSyncing) {
      return Icons.sync_rounded;
    }
    return Icons.cloud_done_rounded;
  }

  String get _statusLabel {
    if (isOffline) {
      return 'Đang offline';
    }
    if (showingCache) {
      return 'Dữ liệu tạm';
    }
    if (isSyncing) {
      return 'Đang đồng bộ';
    }
    return 'Đã đồng bộ';
  }

  Color get _statusColor {
    if (isOffline) {
      return const Color(0xFF8E5B00);
    }
    if (showingCache) {
      return const Color(0xFF5C5A72);
    }
    if (isSyncing) {
      return const Color(0xFF2262C6);
    }
    return const Color(0xFF1D8F62);
  }

  Color get _statusBackground {
    if (isOffline) {
      return const Color(0xFFFFF4D6);
    }
    if (showingCache) {
      return const Color(0xFFF2F2F8);
    }
    if (isSyncing) {
      return const Color(0xFFEAF3FF);
    }
    return const Color(0xFFEAF9F2);
  }
}

class _DiaryMemoryHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final double? minWidth;

  const _DiaryMemoryHeroChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryMemoryLoadMoreCard extends StatelessWidget {
  final int loadedCount;
  final bool isLoading;
  final VoidCallback onTap;

  const _DiaryMemoryLoadMoreCard({
    required this.loadedCount,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF62C7B5).withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C71D8).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang hiển thị $loadedCount ảnh gần nhất.',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E2740),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kéo xuống cuối để mở thêm các kỷ niệm cũ hơn.',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C6D83),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F6BD8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                isLoading ? 'Đang tải thêm...' : 'Tải thêm ảnh cũ hơn',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryMemoryAddButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final bool isLoading;

  const _DiaryMemoryAddButton({
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : () => onTap(),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6F91), Color(0xFFD81B60)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.add_a_photo_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
              const SizedBox(width: 5),
              Text(
                'Thêm ảnh',
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryMemoryMiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DiaryMemoryMiniBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEEDAF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFD81B60)),
          const SizedBox(width: 5),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7C6D83),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryMemoryInlineLoading extends StatelessWidget {
  const _DiaryMemoryInlineLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giả lập header ngày
          const SkeletonContainer.rounded(width: 120, height: 24),
          const SizedBox(height: 16),
          // Giả lập lưới ảnh 3 cột
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) => const SkeletonContainer.rounded(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}
