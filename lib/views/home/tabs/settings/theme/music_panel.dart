import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';

class MusicPanel extends StatelessWidget {
  const MusicPanel({
    super.key,
    required this.autoplay,
    required this.linkController,
    required this.currentTitle,
    required this.currentDescription,
    required this.onAutoplayChanged,
    required this.onSaveLink,
    required this.onRemove,
    this.onShowGuide,
    this.isBusy = false,
    this.title = 'Nhạc nền',
    this.subtitle =
        'Tách autoplay, link input và hành động save/remove để shell tự nối dịch vụ phát nhạc.',
  });

  final bool autoplay;
  final TextEditingController linkController;
  final String currentTitle;
  final String currentDescription;
  final ValueChanged<bool> onAutoplayChanged;
  final VoidCallback onSaveLink;
  final VoidCallback onRemove;
  final VoidCallback? onShowGuide;
  final bool isBusy;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5D4E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7D6C79),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: autoplay,
            activeColor: const Color(0xFFD81B60),
            title: Text(
              'Tự phát khi vào màn hình chính',
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3F3340),
              ),
            ),
            subtitle: Text(
              'Shell chỉ cần nối callback để bật/tắt autoplay trong service hiện tại.',
              style: SLTheme.quicksand(
                fontSize: 11.4,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7D6C79),
              ),
            ),
            onChanged: onAutoplayChanged,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF3C9DA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF6A1B4D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentDescription,
                  style: SLTheme.quicksand(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A4564),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: linkController,
            decoration: InputDecoration(
              hintText: 'Dán link MP3 / MP4',
              prefixIcon: const Icon(
                Icons.music_note_rounded,
                color: Color(0xFFD81B60),
              ),
              filled: true,
              fillColor: const Color(0xFFFFFBFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFF3DDE7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFF3DDE7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD81B60)),
              ),
            ),
            style: SLTheme.quicksand(
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4D3B46),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onSaveLink,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isBusy ? 'Đang xử lý...' : 'Lưu link',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onShowGuide,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE0B2),
                    foregroundColor: const Color(0xFF6A4100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Hướng dẫn',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: isBusy ? null : onRemove,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFFD81B60),
              side: const BorderSide(color: Color(0xFFF3B5C8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              'Gỡ nhạc nền',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
