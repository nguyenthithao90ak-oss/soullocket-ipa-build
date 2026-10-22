import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/calendar/relationship_duration.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';
import 'package:soullocket_app/widgets/sl_image_crop_file.dart';

import '../home/widgets/main_home/hero/balanced_countdown_style.dart';
import '../home/widgets/main_home/hero/relationship_day_counter_content.dart';

enum CoupleShowcaseStyle {
  home,
  polaroid,
  cinema,
  neon,
  floral,
  minimal,
  blush,
  sunshine,
  scrapbook,
  midnight,
}

/// Các tỷ lệ xuất ảnh được chọn độc lập với mẫu màu. Ảnh vẫn được giữ local;
/// khi đổi tỷ lệ, card chỉ bố cục lại chứ không làm mất ảnh đã chọn.
enum CoupleShowcaseRatio {
  square(1, '1:1'),
  portrait(4 / 5, '4:5'),
  classic(3 / 4, '3:4'),
  story(9 / 16, '9:16'),
  landscape(4 / 3, '4:3'),
  wide(16 / 9, '16:9');

  const CoupleShowcaseRatio(this.value, this.label);

  final double value;
  final String label;
}

/// Khung ảnh là một lớp trình bày riêng, không phụ thuộc vào 10 mẫu nền.
enum CoupleShowcaseFrame {
  rounded(Icons.crop_square_rounded, 'couple_showcase_frame_rounded'),
  heart(Icons.favorite_rounded, 'couple_showcase_frame_heart'),
  stamp(Icons.auto_awesome_rounded, 'couple_showcase_frame_stamp'),
  film(Icons.local_movies_rounded, 'couple_showcase_frame_film'),
  arch(Icons.architecture_rounded, 'couple_showcase_frame_arch'),
  ticket(Icons.confirmation_num_rounded, 'couple_showcase_frame_ticket'),
  oval(Icons.circle_outlined, 'couple_showcase_frame_oval');

  const CoupleShowcaseFrame(this.icon, this.labelKey);

  final IconData icon;
  final String labelKey;
}

enum CoupleShowcaseLayout {
  single(1, Icons.crop_portrait_rounded, 'couple_showcase_layout_single'),
  duo(2, Icons.view_column_rounded, 'couple_showcase_layout_duo'),
  trio(3, Icons.dashboard_customize_rounded, 'couple_showcase_layout_trio');

  const CoupleShowcaseLayout(this.maxPhotos, this.icon, this.labelKey);

  final int maxPhotos;
  final IconData icon;
  final String labelKey;
}

/// Các câu thoại có sẵn để card luôn có cảm xúc khác nhau mà không cần
/// người dùng phải tự nghĩ caption từ đầu. Nội dung dùng lại catalog đã dịch
/// của app nên vẫn theo ngôn ngữ đang chọn.
enum CoupleShowcaseQuote {
  dailyMemory('couple_showcase_tagline', Icons.auto_awesome_rounded),
  memorablePage('home_together_subtitle', Icons.menu_book_rounded),
  pieceByPiece('soul_block_tagline', Icons.extension_rounded),
  littleNote('diary_composer_caption', Icons.edit_note_rounded),
  littleLove('reward_store_tagline', Icons.favorite_border_rounded),
  keepMoments('settings_footer_tagline', Icons.photo_library_rounded);

  const CoupleShowcaseQuote(this.translationKey, this.icon);

  final String translationKey;
  final IconData icon;
}

class _CoupleShowcaseStyleSpec {
  const _CoupleShowcaseStyleSpec({
    required this.labelKey,
    required this.gradient,
    required this.accent,
    required this.ink,
    required this.softInk,
    required this.icon,
    this.dark = false,
  });

  final String labelKey;
  final List<Color> gradient;
  final Color accent;
  final Color ink;
  final Color softInk;
  final IconData icon;
  final bool dark;
}

const Map<CoupleShowcaseStyle, _CoupleShowcaseStyleSpec>
_coupleShowcaseStyleSpecs = <CoupleShowcaseStyle, _CoupleShowcaseStyleSpec>{
  CoupleShowcaseStyle.blush: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_blush',
    gradient: <Color>[Color(0xFFFFEAF1), Color(0xFFFFF7E7)],
    accent: Color(0xFFE85D7A),
    ink: Color(0xFF4B2733),
    softInk: Color(0xFF8D5A69),
    icon: Icons.favorite_rounded,
  ),
  CoupleShowcaseStyle.sunshine: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_sunshine',
    gradient: <Color>[Color(0xFFFFF3C7), Color(0xFFFFE0C2)],
    accent: Color(0xFFD2832F),
    ink: Color(0xFF533523),
    softInk: Color(0xFF916A45),
    icon: Icons.wb_sunny_rounded,
  ),
  CoupleShowcaseStyle.scrapbook: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_scrapbook',
    gradient: <Color>[Color(0xFFE2F4F1), Color(0xFFFFF8DD)],
    accent: Color(0xFF3C8D86),
    ink: Color(0xFF244C4A),
    softInk: Color(0xFF5A7E79),
    icon: Icons.auto_awesome_rounded,
  ),
  CoupleShowcaseStyle.midnight: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_midnight',
    gradient: <Color>[Color(0xFF282443), Color(0xFF664E79)],
    accent: Color(0xFFFFD978),
    ink: Color(0xFFFFF8F4),
    softInk: Color(0xFFE9DCE9),
    icon: Icons.nightlight_round,
    dark: true,
  ),
  CoupleShowcaseStyle.home: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_home',
    gradient: <Color>[Color(0xFFFFFCF9), Color(0xFFF9E9EF)],
    accent: Color(0xFFA83F60),
    ink: Color(0xFF3E3038),
    softInk: Color(0xFF806B76),
    icon: Icons.home_rounded,
  ),
  CoupleShowcaseStyle.polaroid: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_polaroid',
    gradient: <Color>[Color(0xFFF8F7F3), Color(0xFFEDE8E1)],
    accent: Color(0xFF785C4D),
    ink: Color(0xFF3D322E),
    softInk: Color(0xFF806D63),
    icon: Icons.camera_alt_rounded,
  ),
  CoupleShowcaseStyle.cinema: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_cinema',
    gradient: <Color>[Color(0xFF211923), Color(0xFF5C293D)],
    accent: Color(0xFFF8C56D),
    ink: Color(0xFFFFF8F4),
    softInk: Color(0xFFF0DDE4),
    icon: Icons.local_movies_rounded,
    dark: true,
  ),
  CoupleShowcaseStyle.neon: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_neon',
    gradient: <Color>[Color(0xFF1F1737), Color(0xFF512A67)],
    accent: Color(0xFFFF74C9),
    ink: Color(0xFFFFF4FD),
    softInk: Color(0xFFEBD6F4),
    icon: Icons.bolt_rounded,
    dark: true,
  ),
  CoupleShowcaseStyle.floral: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_floral',
    gradient: <Color>[Color(0xFFFFE7E2), Color(0xFFE9F6D8)],
    accent: Color(0xFFB75472),
    ink: Color(0xFF4A2F39),
    softInk: Color(0xFF8B6170),
    icon: Icons.local_florist_rounded,
  ),
  CoupleShowcaseStyle.minimal: _CoupleShowcaseStyleSpec(
    labelKey: 'couple_showcase_style_minimal',
    gradient: <Color>[Color(0xFFF8FBFF), Color(0xFFE5F0FA)],
    accent: Color(0xFF4A7FA8),
    ink: Color(0xFF273B4B),
    softInk: Color(0xFF67849A),
    icon: Icons.auto_awesome_rounded,
  ),
};

/// Màn tạo ảnh khoe đôi local: ảnh không được tải lên hay ghi vào dữ liệu House.
class CoupleShowcaseScreen extends StatefulWidget {
  const CoupleShowcaseScreen({super.key, required this.houseId});

  final String houseId;

  @override
  State<CoupleShowcaseScreen> createState() => _CoupleShowcaseScreenState();
}

class _CoupleShowcaseScreenState extends State<CoupleShowcaseScreen> {
  final StoragePickerService _picker = StoragePickerService();
  final GlobalKey _cardKey = GlobalKey();

  CoupleShowcaseStyle _style = CoupleShowcaseStyle.home;
  CoupleShowcaseRatio _ratio = CoupleShowcaseRatio.portrait;
  CoupleShowcaseFrame _frame = CoupleShowcaseFrame.rounded;
  CoupleShowcaseLayout _layout = CoupleShowcaseLayout.duo;
  CoupleShowcaseQuote _quote = CoupleShowcaseQuote.dailyMemory;
  final List<Uint8List> _photos = <Uint8List>[];
  final List<XFile> _croppedImages = <XFile>[];
  int _daysTogether = 0;
  DateTime? _pairingDate;
  bool _isLoadingDays = true;
  bool _isSharing = false;

  Uint8List? get _imageBytes => _photos.isEmpty ? null : _photos.first;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDaysTogether());
  }

  @override
  void dispose() {
    for (final image in _croppedImages) {
      unawaited(discardConfirmedCropImage(image));
    }
    super.dispose();
  }

  Future<void> _loadDaysTogether() async {
    final houseId = widget.houseId.trim();
    if (houseId.isEmpty) {
      if (mounted) setState(() => _isLoadingDays = false);
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('houses/$houseId/settings/startDate')
          .get();
      final raw = snapshot.value?.toString();
      final duration = RelationshipDuration.at(raw);
      final pairingDate = _parseShowcasePairingDate(raw);
      if (!mounted) return;
      setState(() {
        _daysTogether = duration.totalDays;
        _pairingDate = pairingDate;
        _isLoadingDays = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDays = false);
    }
  }

  Future<void> _chooseImage({bool append = false}) async {
    if (append && _photos.length >= _layout.maxPhotos) return;
    final source = await showModalBottomSheet<_CoupleImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  minVerticalPadding: 10,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE7EE),
                    child: Icon(Icons.photo_library_rounded),
                  ),
                  title: Text(context.tr('local_album_source_photos')),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_CoupleImageSource.gallery),
                ),
                ListTile(
                  minVerticalPadding: 10,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF0D8),
                    child: Icon(Icons.photo_camera_rounded),
                  ),
                  title: Text(context.tr('couple_showcase_camera')),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_CoupleImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || source == null) return;

    final picked = source == _CoupleImageSource.camera
        ? await _picker.snapPhoto()
        : await _picker.pickImage();
    if (!mounted || picked == null) return;

    final cropped = await cropAndConfirmImage(
      context: context,
      image: picked,
      aspectRatio: _ratio.value,
      titleKey: 'couple_showcase_crop_title',
      isScopeCurrent: () => mounted,
      maxOutputSize: Size(1440, math.min<double>(2560, 1440 / _ratio.value)),
    );
    if (!mounted || cropped == null) return;

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;
    final previous = append
        ? const <XFile>[]
        : List<XFile>.from(_croppedImages);
    setState(() {
      if (!append) {
        _croppedImages.clear();
        _photos.clear();
      }
      _croppedImages.add(cropped);
      _photos.add(bytes);
    });
    for (final image in previous) {
      unawaited(discardConfirmedCropImage(image));
    }
  }

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return;
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted) return;
      final file = XFile.fromData(
        data.buffer.asUint8List(),
        name: 'soullocket_couple_card.png',
        mimeType: 'image/png',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[file],
          text: context.tr('couple_showcase_share_text'),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('couple_showcase_shared'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('couple_showcase_share_error'))),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _coupleShowcaseStyleSpecs[_style]!;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF17131A)
          : const Color(0xFFFFF8F4),
      appBar: AppBar(
        title: Text(
          context.tr('couple_showcase_title'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 14.0 : 18.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('couple_showcase_subtitle'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF7D6870),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 9),
                    child: Text(
                      context.tr('couple_showcase_editor_hint'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF9A858C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: CoupleShowcasePreview(
                          imageBytes: _imageBytes,
                          imageBytesList: _photos,
                          daysTogether: _daysTogether,
                          pairingDate: _pairingDate,
                          isLoadingDays: _isLoadingDays,
                          style: _style,
                          ratio: _ratio,
                          frame: _frame,
                          layout: _layout,
                          quote: _quote,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _chooseImage,
                    icon: Icon(
                      _imageBytes == null
                          ? Icons.add_photo_alternate_rounded
                          : Icons.edit_rounded,
                    ),
                    label: Text(
                      context.tr(
                        _imageBytes == null
                            ? 'couple_showcase_add_photo'
                            : 'couple_showcase_change_photo',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: palette.accent,
                      foregroundColor: palette.dark
                          ? const Color(0xFF33283C)
                          : Colors.white,
                      textStyle: SLTheme.quicksand(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_photos.isNotEmpty &&
                      _layout != CoupleShowcaseLayout.single)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: _photos.length >= _layout.maxPhotos
                            ? null
                            : () => _chooseImage(append: true),
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(context.tr('couple_showcase_collage_add')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: palette.accent,
                          side: BorderSide(
                            color: palette.accent.withValues(alpha: 0.45),
                          ),
                          textStyle: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('couple_showcase_ratio_title'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF402F36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CoupleShowcaseChoiceRow<CoupleShowcaseRatio>(
                    values: CoupleShowcaseRatio.values,
                    selected: _ratio,
                    keyFor: (value) => 'couple-showcase-ratio-${value.name}',
                    iconFor: (_) => Icons.aspect_ratio_rounded,
                    labelFor: (value) => value.label,
                    semanticPrefix: context.tr('couple_showcase_ratio_title'),
                    onTap: _isSharing
                        ? null
                        : (value) => setState(() => _ratio = value),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('couple_showcase_frame_title'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF402F36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CoupleShowcaseChoiceRow<CoupleShowcaseFrame>(
                    values: CoupleShowcaseFrame.values,
                    selected: _frame,
                    keyFor: (value) => 'couple-showcase-frame-${value.name}',
                    iconFor: (value) => value.icon,
                    labelFor: (value) => context.tr(value.labelKey),
                    semanticPrefix: context.tr('couple_showcase_frame_title'),
                    onTap: _isSharing
                        ? null
                        : (value) => setState(() => _frame = value),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('couple_showcase_layout_title'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF402F36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CoupleShowcaseChoiceRow<CoupleShowcaseLayout>(
                    values: CoupleShowcaseLayout.values,
                    selected: _layout,
                    keyFor: (value) => 'couple-showcase-layout-${value.name}',
                    iconFor: (value) => value.icon,
                    labelFor: (value) => context.tr(value.labelKey),
                    semanticPrefix: context.tr('couple_showcase_layout_title'),
                    onTap: _isSharing
                        ? null
                        : (value) => setState(() {
                            _layout = value;
                            if (_photos.length > value.maxPhotos) {
                              _photos.removeRange(
                                value.maxPhotos,
                                _photos.length,
                              );
                              final removed = _croppedImages.sublist(
                                value.maxPhotos,
                              );
                              _croppedImages.removeRange(
                                value.maxPhotos,
                                _croppedImages.length,
                              );
                              for (final image in removed) {
                                unawaited(discardConfirmedCropImage(image));
                              }
                            }
                          }),
                  ),
                  if (_layout != CoupleShowcaseLayout.single)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.tr('couple_showcase_collage_hint'),
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF9A858C),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('couple_showcase_quote_title'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF402F36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CoupleShowcaseQuoteRow(
                    selected: _quote,
                    onTap: _isSharing
                        ? null
                        : (value) => setState(() => _quote = value),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('couple_showcase_styles'),
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF402F36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in CoupleShowcaseStyle.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 10),
                            child: _CoupleShowcaseStyleOption(
                              style: item,
                              selected: item == _style,
                              imageBytes: _imageBytes,
                              imageBytesList: _photos,
                              daysTogether: _daysTogether,
                              pairingDate: _pairingDate,
                              isLoadingDays: _isLoadingDays,
                              ratio: _ratio,
                              frame: _frame,
                              layout: _layout,
                              quote: _quote,
                              onTap: _isSharing
                                  ? null
                                  : () => setState(() => _style = item),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _isSharing ? null : _shareCard,
                    icon: _isSharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(context.tr('share')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(
                        color: palette.accent.withValues(alpha: 0.55),
                      ),
                      foregroundColor: palette.accent,
                      textStyle: SLTheme.quicksand(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('couple_showcase_photo_hint'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF9A858C),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

DateTime? _parseShowcasePairingDate(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.length < 10) return null;
  final datePart = value.substring(0, 10);
  final parsed = DateTime.tryParse('${datePart}T00:00:00Z');
  if (parsed == null || parsed.year < 1900) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String _showcasePairingDateText(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final formatted = MaterialLocalizations.of(context).formatMediumDate(date);
  return L10nScope.of(
    context,
  ).format('countdown_mode_since', <String, Object?>{'date': formatted});
}

Widget _showcaseTagline(
  BuildContext context, {
  required Color color,
  double fontSize = 11,
  AlignmentGeometry alignment = Alignment.center,
  CoupleShowcaseQuote quote = CoupleShowcaseQuote.dailyMemory,
  DateTime? pairingDate,
}) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: alignment,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(quote.translationKey).replaceAll('✨', '').trim(),
            style: SLTheme.quicksand(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          // Vẽ sao bằng font icon của app, không phụ thuộc bộ emoji khi xuất PNG.
          Icon(Icons.auto_awesome_rounded, size: fontSize, color: color),
        ],
      ),
      if (pairingDate != null) ...[
        const SizedBox(height: 3),
        Text(
          _showcasePairingDateText(context, pairingDate),
          style: SLTheme.quicksand(
            fontSize: math.max(8, fontSize - 1.5),
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: .82),
          ),
        ),
      ],
    ],
  ),
);

class _CoupleShowcaseStyleOption extends StatelessWidget {
  const _CoupleShowcaseStyleOption({
    required this.style,
    required this.selected,
    required this.imageBytes,
    required this.imageBytesList,
    required this.daysTogether,
    required this.pairingDate,
    required this.isLoadingDays,
    required this.ratio,
    required this.frame,
    required this.layout,
    required this.quote,
    required this.onTap,
  });

  final CoupleShowcaseStyle style;
  final bool selected;
  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final int daysTogether;
  final DateTime? pairingDate;
  final bool isLoadingDays;
  final CoupleShowcaseRatio ratio;
  final CoupleShowcaseFrame frame;
  final CoupleShowcaseLayout layout;
  final CoupleShowcaseQuote quote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spec = _coupleShowcaseStyleSpecs[style]!;
    final label = context.tr(spec.labelKey);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: 104,
        child: InkWell(
          key: ValueKey('couple-showcase-style-${style.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? spec.accent
                          : Theme.of(context).dividerColor,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      IgnorePointer(
                        child: CoupleShowcasePreview(
                          imageBytes: imageBytes,
                          imageBytesList: imageBytesList,
                          daysTogether: daysTogether,
                          pairingDate: pairingDate,
                          isLoadingDays: isLoadingDays,
                          style: style,
                          ratio: ratio,
                          frame: frame,
                          layout: layout,
                          quote: quote,
                        ),
                      ),
                      if (selected)
                        PositionedDirectional(
                          top: 3,
                          end: 3,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: spec.accent,
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: spec.dark
                                  ? spec.gradient.first
                                  : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoupleShowcaseChoiceRow<T> extends StatelessWidget {
  const _CoupleShowcaseChoiceRow({
    required this.values,
    required this.selected,
    required this.keyFor,
    required this.iconFor,
    required this.labelFor,
    required this.semanticPrefix,
    required this.onTap,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) keyFor;
  final IconData Function(T value) iconFor;
  final String Function(T value) labelFor;
  final String semanticPrefix;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 9),
              child: _CoupleShowcaseChoiceTile(
                valueKey: keyFor(value),
                selected: value == selected,
                icon: iconFor(value),
                label: labelFor(value),
                tooltip: '$semanticPrefix ${keyFor(value).split('-').last}',
                onTap: onTap == null ? null : () => onTap!(value),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CoupleShowcaseChoiceTile extends StatelessWidget {
  const _CoupleShowcaseChoiceTile({
    required this.valueKey,
    required this.selected,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String valueKey;
  final bool selected;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey(valueKey),
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 88,
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: .12)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? accent
                      : theme.dividerColor.withValues(alpha: .65),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .14),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: .18)
                          : accent.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? accent
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(height: 13),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoupleShowcaseQuoteRow extends StatelessWidget {
  const _CoupleShowcaseQuoteRow({required this.selected, required this.onTap});

  final CoupleShowcaseQuote selected;
  final ValueChanged<CoupleShowcaseQuote>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return SizedBox(
      height: 96,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final value in CoupleShowcaseQuote.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 9),
                child: Semantics(
                  button: true,
                  selected: value == selected,
                  enabled: onTap != null,
                  label: context.tr(value.translationKey),
                  onTap: onTap == null ? null : () => onTap!(value),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: context.tr(value.translationKey),
                    child: InkWell(
                      key: ValueKey('couple-showcase-quote-${value.name}'),
                      onTap: onTap == null ? null : () => onTap!(value),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 174,
                        height: 92,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
                        decoration: BoxDecoration(
                          color: value == selected
                              ? accent.withValues(alpha: .12)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: value == selected
                                ? accent
                                : theme.dividerColor.withValues(alpha: .65),
                            width: value == selected ? 2 : 1,
                          ),
                          boxShadow: value == selected
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: .14),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              value.icon,
                              size: 20,
                              color: value == selected
                                  ? accent
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Text(
                                context
                                    .tr(value.translationKey)
                                    .replaceAll('✨', '')
                                    .trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 11.5,
                                  height: 1.18,
                                  fontWeight: value == selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: value == selected
                                      ? accent
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
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

/// Canvas thiết kế giữ cùng tỷ lệ nội bộ; card được co/cắt vào tỷ lệ người dùng
/// chọn để chữ, khung và PNG luôn đi cùng một bố cục.
/// Cỡ chữ hệ thống vẫn áp dụng cho các nút/chọn mẫu bên ngoài tấm thiệp.
class CoupleShowcasePreview extends StatelessWidget {
  const CoupleShowcasePreview({
    super.key,
    required this.imageBytes,
    this.imageBytesList = const <Uint8List>[],
    required this.daysTogether,
    required this.isLoadingDays,
    required this.style,
    this.ratio = CoupleShowcaseRatio.portrait,
    this.frame = CoupleShowcaseFrame.rounded,
    this.layout = CoupleShowcaseLayout.single,
    this.pairingDate,
    this.quote = CoupleShowcaseQuote.dailyMemory,
  });

  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final int daysTogether;
  final bool isLoadingDays;
  final CoupleShowcaseStyle style;
  final CoupleShowcaseRatio ratio;
  final CoupleShowcaseFrame frame;
  final CoupleShowcaseLayout layout;
  final DateTime? pairingDate;
  final CoupleShowcaseQuote quote;

  List<Uint8List> get photos => imageBytesList.isNotEmpty
      ? imageBytesList
      : imageBytes == null
      ? const <Uint8List>[]
      : <Uint8List>[imageBytes!];

  @override
  Widget build(BuildContext context) {
    final classic = switch (style) {
      CoupleShowcaseStyle.blush ||
      CoupleShowcaseStyle.sunshine ||
      CoupleShowcaseStyle.scrapbook ||
      CoupleShowcaseStyle.midnight => true,
      _ => false,
    };
    return AspectRatio(
      aspectRatio: ratio.value,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            key: ValueKey('couple-showcase-layout-${style.name}'),
            width: 360,
            height: 360 / .78,
            child: MediaQuery.withNoTextScaling(
              child: DefaultTextStyle(
                style: SLTheme.quicksand(color: const Color(0xFF3E3038)),
                child: classic
                    ? _ClassicCoupleShowcasePreview(
                        imageBytes: imageBytes,
                        daysTogether: daysTogether,
                        pairingDate: pairingDate,
                        isLoadingDays: isLoadingDays,
                        style: style,
                        imageBytesList: photos,
                        ratio: ratio,
                        frame: frame,
                        layout: layout,
                        quote: quote,
                      )
                    : _CoupleShowcaseArtwork(
                        imageBytes: imageBytes,
                        imageBytesList: photos,
                        daysTogether: daysTogether,
                        pairingDate: pairingDate,
                        isLoadingDays: isLoadingDays,
                        style: style,
                        ratio: ratio,
                        frame: frame,
                        layout: layout,
                        quote: quote,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoupleShowcaseArtwork extends StatelessWidget {
  const _CoupleShowcaseArtwork({
    required this.imageBytes,
    required this.imageBytesList,
    required this.daysTogether,
    required this.pairingDate,
    required this.isLoadingDays,
    required this.style,
    required this.ratio,
    required this.frame,
    required this.layout,
    required this.quote,
  });

  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final int daysTogether;
  final DateTime? pairingDate;
  final bool isLoadingDays;
  final CoupleShowcaseStyle style;
  final CoupleShowcaseRatio ratio;
  final CoupleShowcaseFrame frame;
  final CoupleShowcaseLayout layout;
  final CoupleShowcaseQuote quote;

  _CoupleShowcaseStyleSpec get spec => _coupleShowcaseStyleSpecs[style]!;
  String get value => isLoadingDays ? '…' : '$daysTogether';

  Widget _line(
    BuildContext context,
    String key, {
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) => key == 'couple_showcase_tagline'
      ? _showcaseTagline(
          context,
          color: color ?? spec.softInk,
          fontSize: size,
          quote: quote,
          pairingDate: pairingDate,
        )
      : FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.tr(key),
            style: SLTheme.quicksand(
              fontSize: size,
              fontWeight: weight,
              color: color ?? spec.softInk,
            ),
          ),
        );

  Widget _brand(BuildContext context, {Color? color}) => _line(
    context,
    'couple_showcase_brand',
    size: 11,
    weight: FontWeight.w900,
    color: color ?? spec.accent,
  );

  Widget _days(BuildContext context, {double size = 48, Color? color}) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: SLTheme.quicksand(
                fontSize: size,
                height: 1,
                fontWeight: FontWeight.w900,
                color: color ?? spec.ink,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('couple_showcase_days_suffix'),
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color ?? spec.softInk,
              ),
            ),
          ],
        ),
      );

  Widget _singlePhoto(
    BuildContext context, {
    Uint8List? bytes,
    double radius = 20,
    bool compactPlaceholder = false,
  }) {
    final content = ColoredBox(
      color: spec.dark
          ? Colors.black.withValues(alpha: .2)
          : Colors.white.withValues(alpha: .65),
      child: bytes != null
          ? Image.memory(
              bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: spec.accent,
                    size: compactPlaceholder ? 24 : 36,
                  ),
                  if (!compactPlaceholder) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _line(
                        context,
                        'couple_showcase_add_photo',
                        color: spec.ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
    return _ShowcasePhotoFrame(
      frame: frame,
      radius: radius,
      accent: spec.accent,
      child: content,
    );
  }

  Uint8List? _photoAt(int index) =>
      index < imageBytesList.length ? imageBytesList[index] : null;

  Widget _photo(BuildContext context, {double radius = 20}) {
    if (layout == CoupleShowcaseLayout.single) {
      return _singlePhoto(context, bytes: _photoAt(0), radius: radius);
    }
    if (layout == CoupleShowcaseLayout.duo) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _singlePhoto(context, bytes: _photoAt(0), radius: radius),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _singlePhoto(
              context,
              bytes: _photoAt(1),
              radius: radius,
              compactPlaceholder: imageBytesList.length < 2,
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: _singlePhoto(context, bytes: _photoAt(0), radius: radius),
        ),
        const SizedBox(width: 7),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                child: _singlePhoto(
                  context,
                  bytes: _photoAt(1),
                  radius: radius,
                  compactPlaceholder: imageBytesList.length < 2,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: _singlePhoto(
                  context,
                  bytes: _photoAt(2),
                  radius: radius,
                  compactPlaceholder: imageBytesList.length < 3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _home(BuildContext context) {
    const palette = BalancedCountdownPalette();
    return Stack(
      children: [
        Positioned(
          top: 18,
          left: 24,
          right: 24,
          child: Row(
            children: [
              Icon(Icons.home_rounded, size: 18, color: spec.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _line(
                    context,
                    'home_together_title',
                    color: spec.ink,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.favorite_rounded, size: 16, color: spec.accent),
            ],
          ),
        ),
        Positioned(
          top: 54,
          left: 20,
          right: 20,
          height: 208,
          child: _photo(context, radius: 24),
        ),
        Positioned(
          top: 213,
          left: 88,
          right: 88,
          height: 184,
          // Dùng đúng nền vòng đếm Home; bản in giữ màu giấy sáng ở mọi theme.
          child: Theme(
            data: ThemeData.light(),
            child: BalancedCountdownSurface(
              progress: isLoadingDays ? null : (daysTogether % 100) / 100,
              child: RelationshipDayCounterContent(
                value: value,
                topLabel: context.tr('pairing_ui_days_together'),
                bottomLabel: context.tr('couple_showcase_days_suffix'),
                size: 184,
                enableMotion: false,
                numberStyle: SLTheme.quicksand(
                  fontSize: 57,
                  fontWeight: FontWeight.w900,
                ),
                topLabelStyle: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
                bottomLabelStyle: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.rose,
                ),
                numberColors: palette.numberColors,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 44,
          left: 26,
          right: 26,
          child: _line(context, 'couple_showcase_tagline', size: 11),
        ),
        Positioned(bottom: 20, left: 26, right: 26, child: _brand(context)),
      ],
    );
  }

  Widget _polaroid(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 42,
        left: 27,
        right: 27,
        height: 348,
        child: Transform.rotate(
          angle: -.045,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: spec.accent.withValues(alpha: .18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(child: _photo(context, radius: 2)),
                const SizedBox(height: 15),
                _days(context, size: 36),
                const SizedBox(height: 5),
                _line(context, 'pairing_ui_days_together', size: 11),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: 31,
        left: 131,
        width: 98,
        height: 25,
        child: Transform.rotate(
          angle: .055,
          child: ColoredBox(
            color: const Color(0xFFE0C8AE).withValues(alpha: .8),
          ),
        ),
      ),
      Positioned(
        top: 356,
        right: 29,
        child: Transform.rotate(
          angle: .18,
          child: const Icon(
            Icons.favorite_rounded,
            size: 39,
            color: Color(0xFFCB7F9A),
          ),
        ),
      ),
      Positioned(
        bottom: 43,
        left: 24,
        right: 24,
        child: _line(context, 'couple_showcase_tagline', size: 11),
      ),
      Positioned(bottom: 19, left: 24, right: 24, child: _brand(context)),
    ],
  );

  Widget _cinema(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    child: Column(
      children: [
        Row(
          children: [
            Icon(spec.icon, color: spec.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _line(
                  context,
                  'home_together_title',
                  color: spec.ink,
                  size: 15,
                  weight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.star_rounded, color: spec.accent, size: 19),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            children: [
              const _ShowcaseFilmEdge(),
              const SizedBox(width: 9),
              Expanded(child: _photo(context, radius: 4)),
              const SizedBox(width: 9),
              const _ShowcaseFilmEdge(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEFDA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _line(
                context,
                'pairing_ui_days_together',
                size: 11,
                color: const Color(0xFF78503C),
              ),
              const SizedBox(height: 4),
              _days(context, size: 38, color: const Color(0xFF512E37)),
              const SizedBox(height: 9),
              _brand(context, color: const Color(0xFF8F3F59)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _line(context, 'couple_showcase_tagline', size: 10),
      ],
    ),
  );

  Widget _neon(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _photo(context, radius: 0),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [.0, .42, 1],
            colors: [Color(0x99301A45), Color(0x00301A45), Color(0xFF21142E)],
          ),
        ),
      ),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: spec.accent.withValues(alpha: .85),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      Positioned(
        top: 28,
        left: 28,
        child: Icon(Icons.bolt_rounded, color: spec.accent, size: 34),
      ),
      Positioned(
        bottom: 139,
        left: 32,
        right: 32,
        child: _line(context, 'pairing_ui_days_together', color: spec.ink),
      ),
      Positioned(
        bottom: 75,
        left: 32,
        right: 32,
        height: 57,
        child: _days(context, size: 57, color: spec.ink),
      ),
      Positioned(
        bottom: 50,
        left: 32,
        right: 32,
        child: _line(context, 'couple_showcase_tagline', size: 10),
      ),
      Positioned(bottom: 28, left: 32, right: 32, child: _brand(context)),
    ],
  );

  Widget _floral(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 22, 40, 20),
    child: Column(
      children: [
        Icon(spec.icon, color: spec.accent, size: 26),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(150),
            ),
            child: _photo(context, radius: 150),
          ),
        ),
        const SizedBox(height: 15),
        _line(context, 'pairing_ui_days_together', size: 12),
        const SizedBox(height: 4),
        _days(context, size: 42),
        const SizedBox(height: 10),
        _line(context, 'couple_showcase_tagline', size: 10.5),
        const SizedBox(height: 8),
        _brand(context),
      ],
    ),
  );

  Widget _minimal(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _line(context, 'pairing_ui_days_together', size: 12),
        ),
        const SizedBox(height: 5),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _days(context, size: 58),
        ),
        const SizedBox(height: 18),
        Expanded(child: _photo(context, radius: 80)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: spec.accent.withValues(alpha: .3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.favorite_border_rounded,
                color: spec.accent,
                size: 17,
              ),
            ),
            Expanded(child: Divider(color: spec.accent.withValues(alpha: .3))),
          ],
        ),
        const SizedBox(height: 7),
        _line(context, 'couple_showcase_tagline', size: 11),
        const SizedBox(height: 8),
        _brand(context),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.gradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ShowcaseCanvasDoodlesPainter(
              accent: spec.dark ? Colors.white : spec.accent,
              dark: spec.dark,
            ),
          ),
          if (style == CoupleShowcaseStyle.floral ||
              style == CoupleShowcaseStyle.polaroid)
            CustomPaint(
              painter: _ShowcasePaperArt(
                floral: style == CoupleShowcaseStyle.floral,
              ),
            ),
          switch (style) {
            CoupleShowcaseStyle.home => _home(context),
            CoupleShowcaseStyle.polaroid => _polaroid(context),
            CoupleShowcaseStyle.cinema => _cinema(context),
            CoupleShowcaseStyle.neon => _neon(context),
            CoupleShowcaseStyle.floral => _floral(context),
            CoupleShowcaseStyle.minimal => _minimal(context),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    ),
  );
}

class _ShowcasePhotoFrame extends StatelessWidget {
  const _ShowcasePhotoFrame({
    required this.frame,
    required this.radius,
    required this.accent,
    required this.child,
  });

  final CoupleShowcaseFrame frame;
  final double radius;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clipped = switch (frame) {
      CoupleShowcaseFrame.rounded => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
      CoupleShowcaseFrame.heart => ClipPath(
        clipper: _ShowcaseHeartClipper(),
        child: child,
      ),
      CoupleShowcaseFrame.stamp => ClipPath(
        clipper: _ShowcaseStampClipper(),
        child: child,
      ),
      CoupleShowcaseFrame.film => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
      CoupleShowcaseFrame.arch => ClipPath(
        clipper: _ShowcaseArchClipper(),
        child: child,
      ),
      CoupleShowcaseFrame.ticket => ClipPath(
        clipper: _ShowcaseTicketClipper(),
        child: child,
      ),
      CoupleShowcaseFrame.oval => ClipOval(child: child),
    };
    if (frame != CoupleShowcaseFrame.film) return clipped;
    return Stack(
      fit: StackFit.expand,
      children: [
        clipped,
        IgnorePointer(
          child: CustomPaint(painter: _ShowcaseFilmFramePainter(accent)),
        ),
      ],
    );
  }
}

class _ShowcaseHeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w / 2, h * .94)
      ..cubicTo(w * .38, h * .82, w * .06, h * .62, w * .06, h * .3)
      ..cubicTo(w * .06, h * .08, w * .3, h * .02, w * .43, h * .18)
      ..cubicTo(w * .48, h * .24, w * .5, h * .29, w * .5, h * .29)
      ..cubicTo(w * .5, h * .29, w * .52, h * .24, w * .57, h * .18)
      ..cubicTo(w * .7, h * .02, w * .94, h * .08, w * .94, h * .3)
      ..cubicTo(w * .94, h * .62, w * .62, h * .82, w / 2, h * .94)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ShowcaseHeartClipper oldClipper) => false;
}

class _ShowcaseStampClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    final hole = math.min(size.width, size.height) * .045;
    for (final center in [
      const Offset(0, 0),
      Offset(size.width / 2, 0),
      Offset(size.width, 0),
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Offset(0, size.height),
      Offset(size.width / 2, size.height),
      Offset(size.width, size.height),
    ]) {
      path.addOval(Rect.fromCircle(center: center, radius: hole));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _ShowcaseStampClipper oldClipper) => false;
}

class _ShowcaseArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final archHeight = math.min(size.width * .52, size.height * .42);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, archHeight)
      ..quadraticBezierTo(
        size.width / 2,
        -archHeight * .32,
        size.width,
        archHeight,
      )
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ShowcaseArchClipper oldClipper) => false;
}

class _ShowcaseTicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final notch = math.min(size.width, size.height) * .08;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .42 - notch)
      ..quadraticBezierTo(
        size.width - notch,
        size.height * .42,
        size.width,
        size.height * .42 + notch,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height * .58 + notch)
      ..quadraticBezierTo(
        notch,
        size.height * .58,
        0,
        size.height * .58 - notch,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _ShowcaseTicketClipper oldClipper) => false;
}

class _ShowcaseFilmFramePainter extends CustomPainter {
  const _ShowcaseFilmFramePainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: .9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      border,
    );
    final holePaint = Paint()..color = accent.withValues(alpha: .86);
    final holeHeight = math.min<double>(10, size.height * .075);
    for (var y = holeHeight * .6; y < size.height; y += holeHeight * 1.7) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, y, 7, holeHeight),
          const Radius.circular(2),
        ),
        holePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - 10, y, 7, holeHeight),
          const Radius.circular(2),
        ),
        holePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShowcaseFilmFramePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _ClassicShowcaseGallery extends StatelessWidget {
  const _ClassicShowcaseGallery({
    required this.imageBytes,
    required this.imageBytesList,
    required this.spec,
    required this.frame,
    required this.layout,
  });

  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final _CoupleShowcaseStyleSpec spec;
  final CoupleShowcaseFrame frame;
  final CoupleShowcaseLayout layout;

  @override
  Widget build(BuildContext context) {
    final photos = imageBytesList.isNotEmpty
        ? imageBytesList
        : imageBytes == null
        ? const <Uint8List>[]
        : <Uint8List>[imageBytes!];

    Widget slot(int index) {
      final bytes = index < photos.length ? photos[index] : null;
      final child = ColoredBox(
        color: spec.dark
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.36),
        child: bytes == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.add_a_photo_rounded,
                    size: index == 0 ? 38 : 24,
                    color: spec.accent,
                  ),
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
      );
      return _ShowcasePhotoFrame(
        frame: frame,
        radius: 20,
        accent: spec.accent,
        child: child,
      );
    }

    if (layout == CoupleShowcaseLayout.single) return slot(0);
    if (layout == CoupleShowcaseLayout.duo) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: slot(0)),
          const SizedBox(width: 6),
          Expanded(child: slot(1)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 6, child: slot(0)),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(child: slot(1)),
              const SizedBox(height: 6),
              Expanded(child: slot(2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShowcaseFilmEdge extends StatelessWidget {
  const _ShowcaseFilmEdge();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 10,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(
        10,
        (_) => Container(
          width: 8,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFECDCD1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ),
  );
}

class _ShowcaseCanvasDoodlesPainter extends CustomPainter {
  const _ShowcaseCanvasDoodlesPainter({
    required this.accent,
    required this.dark,
  });

  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = accent.withValues(alpha: dark ? .11 : .09);
    final stroke = Paint()
      ..color = accent.withValues(alpha: dark ? .24 : .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(Offset(size.width * .92, size.height * .1), 22, soft);
    canvas.drawCircle(Offset(size.width * .08, size.height * .86), 16, soft);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .9, size.height * .78),
        radius: 26,
      ),
      math.pi * .15,
      math.pi * .95,
      false,
      stroke,
    );
    final squiggle = Path()
      ..moveTo(size.width * .06, size.height * .22)
      ..cubicTo(
        size.width * .1,
        size.height * .18,
        size.width * .14,
        size.height * .26,
        size.width * .18,
        size.height * .22,
      )
      ..cubicTo(
        size.width * .22,
        size.height * .18,
        size.width * .26,
        size.height * .26,
        size.width * .3,
        size.height * .22,
      );
    canvas.drawPath(squiggle, stroke);
    for (final point in [
      Offset(size.width * .13, size.height * .11),
      Offset(size.width * .82, size.height * .2),
      Offset(size.width * .16, size.height * .72),
    ]) {
      canvas.drawCircle(point, 2.5, soft);
      canvas.drawLine(
        point - const Offset(5, 0),
        point + const Offset(5, 0),
        stroke,
      );
      canvas.drawLine(
        point - const Offset(0, 5),
        point + const Offset(0, 5),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShowcaseCanvasDoodlesPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.dark != dark;
}

class _ShowcasePaperArt extends CustomPainter {
  const _ShowcasePaperArt({required this.floral});
  final bool floral;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF9D7F6C).withValues(alpha: .15);
    for (var x = 12.0; x < size.width; x += 18) {
      for (var y = 12.0; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), .8, ink);
      }
    }
    if (!floral) return;
    for (final center in [
      const Offset(23, 78),
      Offset(size.width - 24, 264),
      Offset(26, size.height - 89),
    ]) {
      final petals = Paint()..color = const Color(0xFFE6A2AE);
      for (var petal = 0; petal < 6; petal++) {
        final angle = math.pi * petal / 3;
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(math.cos(angle), math.sin(angle)) * 12,
            width: 14,
            height: 16,
          ),
          petals,
        );
      }
      canvas.drawCircle(center, 7, Paint()..color = const Color(0xFFF8D88C));
      final leaf = Paint()..color = const Color(0xFF8CAB81);
      canvas.drawOval(
        Rect.fromCenter(
          center: center + const Offset(10, 30),
          width: 9,
          height: 22,
        ),
        leaf,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center + const Offset(-6, 35),
          width: 17,
          height: 9,
        ),
        leaf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShowcasePaperArt oldDelegate) =>
      oldDelegate.floral != floral;
}

class _ClassicCoupleShowcasePreview extends StatelessWidget {
  const _ClassicCoupleShowcasePreview({
    required this.imageBytes,
    required this.imageBytesList,
    required this.daysTogether,
    required this.pairingDate,
    required this.isLoadingDays,
    required this.style,
    required this.ratio,
    required this.frame,
    required this.layout,
    required this.quote,
  });

  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final int daysTogether;
  final DateTime? pairingDate;
  final bool isLoadingDays;
  final CoupleShowcaseStyle style;
  final CoupleShowcaseRatio ratio;
  final CoupleShowcaseFrame frame;
  final CoupleShowcaseLayout layout;
  final CoupleShowcaseQuote quote;

  @override
  Widget build(BuildContext context) {
    final spec = _coupleShowcaseStyleSpecs[style]!;
    final labelColor = spec.softInk;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: spec.accent.withValues(alpha: spec.dark ? 0.22 : 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -12,
              child: Icon(
                spec.icon,
                size: 104,
                color: spec.accent.withValues(alpha: spec.dark ? 0.12 : 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(spec.icon, color: spec.accent, size: 20),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          context.tr('couple_showcase_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: spec.ink,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: spec.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Expanded(
                    flex: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: spec.dark
                            ? Colors.black.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: spec.dark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.72),
                          width: 1.5,
                        ),
                      ),
                      child: _ClassicShowcaseGallery(
                        imageBytes: imageBytes,
                        imageBytesList: imageBytesList,
                        spec: spec,
                        frame: frame,
                        layout: layout,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('pairing_ui_days_together'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLoadingDays ? '…' : '$daysTogether',
                        style: SLTheme.quicksand(
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: spec.ink,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          context.tr('couple_showcase_days_suffix'),
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _showcaseTagline(
                    context,
                    color: labelColor,
                    alignment: AlignmentDirectional.centerStart,
                    quote: quote,
                    pairingDate: pairingDate,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('couple_showcase_brand'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: spec.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CoupleImageSource { gallery, camera }
