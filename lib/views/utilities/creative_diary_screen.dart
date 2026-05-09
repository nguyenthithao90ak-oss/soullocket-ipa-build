import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/sl_theme.dart';
import '../../services/creative_diary_service.dart';
import '../../services/house_service.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/admob_service.dart';
import '../home/tabs/diary/controllers/diary_guard_controller.dart';

part 'creative_diary/creative_diary_create_sheet.dart';
part 'creative_diary/creative_diary_export_flow.dart';

class CreativeDiaryScreen extends StatefulWidget {
  final String? houseId;

  const CreativeDiaryScreen({super.key, this.houseId});

  @override
  State<CreativeDiaryScreen> createState() => _CreativeDiaryScreenState();
}

class _CreativeDiaryScreenState extends State<CreativeDiaryScreen> {
  static const Duration _rewardedSaveCooldown = Duration(minutes: 10);
  static const String _rewardedSaveUnlockedUntilPrefsKey =
      'creative_diary_rewarded_save_unlocked_until_ms_v1';

  final PageController _pageController = PageController(viewportFraction: 0.96);
  final CreativeDiaryService _creativeDiaryService = CreativeDiaryService();
  final StorageService _storageService = StorageService();
  final HouseService _houseService = HouseService();
  final DiaryGuardController _guardController = DiaryGuardController();
  final GlobalKey _exportBoundaryKey = GlobalKey();
  final List<_DiaryPageData> _pages = [];

  StreamSubscription<List<Map<dynamic, dynamic>>>? _pagesSubscription;

  int _currentIndex = 0;
  int _exportPageIndex = 0;
  String? _houseId;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSaving = false;
  bool _isExportingNotebook = false;
  String? _exportStatus;
  String? _exportDetail;
  _DiaryPageData? _exportPage;

  @override
  void initState() {
    super.initState();
    unawaited(AdMobService().initialize());
    _init();
  }

  Future<void> _init() async {
    final resolvedHouseId =
        widget.houseId ?? await _houseService.getCurrentHouseId();
    if (!mounted) {
      return;
    }

    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      setState(() {
        _houseId = null;
        _isLoading = false;
      });
      return;
    }

    _houseId = resolvedHouseId;
    await _pagesSubscription?.cancel();
    _pagesSubscription =
        _creativeDiaryService.listenToDiaryPages(resolvedHouseId).listen(
      (rawPages) {
        final nextPages = <_DiaryPageData>[];
        for (var index = 0; index < rawPages.length; index++) {
          nextPages.add(_DiaryPageData.fromMap(rawPages[index], index));
        }

        if (!mounted) {
          return;
        }
        final hasExistingPages = _pages.isNotEmpty;
        setState(() {
          _pages
            ..clear()
            ..addAll(nextPages);
          if (_pages.isEmpty) {
            _currentIndex = 0;
          } else if (_currentIndex >= _pages.length) {
            _currentIndex = _pages.length - 1;
          }
          _isLoading = false;
          _isRefreshing = hasExistingPages;
        });
        if (hasExistingPages) {
          Future<void>.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            setState(() => _isRefreshing = false);
          });
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _pagesSubscription?.cancel();
    _pageController.dispose();
    _guardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;
    final safeIndex = hasPages ? _currentIndex.clamp(0, _pages.length - 1) : 0;
    final _DiaryPageData? activePage = hasPages ? _pages[safeIndex] : null;
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.width < 360;
    final compactHeight = screenSize.height < 760;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(
        context,
        'Sổ tay kỷ niệm 📖',
        actions: [
          if (hasPages)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<_DiarySaveTarget>(
                tooltip: 'Lưu sổ tay',
                enabled: !_isExportingNotebook,
                onSelected: (target) {
                  if (target == _DiarySaveTarget.currentPage) {
                    _saveCurrentPageToDevice();
                    return;
                  }
                  _saveNotebookToDevice();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_DiarySaveTarget>(
                    value: _DiarySaveTarget.currentPage,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bookmark_added_rounded),
                      title: Text('Lưu trang đang xem'),
                    ),
                  ),
                  PopupMenuItem<_DiarySaveTarget>(
                    value: _DiarySaveTarget.fullNotebook,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.collections_bookmark_rounded),
                      title: Text('Lưu toàn bộ sổ tay'),
                    ),
                  ),
                ],
                icon: _isExportingNotebook
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.download_rounded,
                        color: SLColors.primaryActive,
                      ),
              ),
            ),
        ],
      ),
      floatingActionButton: _houseId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isExportingNotebook ? null : _showCreateSheet,
              backgroundColor: SLColors.primaryActive,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                'Viết trang',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: SLTheme.defaultGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 14,
                      compactHeight ? 8 : 12,
                      compact ? 12 : 14,
                      0,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(compact ? 14 : 15),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                            width: 1.6,
                          ),
                        boxShadow: SLTheme.cardShadow,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 340;
                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasPages
                                    ? 'Trang ${safeIndex + 1}/${_pages.length}'
                                    : 'Sổ tay riêng của hai bạn',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: FontWeight.w800,
                                  color: SLColors.primaryActive,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SLSpacing.h8,
                              Text(
                                activePage?.title ?? 'Sổ tay của hai bạn',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 17 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: SLColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              SLSpacing.h8,
                              Text(
                                activePage == null
                                    ? 'Lưu lại những dòng tâm tư đẹp nhất của hai bạn'
                                    : 'Lưu ngày ${DateFormat('dd/MM/yyyy').format(activePage.createdAt)}',
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 11.5 : 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: SLColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                          final chip = Container(
                            constraints: BoxConstraints(
                              maxWidth: narrow
                                  ? constraints.maxWidth
                                  : constraints.maxWidth * 0.28,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  activePage?.surface ?? SLColors.primaryLight,
                              borderRadius: SLRadius.pillAll,
                            ),
                            child: Text(
                              hasPages
                                  ? '${activePage!.wordCount} chữ'
                                  : 'Bắt đầu viết',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w800,
                                color: activePage?.accent ??
                                    SLColors.primaryActive,
                              ),
                            ),
                          );
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [info, SLSpacing.h10, chip],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: info),
                              SLSpacing.w8,
                              Flexible(flex: 0, child: chip),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading && _pages.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            children: [
                              if (hasPages)
                                PageView.builder(
                                  controller: _pageController,
                                  itemCount: _pages.length,
                                  onPageChanged: (value) {
                                    setState(() => _currentIndex = value);
                                  },
                                  itemBuilder: (context, index) {
                                    final page = _pages[index];
                                    return Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        compact ? 4 : 6,
                                        compactHeight ? 12 : 16,
                                        compact ? 4 : 6,
                                        8,
                                      ),
                                      child: _DiaryPageCard(page: page),
                                    );
                                  },
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    compact ? 12 : 14,
                                    compactHeight ? 12 : 16,
                                    compact ? 12 : 14,
                                    8,
                                  ),
                                  child: Center(
                                    child: _CreativeDiaryEmptyCard(
                                      canCreate: _houseId != null,
                                      onCreate: _houseId == null
                                          ? null
                                          : _showCreateSheet,
                                    ),
                                  ),
                                ),
                              if (_isRefreshing)
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 16,
                      8,
                      compact ? 14 : 16,
                      0,
                    ),
                    child: hasPages
                        ? Row(
                            children: List.generate(_pages.length, (index) {
                              final active = index == safeIndex;
                              final page = _pages[index];
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  height: active ? 8 : 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? page.accent
                                        : Colors.white.withValues(alpha: 0.55),
                                    borderRadius: SLRadius.pillAll,
                                  ),
                                ),
                              );
                            }),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (hasPages && activePage?.prompt.trim().isNotEmpty == true)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 16,
                        12,
                        compact ? 14 : 16,
                        compactHeight ? 16 : 20,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: activePage?.surface ??
                                    SLColors.primaryLight,
                                borderRadius: SLRadius.lgAll,
                              ),
                              child: Icon(
                                Icons.lightbulb_rounded,
                                size: 20,
                                color: activePage?.accent ??
                                    SLColors.primaryActive,
                              ),
                            ),
                            SLSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prompt gợi nhớ',
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: SLColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activePage?.prompt ??
                                        'Mỗi trang sẽ hiển thị đúng nội dung bạn đã viết và lưu lại.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: SLColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: compactHeight ? 72 : 84),
                ],
              ),
            ),
            if (_exportPage != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.01,
                    child: SafeArea(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: RepaintBoundary(
                          key: _exportBoundaryKey,
                          child: _DiaryExportPageCard(
                            page: _exportPage!,
                            pageNumber: _exportPageIndex + 1,
                            totalPages: _pages.length,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isExportingNotebook)
              Positioned.fill(
                child: _DiaryExportProgressOverlay(
                  status: _exportStatus ?? 'Đang lưu sổ tay về máy...',
                  detail: _exportDetail ??
                      'Mỗi trang sẽ được lưu thành một ảnh đầy đủ.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DiarySaveTarget {
  currentPage,
  fullNotebook,
}

class _CreativeDiaryEmptyCard extends StatelessWidget {
  final bool canCreate;
  final VoidCallback? onCreate;

  const _CreativeDiaryEmptyCard({
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SLTheme.glassCardStrong,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SLColors.primaryLight,
              borderRadius: SLRadius.xlAll,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: SLColors.primaryActive,
              size: 30,
            ),
          ),
          SLSpacing.h16,
          Text(
            canCreate ? 'Chưa có trang nào' : 'Chưa thể mở sổ tay',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h8,
          Text(
            canCreate
                ? 'Viết trang đầu tiên để sổ tay bắt đầu lưu lại những kỷ niệm quan trọng của hai bạn.'
                : 'Không tìm thấy mã nhà hiện tại nên chưa thể tải dữ liệu sổ tay.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: SLColors.textSecondary,
            ),
          ),
          if (canCreate) ...[
            SLSpacing.h16,
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: SLColors.primaryActive,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.lgAll,
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                'Viết trang đầu tiên',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiaryPageCard extends StatelessWidget {
  final _DiaryPageData page;

  const _DiaryPageCard({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: SLTheme.glassCardStrong,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: page.surface,
                  borderRadius: SLRadius.lgAll,
                ),
                child: Icon(page.icon, color: page.accent),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(page.createdAt)} • ${page.wordCount} chữ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (page.imageUrls.isNotEmpty) ...[
            _DiaryAttachmentStrip(page: page),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: page.surface.withValues(alpha: 0.75),
                borderRadius: SLRadius.xlAll,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  page.memory,
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    height: 1.7,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          SLSpacing.h16,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DiaryMetaChip(
                icon: Icons.event_note_rounded,
                label: DateFormat('dd/MM/yyyy').format(page.createdAt),
                color: page.accent,
                background: page.surface,
              ),
              _DiaryMetaChip(
                icon: Icons.short_text_rounded,
                label: '${page.wordCount} chữ',
                color: SLColors.primaryActive,
                background: SLColors.primaryLight,
              ),
              if (page.prompt.trim().isNotEmpty)
                _DiaryMetaChip(
                  icon: Icons.lightbulb_rounded,
                  label: 'Có gợi nhớ',
                  color: SLColors.accentPurpleDark,
                  background: SLColors.accentPurple.withValues(alpha: 0.16),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryAttachmentStrip extends StatelessWidget {
  final _DiaryPageData page;

  const _DiaryAttachmentStrip({required this.page});

  @override
  Widget build(BuildContext context) {
    final firstImage = page.imageUrls.first;
    final extraCount = page.imageUrls.length - 1;
    return GestureDetector(
      onTap: () => _openImage(context, firstImage),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: page.accent.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                firstImage,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Container(
                  color: page.surface,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_rounded, color: page.accent),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: SLRadius.pillAll,
                  ),
                  child: Text(
                    extraCount > 0 ? 'Bộ sưu tập +$extraCount' : 'Ảnh đính kèm',
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: page.accent,
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: 12,
                bottom: 10,
                child: Icon(Icons.open_in_full_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Container(
                height: 260,
                color: Colors.white,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiaryExportPageCard extends StatelessWidget {
  final _DiaryPageData page;
  final int pageNumber;
  final int totalPages;

  const _DiaryExportPageCard({
    required this.page,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.98),
            page.surface.withValues(alpha: 0.88),
            Colors.white.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: page.surface,
                    borderRadius: SLRadius.lgAll,
                  ),
                  child: Icon(page.icon, color: page.accent),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style: SLTheme.quicksand(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                          height: 1.18,
                        ),
                      ),
                      SLSpacing.h6,
                      Text(
                        'Ngày ${DateFormat('dd/MM/yyyy').format(page.createdAt)}',
                        style: SLTheme.quicksand(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: page.surface,
                    borderRadius: SLRadius.pillAll,
                  ),
                  child: Text(
                    'Trang $pageNumber/$totalPages',
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: page.accent,
                    ),
                  ),
                ),
              ],
            ),
            SLSpacing.h20,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    page.surface.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.96),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: SLRadius.xlAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nội dung',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: page.accent,
                    ),
                  ),
                  SLSpacing.h12,
                  Text(
                    page.memory,
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      height: 1.72,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (page.prompt.trim().isNotEmpty) ...[
              SLSpacing.h16,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: SLColors.bgSubtle,
                  borderRadius: SLRadius.xlAll,
                  border: Border.all(color: SLColors.borderLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: SLColors.accentPurple.withValues(alpha: 0.14),
                        borderRadius: SLRadius.lgAll,
                      ),
                      child: const Icon(
                        Icons.lightbulb_rounded,
                        color: SLColors.accentPurpleDark,
                        size: 18,
                      ),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prompt gợi nhớ',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: SLColors.textPrimary,
                            ),
                          ),
                          SLSpacing.h6,
                          Text(
                            page.prompt,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                              color: SLColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SLSpacing.h16,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DiaryMetaChip(
                  icon: Icons.event_note_rounded,
                  label: DateFormat('dd/MM/yyyy').format(page.createdAt),
                  color: page.accent,
                  background: page.surface,
                ),
                _DiaryMetaChip(
                  icon: Icons.short_text_rounded,
                  label: '${page.wordCount} chữ',
                  color: SLColors.primaryActive,
                  background: SLColors.primaryLight,
                ),
              ],
            ),
            SLSpacing.h16,
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: page.surface,
                  ),
                ),
                SLSpacing.w12,
                Text(
                  'SoulLocket • Sổ tay kỷ niệm',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SLColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryExportProgressOverlay extends StatelessWidget {
  final String status;
  final String detail;

  const _DiaryExportProgressOverlay({
    required this.status,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD9FFF8FB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white),
                boxShadow: SLTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: SLColors.primaryLight,
                      borderRadius: SLRadius.xlAll,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                  SLSpacing.h16,
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiaryMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _DiaryMetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: SLRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SLSpacing.w8,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;

  const _DiaryInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SLColors.textPrimary,
          ),
        ),
        SLSpacing.h8,
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: SLColors.textPrimary,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: SLTheme.quicksand(
              color: SLColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: SLColors.bgSubtle,
            border: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaryPageData {
  final String id;
  final String title;
  final String mood;
  final String memory;
  final String prompt;
  final DateTime createdAt;
  final Color accent;
  final Color surface;
  final IconData icon;
  final List<String> imageUrls;

  int get wordCount => RegExp(r'\S+').allMatches(memory.trim()).length;

  const _DiaryPageData({
    required this.id,
    required this.title,
    required this.mood,
    required this.memory,
    required this.prompt,
    required this.createdAt,
    required this.accent,
    required this.surface,
    required this.icon,
    required this.imageUrls,
  });

  factory _DiaryPageData.fromMap(Map<dynamic, dynamic> raw, int index) {
    final metadata = raw['metadata'] is Map
        ? Map<dynamic, dynamic>.from(raw['metadata'] as Map)
        : <dynamic, dynamic>{};
    final palette = _diaryPaletteAt(index);
    final timestamp = raw['timestamp'];
    final createdAt = timestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    return _DiaryPageData(
      id: '${raw['id'] ?? ''}',
      title: '${metadata['title'] ?? 'Trang kỷ niệm'}',
      mood: '${metadata['mood'] ?? 'Yêu thương'}',
      memory: '${raw['content'] ?? ''}',
      prompt:
          '${metadata['prompt'] ?? 'Hãy thêm một chi tiết nhỏ để ghi nhớ lâu hơn.'}',
      createdAt: createdAt,
      accent: palette.accent,
      surface: palette.surface,
      icon: palette.icon,
      imageUrls: _readImageUrls(raw, metadata),
    );
  }

  static List<String> _readImageUrls(
    Map<dynamic, dynamic> raw,
    Map<dynamic, dynamic> metadata,
  ) {
    final values = <String>[];
    void addValue(Object? value) {
      final text = '${value ?? ''}'.trim();
      if (text.startsWith('http://') || text.startsWith('https://')) {
        values.add(text);
      }
    }

    addValue(raw['imageUrl']);
    addValue(raw['photoUrl']);
    addValue(metadata['imageUrl']);
    addValue(metadata['photoUrl']);
    for (final source in [raw['imageUrls'], metadata['imageUrls']]) {
      if (source is Iterable) {
        for (final item in source) {
          addValue(item);
        }
      } else if (source is Map) {
        for (final item in source.values) {
          addValue(item);
        }
      }
    }
    return values.toSet().toList(growable: false);
  }
}

({
  Color accent,
  Color surface,
  IconData icon,
}) _diaryPaletteAt(int index) {
  final palettes = [
    (
      accent: SLColors.primaryActive,
      surface: SLColors.primaryLight,
      icon: Icons.favorite_rounded,
    ),
    (
      accent: SLColors.info,
      surface: SLColors.infoLight,
      icon: Icons.auto_awesome_rounded,
    ),
    (
      accent: SLColors.success,
      surface: SLColors.successLight,
      icon: Icons.photo_camera_back_rounded,
    ),
    (
      accent: SLColors.warning,
      surface: SLColors.warningLight,
      icon: Icons.wb_sunny_rounded,
    ),
  ];
  return palettes[index % palettes.length];
}
