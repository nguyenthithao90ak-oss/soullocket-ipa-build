part of '../../main_home_tab.dart';

extension MainHomeWishTipController on _MainHomeTabState {
  List<String> _resolveHomeWishes() {
    final raw = _houseSettings?['wishes']?.toString() ?? '';
    final wishes = raw
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (wishes.isNotEmpty) {
      return wishes;
    }
    if (_isSingleRelationship) {
      return const [
        'Một chút dịu dàng với chính mình hôm nay cũng đủ làm ngày mới dễ thương hơn rồi.',
        'Bấm vào trái tim ở giữa để thả sang một tín hiệu thật dễ thương nhé.',
        'Mở bản đồ lên xem vị trí hiện tại của bạn để lưu lại những nơi mình đã đi qua.',
        'Lưu lại một bức ảnh xinh hoặc một dòng note ngọt ngào cho trang chủ nhé.',
      ];
    }
    return const [
      'Một câu nhớ bạn nho nhỏ cũng đủ làm tim người ấy rung nhẹ đó.',
      'Bấm vào trái tim ở giữa để thả sang một tín hiệu thật dễ thương nhé.',
      'Mở bản đồ lên xem hai đứa đang xa bao nhiêu để còn thương nhau thêm.',
      'Lưu lại một bức ảnh xinh hoặc một dòng note ngọt ngào cho trang chủ nhé.',
    ];
  }

  String _currentHomeWish() {
    final wishes = _resolveHomeWishes();
    if (wishes.isEmpty) return '';
    final safeIndex = _wishIndex >= 0 ? _wishIndex % wishes.length : 0;
    return wishes[safeIndex];
  }

  int _pickNextRandomIndex({
    required int length,
    required int previousIndex,
  }) {
    if (length <= 1) {
      return 0;
    }
    var nextIndex = _random.nextInt(length);
    while (nextIndex == previousIndex) {
      nextIndex = _random.nextInt(length);
    }
    return nextIndex;
  }

  String _currentCountdownTip() {
    if (_MainHomeTabState._kCountdownPressHoldTips.isEmpty) return '';
    final safeIndex = _tipIndex >= 0
        ? _tipIndex % _MainHomeTabState._kCountdownPressHoldTips.length
        : 0;
    return _MainHomeTabState._kCountdownPressHoldTips[safeIndex];
  }

  String? _advanceHomeWish() {
    final wishes = _resolveHomeWishes();
    if (wishes.isEmpty || !mounted) return null;
    final nextIndex = _pickNextRandomIndex(
      length: wishes.length,
      previousIndex: _wishIndex,
    );
    setState(() => _wishIndex = nextIndex);
    return wishes[nextIndex];
  }

  String? _advanceCountdownTip() {
    if (_MainHomeTabState._kCountdownPressHoldTips.isEmpty || !mounted) {
      return null;
    }
    final nextIndex = _pickNextRandomIndex(
      length: _MainHomeTabState._kCountdownPressHoldTips.length,
      previousIndex: _tipIndex,
    );
    setState(() => _tipIndex = nextIndex);
    return _MainHomeTabState._kCountdownPressHoldTips[nextIndex];
  }

  Widget _buildHomeNoticeSection({
    required IconData icon,
    required Color accent,
    required String label,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

  void _showNextWish() {
    final nextWish = _advanceHomeWish();
    if (nextWish == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF262E3F), Color(0xFF313A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.26),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _buildHomeNoticeSection(
              icon: Icons.favorite_rounded,
              accent: const Color(0xFFFF8DB6),
              label: 'Lời chúc từ SoulLocket',
              message: nextWish,
            ),
          ),
        ),
      );
  }

  void _showCountdownCircleHint({required String smartGreeting}) {
    final showWish = Random().nextBool();
    final selectedMessage =
        showWish ? _advanceHomeWish() : _advanceCountdownTip();
    if (selectedMessage == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF262E3F), Color(0xFF313A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: _buildHomeNoticeSection(
              icon: showWish
                  ? Icons.favorite_rounded
                  : Icons.tips_and_updates_rounded,
              accent:
                  showWish ? const Color(0xFFFF8DB6) : const Color(0xFF8BE9FF),
              label: showWish ? 'Lời chúc từ SoulLocket' : 'Mẹo nhanh',
              message: selectedMessage,
            ),
          ),
        ),
      );
  }
}
