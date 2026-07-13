part of '../../main_home_tab.dart';

class SoulMergeSticker extends StatefulWidget {
  final int activeIndex;
  const SoulMergeSticker({super.key, this.activeIndex = 0});

  @override
  State<SoulMergeSticker> createState() => SoulMergeStickerState();
}

class SoulMergeStickerState extends State<SoulMergeSticker> {
  Offset? _position;
  Offset _dragOffset = Offset.zero;
  bool _isSingle = true;

  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  Timer? _tipsTimer;
  Timer? _bubbleHideTimer;
  String? _bubbleText;
  bool _showBubble = false;
  String _myRole = 'user1';
  final _random = Random();

  final GlobalKey<TapHeartsOverlayState> _globalHeartsKey =
      GlobalKey<TapHeartsOverlayState>();
  String _globalHeartStyle = 'basic';
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;

  bool _showHeartNotif = false;

  static const List<String> _appTips = [
    '💡 Chạm giữ nút "Lưu Tâm Sự" để thấy hiệu ứng co giãn 3D cực mượt nha!',
    '💡 Viết tâm sự dưới 30 ký tự sẽ tự động biến thành thẻ trích dẫn nghệ thuật lãng mạn đó!',
    '💡 Lắc điện thoại cùng lúc với người ấy khi mở Soul Merge để ghép đôi tâm hồn 💕',
    '💡 Chia sẻ kỷ niệm ra ngoài qua liên kết Memory Share để bạn bè cùng xem nhé 🏡',
    '💡 Chạm liên tục vào trái tim trong Soul Merge để bắn ra những hạt bụi phép thuật lãng mạn 💫',
    '💡 Bạn có thể gửi ảnh thì thầm trực tiếp cho người ấy ngay trong màn hình Soul Merge 📸',
    '💡 Bật bong bóng nổi ngoài app (nút chat ở góc) để trò chuyện nhanh với người ấy bất cứ lúc nào!',
    '💡 Nâng cấp tài khoản PRO để tạo tới 20 liên kết Memory Share và tắt quảng cáo hoàn toàn 💎',
    '💡 Trải nghiệm Rạp chiếu phim đôi ở tab Tiện ích để cùng xem phim online với người ấy 🍿',
    '💡 Sử dụng Sổ tay chi tiêu chung ở tab Tiện ích để quản lý quỹ hẹn hò của hai bạn minh bạch 💰',
    '💡 Gửi thư đến tương lai bằng Hộp thư thời gian (Capsule) để bất ngờ trao gửi yêu thương ✉️',
    '💡 Cùng lên danh sách To-do list hoặc ghi lại ghi chú ngọt ngào ở mục Ghi chú chung 📝',
    '💡 Thử vận may hoặc giải trí cùng người ấy với Vòng quay thử thách ở tab Giải Trí 🎡',
    '💡 Rút bài Tarot tình duyên mỗi ngày ở tab Giải Trí để xem mức độ đồng điệu hôm nay 🔮',
    '💡 Đừng quên cho thú cưng ảo ăn và tương tác mỗi ngày trong ngôi nhà chung nhé 🐱',
    '💡 Vào Cài đặt ➔ Giao diện để đổi màu chủ đề cực xinh như "Hoàng hôn", "Đại dương" hay "Hồng ngọt ngào"! 🎨',
    '💡 Bạn có thể bật hiệu ứng tuyết rơi, trái tim bay hoặc lá rụng rất lãng mạn trong Cài đặt ➔ Giao diện! ❄️',
    '💡 Đừng quên vào Cài đặt ➔ Giao diện để tải lên ảnh đôi (tỷ lệ 9:16) làm hình nền nhà chung ấm cúng nhé! 🖼️',
    '💡 Muốn đổi kiểu chữ lãng mạn? Hãy vào Cài đặt ➔ Giao diện ➔ Chọn phông chữ (Quicksand, Inter, Roboto...)! ✍️',
    '💡 Vào Cài đặt ➔ Giao diện để bật/tắt khung viền ảnh đại diện thủy tinh, ngọc trai hay viền VIP lấp lánh! 💍',
    '💡 Cài đặt phong cách đồng hồ đếm ngược ngày yêu (Anniversary style) với nhiều mẫu độc đáo trong Cài đặt! ⏰',
    '💡 Vào Cài đặt ➔ Bảo mật ➔ Thiết lập câu hỏi bảo mật để dễ dàng tự khôi phục tài khoản khi cần! 🔑',
    '💡 Để tránh người lạ đọc trộm nhật ký, hãy vào Cài đặt ➔ Bảo mật và đặt "Mã PIN dự phòng" ngay nha! 🔒',
    '💡 Tính năng Kho báu bí mật tự động khóa sau 5p/15p/1h, bạn có thể tùy chỉnh ở Cài đặt ➔ Bảo mật! 💼',
    '💡 Vào Cài đặt ➔ Bảo mật ➔ Quản lý thiết bị để kiểm tra và đăng xuất từ xa khỏi các thiết bị lạ! 📱',
    '💡 Bạn có thể liên kết tài khoản Google trong Cài đặt ➔ Bảo mật để đăng nhập nhanh chóng và an toàn hơn! 🌐',
    '💡 Đăng ký Email phụ trong Cài đặt ➔ Bảo mật để tăng cường an toàn và nhận mã khôi phục khi quên mật khẩu! ✉️',
    '💡 Vào Cài đặt ➔ Thông báo để nhận tin nhắc nhở trước ngày kỷ niệm 1 ngày, 3 ngày hoặc 7 ngày nhé! 📅',
    '💡 Để biết lúc nào người ấy vào ứng dụng, hãy bật "Thông báo đối phương online" trong Cài đặt ➔ Thông báo! 🔔',
    '💡 Để ẩn thời gian online, hãy vào Cài đặt ➔ Thông báo ➔ tắt mục "Hiển thị trạng thái hoạt động". Người ấy sẽ không thấy bạn đang hoạt động nữa! 🟢',
    '💡 Vào Cài đặt ➔ Mối quan hệ để đổi biệt danh đáng yêu hiển thị riêng cho hai bạn nha! 💕',
    '💡 Bạn có thể chỉnh ngày bắt đầu yêu trong Cài đặt ➔ Mối quan hệ để đếm chính xác số ngày bên nhau! 🗓️',
    '💡 Hãy vào Cài đặt ➔ Widget để tùy chỉnh giao diện đếm ngày yêu ngoài màn hình chính điện thoại cực đẹp! 📱',
    '💡 Trong Cài đặt ➔ Mối quan hệ, bạn có thể dễ dàng chuyển đổi giữa chế độ Độc thân (Single) và Đôi lứa (Couple)! 🏡',
  ];

  @override
  void initState() {
    super.initState();
    _checkSingleStatus();
    _loadPosition();
    _loadSettings();
  }

  @override
  void didUpdateWidget(covariant SoulMergeSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showHeartNotif = prefs.getBool('soul_merge_show_heart_notif') ?? false;
        if (!_showHeartNotif) {
          _showBubble = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _interactiveEventsSub?.cancel();
    _tipsTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSingleStatus() async {
    final houseId = await HouseService().getCurrentHouseId();
    if (mounted) {
      setState(() {
        _isSingle = (houseId == null || houseId.isEmpty);
      });
      if (!_isSingle) {
        _initChatListening();
        _initInteractiveEventsListening();
        _startTipsTimer();
      }
    }
  }

  void _initInteractiveEventsListening() {
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub =
        SoulMergeService().watchInteractiveEvents().listen((event) async {
      if (event.isEmpty || _isSingle || !mounted) return;
      final sender = event['sender']?.toString();
      if (sender == _myRole) return; // ignore my own

      final type = event['type']?.toString();
      if (type == 'photo_shot') {
        // 1. Hiển thị thông báo bằng chữ nếu được bật
        if (_showHeartNotif) {
          _showFloatingMessage('Người ấy vừa thả tim cho bạn! 💕');
        }

        // 2. Hiển thị hiệu ứng tim bay nếu:
        // - Chúng ta đang ở màn hình home (luôn bay ở home)
        if (widget.activeIndex == 0) {
          final prefs = await SharedPreferences.getInstance();
          final style = prefs.getString('soul_merge_heart_style') ?? 'basic';
          if (mounted) {
            setState(() {
              _globalHeartStyle = style;
            });
            // Trì hoãn nhẹ 50ms để widget cập nhật style mới rồi bắn tim
            Future.delayed(const Duration(milliseconds: 50), () {
              _globalHeartsKey.currentState
                  ?.spawnLocalExplosion(const Offset(26, 26), count: 6);
            });
          }
        }
      }
    });
  }

  Future<void> _initChatListening() async {
    final prefs = await SharedPreferences.getInstance();
    _myRole = prefs.getString('il_role') ?? 'user1';

    _messagesSub = SoulMergeService().watchSoulMessages().listen((messages) {
      if (messages.isEmpty || _isSingle) return;
      final isVisible = widget.activeIndex == 0;
      if (!isVisible) return;
      final lastMsg = messages.last;
      final sender = lastMsg['sender']?.toString();
      if (sender != _myRole) {
        final text = lastMsg['text']?.toString() ?? '';
        final imgUrl = lastMsg['imageUrl']?.toString() ?? '';
        final displayTxt = text.isNotEmpty
            ? text
            : (imgUrl.isNotEmpty ? 'Đã gửi một ảnh 📸' : '');
        if (displayTxt.isEmpty) return;

        final msgTime = lastMsg['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Chỉ hiển thị tin nhắn mới trong vòng 10 giây gần nhất
        if ((now - msgTime).abs() < 10000) {
          _showFloatingMessage(displayTxt);
        }
      }
    });
  }

  void _startTipsTimer() {
    _tipsTimer?.cancel();
    _tipsTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _showRandomTip();
    });
  }

  void _showRandomTip() {
    final isVisible = widget.activeIndex == 0;
    if (!isVisible) return;
    final tip = _appTips[_random.nextInt(_appTips.length)];
    _showFloatingMessage(tip);
  }

  void _showFloatingMessage(String text) {
    if (!mounted) return;
    if (!_showHeartNotif) return;
    
    // [Fix] Chỉ hiển thị thông báo bong bóng khi ở màn hình chính (tab 0) 
    // theo yêu cầu của người dùng, tránh đè lên các tính năng ở tab khác.
    if (widget.activeIndex != 0) return;

    setState(() {
      _bubbleText = text;
      _showBubble = true;
    });
    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showBubble = false;
        });
      }
    });
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('soul_merge_x');
    final dy = prefs.getDouble('soul_merge_y');
    if (dx != null && dy != null && mounted) {
      setState(() => _position = Offset(dx, dy));
    }
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('soul_merge_x', pos.dx);
    await prefs.setDouble('soul_merge_y', pos.dy);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSingle) return const SizedBox.shrink();

    final isVisible = widget.activeIndex == 0;
    if (!isVisible) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.captureModeNotifier,
      builder: (context, captureMode, _) {
        if (captureMode) return const SizedBox.shrink();

        final defaultPos = Offset(14, MediaQuery.paddingOf(context).top + 4);
        final pos = _position ?? defaultPos;
        final screenWidth = MediaQuery.sizeOf(context).width;

        // Căn giữa sticker mặc định (52 - 212) / 2 = -80
        double tooltipLeft = -80;
        if (pos.dx + tooltipLeft < 8) {
          tooltipLeft = -pos.dx + 8;
        } else if (pos.dx + 52 + (tooltipLeft * -1) > screenWidth - 8) {
          tooltipLeft = screenWidth - pos.dx - 212 - 8;
        }

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bong bóng chat hiển thị tin nhắn / mẹo dạng viên nang Glassmorphic lơ lửng cực sang trọng
              Positioned(
                bottom: 60,
                left: tooltipLeft,
                child: AnimatedOpacity(
                  opacity: _showBubble ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _showBubble && _bubbleText != null
                      ? Container(
                          width: 212,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFFC0D3).withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB3CA)
                                    .withValues(alpha: 0.22),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            _bubbleText!,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF4A3445),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 52,
                height: 52,
                child: IgnorePointer(
                  child: TapHeartsOverlay(
                    key: _globalHeartsKey,
                    style: _globalHeartStyle,
                  ),
                ),
              ),
              GestureDetector(
                onPanStart: (details) {
                  _dragOffset = details.globalPosition - pos;
                },
                onPanUpdate: (details) {
                  setState(() {
                    final targetPos = details.globalPosition - _dragOffset;
                    _position = Offset(
                      targetPos.dx
                          .clamp(0.0, MediaQuery.sizeOf(context).width - 52),
                      targetPos.dy
                          .clamp(0.0, MediaQuery.sizeOf(context).height - 150),
                    );
                  });
                },
                onPanEnd: (_) {
                  if (_position != null) _savePosition(_position!);
                },
                onTap: () async {
                  await Navigator.push(
                    context,
                    SLRoute(builder: (_) => const SoulMergeScreen()),
                  );
                  _loadSettings();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF85A1), Color(0xFFF15BB5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4F93).withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: 2.5,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: const R2StickerImage(
                        'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
                        fit: BoxFit.contain,
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

