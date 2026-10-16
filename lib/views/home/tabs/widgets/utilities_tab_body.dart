import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/utility_service.dart';
import 'utilities_category_section.dart';
import 'utilities_daily_pick_card.dart';
import 'utilities_hub_header.dart';
import 'utilities_recent_row.dart';
import 'utilities_scrapbook_design.dart';

class UtilitiesTabBody extends StatefulWidget {
  const UtilitiesTabBody({
    super.key,
    required this.categories,
    required this.recentApps,
    required this.pinnedIds,
    required this.dailyPick,
    required this.dailyPickApp,
    required this.onAppTap,
    required this.onAppLongPress,
  });

  final Map<UtilityCategory, List<UtilityApp>> categories;
  final List<UtilityApp> recentApps;
  final Set<String> pinnedIds;
  final UtilityDailyPick? dailyPick;
  final UtilityApp? dailyPickApp;
  final ValueChanged<String> onAppTap;
  final ValueChanged<UtilityApp>? onAppLongPress;

  @override
  State<UtilitiesTabBody> createState() => _UtilitiesTabBodyState();
}

class _UtilitiesTabBodyState extends State<UtilitiesTabBody> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipsController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<UtilityCategory, GlobalKey> _sectionKeys = {
    for (final category in UtilityCategory.values) category: GlobalKey(),
  };
  final Map<UtilityCategory?, GlobalKey> _chipKeys = {
    null: GlobalKey(),
    for (final category in UtilityCategory.values) category: GlobalKey(),
  };

  UtilityCategory? _activeCategory;
  double _pinnedHeaderExtent = 0;
  bool _isAutoScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  RenderBox? get _viewportBox {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.attached
        ? renderObject
        : null;
  }

  /// Khoảng cách từ đỉnh vùng cuộn tới đầu nhóm.
  double? _sectionTop(UtilityCategory category, RenderBox viewport) {
    final renderObject = _sectionKeys[category]?.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Bỏ qua các hàng cuộn ngang bên trong.
    if (notification.depth != 0 || _isAutoScrolling) return false;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _syncActiveCategory();
    }
    return false;
  }

  void _syncActiveCategory() {
    final viewport = _viewportBox;
    if (viewport == null || !_scrollController.hasClients) return;
    final threshold = _pinnedHeaderExtent + 24;
    UtilityCategory? next;
    for (final category in widget.categories.keys) {
      final top = _sectionTop(category, viewport);
      if (top == null) continue;
      if (top > threshold) break;
      next = category;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 2 &&
        widget.categories.isNotEmpty) {
      // Nhóm cuối quá ngắn để chạm ngưỡng, nhưng đã hiện trọn khi cuộn hết.
      next = widget.categories.keys.last;
    }
    _setActiveCategory(next);
  }

  void _setActiveCategory(UtilityCategory? category) {
    if (category == _activeCategory) return;
    setState(() => _activeCategory = category);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChip(category));
  }

  void _revealChip(UtilityCategory? category) {
    if (!mounted || !_chipsController.hasClients) return;
    final renderObject = _chipKeys[category]?.currentContext
        ?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;
    final position = _chipsController.position;
    final target = viewport
        .getOffsetToReveal(renderObject, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _chipsController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _selectCategory(UtilityCategory? category) async {
    HapticFeedback.selectionClick();
    _setActiveCategory(category);
    if (!_scrollController.hasClients) return;
    var target = 0.0;
    if (category != null) {
      final viewport = _viewportBox;
      final top = viewport == null ? null : _sectionTop(category, viewport);
      if (top == null) return;
      target = _scrollController.offset + top - _pinnedHeaderExtent - 8;
    }
    final position = _scrollController.position;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    _isAutoScrolling = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAutoScrolling = false;
    }
  }

  List<Widget> _buildContent(BuildContext context) {
    final pick = widget.dailyPick;
    final pickApp = widget.dailyPickApp;
    final children = <Widget>[const SizedBox(height: 14)];

    if (pick != null && pickApp != null) {
      children
        ..add(
          UtilitiesDailyPickCard(
            pick: pick,
            app: pickApp,
            onOpen: () => widget.onAppTap(pickApp.id),
          ),
        )
        ..add(const SizedBox(height: 20));
    }

    if (widget.recentApps.isNotEmpty) {
      children
        ..add(
          UtilitiesRecentRow(
            apps: widget.recentApps,
            pinnedIds: widget.pinnedIds,
            onTap: (app) => widget.onAppTap(app.id),
            onLongPress: widget.onAppLongPress,
          ),
        )
        ..add(const SizedBox(height: 20));
    }

    for (final entry in widget.categories.entries) {
      children
        ..add(
          KeyedSubtree(
            key: _sectionKeys[entry.key],
            child: UtilitiesCategorySection(
              category: entry.key,
              apps: entry.value,
              pinnedIds: widget.pinnedIds,
              onTap: (app) => widget.onAppTap(app.id),
              onLongPress: widget.onAppLongPress,
            ),
          ),
        )
        ..add(const SizedBox(height: 22));
    }

    // Gợi ý nhấn giữ chỉ hiện khi màn có thao tác nhấn giữ.
    if (widget.onAppLongPress != null) children.add(const _LongPressHint());
    children.add(const SizedBox(height: 120));
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final textScale = (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
      1.0,
      1.3,
    );
    final titleExtent = 88.0 * textScale;
    final chipsExtent = (48.0 * textScale).clamp(48.0, 62.0) + 16;
    _pinnedHeaderExtent = topInset + chipsExtent;

    return UtilitiesScrapbookBackdrop(
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: CustomScrollView(
          key: _viewportKey,
          controller: _scrollController,
          physics: SLResponsive.scrollPhysicsForPlatform(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: UtilitiesHubHeaderDelegate(
                topInset: topInset,
                titleExtent: titleExtent,
                chipsExtent: chipsExtent,
                title: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: const UtilitiesHubTitle(),
                ),
                chips: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: UtilitiesCategoryChips(
                    categories: widget.categories.keys.toList(growable: false),
                    active: _activeCategory,
                    onSelected: _selectCategory,
                    controller: _chipsController,
                    chipKeys: _chipKeys,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildContent(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LongPressHint extends StatelessWidget {
  const _LongPressHint();

  @override
  Widget build(BuildContext context) {
    final colors = UtilitiesScrapbookColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.push_pin_outlined, size: 14, color: colors.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr('utilities_long_press_hint'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.muted,
            ),
          ),
        ),
      ],
    );
  }
}
