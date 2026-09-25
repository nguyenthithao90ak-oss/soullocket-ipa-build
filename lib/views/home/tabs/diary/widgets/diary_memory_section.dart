import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/cloudflare_r2_service.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/skeleton_container.dart';

import '../controllers/diary_memory_controller.dart';
import '../utils/diary_memory_media.dart';
import 'diary_tab_shell_sections.dart';
import 'diary_album_style.dart';
import 'private_diary_image.dart';
import 'diary_memory_video_player.dart';
import '../utils/private_memory_link_policy.dart';

typedef DiaryPrepareMemoryFeedCallback =
    PreparedDiaryMemoryFeed Function({
      required Object? liveSource,
      required Object? cacheSource,
      required bool useLiveSource,
      required bool isOffline,
      required bool waitingForLive,
    });

class DiaryMemorySection extends StatefulWidget {
  final Widget? header;
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
  )
  onOpenMemory;
  final bool isLoadingMoreMemories;
  final VoidCallback onLoadMore;
  final Future<void> Function(Map<String, dynamic> photo) onEnsurePhotoUrl;
  final Future<void> Function(
    DateTime selectedDate,
    List<Map<String, dynamic>> photos,
  )
  onEditGroupDate;

  const DiaryMemorySection({
    super.key,
    this.header,
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
    required this.onEditGroupDate,
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

  // Month filter state
  DateTime? _selectedMonth; // only year/month used, day = 1
  List<DateTime> _availableMonths = [];

  // Scroll indicator state
  final ValueNotifier<({bool isVisible, String label, double fraction})>
  _scrollIndicatorNotifier = ValueNotifier((
    isVisible: false,
    label: '',
    fraction: 0.0,
  ));
  Timer? _hideIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollIndicatorNotifier.dispose();
    _hideIndicatorTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 400 && !widget.isLoadingMoreMemories) {
      widget.onLoadMore();
    }
  }

  /// Extract available months from photos list
  void _updateAvailableMonths(List<Map<String, dynamic>> photos) {
    final months = <DateTime>{};
    for (final photo in photos) {
      final ts = photo['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      months.add(DateTime(date.year, date.month, 1));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    _availableMonths = sorted;
    // Không gọi setState ở đây vì _updateAvailableMonths được gọi trong build
    // Widget build sẽ pick up _availableMonths qua lần rebuild tiếp theo
  }

  Widget _buildMonthFilter() {
    final months = _availableMonths;
    if (months.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Lọc theo tháng'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DiaryAlbumStyle.muted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48 + (MediaQuery.textScalerOf(context).scale(12) - 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: months.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final isSelected = isAll
                    ? _selectedMonth == null
                    : _selectedMonth == months[index - 1];
                final label = isAll
                    ? context.tr('Tất cả')
                    : DateFormat('MM/yyyy').format(months[index - 1]);
                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : DiaryAlbumStyle.muted,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: DiaryAlbumStyle.rose,
                  backgroundColor: DiaryAlbumStyle.paper,
                  showCheckmark: false,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  side: isSelected
                      ? BorderSide.none
                      : const BorderSide(color: DiaryAlbumStyle.line),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedMonth = isAll ? null : months[index - 1];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DiaryMemoryFlattenedItem> _filterByMonth(
    List<DiaryMemoryFlattenedItem> items,
  ) {
    if (_selectedMonth == null || _availableMonths.length <= 1) return items;

    final filtered = <DiaryMemoryFlattenedItem>[];
    bool includeCurrentGroup = false;

    for (final item in items) {
      if (item.isHeader) {
        final d = item.date;
        if (d != null &&
            d.year == _selectedMonth!.year &&
            d.month == _selectedMonth!.month) {
          includeCurrentGroup = true;
          filtered.add(item);
        } else {
          includeCurrentGroup = false;
        }
      } else {
        if (includeCurrentGroup) {
          filtered.add(item);
        }
      }
    }
    return filtered;
  }

  /// Filter raw photos list by selected month
  List<Map<String, dynamic>> _filterPhotosByMonth(
    List<Map<String, dynamic>> photos,
  ) {
    if (_selectedMonth == null || _availableMonths.length <= 1) return photos;
    return photos.where((photo) {
      final ts = photo['ts'] as int? ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == _selectedMonth!.year && d.month == _selectedMonth!.month;
    }).toList();
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
        if (!PrivateMemoryLinkPolicy.isPrivate(photo))
        (isDiaryMemoryVideo(photo)
                    ? resolveDiaryMemoryVideoThumbnailUrl(photo)
                    : resolveDiaryMemoryMediaUrl(photo))
                ?.trim() ??
            '',
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
              url,
              widget.thumbnailCacheWidth,
            ),
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
        title: context.tr('home_chaticknim_96daa5'),
        message: context.tr('home_khngtmthym_030e31'),
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
              final isOffline =
                  connSnapshot.hasData &&
                  connSnapshot.data == ConnectivityResult.none;

              if (isOffline && widget.initialMemoriesCache == null) {
                return DiaryHouseSetupCard(
                  title: context.tr('home_khngcktni_2053bb'),
                  message: context.tr('home_vuilngkimt_2a0344'),
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
                      var filteredCount = 0;
                      var filteredItems = <DiaryMemoryFlattenedItem>[];

                      final waitingForLive =
                          !isOffline &&
                          snapshot.connectionState == ConnectionState.waiting;
                      widget.onFinishLoadingMore(waitingForLive);
                      final hasUsableCache =
                          cacheSnapshot.hasData && cacheSnapshot.data is List;

                      if (waitingForLive &&
                          _lastPreparedFeed == null &&
                          !hasUsableCache) {
                        bodySlivers.add(
                          const SliverToBoxAdapter(
                            child: _DiaryMemoryInlineLoading(),
                          ),
                        );
                      } else {
                        try {
                          final useLiveSource =
                              !isOffline &&
                              snapshot.hasData &&
                              snapshot.data?.snapshot.value != null &&
                              snapshot.data!.snapshot.value is Map;
                          final canReuseLastFeed =
                              waitingForLive && _lastPreparedFeed != null;
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

                          // Update available months for filter
                          if (photos.isNotEmpty && _availableMonths.isEmpty) {
                            _updateAvailableMonths(photos);
                          }

                          // Apply month filter
                          filteredItems = _filterByMonth(flattenedItems);
                          final filteredPhotos = _filterPhotosByMonth(photos);
                          filteredCount = _selectedMonth == null
                              ? visiblePhotoCount
                              : filteredPhotos.length;

                          if (photos.isEmpty) {
                            bodySlivers.add(
                              const SliverToBoxAdapter(
                                child: DiaryMemoryEmptyStateCard(),
                              ),
                            );
                          } else {
                            // Month filter bar
                            if (_availableMonths.length > 1) {
                              bodySlivers.add(
                                SliverToBoxAdapter(child: _buildMonthFilter()),
                              );
                            }

                            // Dùng SliverList.builder duy nhất cho toàn bộ danh sách ảnh
                            // để giảm tối đa chi phí GPU/Layout của CustomScrollView
                            bodySlivers.add(
                              SliverList.builder(
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  Widget cellWidget;
                                  if (item.isHeader) {
                                    final highlights = item.highlights;
                                    if (highlights.isNotEmpty) {
                                      cellWidget = _DiaryMemorySpecialHeader(
                                        icon: highlights.first['icon'] ?? '💖',
                                        title: highlights.first['text'] ?? '',
                                        dateString: item.dateString ?? '',
                                        totalPhotos: item.totalPhotos ?? 0,
                                      );
                                    } else {
                                      cellWidget = _DiaryMemoryDateHeader(
                                        dateString: item.dateString ?? '',
                                        totalPhotos: item.totalPhotos ?? 0,
                                      );
                                    }
                                  } else {
                                    final rowPhotos =
                                        item.photosRow ?? const [];
                                    if (rowPhotos.isEmpty) {
                                      cellWidget = const SizedBox.shrink();
                                    } else {
                                      cellWidget = Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                          left: 20,
                                          right: 20,
                                        ),
                                        child: Row(
                                          children: [
                                            for (
                                              int i = 0;
                                              i < rowPhotos.length;
                                              i++
                                            ) ...[
                                              if (i > 0)
                                                const SizedBox(width: 12),
                                              Expanded(
                                                child: AspectRatio(
                                                  aspectRatio:
                                                      1.0, // Cố định tỷ lệ vuông cho mỗi ảnh trong hàng
                                                  child: _DiaryMemoryPhotoCell(
                                                    key: ValueKey(
                                                      rowPhotos[i]['id'] ??
                                                          'photo_${index * 10 + i}',
                                                    ),
                                                    photo: rowPhotos[i],
                                                    index: index * 10 + i,
                                                    thumbnailCacheWidth: widget
                                                        .thumbnailCacheWidth,
                                                    selectionListenable: widget
                                                        .selectionListenable,
                                                    selectedMemories:
                                                        widget.selectedMemories,
                                                    isSelectionMode:
                                                        widget.isSelectionMode,
                                                    onToggleSelection: widget
                                                        .onToggleSelection,
                                                    onOpenMemory:
                                                        widget.onOpenMemory,
                                                    allPhotos: filteredPhotos,
                                                    onEnsurePhotoUrl:
                                                        widget.onEnsurePhotoUrl,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                  return RepaintBoundary(child: cellWidget);
                                },
                              ),
                            );

                            bodySlivers.add(
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    12,
                                  ),
                                  child: Text(
                                    context.tr('Hết ảnh rồi nha bạn yêu !!!!'),
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: DiaryAlbumStyle.muted,
                                    ),
                                  ),
                                ),
                              ),
                            );
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
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      return Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (filteredItems.isEmpty) return false;
                              if (notification is ScrollUpdateNotification ||
                                  notification is ScrollStartNotification) {
                                final maxExt =
                                    notification.metrics.maxScrollExtent;
                                if (maxExt <= 0) return false;

                                double fraction =
                                    notification.metrics.pixels / maxExt;
                                fraction = fraction.clamp(0.0, 1.0);

                                final index =
                                    (fraction * (filteredItems.length - 1))
                                        .round();
                                final item = filteredItems[index];
                                final d = item.date;
                                final label = d != null
                                    ? DateFormat('dd/MM/yyyy').format(d)
                                    : '';

                                _scrollIndicatorNotifier.value = (
                                  isVisible: true,
                                  label: label,
                                  fraction: fraction,
                                );

                                _hideIndicatorTimer?.cancel();
                                _hideIndicatorTimer = Timer(
                                  const Duration(milliseconds: 1200),
                                  () {
                                    _scrollIndicatorNotifier.value = (
                                      isVisible: false,
                                      label:
                                          _scrollIndicatorNotifier.value.label,
                                      fraction: _scrollIndicatorNotifier
                                          .value
                                          .fraction,
                                    );
                                  },
                                );
                              }
                              return false;
                            },
                            child: RawScrollbar(
                              controller: _scrollController,
                              thumbColor: DiaryAlbumStyle.rose.withValues(
                                alpha: 0.45,
                              ),
                              radius: const Radius.circular(8),
                              thickness: 3,
                              interactive: true,
                              mainAxisMargin: 32,
                              crossAxisMargin: 2,
                              child: CustomScrollView(
                                key: const ValueKey('memory_content'),
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  if (widget.header != null)
                                    SliverSafeArea(
                                      bottom: false,
                                      sliver: SliverToBoxAdapter(
                                        child: widget.header!,
                                      ),
                                    ),
                                  SliverToBoxAdapter(
                                    child: _DiaryMemoryHeroCard(
                                      totalPhotos: filteredCount,
                                      isOffline: isOffline,
                                      showingCache: showingCache,
                                      onAdd: _handleAddMemory,
                                      hasPendingUploadRetry:
                                          widget.hasPendingUploadRetry,
                                      pendingUploadMessage:
                                          widget.pendingUploadMessage,
                                      onRetryPendingUpload:
                                          _handleRetryPendingUpload,
                                      isUploading: _isUploadingMemory,
                                    ),
                                  ),
                                  ...bodySlivers,
                                  const SliverPadding(
                                    padding: EdgeInsets.only(bottom: 128),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ValueListenableBuilder<
                            ({bool isVisible, String label, double fraction})
                          >(
                            valueListenable: _scrollIndicatorNotifier,
                            builder: (context, state, _) {
                              if (state.label.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              const topMargin = 80.0;
                              const bottomMargin = 120.0;
                              final availableHeight =
                                  MediaQuery.of(context).size.height -
                                  topMargin -
                                  bottomMargin;
                              final topPos =
                                  topMargin + state.fraction * availableHeight;

                              return Positioned(
                                right: 16,
                                top: topPos,
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: state.isVisible ? 1.0 : 0.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DiaryAlbumStyle.ink,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            state.label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
          colors: [Color(0xFFFFF8FC), Color(0xFFEAFBFF), Color(0xFFFFF6E7)],
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home_albumngy_7e474f'),
            style: SLTheme.quicksand(
              fontSize: 11,
              color: DiaryAlbumStyle.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                dateString,
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: DiaryAlbumStyle.ink,
                ),
              ),
              Text(
                L10nService().format('diary_photos_count', {
                  'count': totalPhotos,
                }),
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DiaryAlbumStyle.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: DiaryAlbumStyle.line),
        ],
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
      margin: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiaryAlbumStyle.roseWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('home_storycbit_5a2a17'),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DiaryAlbumStyle.rose,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DiaryAlbumStyle.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      dateString,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: DiaryAlbumStyle.muted,
                      ),
                    ),
                    Text(
                      L10nService().format('diary_photos_count', {
                        'count': totalPhotos,
                      }),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: DiaryAlbumStyle.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryMemoryPhotoCell extends StatefulWidget {
  final Map<String, dynamic> photo;
  final int index;
  final int thumbnailCacheWidth;
  final ValueListenable<int> selectionListenable;
  final Map<String, Map<String, dynamic>> selectedMemories;
  final bool isSelectionMode;
  final void Function(Map<String, dynamic> photo) onToggleSelection;
  final void Function(
    Map<String, dynamic> photo,
    List<Map<String, dynamic>> allPhotos,
  )
  onOpenMemory;
  final List<Map<String, dynamic>> allPhotos;
  final Future<void> Function(Map<String, dynamic> photo) onEnsurePhotoUrl;

  const _DiaryMemoryPhotoCell({
    super.key,
    required this.photo,
    required this.index,
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
  State<_DiaryMemoryPhotoCell> createState() => _DiaryMemoryPhotoCellState();
}

class _DiaryMemoryPhotoCellState extends State<_DiaryMemoryPhotoCell> {
  int _retryCount = 0;
  int _imageAttempt = 0;
  bool _manualRetry = false;
  bool _urlsRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshUrlsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _DiaryMemoryPhotoCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo != oldWidget.photo) {
      _retryCount = 0;
      _imageAttempt++;
      _refreshUrlsIfNeeded();
    }
  }

  Future<void> _refreshUrlsIfNeeded() async {
    if (PrivateMemoryLinkPolicy.isPrivate(widget.photo)) return;
    if (_urlsRefreshing) return;
    _urlsRefreshing = true;
    try {
      if (_needsSignedRefresh(widget.photo)) {
        await _refreshPhotoUrl(widget.photo);
      }
    } finally {
      if (mounted) {
        setState(() {
          _urlsRefreshing = false;
        });
      } else {
        _urlsRefreshing = false;
      }
    }
  }

  Future<void> _refreshPhotoUrl(Map<String, dynamic> photo) async {
    final oldUrl = photo['url']?.toString() ?? '';
    await widget.onEnsurePhotoUrl(photo);
    if (mounted && photo['url']?.toString() != oldUrl) {
      setState(() {});
    }
  }

  Future<void> _refreshStalePhotoUrl(Map<String, dynamic> photo) async {
    if (photo['privateMedia'] == true || photo['storageAccess'] == 'signed') {
      photo['url'] = '';
      photo['urlExpiresAt'] = 0;
    }
    await _refreshPhotoUrl(photo);
  }

  Future<void> _retryImage() async {
    if (_manualRetry) return;
    final photo = widget.photo;
    setState(() => _manualRetry = true);
    try {
      final url = _resolvePhotoUrl(photo);
      if (url.isNotEmpty) await CachedNetworkImage.evictFromCache(url);
      await _refreshStalePhotoUrl(photo);
    } catch (_) {
      // Giữ nút thử lại khi thiết bị còn mất mạng.
    } finally {
      if (mounted && identical(widget.photo, photo)) {
        setState(() {
          _manualRetry = false;
          _retryCount = 0;
          _imageAttempt++;
        });
      }
    }
  }

  Widget _buildImageRetry() => ColoredBox(
    color: DiaryAlbumStyle.canvas,
    child: Center(
      child: IconButton(
        tooltip: context.tr('core_retry'),
        onPressed: _manualRetry ? null : _retryImage,
        icon: _manualRetry
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, color: DiaryAlbumStyle.rose),
      ),
    ),
  );

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

  String _stableFallbackVideoUrl(Map<String, dynamic> photo) {
    for (final key in const <String>[
      'resolvedUrl',
      'downloadUrl',
      'videoUrl',
      'video_url',
      'mediaUrl',
      'media_url',
      'contentUrl',
      'content_url',
      'fileUrl',
      'file_url',
    ]) {
      final value = photo[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _resolvePhotoUrl(Map<String, dynamic> photo) {
    if (PrivateMemoryLinkPolicy.isPrivate(photo)) return photo['url']?.toString() ?? '';
    final isVideo = isDiaryMemoryVideo(photo);
    final fallbackUrl = isVideo
        ? _stableFallbackVideoUrl(photo)
        : _stableFallbackPhotoUrl(photo);
    final url = photo['url']?.toString().trim() ?? '';
    if (fallbackUrl.isNotEmpty &&
        (_needsSignedRefresh(photo) || _isLikelyTemporarySignedUrl(url))) {
      return fallbackUrl;
    }
    if (url.isNotEmpty) return url;
    return fallbackUrl;
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> photo, String videoUrl) {
    if (PrivateMemoryLinkPolicy.isPrivate(photo)) {
      return IgnorePointer(child: DiaryMemoryVideoPlayer(
        url: '', houseId: photo['houseId']?.toString() ?? photo['house_id']?.toString(),
        memoryId: photo['id']?.toString(), requireFreshAuthorization: true,
        previewOnly: true, isActive: false,
      ));
    }
    return _DiaryMemoryVideoPreview(
      videoUrl: videoUrl,
      thumbnailUrl: resolveDiaryMemoryVideoThumbnailUrl(photo) ?? '',
      thumbnailCacheWidth: widget.thumbnailCacheWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final photoUrl = _resolvePhotoUrl(photo);
    final photoId = photo['id']?.toString() ?? 'unknown_${widget.index}';

    final isStickerOrPng =
        photoUrl.toLowerCase().contains('.png') ||
        photo['isSticker'] == true ||
        photo['isCutout'] == true;

    final isVideo = isDiaryMemoryVideo(photo);

    if (photoUrl.isEmpty && !PrivateMemoryLinkPolicy.isPrivate(photo)) {
      if (_retryCount < 1) {
        _retryCount++;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            await _refreshStalePhotoUrl(photo);
          } catch (error) {
            debugPrint(
              '[SuppressedError] lib/views/home/tabs/diary/widgets/diary_memory_section.dart: $error',
            );
          }
        });
      }
      return _buildImageRetry();
    }

    return ValueListenableBuilder<int>(
      valueListenable: widget.selectionListenable,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 16),
          decoration: BoxDecoration(
            color: DiaryAlbumStyle.paper,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: DiaryAlbumStyle.line),
            boxShadow: [
              BoxShadow(
                color: DiaryAlbumStyle.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Hero(
              tag: 'memory_image_${photo['id']}',
              child: isVideo
                  ? _buildVideoThumbnail(photo, photoUrl)
                  : PrivateMemoryLinkPolicy.isPrivate(photo)
                  ? PrivateDiaryImage(
                      houseId: photo['houseId']?.toString() ?? photo['house_id']?.toString() ?? '',
                      memoryId: photoId, cacheWidth: widget.thumbnailCacheWidth,
                      fit: isStickerOrPng ? BoxFit.contain : BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      key: ValueKey('$photoId-$_imageAttempt'),
                      imageUrl: photoUrl,
                      memCacheWidth: widget.thumbnailCacheWidth,
                      fit: isStickerOrPng ? BoxFit.contain : BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      placeholder: (context, url) => Container(
                        color: isStickerOrPng
                            ? Colors.transparent
                            : const Color(0xFFF1F5F9),
                      ),
                      errorWidget: (context, url, error) {
                        if (_retryCount < 1 && _needsSignedRefresh(photo)) {
                          _retryCount++;
                          WidgetsBinding.instance.addPostFrameCallback((
                            _,
                          ) async {
                            if (!mounted) return;
                            try {
                              await _refreshStalePhotoUrl(photo);
                            } catch (_) {}
                          });
                        }
                        return _buildImageRetry();
                      },
                    ),
            ),
          ),
        ),
      ),
      builder: (context, _, imageChild) {
        final isSelected = widget.selectedMemories.containsKey(photoId);

        return _DiaryMemoryScaleOnPress(
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
            fit: StackFit.passthrough,
            children: [
              imageChild!,
              if (widget.isSelectionMode)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: DiaryAlbumStyle.rose,
                          width: 2,
                        ),
                        color: DiaryAlbumStyle.ink.withValues(alpha: 0.25),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale: isSelected ? 1.0 : 0.5,
                        curve: Curves.elasticOut,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DiaryAlbumStyle.rose,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Dùng ảnh thumbnail khi có. Với video cũ chưa có thumbnail, lấy frame đầu
/// bằng [VideoPlayer] để mọi máy vẫn có ảnh xem trước thay vì khung trắng.
class _DiaryMemoryVideoPreview extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final int thumbnailCacheWidth;

  const _DiaryMemoryVideoPreview({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.thumbnailCacheWidth,
  });

  @override
  State<_DiaryMemoryVideoPreview> createState() =>
      _DiaryMemoryVideoPreviewState();
}

class _DiaryMemoryVideoPreviewState extends State<_DiaryMemoryVideoPreview> {
  VideoPlayerController? _controller;
  bool _thumbnailFailed = false;
  bool _isLoadingPreview = false;
  bool _previewFailed = false;
  int _previewGeneration = 0;

  bool get _usesVideoPreview =>
      widget.thumbnailUrl.trim().isEmpty || _thumbnailFailed;

  @override
  void initState() {
    super.initState();
    if (_usesVideoPreview) {
      _initializeVideoPreview();
    }
  }

  @override
  void didUpdateWidget(covariant _DiaryMemoryVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl &&
        oldWidget.thumbnailUrl == widget.thumbnailUrl) {
      return;
    }

    _resetPreview();
    if (_usesVideoPreview) {
      _initializeVideoPreview();
    }
  }

  void _resetPreview() {
    _previewGeneration++;
    final controller = _controller;
    _controller = null;
    _thumbnailFailed = false;
    _isLoadingPreview = false;
    _previewFailed = false;
    if (controller != null) {
      unawaited(controller.dispose());
    }
  }

  void _handleThumbnailFailure() {
    if (_thumbnailFailed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _thumbnailFailed) {
        return;
      }
      setState(() => _thumbnailFailed = true);
      _initializeVideoPreview();
    });
  }

  Future<void> _initializeVideoPreview() async {
    if (!_usesVideoPreview || _isLoadingPreview || _previewFailed) {
      return;
    }

    final rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) {
      if (mounted) {
        setState(() => _previewFailed = true);
      }
      return;
    }

    final generation = ++_previewGeneration;
    if (mounted) {
      setState(() => _isLoadingPreview = true);
    }

    VideoPlayerController? controller;
    try {
      final playableUrl = CloudflareR2Service.resolveVideoUrl(rawUrl);
      final uri = Uri.tryParse(playableUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Invalid diary video URL');
      }

      controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize().timeout(const Duration(seconds: 20));
      await controller.setVolume(0);
      await controller.pause();

      if (!mounted || generation != _previewGeneration) {
        await controller.dispose();
        return;
      }

      final previousController = _controller;
      setState(() {
        _controller = controller;
        _isLoadingPreview = false;
      });
      if (previousController != null) {
        unawaited(previousController.dispose());
      }
    } catch (error) {
      if (controller != null) {
        await controller.dispose();
      }
      debugPrint('[DiaryMemory] video preview failed: $error');
      if (mounted && generation == _previewGeneration) {
        setState(() {
          _isLoadingPreview = false;
          _previewFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _previewGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = widget.thumbnailUrl.trim();
    Widget media;
    if (!_usesVideoPreview && thumbnailUrl.isNotEmpty) {
      media = CachedNetworkImage(
        imageUrl: thumbnailUrl,
        memCacheWidth: widget.thumbnailCacheWidth,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        placeholder: (context, url) => _buildFallbackSurface(isLoading: true),
        errorWidget: (context, url, error) {
          _handleThumbnailFailure();
          return _buildFallbackSurface(isLoading: true);
        },
      );
    } else {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        final size = controller.value.size;
        media = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      } else {
        media = _buildFallbackSurface(isLoading: _isLoadingPreview);
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackSurface({required bool isLoading}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFECF4FF), Color(0xFFDCE8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(
                Icons.movie_creation_outlined,
                color: Color(0xFF6E88B0),
                size: 38,
              ),
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
  final bool showingCache;
  final Future<void> Function() onAdd;
  final bool hasPendingUploadRetry;
  final String pendingUploadMessage;
  final Future<void> Function() onRetryPendingUpload;
  final bool isUploading;

  const _DiaryMemoryHeroCard({
    required this.totalPhotos,
    required this.isOffline,
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
        label: L10nService().format('diary_photos_count', {
          'count': totalPhotos,
        }),
        color: DiaryAlbumStyle.muted,
        background: Colors.transparent,
      ),
      _DiaryMemoryHeroChip(
        icon: _statusIcon,
        label: _statusLabel,
        color: _statusColor,
        background: _statusBackground,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home_knimcachng_692bf0'),
            style: SLTheme.quicksand(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: DiaryAlbumStyle.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            context.tr('Lưu giữ khoảnh khắc yêu thương 💕'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: DiaryAlbumStyle.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: statusChips),
          const SizedBox(height: 14),
          _DiaryMemoryAddButton(onTap: onAdd, isLoading: isUploading),
          if (hasPendingUploadRetry) ...[
            const SizedBox(height: 16),
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
                    context.tr('home_thli_4dffdf'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF8E5B00),
                    ),
                  ),
                );

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0C36A)),
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
    );
  }

  IconData get _statusIcon {
    if (isOffline) {
      return Icons.cloud_off_rounded;
    }
    if (showingCache) {
      return Icons.history_rounded;
    }
    return Icons.cloud_done_rounded;
  }

  String get _statusLabel {
    if (isOffline) {
      return L10nService().translate('home_angoffline_bbb3d5');
    }
    if (showingCache) {
      return L10nService().translate('home_dliutm_0004b5');
    }
    return L10nService().translate('home_ngb_85d905');
  }

  Color get _statusColor {
    if (isOffline) {
      return const Color(0xFF8E5B00);
    }
    if (showingCache) {
      return const Color(0xFF5C5A72);
    }
    return DiaryAlbumStyle.sage;
  }

  Color get _statusBackground {
    if (isOffline) {
      return const Color(0xFFFFF4D6);
    }
    if (showingCache) {
      return const Color(0xFFF2F2F8);
    }
    return Colors.transparent;
  }
}

class _DiaryMemoryHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _DiaryMemoryHeroChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

class _DiaryMemoryAddButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final bool isLoading;

  const _DiaryMemoryAddButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : () => onTap(),
        style: FilledButton.styleFrom(
          backgroundColor: DiaryAlbumStyle.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DiaryAlbumStyle.rose.withValues(alpha: 0.65),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.tr('Lưu giữ kỷ niệm mới ✨'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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

class _DiaryMemoryScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DiaryMemoryScaleOnPress({
    required this.child,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_DiaryMemoryScaleOnPress> createState() =>
      _DiaryMemoryScaleOnPressState();
}

class _DiaryMemoryScaleOnPressState extends State<_DiaryMemoryScaleOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: () {
        _controller.reverse();
        widget.onLongPress();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: 1 - _controller.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
