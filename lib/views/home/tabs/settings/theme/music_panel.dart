import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';

class MusicPanel extends StatelessWidget {
  static const Color _accentColor = Color(0xFFD81B60);
  static const Color _primaryTextColor = Color(0xFF3F3340);
  static const Color _secondaryTextColor = Color(0xFF7D6C79);
  static const Color _panelBorderColor = Color(0xFFF5D4E1);
  static const Color _summarySurfaceColor = Color(0xFFFFF4F8);
  static const Color _summaryBorderColor = Color(0xFFF3C9DA);
  static const Color _summaryTitleColor = Color(0xFF6A1B4D);
  static const Color _summaryBodyColor = Color(0xFF7A4564);
  static const Color _inputFillColor = Color(0xFFFFFBFD);
  static const Color _inputBorderColor = Color(0xFFF3DDE7);
  static const Color _saveButtonColor = Color(0xFF2196F3);
  static const Color _guideButtonColor = Color(0xFFFFE0B2);
  static const Color _guideTextColor = Color(0xFF6A4100);
  static const Color _removeBorderColor = Color(0xFFF3B5C8);

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
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _secondaryTextColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: autoplay,
            activeThumbColor: _accentColor,
            title: Text(
              'Tự phát khi vào màn hình chính',
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _primaryTextColor,
              ),
            ),
            subtitle: Text(
              'Shell chỉ cần nối callback để bật/tắt autoplay trong service hiện tại.',
              style: SLTheme.quicksand(
                fontSize: 11.4,
                fontWeight: FontWeight.w700,
                color: _secondaryTextColor,
              ),
            ),
            onChanged: onAutoplayChanged,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _summarySurfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _summaryBorderColor),
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
                    color: _summaryTitleColor,

                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentDescription,
                  style: SLTheme.quicksand(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: _summaryBodyColor,

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
                color: _accentColor,
              ),
              filled: true,
              fillColor: _inputFillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _inputBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _inputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _accentColor),
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
                    backgroundColor: _saveButtonColor,
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
                    backgroundColor: _guideButtonColor,
                    foregroundColor: _guideTextColor,
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
              foregroundColor: _accentColor,
              side: const BorderSide(color: _removeBorderColor),
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
