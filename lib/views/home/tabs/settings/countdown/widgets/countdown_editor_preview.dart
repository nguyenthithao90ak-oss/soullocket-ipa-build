// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension PreviewEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorPreview(BuildContext context, _CountdownModeThemeData themeData) {
    return [
      Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _copyFromMainCountdown,
                                icon: const Icon(Icons.copy_all_rounded,
                                    size: 18),
                                label: const Text('Sao chép từ Vòng Đếm chính'),
                                style: TextButton.styleFrom(
                                  foregroundColor: themeData.isDark
                                      ? Colors.white
                                      : const Color(0xFFD81B60),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: themeData.isDark ? 0.12 : 0.85,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: themeData.isDark
                                          ? Colors.white24
                                          : const Color(0xFFF4D2E1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
      const SizedBox(height: 14),
    ];
  }
}
