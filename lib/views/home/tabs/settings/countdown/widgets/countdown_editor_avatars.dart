// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension AvatarsEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorAvatars(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) => [
    FilledButton.icon(
      onPressed:
          _isUploadingBackground ||
              _uploadingAvatarRole != null ||
              _isUnlockingCountdownStyle
          ? null
          : () => Navigator.of(
              context,
            ).pop(_buildResult(_CountdownModeSettingsAction.save)),
      style: FilledButton.styleFrom(
        backgroundColor: AppearancePanelStyle.rose,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.check_rounded),
      label: Text(
        context.tr('home_luthayi_0dc3cc'),
        textAlign: TextAlign.center,
      ),
    ),
  ];
}
