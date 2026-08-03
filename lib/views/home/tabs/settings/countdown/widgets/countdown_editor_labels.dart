// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension LabelsEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorLabels(
      BuildContext context, _CountdownModeThemeData themeData) {
    return [
      _sectionCard(
        icon: Icons.timelapse_rounded,
        title: 'Xem nhanh không gian',
        subtitle: 'Xem vòng đếm gọn trước khi lưu',
        iconGradient: const [
          Color(0xFF3B82F6),
          Color(0xFF60A5FA),
        ],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF4D2E1)),
          ),
          child: Column(
            children: [
              Text(
                _previewTopLabel(),
                style: SLTheme.textStyleForKey(
                  _fontKey,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C6D76),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _anchorDate == null
                    ? '--'
                    : _daysSince(_anchorDate!).toString(),
                style: SLTheme.textStyleForKey(
                  _fontKey,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD81B60),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _previewBottomLabel(),
                style: SLTheme.textStyleForKey(
                  _fontKey,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C6D76),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
    ];
  }
}
