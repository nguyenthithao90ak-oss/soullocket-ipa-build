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

import '../../services/gift_maker_service.dart';
import '../../services/deeplink_service.dart';
import '../../services/image_picker_recovery_service.dart';
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
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
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
                  color: Colors.white.withOpacity(0.14),
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
                  color: Colors.white.withOpacity(0.82),
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
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
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
                    FilledButton.icon(
                      onPressed: onPreview,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFD81B60),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: Text(
                        'Xem trước',
                        style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _giftTeaser(selectedType),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: foreground.withOpacity(0.88),
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
  late Stream<List<GiftData>> _receivedGiftsStream;

  GiftType _selectedType = GiftType.giftBox;
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
      _showSnack('Không thể chọn ảnh: $e');
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
    _receivedGiftsStream =
        _giftService.streamReceivedGifts(widget.houseId).asBroadcastStream();
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
        _showSnack('Lỗi tải ảnh lên: $e');
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
            child: Stack(
              children: [
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
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      SafeArea(
              child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
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
                              color: Colors.white.withOpacity(0.82),
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
                                color: const Color(0xFFD81B60)
                                    .withOpacity(0.10),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final navigator = Navigator.of(dialogContext);
                                await Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        _deeplinkService.generateGiftLink(draft),
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
                          SLSpacing.w10,
                          Expanded(
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

  Future<void> _copyGiftLink(GiftData gift) async {
    final link = _deeplinkService.generateGiftLink(gift);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showSnack('Đã copy link quà');
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
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF12051E),
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
                  Color(0xFFD4145A),
                  Color(0xFFF54EA2),
                  Color(0xFFFF7A7A),
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  splashBorderRadius: BorderRadius.circular(999),
                  labelColor: const Color(0xFFD81B60),
                  unselectedLabelColor: Colors.white.withOpacity(0.9),
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
                    Tab(text: 'Đã nhận'),
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
                      Color(0xFF12051E),
                      Color(0xFF30104A),
                      Color(0xFF17192E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      children: [
        widget._buildHeroBanner(
          selectedType: _selectedType,
          onPreview: () => _openGiftPreview(
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
        ),
        SLSpacing.h12,
        _sectionCard(
          title: 'Chọn kiểu quà',
          subtitle: '9 kiểu quà với cách mở và cảm giác khác nhau.',
          child: Column(
            children: [
              Column(
                children: List.generate(GiftType.values.length, (index) {
                  final type = GiftType.values[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == GiftType.values.length - 1 ? 0 : 12,
                    ),
                    child: _buildGiftTypeCard(type),
                  );
                }),
              ),
              SLSpacing.h12,
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF2D6E2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD81B60).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFD81B60),
                        size: 20,
                      ),
                    ),
                    SLSpacing.w10,
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.12),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          GiftMakerService.giftNote(_selectedType),
                          key: ValueKey('selection_note_${_selectedType.name}'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                            color: const Color(0xFF4B5563),
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
        SLSpacing.h12,
        _sectionCard(
          title: 'Nội dung món quà',
          subtitle: 'Quà được lưu ngay trong nhà hiện tại để hai bạn mở lại.',
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
              SLSpacing.h12,
              TextField(
                controller: _messageCtrl,
                maxLines: 5,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                decoration: _inputDecoration(
                  'Viết lời nhắn thật dịu dàng hoặc một điều bạn muốn nói...',
                  Icons.favorite_rounded,
                ),
              ),
              SLSpacing.h12,
              _buildImagePicker(),
              SLSpacing.h12,
              _buildLinkPromiseCard(),
              SLSpacing.h12,
              Row(
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
                        backgroundColor: Colors.white.withOpacity(0.9),
                        side: const BorderSide(color: Color(0xFFF0D5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
              SLSpacing.h16,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createGift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
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
                          'TẠO QUÀ',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiftTypeCard(GiftType type) {
    final selected = type == _selectedType;
    final colors = widget._giftColors(type);
    final foreground = widget._giftForeground(type);
    return _GiftTouchTile(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(colors.first, Colors.white, selected ? 0 : 0.08)!,
              Color.lerp(colors.last, Colors.white, selected ? 0 : 0.08)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.92)
                : colors.first.withOpacity(0.36),
            width: selected ? 2 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(selected ? 0.16 : 0.07),
              blurRadius: selected ? 22 : 14,
              offset: const Offset(0, 12),
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
                color: Colors.white.withOpacity(
                  foreground == Colors.white ? 0.16 : 0.42,
                ),
                borderRadius: BorderRadius.circular(24),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          GiftMakerService.giftLabel(type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                            color: foreground,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: foreground == Colors.white
                                ? Colors.white.withOpacity(0.16)
                                : Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Đã chọn',
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              color: foreground,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SLSpacing.h8,
                  Text(
                    widget._giftTeaser(type),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: foreground.withOpacity(0.84),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.w12,
            Icon(
              Icons.arrow_forward_rounded,
              color: foreground.withOpacity(0.84),
            ),
          ],
        ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD81B60)),
          );
        }

        if (snapshot.hasError) {
          return _buildHistoryErrorState(snapshot.error);
        }

        final gifts = snapshot.data ?? const <GiftData>[];
        if (gifts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SLTheme.emptyStatePanel(
                icon: Icons.redeem_rounded,
                title: emptyTitle,
                subtitle: emptySubtitle,
                accentColor: const Color(0xFFD81B60),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: gifts.length,
          separatorBuilder: (_, __) => SLSpacing.h12,
          itemBuilder: (context, index) {
            final gift = gifts[index];
            final colors = widget._giftColors(gift.giftType);
            final actionColor =
                Color.lerp(colors.first, Colors.black, 0.18) ?? colors.first;
            final chipColor = gift.isOpened
                ? const Color(0xFF16A34A)
                : const Color(0xFFF59E0B);
            return Container(
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFCFD),
                    Color.lerp(colors.first, Colors.white, 0.88)!,
                    Color.lerp(colors.last, Colors.white, 0.90)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: colors.first.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(0.10),
                    blurRadius: 22,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.first.withOpacity(0.92),
                              colors.last.withOpacity(0.82),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: SLRadius.lgAll,
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          GiftMakerService.giftEmoji(gift.giftType),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      SLSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              GiftMakerService.giftLabel(gift.giftType),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            SLSpacing.h4,
                            Text(
                              'Từ ${gift.fromName} • ${_formatTime(gift.ts)}',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6B7280),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor.withOpacity(0.12),
                          borderRadius: SLRadius.pillAll,
                        ),
                        child: Text(
                          gift.isOpened ? 'Đã mở' : 'Chưa mở',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                            color: chipColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h12,
                  Text(
                    gift.message,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                      height: 1.55,
                    ),
                  ),
                  SLSpacing.h12,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openGiftPreview(
                          gift,
                          markOpened: markOpened && !gift.isOpened,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: actionColor,
                          backgroundColor: Colors.white.withOpacity(0.76),
                          side: BorderSide(
                            color: colors.first.withOpacity(0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        label: Text(
                          'Xem quà',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copyGiftLink(gift),
                        icon: const Icon(Icons.link_rounded),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: actionColor,
                          backgroundColor: colors.first.withOpacity(0.08),
                          side: BorderSide(
                            color: colors.first.withOpacity(0.28),
                          ),
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
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryErrorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SLTheme.emptyStatePanel(
          icon: Icons.wifi_tethering_error_rounded,
          title: 'Không tải được danh sách quà',
          subtitle: 'Thử chuyển tab hoặc mở lại màn này.',
          accentColor: const Color(0xFFD81B60),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF1E7EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
              fontSize: 20,
              color: const Color(0xFF111827),
            ),
          ),
          SLSpacing.h8,
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          SLSpacing.h16,
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: SLTheme.quicksand(
        color: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF111827)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF111827), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Widget _buildLinkPromiseCard() {
    final colors = widget._giftColors(_selectedType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(colors.first, Colors.white, 0.86)!,
            Color.lerp(colors.last, Colors.white, 0.88)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.first.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.link_rounded,
              color: colors.first,
              size: 22,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Có link riêng sau khi tạo',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Bạn có thể copy link quà hoặc xem thử hiệu ứng trước khi gửi.',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    fontSize: 12.5,
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
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: double.infinity,
        height: 156,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: _selectedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: SLSpacing.all8,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: Color(0xFF111827),
                      size: 30,
                    ),
                  ),
                  SLSpacing.h12,
                  Text(
                    'Thêm ảnh vào quà (không bắt buộc)',
                    style: SLTheme.quicksand(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
