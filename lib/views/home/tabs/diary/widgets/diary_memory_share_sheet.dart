import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/sl_notice.dart';
import 'diary_album_style.dart';

enum DiaryMemoryShareAction { files, cuteLink }

class DiaryMemoryShareSheet extends StatefulWidget {
  const DiaryMemoryShareSheet({
    super.key,
    required this.photosOnly,
    required this.onShareFiles,
  });

  final bool photosOnly;
  final Future<void> Function(Rect origin, bool Function() isCurrent)
  onShareFiles;

  @override
  State<DiaryMemoryShareSheet> createState() => _DiaryMemoryShareSheetState();
}

class _DiaryMemoryShareSheetState extends State<DiaryMemoryShareSheet> {
  bool _busy = false;

  Future<void> _shareFiles() async {
    if (_busy) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await widget.onShareFiles(origin, () => mounted);
      if (mounted) Navigator.of(context).pop(DiaryMemoryShareAction.files);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      SLNotice.showError(
        context,
        AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('share_send_failed'),
        ).message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DiaryAlbumPalette.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: palette.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 3, color: palette.line),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('memory_media_share_title'),
                style: SLTheme.quicksand(
                  color: palette.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                key: const ValueKey('diary-share-files'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                enabled: !_busy,
                leading: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.ios_share_rounded, color: palette.ink),
                title: Text(
                  context.tr(
                    _busy
                        ? 'memory_media_share_preparing'
                        : 'memory_media_share_apps',
                  ),
                  style: SLTheme.quicksand(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  context.tr('memory_media_share_apps_hint'),
                  style: SLTheme.quicksand(color: palette.muted, height: 1.5),
                ),
                onTap: _shareFiles,
              ),
              if (widget.photosOnly) ...[
                Divider(height: 20, color: palette.line),
                ListTile(
                  key: const ValueKey('diary-share-cute-link'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  enabled: !_busy,
                  leading: Icon(Icons.link_rounded, color: palette.ink),
                  title: Text(
                    context.tr('memory_media_share_cute_link'),
                    style: SLTheme.quicksand(
                      color: palette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    context.tr('memory_media_share_cute_hint'),
                    style: SLTheme.quicksand(color: palette.muted, height: 1.5),
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(DiaryMemoryShareAction.cuteLink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
