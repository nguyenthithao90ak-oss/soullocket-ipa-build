import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/gift_maker_service.dart';
import '../../../../utils/sl_notice.dart';

class SettingsGiftLinksManagerScreen extends StatefulWidget {
  final String houseId;

  const SettingsGiftLinksManagerScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<SettingsGiftLinksManagerScreen> createState() => _SettingsGiftLinksManagerScreenState();
}

class _SettingsGiftLinksManagerScreenState extends State<SettingsGiftLinksManagerScreen> {
  final GiftMakerService _giftMakerService = GiftMakerService();

  Future<void> _deleteGiftLink(GiftData gift) async {
    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: 'Xóa liên kết quà',
      message: 'Bạn có chắc muốn gỡ bỏ liên kết quà "${GiftMakerService.giftLabel(gift.giftType)}" này không? Người nhận sẽ không thể mở quà được nữa.',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _giftMakerService.deleteGiftLink(houseId: widget.houseId, giftId: gift.giftId);
      if (!mounted) return;
      SLNotice.showInfo(context, 'Đã gỡ liên kết thành công');
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(context, 'Không thể gỡ liên kết lúc này. Hãy thử lại sau.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          'Quản lý liên kết quà',
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF243041),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1565C0)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<GiftData>>(
        stream: _giftMakerService.streamSentGifts(widget.houseId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Không tải được danh sách liên kết lúc này.'),
            );
          }

          final gifts = snapshot.data ?? [];
          if (gifts.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: gifts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return _buildGiftItem(gift);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có liên kết quà nào',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(GiftData gift) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(gift.ts));
    final giftLabel = GiftMakerService.giftLabel(gift.giftType);
    final giftEmoji = GiftMakerService.giftEmoji(gift.giftType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(giftEmoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      giftLabel,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tạo ngày $dateStr',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gift.isOpened ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  gift.isOpened ? 'Đã mở' : 'Chưa mở',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: gift.isOpened ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ],
          ),
          if (gift.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE3F2FD)),
              ),
              child: Text(
                gift.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF455A64),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://soullocket.app/gift/${gift.giftId}'));
                    SLNotice.showInfo(context, 'Đã copy link quà');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 24, color: Color(0xFF1565C0)),
                  tooltip: 'Copy Link',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IconButton(
                  onPressed: () => _deleteGiftLink(gift),
                  icon: const Icon(Icons.delete_outline_rounded, size: 24, color: Color(0xFFD32F2F)),
                  tooltip: 'Gỡ liên kết',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
