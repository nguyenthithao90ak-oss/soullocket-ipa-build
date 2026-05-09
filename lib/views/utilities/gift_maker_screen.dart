import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/gift_maker_service.dart';
import '../../services/deeplink_service.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../services/storage_service.dart';
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
        return const [Color(0xFFFF4F64), Color(0xFFFF879D)];
      case GiftType.loveLetter:
        return const [Color(0xFFFF5C78), Color(0xFFFFA46A)];
      case GiftType.surpriseEgg:
        return const [Color(0xFF53B54E), Color(0xFFA7E163)];
      case GiftType.bubbleWrap:
        return const [Color(0xFF94A3B8), Color(0xFFCBD5E1)];
      case GiftType.scratchReveal:
        return const [Color(0xFFF6D11A), Color(0xFFFFE58A)];
      case GiftType.happyBirthday:
        return const [Color(0xFF6C5CE7), Color(0xFFA78BFA)];
      case GiftType.yourHeart:
        return const [Color(0xFFFF6FA8), Color(0xFFFFA7D1)];
      case GiftType.lovelyTurkey:
        return const [Color(0xFFF57901), Color(0xFFFFB14A)];
      case GiftType.moonWish:
        return const [Color(0xFF4753D6), Color(0xFF93A7FF)];
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
        return 'Chạm nhiều lần để mở lời nhắn cuối.';
      case GiftType.loveLetter:
        return 'Phong thư riêng, mở ra nhẹ nhàng hơn.';
      case GiftType.surpriseEgg:
        return 'Bóc từng lớp để mở ra bất ngờ bên trong.';
      case GiftType.bubbleWrap:
        return 'Bóp hết bong bóng rồi mới mở được quà.';
      case GiftType.scratchReveal:
        return 'Cào lớp phủ để lộ món quà bên dưới.';
      case GiftType.happyBirthday:
        return 'Một kiểu quà rực rỡ cho dịp chúc mừng.';
      case GiftType.yourHeart:
        return 'Một nhịp tim lớn cho lời nhắn thật rõ ràng.';
      case GiftType.lovelyTurkey:
        return 'Vui nhộn, ấm áp và hợp không khí mùa lễ.';
      case GiftType.moonWish:
        return 'Dịu dàng hơn, hợp lời chúc đêm muộn.';
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
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
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
                  'Gợi ý kiểu trình bày',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tạo quà theo kiểu full màn hình.',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: wide ? 30 : 24,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              SLSpacing.h10,
              Text(
                'Giữ cách mở quà như cũ, nhưng phần nhìn nổi bật hơn và xem trước ngay trên đầu màn.',
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
  bool _didPromptPendingUploadRetry = false;

  String get _pendingUploadKey => '$_pendingUploadKeyPrefix${widget.houseId}';

  Future<void> _pickImage() async {
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
              'Chưa thể chọn ảnh lúc này. Hãy kiểm tra quyền thư viện rồi thử lại.',
        ).message,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _senderCtrl.text =
        widget.myName.trim().isNotEmpty ? widget.myName.trim() : 'Người thương';
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
    _sentGiftsStream =
        _giftService.streamSentGifts(widget.houseId).asBroadcastStream();
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
          content: const Text('Lần tạo quà trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
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
    final sender = _senderCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (sender.isEmpty || message.isEmpty) {
      _showSnack('Cần nhập tên người gửi và nội dung món quà.');
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
                'Chưa thể tải ảnh lên lúc này. Hãy kiểm tra kết nối rồi thử lại.',
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
      _showSnack('Không tạo được món quà. Vui lòng thử lại.');
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
                            'Quà đã sẵn sàng',
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
                        'Món quà đã được lưu vào ngôi nhà hiện tại. Link riêng đã tạo xong để bạn gửi lại nhanh.',
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
                                color:
                                    const Color(0xFFD81B60).withValues(alpha: 0.10),
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
                                'Copy link để gửi ngay, hoặc xem thử hiệu ứng mở quà trước.',
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
                                _showSnack('Đã copy link quà: $giftId');
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
                                'Xem thử',
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
                            'Mở Web Quà Tặng',
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

  String _formatTime(int ts) {
    if (ts <= 0) return 'Vừa xong';
    return DateFormat('HH:mm - dd/MM').format(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF1F7),
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
                  Color(0xFFFF8AB3),
                  Color(0xFFFFC2D8),
                  Color(0xFFFFE3AF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            'Tặng Quà',
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                  tabs: const [
                    Tab(text: 'Tạo quà'),
                    Tab(text: 'Đã gửi'),
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
                      Color(0xFFFFF1F7),
                      Color(0xFFFFDCEB),
                      Color(0xFFFFF0C7),
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
                          Color(0xFFFFFCFE),
                          Color(0xFFFFF5FA),
                          Color(0xFFFFF9E8),
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
                      children: [
                        _buildCreateTab(),
                        _buildHistoryTab(
                          stream: _sentGiftsStream,
                          emptyTitle: 'Bạn chưa tạo quà nào',
                          emptySubtitle: 'Quà bạn đã tạo sẽ hiện ở đây.',
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
                'Chọn kiểu quà',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '9 kiểu quà với cách mở và cảm giác khác nhau.',
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
                    'Nội dung quà',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Kiểu: ${GiftMakerService.giftLabel(_selectedType)}',
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
          title: 'Thông tin gửi quà',
          subtitle: 'Viết những lời ngọt ngào nhất gửi đến người ấy nhé.',
          child: Column(
            children: [
              TextField(
                controller: _senderCtrl,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                decoration: _inputDecoration(
                  'Tên người gửi',
                  Icons.badge_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageCtrl,
                maxLines: 6,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                decoration: _inputDecoration(
                  'Viết lời nhắn thật dịu dàng...',
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
                          ? 'Món quà thử để xem trước.'
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
                    'Xem trước',
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
                    'TẠO VÀ GỬI QUÀ NGAY',
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
                : [Colors.white, const Color(0xFFFFF7FB)],
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
              color: (selected ? colors.first : Colors.black).withValues(
                alpha: selected ? 0.24 : 0.05,
              ),
              blurRadius: selected ? 22 : 12,
              offset: Offset(0, selected ? 12 : 5),
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
                    _selectedImage != null ? 'Đã chọn ảnh' : 'Đính kèm ảnh',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    _selectedImage != null
                        ? 'Ảnh sẽ hiện khi mở quà'
                        : 'Không bắt buộc, giúp quà ý nghĩa hơn',
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
              'Link quà tặng sẽ tự động được tạo sau khi lưu xong để bạn gửi cho người thương.',
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
      prefixIcon:
          Icon(icon, color: const Color(0xFFD81B60).withValues(alpha: 0.7), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: const Color(0xFFE5E7EB).withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: const Color(0xFFE5E7EB).withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.2),
      ),
    );
  }

  Widget _buildHistoryTab({
    required Stream<List<GiftData>> stream,
    required String emptyTitle,
    required String emptySubtitle,
    required bool markOpened,
  }) {
    return StreamBuilder<List<GiftData>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD81B60)),
          );
        }
        final list = snapshot.data!;
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
    final isOpened = gift.status == 'opened';

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
                      if (isOpened)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 16)
                      else
                        const Icon(Icons.new_releases_rounded,
                            color: Color(0xFFD81B60), size: 16),
                    ],
                  ),
                  SLSpacing.h4,
                  Text(
                    'Từ: ${gift.fromName} • ${_formatTime(gift.ts)}',
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
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
