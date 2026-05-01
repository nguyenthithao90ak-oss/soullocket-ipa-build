import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';

class ThemeBackgroundActions extends StatelessWidget {
  const ThemeBackgroundActions({
    super.key,
    required this.preview,
    this.isUploading = false,
    this.onUpload,
    this.onClear,
    this.title = 'Ảnh nền',
    this.subtitle =
        'Tách phần upload/clear/background preview để shell chỉ cần nối picker và storage.',
    this.uploadLabel = 'Chọn ảnh nền',
    this.clearLabel = 'Xóa ảnh nền',
  });

  final Widget preview;
  final bool isUploading;
  final VoidCallback? onUpload;
  final VoidCallback? onClear;
  final String title;
  final String subtitle;
  final String uploadLabel;
  final String clearLabel;

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
          const SizedBox(height: 14),
          preview,
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isUploading ? null : onUpload,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isUploading ? 'Đang tải...' : uploadLabel,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isUploading ? null : onClear,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: const Color(0xFFD81B60),
                    side: const BorderSide(color: Color(0xFFF3B5C8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    clearLabel,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
