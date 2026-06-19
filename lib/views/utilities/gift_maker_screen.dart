import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_page_physics.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/services/gift_maker_service.dart';
import '../../utils/services/deeplink_service.dart';
import '../../utils/services/image_picker_recovery_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/storage_service.dart';
import '../../core/sl_theme.dart';

part 'gift_maker/gift_maker_preview_dialog.dart';
part 'gift_maker/gift_maker_widgets.dart';

class GiftMakerScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const GiftMakerScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  List<Color> _giftColors(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return const [Color(0xFFFF2D75), Color(0xFFFF7A9E)];
      case GiftType.loveLetter:
        return const [Color(0xFFFF3D8E), Color(0xFFFFB15E)];
      case GiftType.surpriseEgg:
        return const [Color(0xFF20C997), Color(0xFFC7F464)];
      case GiftType.bubbleWrap:
        return const [Color(0xFF7C8CF8), Color(0xFFC4B5FD)];
      case GiftType.scratchReveal:
        return const [Color(0xFFFFC700), Color(0xFFFFF0A3)];
      case GiftType.happyBirthday:
        return const [Color(0xFF7C3AED), Color(0xFFFF6EC7)];
      case GiftType.yourHeart:
        return const [Color(0xFFFF1F70), Color(0xFFFF9DD4)];
      case GiftType.lovelyTurkey:
        return const [Color(0xFFFF7A1A), Color(0xFFFFD166)];
      case GiftType.moonWish:
        return const [Color(0xFF4F46E5), Color(0xFF6EE7F9)];
    }
  }

  Color _giftForeground(GiftType type) {
    switch (type) {
      case GiftType.bubbleWrap:
      case GiftType.scratchReveal:
        return const Color(0xFF111827);
      default:
        return Colors.white;
    }
  }

  String _giftTeaser(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return L10nService().translate('util_chmnhiulnm_bd465c');
      case GiftType.loveLetter:
        return L10nService().translate('util_phongthrin_55547c');
      case GiftType.surpriseEgg:
        return L10nService().translate('util_bctnglpmra_7bf20a');
      case GiftType.bubbleWrap:
        return L10nService().translate('util_bphtbongbn_dc14ac');
      case GiftType.scratchReveal:
        return L10nService().translate('util_colpphlmnq_574521');
      case GiftType.happyBirthday:
        return L10nService().translate('util_mtkiuqurcr_103840');
      case GiftType.yourHeart:
        return L10nService().translate('util_mtnhptimln_3d6763');
      case GiftType.lovelyTurkey:
        return L10nService().translate('util_vuinhnmpvh_58c9ec');
      case GiftType.moonWish:
        return L10nService().translate('util_dudnghnhpl_f12824');
    }
  }

  Widget _buildHeroBanner({
    required GiftType selectedType,
    required VoidCallback onPreview,
  }) {
    final colors = _giftColors(selectedType);
    final foreground = _giftForeground(selectedType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.first, colors.last, const Color(0xFF17192E)],
          stops: const [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.32),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: const Color(0xFF17192E).withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 780;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr('util_gikiutrnhb_90c66b'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('util_toqutheoki_254ac4'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: wide ? 30 : 24,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              SLSpacing.h10,
              Text(
                context.tr('util_gicchmqunh_ae3147'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.5,
                ),
              ),
            ],
          );

          final right = SizedBox(
            width: wide ? 300 : double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            GiftMakerService.giftEmoji(selectedType),
                            style: const TextStyle(fontSize: 22),
                          ),
                          SLSpacing.w8,
                          Text(
                            GiftMakerService.giftLabel(selectedType),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _giftTeaser(selectedType),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: foreground.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                SLSpacing.w16,
                right,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              SLSpacing.h16,
              right,
            ],
          );
        },
      ),
    );
  }

  @override
  State<GiftMakerScreen> createState() => _GiftMakerScreenState();
}

class _GiftMakerScreenState extends State<GiftMakerScreen> {

  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Làm quà tặng',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Tự tay thiết kế hộp quà ảo để tặng người ấy nhân dịp đặc biệt.\n- Gói ghém hình ảnh, tin nhắn thoại, hoặc mã quà tặng (Gift Code) bên trong hộp.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Chọn kiểu hộp quà và dây ruy băng.\n- Nhét ảnh hoặc lời chúc vào trong hộp.\n- Bấm Gửi để hộp quà bay thẳng sang màn hình của người ấy (có kèm hiệu ứng mở quà sinh động).'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  static const String _pendingUploadKeyPrefix = 'gift_maker_';
  final _giftService = GiftMakerService();
  final _storageService = StorageService();
  final _deeplinkService = DeeplinkService();
  final _senderCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  late Stream<List<GiftData>> _sentGiftsStream;

  GiftType _selectedType = GiftType.giftBox;
  bool _isChoosingType = true;
  bool _isCreating = false;
  String? _lastGiftId;
  File? _selectedImage;
  List<GiftData> _sentGiftCache = const <GiftData>[];
  bool _didPromptPendingUploadRetry = false;

  String get _pendingUploadKey => '$_pendingUploadKeyPrefix${widget.houseId}';

  Future<void> _pickImage() async {
    final msgPickFail = context.tr('util_chathchnnh_f9d997');
    try {
      final picker = ImagePicker();
      final picked = await AppLifecyclePresenceGuard.guard(
        () => ImagePickerRecoveryService.instance.pickImage(
          picker: picker,
          source: ImageSource.gallery,
        ),
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      _showSnack(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              msgPickFail,
        ).message,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _senderCtrl.text =
        widget.myName.trim().isNotEmpty ? widget.myName.trim() : context.tr('util_ngithng_ec713c');
    _refreshGiftStreams();
    unawaited(_promptPendingUploadRetryIfNeeded());
  }

  @override
  void didUpdateWidget(covariant GiftMakerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _refreshGiftStreams();
    }
  }

  void _refreshGiftStreams() {
    _sentGiftCache = const <GiftData>[];
    _sentGiftsStream = _giftService.streamSentGifts(widget.houseId).map((list) {
      _sentGiftCache = list;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      return list;
    }).asBroadcastStream();
  }

  @override
  void dispose() {
    _senderCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('util_lntoqutrcb_38d6f5')),
          action: SnackBarAction(
            label: context.tr('util_thli_4dffdf'),
            onPressed: () {
              unawaited(_retryPendingGiftCreation());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingGiftCreation() async {
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    final imagePath = pending['imagePath']?.toString().trim() ?? '';
    File? imageFile;
    if (imagePath.isNotEmpty) {
      final candidate = File(imagePath);
      if (await candidate.exists()) {
        imageFile = candidate;
      }
    }
    final savedType = pending['giftType']?.toString() ?? GiftType.giftBox.name;
    setState(() {
      _senderCtrl.text = pending['sender']?.toString() ?? '';
      _messageCtrl.text = pending['message']?.toString() ?? '';
      _selectedType = GiftType.values.firstWhere(
        (value) => value.name == savedType,
        orElse: () => GiftType.giftBox,
      );
      _selectedImage = imageFile;
    });
    await _createGift();
  }

  Future<void> _createGift() async {
    final msgInputRequired = context.tr('util_cnnhptnngi_738968');
    final msgUploadFail = context.tr('util_chathtinhl_b6e8f8');
    final msgCreateFail = context.tr('util_khngtocmnq_a320c7');
    final sender = _senderCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (sender.isEmpty || message.isEmpty) {
      _showSnack(msgInputRequired);
      return;
    }

    setState(() => _isCreating = true);

    String imageUrl = '';
    if (_selectedImage != null) {
      try {
        await PendingUploadService.instance
            .save(_pendingUploadKey, <String, dynamic>{
          'sender': sender,
          'message': message,
          'giftType': _selectedType.name,
          'imagePath': _selectedImage!.path,
        });
        final upload = await _storageService.uploadGiftImage(
          widget.houseId,
          XFile(_selectedImage!.path),
        );
        imageUrl = upload?.downloadUrl ?? '';
      } catch (e) {
        _showSnack(
          AppErrorMapper.resolve(
            e,
            fallbackMessage:
                msgUploadFail,
          ).message,
        );
      }
    }

    final giftId = await _giftService.createGift(
      houseId: widget.houseId,
      senderName: sender,
      message: message,
      giftType: _selectedType,
      imageUrl: imageUrl,
      toHouseId: widget.houseId,
    );

    if (!mounted) return;

    setState(() {
      _isCreating = false;
      _lastGiftId = giftId;
    });

    if (giftId == null || giftId.isEmpty) {
      _showSnack(msgCreateFail);
      return;
    }
    await PendingUploadService.instance.clear(_pendingUploadKey);
    if (!mounted) return;

    final draft = GiftData(
      giftId: giftId,
      fromHouseId: widget.houseId,
      fromName: sender,
      toHouseId: widget.houseId,
      message: message,
      imageUrl: imageUrl,
      ts: DateTime.now().millisecondsSinceEpoch,
      status: 'new',
      giftType: _selectedType,
      features: const {},
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = widget._giftColors(draft.giftType);

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.first,
                        colors.last,
                        const Color(0xFF17192E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -14,
                        top: -14,
                        child: Icon(
                          Icons.link_rounded,
                          size: 86,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              GiftMakerService.giftEmoji(draft.giftType),
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.tr('util_qusnsng_476d65'),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
                              color: Colors.white,
                            ),
                          ),
                          SLSpacing.h6,
                          Text(
                            GiftMakerService.giftLabel(draft.giftType),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFFBFD),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('util_mnqucluvon_c2e89b'),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2F7),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFF2D6E2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD81B60)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.ios_share_rounded,
                                color: Color(0xFFD81B60),
                                size: 20,
                              ),
                            ),
                            SLSpacing.w10,
                            Expanded(
                              child: Text(
                                context.tr('util_copylinkgi_1ecca9'),
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                  color: const Color(0xFF6B2945),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SLSpacing.h16,
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final navigator = Navigator.of(dialogContext);
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _deeplinkService
                                        .generateGiftLink(draft),
                                  ),
                                );
                                if (!mounted) return;
                                navigator.pop();
                                _showSnack(L10nService().format('util_gift_link_copied', {'id': giftId}));
                              },
                              icon: const Icon(Icons.link_rounded),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD81B60),
                                side: const BorderSide(
                                  color: Color(0xFFF0D5E1),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              label: Text(
                                'Copy link',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox.shrink(),
                          Offstage(
                            offstage: true,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _openGiftPreview(draft, markOpened: false);
                              },
                              icon: const Icon(Icons.visibility_rounded),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD81B60),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              label: Text(
                                context.tr('util_xemth_003938'),
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final link =
                                _deeplinkService.generateGiftLink(draft);
                            if (await canLaunchUrl(Uri.parse(link))) {
                              await launchUrl(
                                Uri.parse(link),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.language_rounded),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF17192E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          label: Text(
                            context.tr('util_mwebqutng_fce331'),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _messageCtrl.clear();
    setState(() => _selectedImage = null);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openGiftPreview(GiftData gift, {required bool markOpened}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => GiftPreviewDialog(
        gift: gift,
        onOpened: markOpened
            ? () => _giftService.markGiftOpened(
                  receiverHouseId: widget.houseId,
                  giftId: gift.giftId,
                )
            : null,
      ),
    );
  }

  String _formatCreatedAt(int ts) {
    if (ts <= 0) return L10nService().translate('util_vato_4adb0d');
    return DateFormat('HH:mm - dd/MM/yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7FB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF5DA2),
                  Color(0xFFFF9EB6),
                  Color(0xFFFFD28A),
                  Color(0xFFFFF1C8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            context.tr('util_tngqu_511367'),
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  splashBorderRadius: BorderRadius.circular(999),
                  labelColor: const Color(0xFFD81B60),
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  unselectedLabelStyle:
                      SLTheme.quicksand(fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: context.tr('util_toqu_d72b1a')),
                    Tab(text: context.tr('util_to_1a51f8')),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF8FC),
                      Color(0xFFFFE6F1),
                      Color(0xFFFFF3D5),
                      Color(0xFFF5EEFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GiftBackdropPainter(),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFFFDFF),
                          Color(0xFFFFF4FA),
                          Color(0xFFFFF7E6),
                          Color(0xFFF9F2FF),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: TabBarView(
                      physics: const SLPagePhysics(),
                      children: [
                        _buildCreateTab(),
                        _buildHistoryTab(
                          stream: _sentGiftsStream,
                          initialData: _sentGiftCache,
                          emptyTitle: context.tr('util_bnchatoqun_50163a'),
                          emptySubtitle: context.tr('util_qubntoshin_2306ba'),
                          markOpened: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: SLCurves.easeOutQuicksand,
      switchOutCurve: SLCurves.easeInQuicksand,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _isChoosingType
          ? _buildGiftTypeSelectionView()
          : _buildGiftEditView(),
    );
  }

  Widget _buildGiftTypeSelectionView() {
    return ListView(
      key: const ValueKey('gift_type_selection'),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      children: [
        widget._buildHeroBanner(
          selectedType: _selectedType,
          onPreview: () {},
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('util_chnkiuqu_9354f3'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('util_9kiuquvicc_e6b9ec'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 110,
            mainAxisSpacing: 12,
          ),
          itemCount: GiftType.values.length,
          itemBuilder: (context, index) {
            final type = GiftType.values[index];
            return _buildGiftTypeCard(type);
          },
        ),
      ],
    );
  }

  Widget _buildGiftEditView() {
    final colors = widget._giftColors(_selectedType);
    return ListView(
      key: const ValueKey('gift_edit_view'),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      children: [
        Row(
          children: [
            IconButton.filled(
              onPressed: () => setState(() => _isChoosingType = true),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF374151),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('util_nidungqu_bf27a4'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    L10nService().format('util_gift_type_label', {'type': GiftMakerService.giftLabel(_selectedType)}),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD81B60),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.first.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                GiftMakerService.giftEmoji(_selectedType),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildEditHeroCard(colors),
        const SizedBox(height: 18),
        _sectionCard(
          title: context.tr('util_thngtingiq_1d5fa0'),
          subtitle: context.tr('util_vitnhnglin_7b452f'),
          child: Column(
            children: [
              TextField(
                controller: _senderCtrl,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                decoration: _inputDecoration(
                  context.tr('util_tnngigi_cbd3e4'),
                  Icons.badge_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageCtrl,
                maxLines: 6,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                decoration: _inputDecoration(
                  context.tr('util_vitlinhnth_980059'),
                  Icons.favorite_rounded,
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePicker(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLinkPromiseCard(),
        const SizedBox(height: 24),
        Offstage(
          offstage: true,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGiftPreview(
                    GiftData(
                      giftId: _lastGiftId ?? 'preview',
                      fromHouseId: widget.houseId,
                      fromName: _senderCtrl.text.trim().isEmpty
                          ? widget.myName
                          : _senderCtrl.text.trim(),
                      toHouseId: widget.houseId,
                      message: _messageCtrl.text.trim().isEmpty
                          ? context.tr('util_mnquthxemt_422c1e')
                          : _messageCtrl.text.trim(),
                      imageUrl: _selectedImage?.path ?? '',
                      ts: DateTime.now().millisecondsSinceEpoch,
                      status: 'new',
                      giftType: _selectedType,
                      features: const {},
                    ),
                    markOpened: false,
                  ),
                  icon: const Icon(Icons.visibility_rounded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD81B60),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFF0D5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  label: Text(
                    context.tr('util_xemtrc_1507b5'),
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCreating ? null : _createGift,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD81B60),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    context.tr('util_tovgiqunga_7ecb7b'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGiftTypeCard(GiftType type) {
    final selected = type == _selectedType;
    final colors = widget._giftColors(type);
    return _GiftTouchTile(
      onTap: () => setState(() {
        _selectedType = type;
        _isChoosingType = false;
      }),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [colors.first, colors.last]
                : [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFFFF7FB).withValues(alpha: 0.98),
                    Color.lerp(colors.last, Colors.white, 0.88) ??
                        const Color(0xFFFFF7FB),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.78)
                : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? colors.first : const Color(0xFFFF6BA6))
                  .withValues(
                alpha: selected ? 0.28 : 0.08,
              ),
              blurRadius: selected ? 28 : 18,
              offset: Offset(0, selected ? 14 : 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? 0.24 : 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.34 : 0.9),
                ),
              ),
              child: AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Text(
                  GiftMakerService.giftEmoji(type),
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            SLSpacing.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GiftMakerService.giftLabel(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: selected ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget._giftTeaser(type),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.86)
                          : const Color(0xFF6B7280),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditHeroCard(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.first, colors.last, const Color(0xFF2B1736)],
          stops: const [0, 0.58, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Text(
              GiftMakerService.giftEmoji(_selectedType),
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GiftMakerService.giftLabel(_selectedType),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget._giftTeaser(_selectedType),
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return _GiftTouchTile(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                  : const Icon(Icons.image_outlined, color: Color(0xFF6B7280)),
            ),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedImage != null ? context.tr('util_chnnh_d05e7e') : context.tr('util_nhkmnh_607916'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    _selectedImage != null
                        ? context.tr('util_nhshinkhim_6e0f2e')
                        : context.tr('util_khngbtbucg_9881a4'),
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedImage != null)
              IconButton(
                onPressed: () => setState(() => _selectedImage = null),
                icon: const Icon(Icons.close_rounded, color: Color(0xFFD81B60)),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkPromiseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF059669)),
          SLSpacing.w12,
          Expanded(
            child: Text(
              context.tr('util_linkqutngs_30042e'),
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4F93).withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              color: const Color(0xFF111827),
            ),
          ),
          SLSpacing.h4,
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
          SLSpacing.h20,
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: SLTheme.quicksand(
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon,
          color: const Color(0xFFD81B60).withValues(alpha: 0.7), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: const Color(0xFFE5E7EB).withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: const Color(0xFFE5E7EB).withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.2),
      ),
    );
  }

  Widget _buildHistoryTab({
    required Stream<List<GiftData>> stream,
    required List<GiftData> initialData,
    required String emptyTitle,
    required String emptySubtitle,
    required bool markOpened,
  }) {
    return StreamBuilder<List<GiftData>>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr('util_chaticdanh_4a7d79'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9F1239),
                ),
              ),
            ),
          );
        }
        final list = snapshot.data ?? const <GiftData>[];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard_rounded,
                    size: 64, color: Color(0xFFFCE7F3)),
                SLSpacing.h16,
                Text(
                  emptyTitle,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: const Color(0xFF374151),
                  ),
                ),
                SLSpacing.h6,
                Text(
                  emptySubtitle,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final gift = list[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGiftHistoryTile(gift, markOpened: markOpened),
            );
          },
        );
      },
    );
  }

  Widget _buildGiftHistoryTile(GiftData gift, {required bool markOpened}) {
    final colors = widget._giftColors(gift.giftType);
    final giftLink = _deeplinkService.generateGiftLink(gift);

    return _GiftTouchTile(
      onTap: () => _openGiftPreview(gift, markOpened: markOpened),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.first.withValues(alpha: 0.12),
                    colors.last.withValues(alpha: 0.06)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                GiftMakerService.giftEmoji(gift.giftType),
                style: const TextStyle(fontSize: 28),
              ),
            ),
            SLSpacing.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          GiftMakerService.giftLabel(gift.giftType),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEF6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.tr('util_to_1a51f8'),
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFD81B60),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h4,
                  Text(
                    L10nService().format('util_gift_created_date', {'date': _formatCreatedAt(gift.ts)}),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    giftLink,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}
