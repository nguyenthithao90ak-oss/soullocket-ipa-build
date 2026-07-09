import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import '../screens/single_match_finding_screen.dart';

class SingleMatchChatsTab extends StatefulWidget {
  final String houseId;

  const SingleMatchChatsTab({super.key, required this.houseId});

  @override
  State<SingleMatchChatsTab> createState() => _SingleMatchChatsTabState();
}

class _SingleMatchChatsTabState extends State<SingleMatchChatsTab> {
  final SingleMatchService _service = SingleMatchService.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
  List<Map<String, dynamic>> _mappings = [];
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chatSub = _service.streamChatMappings(widget.houseId).listen(
      (list) {
        if (mounted) setState(() => _mappings = list);
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _error = AppErrorMapper.resolve(
              err,
              fallbackMessage:
                  L10nService().translate('match_khngthtidl_11f27c'),
            ).message;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _startRandomChat() async {
    if (_isCreating) return;

    try {
      final alreadyChatted =
          _mappings.map((m) => m['peerHouseId'].toString()).toSet();

      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (context) => SingleMatchFindingScreen(
            currentHouseId: widget.houseId,
            excludeHouseIds: alreadyChatted,
            isChat: true,
          ),
        ),
      );

      if (result == 'cancelled') return;

      if (result == null || result is! SingleMatchCandidate) {
        if (!mounted) return;
        _showSnack(
            'Hiện không có ai để trò chuyện lúc này. Hãy ghép đôi thêm.');
        return;
      }

      setState(() => _isCreating = true);

      final pick = result;
      await _service.getOrCreateMatchChatRoom(
        myHouseId: widget.houseId,
        peerHouseId: pick.houseId,
        peerName: pick.displayName,
        peerAvatarUrl: pick.avatarUrl,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            myHouseId: widget.houseId,
            targetHouseId: pick.houseId,
            targetName: pick.displayName,
            targetAvatar: pick.avatarUrl,
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnack(AppErrorMapper.resolve(
        err,
        fallbackMessage: L10nService().translate('match_khngthtidl_11f27c'),
      ).message);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD81B60) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: SLColors.textTertiary),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: SLColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        // Nút chat ngẫu nhiên
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFDCE7)),
          ),
          child: Column(
            children: [
              const Icon(Icons.casino_rounded,
                  size: 40, color: Color(0xFFFF4F87)),
              const SizedBox(height: 8),
              Text(
                'Trò chuyện ngẫu nhiên',
                style: SLTheme.quicksand(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF32203B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hệ thống chọn người phù hợp nhất với bạn',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A798E),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCreating ? null : _startRandomChat,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4F87),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.chat_rounded),
                  label: Text(
                    _isCreating ? 'Đang ghép...' : 'Trò chuyện ngay',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_mappings.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Lịch sử trò chuyện',
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF32203B),
                ),
              ),
              const Spacer(),
              Text('${_mappings.length} người',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textTertiary,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ..._mappings.map(_buildChatItem),
        ],
        if (_mappings.isEmpty && !_isCreating) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 52, color: SLColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'Chưa có phòng trò chuyện nào',
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhấn "Trò chuyện ngay" để kết nối hoặc quay lại tab Ghép đôi để gọi.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChatItem(Map<String, dynamic> mapping) {
    final peerHouseId = mapping['peerHouseId']?.toString() ?? '';
    final peerName = mapping['peerName']?.toString() ??
        L10nService().translate('match_hsc_81b822');
    final peerAvatar = mapping['peerAvatarUrl']?.toString() ?? '';
    final createdAt = mapping['createdAt'] is num
        ? _formatTime(mapping['createdAt'] as num)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFDCE7),
              backgroundImage:
                  peerAvatar.isNotEmpty ? NetworkImage(peerAvatar) : null,
              child: peerAvatar.isEmpty
                  ? Text(peerName.isNotEmpty ? peerName[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF32203B),
                      )),
                  if (createdAt.isNotEmpty)
                    Text(createdAt,
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textTertiary,
                        )),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      myHouseId: widget.houseId,
                      targetHouseId: peerHouseId,
                      targetName: peerName,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C61FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: Text('Nhắn tin',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(num ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
