import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SingleMatchPostCallDialog extends StatefulWidget {
  final String peerName;
  final String? peerAvatarUrl;
  final String peerHouseId;
  final int durationSeconds;
  final bool isVideo;
  final bool isBlind;
  final VoidCallback? onSendFriendRequest;
  final void Function(List<String> tags)? onSubmitFeedback;

  const SingleMatchPostCallDialog({
    super.key,
    required this.peerName,
    this.peerAvatarUrl,
    required this.peerHouseId,
    required this.durationSeconds,
    this.isVideo = false,
    this.isBlind = false,
    this.onSendFriendRequest,
    this.onSubmitFeedback,
  });

  static Future<void> show(
    BuildContext context, {
    required String peerName,
    String? peerAvatarUrl,
    required String peerHouseId,
    required int durationSeconds,
    bool isVideo = false,
    bool isBlind = false,
    VoidCallback? onSendFriendRequest,
    void Function(List<String> tags)? onSubmitFeedback,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SingleMatchPostCallDialog(
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        peerHouseId: peerHouseId,
        durationSeconds: durationSeconds,
        isVideo: isVideo,
        isBlind: isBlind,
        onSendFriendRequest: onSendFriendRequest,
        onSubmitFeedback: onSubmitFeedback,
      ),
    );
  }

  @override
  State<SingleMatchPostCallDialog> createState() =>
      _SingleMatchPostCallDialogState();
}

class _SingleMatchPostCallDialogState extends State<SingleMatchPostCallDialog> {
  final Set<String> _selectedTags = {};
  bool _sentRequest = false;

  static const List<Map<String, String>> _impressionTags = [
    {'key': 'warm_voice', 'label': 'Giọng ấm áp 🍯'},
    {'key': 'humorous', 'label': 'Hài hước 😂'},
    {'key': 'polite', 'label': 'Lịch sự, tinh tế ✨'},
    {'key': 'friendly', 'label': 'Dễ gần, thân thiện 🌸'},
    {'key': 'deep_talker', 'label': 'Tâm sự sâu sắc 🌙'},
    {'key': 'good_listener', 'label': 'Biết lắng nghe 🎧'},
  ];

  String _formatDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.peerAvatarUrl != null &&
                            widget.peerAvatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.peerAvatarUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            memCacheHeight: 200,
                            placeholder: (_, __) => const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Color(0xFF9CA3AF),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : const Icon(
                            Icons.favorite_rounded,
                            size: 40,
                            color: Color(0xFFFF5E7E),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5E7E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Cuộc gọi với ${widget.peerName}',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2D1F3B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thời lượng: ${_formatDuration(widget.durationSeconds)}',
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A798E),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ấn tượng của bạn về người ấy:',
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4A3858),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _impressionTags.map((tag) {
                final isSelected = _selectedTags.contains(tag['key']);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag['key']);
                      } else {
                        _selectedTags.add(tag['key']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFF1F2)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF5E7E)
                            : const Color(0xFFF0E5DF),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      tag['label']!,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFFFF5E7E)
                            : const Color(0xFF5E5056),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onSubmitFeedback?.call(_selectedTags.toList());
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7A6B72),
                      side: const BorderSide(color: Color(0xFFF0E5DF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Bỏ qua',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _sentRequest
                        ? null
                        : () {
                            setState(() => _sentRequest = true);
                            widget.onSendFriendRequest?.call();
                            widget.onSubmitFeedback
                                ?.call(_selectedTags.toList());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã gửi lời mời kết bạn! 💌'),
                                backgroundColor: Color(0xFFFF5E7E),
                              ),
                            );
                            Future.delayed(const Duration(milliseconds: 600),
                                () {
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5E7E),
                      disabledBackgroundColor:
                          const Color(0xFFFF5E7E).withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      _sentRequest
                          ? Icons.check_rounded
                          : Icons.favorite_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _sentRequest ? 'Đã gửi lời mời' : 'Kết bạn & Trò chuyện',
                      style: SLTheme.quicksand(
                        fontSize: 14,
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
    );
  }
}
