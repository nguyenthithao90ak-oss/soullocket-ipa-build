part of '../map_screen.dart';

extension _MapDetailDialogsExt on _MapScreenState {
  Future<void> _maybeShowFirstMapNotice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final houseScope =
          widget.houseId.trim().isEmpty ? 'global' : widget.houseId.trim();
      final seenKey = 'il_map_first_notice_seen_$houseScope';
      if (prefs.getBool(seenKey) == true || !mounted) return;

      await _showMapFirstNoticeDialog();
      await prefs.setBool(seenKey, true);
    } catch (_) {}
  }

  Future<void> _showMapFirstNoticeDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFCF7), Color(0xFFFFF3EE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB36A), Color(0xFFFF6F8F)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SLSpacing.w10,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8DA),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFFD0B2),
                              ),
                            ),
                            child: Text(
                              'LƯU Ý KHI XEM BẢN ĐỒ',
                              style: SLTheme.quicksand(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFC2410C),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          SLSpacing.h8,
                          Text(
                            'Bản đồ hiện phù hợp để theo dõi và xem giải trí',
                            style: SLTheme.quicksand(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1F2937),
                              height: 1.12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Một vài dữ liệu trên bản đồ có thể chưa chính xác tuyệt đối. Màn này đang được hoàn thiện dần để ổn định hơn theo thời gian.',
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    height: 1.38,
                  ),
                ),
                SLSpacing.h12,
                _buildMapIntroNoticeItem(
                  icon: Icons.celebration_rounded,
                  color: const Color(0xFFE11D48),
                  title: 'Chủ yếu để xem vui và tham khảo',
                  message:
                      'Không nên dùng màn này cho định vị chính xác, di chuyển quan trọng hoặc các quyết định cần độ đúng tuyệt đối.',
                ),
                SLSpacing.h8,
                _buildMapIntroNoticeItem(
                  icon: Icons.gps_not_fixed_rounded,
                  color: const Color(0xFF2563EB),
                  title: 'Vị trí có thể có sai số',
                  message:
                      'Sai lệch có thể đến từ GPS, mạng, thiết bị, pin, quyền vị trí hoặc khi một trong hai bạn đang tắt chia sẻ vị trí hay chạy nền.',
                ),
                SLSpacing.h8,
                _buildMapIntroNoticeItem(
                  icon: Icons.construction_rounded,
                  color: const Color(0xFFCA8A04),
                  title: 'Dự án vẫn đang phát triển',
                  message:
                      'Khoảng cách, thời gian, lộ trình, check-in và lịch sử di chuyển sẽ còn được tối ưu thêm ở các bản cập nhật sau.',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFDEC9)),
                  ),
                  child: Text(
                    'Chúc hai bạn xem vui vẻ. Nếu thấy vị trí hoặc lộ trình chưa đúng, cứ tiếp tục góp ý để bản đồ hoàn thiện hơn nhé.',
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7C2D12),
                      height: 1.32,
                    ),
                  ),
                ),
                SLSpacing.h12,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('Đã hiểu'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kMapPinkDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMapPointDialog({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    required String coordinateText,
    int? timestamp,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(accent, Colors.white, 0.22)!,
                          accent,
                        ],
                      ),
                      borderRadius: SLRadius.mdAll,
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF242526),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (subtitle.trim().isNotEmpty) ...[
                SLSpacing.h12,
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
              SLSpacing.h12,
              _buildMetaLine(Icons.location_on_rounded, coordinateText),
              if (timestamp != null)
                _buildMetaLine(
                  Icons.schedule_rounded,
                  _formatFullDate(timestamp),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckinDialog(_MapCheckinItem checkin) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kMapPinkSoft, _kMapPinkDeep],
                      ),
                      borderRadius: SLRadius.mdAll,
                    ),
                    child:
                        const Icon(Icons.favorite_rounded, color: Colors.white),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Text(
                      checkin.title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF242526),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (checkin.imageUrl.trim().isNotEmpty) ...[
                SLSpacing.h12,
                ClipRRect(
                  borderRadius: SLRadius.lgAll,
                  child: Image.network(
                    checkin.imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (checkin.note.trim().isNotEmpty) ...[
                SLSpacing.h12,
                Text(
                  checkin.note,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
              SLSpacing.h12,
              _buildMetaLine(
                Icons.location_on_rounded,
                '${checkin.lat.toStringAsFixed(5)}, ${checkin.lng.toStringAsFixed(5)}',
              ),
              _buildMetaLine(
                Icons.schedule_rounded,
                checkin.ts == null
                    ? 'Không rõ thời gian'
                    : _formatFullDate(checkin.ts!),
              ),
              if (checkin.author.trim().isNotEmpty)
                _buildMetaLine(Icons.person_rounded, checkin.author),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemoryDialog(_MapMemoryItem memory) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kMapPinkSoft, _kMapPinkDeep],
                      ),
                      borderRadius: SLRadius.mdAll,
                    ),
                    child:
                        const Icon(Icons.push_pin_rounded, color: Colors.white),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Text(
                      memory.title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (memory.imageUrl.trim().isNotEmpty) ...[
                SLSpacing.h12,
                ClipRRect(
                  borderRadius: SLRadius.lgAll,
                  child: Image.network(
                    memory.imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (memory.note.trim().isNotEmpty) ...[
                SLSpacing.h12,
                Text(
                  memory.note,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
              SLSpacing.h12,
              _buildMetaLine(
                Icons.location_on_rounded,
                '${memory.lat.toStringAsFixed(5)}, ${memory.lng.toStringAsFixed(5)}',
              ),
              _buildMetaLine(
                Icons.schedule_rounded,
                memory.ts == null
                    ? 'Không rõ thời gian'
                    : _formatFullDate(memory.ts!),
              ),
              if (memory.author.trim().isNotEmpty)
                _buildMetaLine(Icons.person_rounded, memory.author),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapIntroNoticeItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          SLSpacing.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2937),
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kMapPinkDeep),
          SLSpacing.w8,
          Expanded(
            child: Text(
              text,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kMapTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
