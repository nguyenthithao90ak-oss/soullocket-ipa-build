import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/custom_mood_sticker_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/r2_sticker_image.dart';
import '../../../widgets/sl_feedback.dart';

const _diaryRose = Color(0xFFB65C86);
const _diaryLilac = Color(0xFF8873BD);
const _diaryInk = Color(0xFF51455D);

class DiaryComposer extends StatefulWidget {
  final String houseId;
  final List<Map<String, dynamic>> moods;
  final String selectedMood;
  final ValueChanged<String> onMoodChanged;
  final TextEditingController composerController;
  final bool isPostingDiary;
  final VoidCallback onSubmit;
  final CustomMoodStickerService? stickerService;

  const DiaryComposer({
    super.key,
    required this.houseId,
    required this.moods,
    required this.selectedMood,
    required this.onMoodChanged,
    required this.composerController,
    required this.isPostingDiary,
    required this.onSubmit,
    this.stickerService,
  });

  @override
  State<DiaryComposer> createState() => _DiaryComposerState();
}

class _DiaryComposerState extends State<DiaryComposer> {
  final _focusNode = FocusNode();
  CustomMoodStickerService get _stickers =>
      widget.stickerService ?? CustomMoodStickerService.instance;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedMood {
    for (final mood in widget.moods) {
      if (mood['icon'] == widget.selectedMood) return mood;
    }
    return null;
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message =
        error is FormatException && error.message == 'image-too-large'
        ? context.tr('diary_custom_sticker_too_large')
        : error is StateError && error.message.startsWith('Upload failed')
        ? context.tr('diary_custom_sticker_upload_failed')
        : AppErrorMapper.resolve(
            error,
            fallbackMessage: context.tr('diary_custom_sticker_upload_failed'),
          ).message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SLSnackBar(content: Text(message)));
  }

  Future<void> _pickSticker() async {
    if (_stickers.isBusyVN.value || widget.isPostingDiary) return;
    final houseId = widget.houseId;
    try {
      final url = await _stickers.pickAndUploadSticker(houseId);
      if (!mounted || houseId != widget.houseId || url == null) return;
      widget.onMoodChanged('📷');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _removeSticker() async {
    if (_stickers.isBusyVN.value || widget.isPostingDiary) return;
    final houseId = widget.houseId;
    try {
      await _stickers.removeSticker(houseId);
      if (!mounted || houseId != widget.houseId) return;
      if (widget.selectedMood == '📷') {
        final fallback = widget.moods
            .where((mood) => mood['isCustom'] != true)
            .firstOrNull;
        if (fallback != null) widget.onMoodChanged(fallback['icon'] as String);
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _showStickerOptions() {
    if (_stickers.isBusyVN.value || widget.isPostingDiary) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF8FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_photo_alternate_rounded,
                color: _diaryLilac,
              ),
              title: Text(
                context.tr('diary_custom_sticker_replace'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickSticker();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: _diaryRose,
              ),
              title: Text(
                context.tr('diary_custom_sticker_remove'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _removeSticker();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _stickers.isBusyVN,
        _stickers.isUploadingVN,
        _focusNode,
      ]),
      builder: (context, child) {
        final locked = _stickers.isBusyVN.value || widget.isPostingDiary;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFAF5), Color(0xFFFFF4F9), Color(0xFFF6F2FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FBF83A5),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeading(context),
                const SizedBox(height: 16),
                _buildMoodShelf(context, locked),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.photo_outlined,
                        size: 14,
                        color: _diaryLilac,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr(
                          _stickers.isUploadingVN.value
                              ? 'diary_custom_sticker_uploading'
                              : 'diary_custom_sticker_hint',
                        ),
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          color: const Color(0xFF796C85),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildNoteField(context),
                const SizedBox(height: 14),
                _buildSubmitButton(context, locked),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeading(BuildContext context) {
    final selectedMood = _selectedMood;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF8DFE9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.favorite_border_rounded,
            color: _diaryRose,
            size: 25,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('home_tms_f029b6'),
                style: SLTheme.quicksand(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _diaryInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('diary_composer_caption'),
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF867287),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (selectedMood != null)
          Transform.rotate(
            angle: 0.07,
            child: Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFEADDF4)),
              ),
              child: _moodImage(selectedMood, size: 40),
            ),
          ),
      ],
    );
  }

  Widget _moodImage(Map<String, dynamic> mood, {required double size}) {
    if (mood['isCustom'] == true) {
      final url = mood['customUrl'] as String?;
      if (url == null || url.isEmpty) {
        return const Icon(Icons.add_rounded, color: _diaryLilac, size: 28);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          memCacheWidth: 160,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          placeholder: (_, _) =>
              const Icon(Icons.photo_outlined, color: _diaryLilac),
          errorWidget: (_, _, _) => const Icon(
            Icons.image_not_supported_outlined,
            color: _diaryLilac,
          ),
        ),
      );
    }
    return R2StickerImage(
      mood['asset'] as String,
      width: size,
      height: size,
      fit: BoxFit.contain,
      animateLocalSticker: true,
      errorWidget: Center(
        child: Text(
          mood['icon'] as String,
          style: TextStyle(fontSize: size * 0.65),
        ),
      ),
    );
  }

  Widget _buildMoodShelf(BuildContext context, bool locked) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFEDE0F1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.moods.isEmpty) return const SizedBox.shrink();
          const spacing = 8.0;
          final textScaler = MediaQuery.textScalerOf(context);
          final scale = textScaler.scale(11) / 11;
          final minWidth = 72.0 + (scale - 1).clamp(0, 4) * 44;
          final columns =
              ((constraints.maxWidth + spacing) / (minWidth + spacing))
                  .floor()
                  .clamp(1, 5);
          final tileWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          var labelHeight = 0.0;
          for (final mood in widget.moods) {
            final painter = TextPainter(
              text: TextSpan(
                text: _moodLabel(context, mood),
                style: _moodLabelStyle(false),
              ),
              textDirection: Directionality.of(context),
              textScaler: textScaler,
            )..layout(maxWidth: tileWidth - 16);
            if (painter.height > labelHeight) labelHeight = painter.height;
            painter.dispose();
          }
          final tileHeight = (43 + 6 + 16 + 4 + labelHeight).ceilToDouble();
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final mood in widget.moods)
                _moodTile(
                  context,
                  mood,
                  locked,
                  width: tileWidth,
                  height: tileHeight,
                ),
            ],
          );
        },
      ),
    );
  }

  String _moodLabel(BuildContext context, Map<String, dynamic> mood) {
    final url = mood['customUrl'] as String?;
    return mood['isCustom'] == true && (url == null || url.isEmpty)
        ? context.tr('diary_custom_sticker_add')
        : mood['label'] as String;
  }

  TextStyle _moodLabelStyle(bool active) => SLTheme.quicksand(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: active ? _diaryRose : const Color(0xFF80728B),
  );

  Widget _moodTile(
    BuildContext context,
    Map<String, dynamic> mood,
    bool locked, {
    required double width,
    required double height,
  }) {
    final isCustom = mood['isCustom'] == true;
    final url = mood['customUrl'] as String?;
    final hasImage = url != null && url.isNotEmpty;
    final active =
        widget.selectedMood == mood['icon'] && (!isCustom || hasImage);
    final label = _moodLabel(context, mood);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: active,
        enabled: !locked,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('diary-mood-${mood['icon']}'),
            borderRadius: BorderRadius.circular(18),
            onTap: locked
                ? null
                : () {
                    if (isCustom && !hasImage) {
                      _pickSticker();
                    } else if (isCustom && active) {
                      _showStickerOptions();
                    } else {
                      widget.onMoodChanged(mood['icon'] as String);
                    }
                  },
            onLongPress: isCustom && hasImage && !locked
                ? _showStickerOptions
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFEDF4)
                    : isCustom
                    ? const Color(0xFFF1EAFB)
                    : const Color(0xFFFFFCFD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? const Color(0xFFD69AB6) : Colors.white,
                  width: active ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 43,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isCustom && _stickers.isBusyVN.value)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _diaryLilac,
                            ),
                          )
                        else
                          _moodImage(mood, size: 43),
                        if (active)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _diaryRose,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: _moodLabelStyle(active),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _focusNode.hasFocus
              ? const Color(0xFFC5ACDF)
              : const Color(0xFFEEDDCD),
          width: 1.3,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.composerController,
        minLines: 3,
        maxLines: 6,
        maxLength: 5000,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.6,
          color: _diaryInk,
        ),
        decoration: InputDecoration(
          hintText: context.tr('home_hmnaythnog_0c01f7'),
          hintStyle: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9B8692),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterStyle: SLTheme.quicksand(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF978B94),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool locked) {
    return Opacity(
      opacity: locked && !widget.isPostingDiary ? 0.55 : 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_diaryRose, _diaryLilac]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26B65C86),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('diary-submit'),
            borderRadius: BorderRadius.circular(18),
            onTap: locked ? null : widget.onSubmit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: widget.isPostingDiary
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            context.tr('home_lutms_b4b0f3'),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: Colors.white,
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
