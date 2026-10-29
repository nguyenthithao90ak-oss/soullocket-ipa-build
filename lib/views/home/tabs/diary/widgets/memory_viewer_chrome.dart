import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/l10n_service.dart';
import 'diary_album_style.dart';

const _memoryActions = [
  (
    value: 'save',
    label: 'home_lunh_9088ba',
    icon: Icons.save_alt_rounded,
    color: DiaryAlbumStyle.sage,
    wash: Color(0xFFEAF1EC),
  ),
  (
    value: 'share',
    label: 'home_chiasnh_003604',
    icon: Icons.ios_share_rounded,
    color: Color(0xFF766593),
    wash: Color(0xFFF0EBF7),
  ),
  (
    value: 'info',
    label: 'home_chititnh_958bbd',
    icon: Icons.info_outline_rounded,
    color: Color(0xFF947044),
    wash: Color(0xFFF5EEDF),
  ),
  (
    value: 'delete',
    label: 'home_xanh_0b98d1',
    icon: Icons.delete_outline_rounded,
    color: Color(0xFFB35F62),
    wash: Color(0xFFF8EBE9),
  ),
];

class MemoryViewerActionsButton extends StatelessWidget {
  const MemoryViewerActionsButton({
    super.key,
    required this.onSelected,
    this.isVideo = false,
  });

  final ValueChanged<String> onSelected;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return PopupMenuButton<String>(
      key: const ValueKey('memory-viewer-actions'),
      tooltip: context.tr(isVideo ? 'memory_video_options' : 'home_tychnnh_5e18e0'),
      constraints: BoxConstraints(
        minWidth: (width - 40).clamp(0, 244),
        maxWidth: (width - 40).clamp(0, 300),
      ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      padding: const EdgeInsets.all(12),
      color: colors.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.line),
      ),
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 38,
          child: _MemoryActionsHeading(isVideo: isVideo),
        ),
        for (final action in _memoryActions) ...[
          if (action.value == 'delete') const PopupMenuDivider(height: 12),
          PopupMenuItem<String>(
            key: ValueKey('memory-action-${action.value}'),
            value: action.value,
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _MemoryActionContent(action: action.value, isVideo: isVideo),
          ),
        ],
      ],
      onSelected: onSelected,
    );
  }
}

class MemoryViewerActionSheet extends StatelessWidget {
  const MemoryViewerActionSheet({super.key, this.isVideo = false});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: colors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 3, color: colors.line),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                child: _MemoryActionsHeading(isVideo: isVideo),
              ),
              for (final action in _memoryActions) ...[
                if (action.value == 'delete')
                  Divider(height: 16, color: colors.line),
                InkWell(
                  key: ValueKey('memory-action-${action.value}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).pop(action.value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: _MemoryActionContent(action: action.value, isVideo: isVideo),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryActionsHeading extends StatelessWidget {
  const _MemoryActionsHeading({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(isVideo ? 'memory_video_options' : 'home_tychnnh_5e18e0'),
    style: SLTheme.quicksand(
      color: DiaryAlbumPalette.of(context).muted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _MemoryActionContent extends StatelessWidget {
  const _MemoryActionContent({required this.action, required this.isVideo});

  final String action;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    final item = _memoryActions.firstWhere((item) => item.value == action);
    final label = isVideo
        ? switch (action) {
            'save' => 'memory_video_save',
            'share' => 'memory_video_share',
            'info' => 'memory_video_details',
            _ => 'memory_video_delete',
          }
        : item.label;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.isDark
                ? colors.tint(item.color).withValues(alpha: 0.12)
                : item.wash,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: colors.tint(item.color), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(label),
            style: SLTheme.quicksand(
              color: item.value == 'delete'
                  ? colors.tint(item.color)
                  : colors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class MemoryViewerFooter extends StatelessWidget {
  const MemoryViewerFooter({
    super.key,
    required this.position,
    required this.total,
    required this.timestamp,
    this.topPadding = 48,
  });

  final int position;
  final int total;
  final String timestamp;

  /// Khoảng đệm phía trên chữ; thu nhỏ khi thanh tua video nằm ngay phía trên.
  final double topPadding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xB8000000), Color(0xD1000000)],
        stops: [0, 0.12, 1],
      ),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        topPadding,
        22,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: MemoryViewerCaption(
        position: position,
        total: total,
        timestamp: timestamp,
      ),
    ),
  );
}

class MemoryViewerCaption extends StatelessWidget {
  const MemoryViewerCaption({
    super.key,
    required this.position,
    required this.total,
    required this.timestamp,
  });

  final int position;
  final int total;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      context.tr('memory_viewer_caption_title'),
      style: SLTheme.quicksand(
        color: const Color(0xFFFFF9F1),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.4,
      ),
    );
    final date = Text(
      timestamp,
      style: SLTheme.quicksand(
        color: const Color(0xFFD8D6D1),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
    final counter = Semantics(
      container: true,
      label: L10nService().format('memory_viewer_position', {
        'current': position,
        'total': total,
      }),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$position / $total',
          textDirection: TextDirection.ltr,
          style: SLTheme.quicksand(
            color: const Color(0xFFE1E7DB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
      ),
    );
    return Column(
      key: const ValueKey('memory-viewer-caption'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 18,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [date, counter],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [title, const SizedBox(height: 3), date],
                  ),
                ),
                const SizedBox(width: 20),
                counter,
              ],
            );
          },
        ),
      ],
    );
  }
}
