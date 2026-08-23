import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/skeleton_container.dart';

import '../controllers/diary_memory_controller.dart';
import 'diary_tab_shell_sections.dart';

const Color _diaryMemoryAccentColor = Color(0xFFFF4D79);

typedef DiaryPrepareMemoryFeedCallback = PreparedDiaryMemoryFeed Function({
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
  ) onOpenMemory;
  final bool isLoadingMoreMemories;
  final VoidCallback onLoadMore;
  final Future<void> Function(Map<String, dynamic> photo) onEnsurePhotoUrl;
  final Future<void> Function(
    DateTime selectedDate,
    List<Map<String, dynamic>> photos,
  ) onEditGroupDate;

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
      _scrollIndicatorNotifier =
      ValueNotifier((isVisible: false, label: '', fraction: 0.0));
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
            'Lọc theo tháng',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
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
                    ? 'Tất cả'
                    : DateFormat('MM/yyyy').format(months[index - 1]);
                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : const Color(0xFF8A5B76),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFD81B60),
                  backgroundColor: Colors.white.withValues(alpha: 0.7),
                  elevation: isSelected ? 4 : 0,
                  shadowColor: const Color(0xFFD81B60).withValues(alpha: 0.3),
                  side: isSelected
                      ? BorderSide.none
                      : BorderSide(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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
              final isOffline = connSnapshot.hasData &&
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

                      final waitingForLive = !isOffline &&
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
                          final useLiveSource = !isOffline &&
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
                                SliverToBoxAdapter(
                                  child: _buildMonthFilter(),
                                ),
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
                                            bottom: 8, left: 10, right: 10),
                                        child: Row(
                                          children: [
                                            for (int i = 0;
                                                i < rowPhotos.length;
                                                i++) ...[
                                              if (i > 0) const SizedBox(width: 8),
                                              Expanded(
                                                child: AspectRatio(
                                                  aspectRatio:
                                                      1.0, // Cố định tỷ lệ vuông cho mỗi ảnh trong hàng
                                                  child: _DiaryMemoryPhotoCell(
                                                    key: ValueKey(rowPhotos[i]
                                                            ['id'] ??
                                                        'photo_${index * 10 + i}'),
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
                                                    onToggleSelection:
                                                        widget.onToggleSelection,
                                                    onOpenMemory:
                                                        widget.onOpenMemory,
                                                    allPhotos: filteredPhotos,
                                                    onEnsurePhotoUrl:
                                                        widget.onEnsurePhotoUrl,
                                                  ),
                                                ),
                                              ),
                                            ]
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFCE4EC)
                                            .withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: const Color(0xFFF48FB1),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFD81B60)
                                                .withValues(alpha: 0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Hết ảnh rồi nha bạn yêu !!!!',
                                        style: SLTheme.quicksand(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD81B60),
                                        ),
                                      ),
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
                                  style:
                                      const TextStyle(color: Colors.redAccent),
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
                                  fraction: fraction
                                );

                                _hideIndicatorTimer?.cancel();
                                _hideIndicatorTimer = Timer(
                                    const Duration(milliseconds: 1200), () {
                                  _scrollIndicatorNotifier.value = (
                                    isVisible: false,
                                    label: _scrollIndicatorNotifier.value.label,
                                    fraction:
                                        _scrollIndicatorNotifier.value.fraction
                                  );
                                });
                              }
                              return false;
                            },
                            child: RawScrollbar(
                              controller: _scrollController,
                              thumbColor: const Color(0xFFD81B60)
                                  .withValues(alpha: 0.6),
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
                                  if (widget.header != null)
                                    SliverSafeArea(
                                      bottom: false,
                                      sliver: SliverToBoxAdapter(
                                          child: widget.header!),
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
                              ({
                                bool isVisible,
                                String label,
                                double fraction
                              })>(
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
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD81B60),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFD81B60)
                                                .withValues(alpha: 0.4),
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
                                              size: 14),
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
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C8BFF).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(-2, -2),
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
                  context.tr('home_albumngy_7e474f'),
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
              L10nService().format(
                'diary_photos_count',
                {'count': totalPhotos},
              ),
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
      margin: const EdgeInsets.only(top: 20, bottom: 8, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEEF7), Color(0xFFF3F0FF), Color(0xFFEAFBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
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
                  context.tr('home_storycbit_5a2a17'),
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
              L10nService().format(
                'diary_photos_count',
                {'count': totalPhotos},
              ),
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
  ) onOpenMemory;
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
      _refreshUrlsIfNeeded();
    }
  }

  Future<void> _refreshUrlsIfNeeded() async {
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

  Widget _buildVideoThumbnail(
      Map<String, dynamic> photo, String videoUrl) {
    final thumbUrl = photo['thumbnailUrl']?.toString().trim() ?? '';
    if (thumbUrl.isEmpty) {
      // Fallback: không có thumbnail → icon play trên nền trắng
      return Container(
        color: const Color(0xFFF8FAFC),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Color(0xFF94A3B8),
            size: 48,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: thumbUrl,
          memCacheWidth: widget.thumbnailCacheWidth,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          placeholder: (context, url) =>
              Container(color: const Color(0xFFF1F5F9)),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFFF8FAFC),
            child: const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Color(0xFF94A3B8), size: 48),
            ),
          ),
        ),
        // Overlay icon play
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
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

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final photoUrl = _resolvePhotoUrl(photo);
    final photoId = photo['id']?.toString() ?? 'unknown_${widget.index}';

    final isStickerOrPng = photoUrl.toLowerCase().contains('.webp') ||
        photo['isSticker'] == true ||
        photo['isCutout'] == true;

    final isVideo = photo['type']?.toString().toLowerCase() == 'video' ||
        photoUrl.toLowerCase().endsWith('.mp4') ||
        photoUrl.toLowerCase().endsWith('.mov');

    if (photoUrl.isEmpty) {
      if (_retryCount < 1) {
        _retryCount++;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            await _refreshStalePhotoUrl(photo);
          } catch (_) {}
        });
      }
      return Container(
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
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: widget.selectionListenable,
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: isStickerOrPng
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF5C71D8).withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Hero(
              tag: 'memory_image_${photo['id']}',
              child: isVideo 
                  ? _buildVideoThumbnail(photo, photoUrl)
                  : CachedNetworkImage(
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
                        if (_retryCount < 2) {
                          _retryCount++;
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            if (!mounted) return;
                            try {
                              if (_retryCount > 1) {
                                photo['broken'] = true;
                              } else {
                                await _refreshStalePhotoUrl(photo);
                              }
                            } catch (_) {
                              photo['broken'] = true;
                            }
                          });
                        }
                        if (_retryCount >= 2 || photo['broken'] == true) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          color: const Color(0xFFF8FAFC),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF94A3B8),
                                size: 24,
                              ),
                            ],
                          ),
                        );
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
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                      ],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              if (widget.isSelectionMode)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.black.withValues(alpha: 0.4),
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
                            color: Color(0xFFD81B60),
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
        label: L10nService().format(
          'diary_photos_count',
          {'count': totalPhotos},
        ),
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF85A1), Color(0xFFFFA6C1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_knimcachng_692bf0'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2E2740),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lưu giữ khoảnh khắc yêu thương 💕',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8C7E95),
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
            children: statusChips,
          ),
          const SizedBox(height: 14),
          _DiaryMemoryAddButton(
            onTap: onAdd,
            isLoading: isUploading,
          ),
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
                      onPressed:
                          isUploading ? null : () => onRetryPendingUpload(),
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
    return const Color(0xFF1D8F62);
  }

  Color get _statusBackground {
    if (isOffline) {
      return const Color(0xFFFFF4D6);
    }
    if (showingCache) {
      return const Color(0xFFF2F2F8);
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

class _DiaryMemoryAddButton extends StatefulWidget {
  final Future<void> Function() onTap;
  final bool isLoading;

  const _DiaryMemoryAddButton({
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_DiaryMemoryAddButton> createState() => _DiaryMemoryAddButtonState();
}

class _DiaryMemoryAddButtonState extends State<_DiaryMemoryAddButton>
    with SingleTickerProviderStateMixin {
  bool _showOnboarding = false;
  late final AnimationController _pulseCtrl;
  static const _prefKey = 'diary_memory_onboarding_done';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkFirstVisit();
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_prefKey) ?? false;
    if (!done && mounted) {
      setState(() => _showOnboarding = true);
    }
  }

  Future<void> _dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Onboarding tooltip ──
        if (_showOnboarding)
          GestureDetector(
            onTap: _dismissOnboarding,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nhấn vào đây để đăng nhật ký, video, ảnh kỷ niệm nhé! 💕',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ),
        // ── Button with optional glow ring ──
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final glowAlpha = _showOnboarding
                ? 0.15 + (_pulseCtrl.value * 0.20)
                : 0.0;
            return Container(
              decoration: _showOnboarding
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7)
                              .withValues(alpha: glowAlpha),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    )
                  : null,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading
                  ? null
                  : () {
                      if (_showOnboarding) _dismissOnboarding();
                      widget.onTap();
                    },
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7EB3).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      'Đăng kỷ niệm mới ✨',
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
          return Transform.scale(
            scale: 1 - _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
