part of '../settings_tab.dart';

const CropAspectRatio _themeBackgroundAspectRatio = CropAspectRatio(ratioX: 9, ratioY: 19.5);
const CropAspectRatioPreset _themeBackgroundAspectRatioPreset = CropAspectRatioPreset.original;

extension _SettingsTabThemeSection on _SettingsTabState {
  Widget _buildThemePanel({bool hideBackButton = false}) {
    final anchorDate = DateTime.tryParse(_loveDate);
    return ThemePanel(
      themeControls: _buildThemeSectionHeader('Chủ đề & Hiệu ứng', Icons.palette_rounded),
      preview: ThemePreviewBuilder(
        data: ThemePreviewData(
          themeKey: _draftThemeKey ?? 'pink',
          effectKey: _draftEffectKey ?? 'off',
          countdownLabel: _autoReplyCtrl.text,
          countdownValue: anchorDate == null ? '--' : _daysSince(anchorDate).toString(),
          dateCaption: _loveDate,
          dockCaption: _loveUnit,
          accentColor: const Color(0xFFD81B60),
          leadingProfile: ThemePreviewProfileData(
            name: _nameU1,
            avatarUrl: _avatarUrl1,
            subtitle: 'Bạn',
          ),
          trailingProfile: ThemePreviewProfileData(
            name: _nameU2,
            avatarUrl: _avatarUrl2,
            subtitle: 'Người ấy',
          ),
          backgroundImageUrl: _draftCustomBackgroundUrl ?? '',
        ),
      ),
      backgroundActions: ThemeBackgroundActions(
        preview: _buildThemeBackgroundPreviewCard(_draftCustomBackgroundUrl ?? ''),
        isUploading: _isUploadingThemeBackground,
        onUpload: _pickAndUploadThemeBackground,
        onClear: _clearThemeBackground,
      ),
      anniversaryPanel: AnniversaryPanel(
        nameController: _anniversaryNameCtrl,
        dateController: _anniversaryDateCtrl,
        items: const [], // TODO: Map real anniversary items
        onAdd: _addCustomAnniversary,
      ),
    );
  }

  Widget _buildAIPanel({bool hideBackButton = false}) {
    return _buildPanel(
      id: 'ai_tools',
      title: 'AI Personalization',
      borderColor: const Color(0xFF9C27B0),
      hideBackButton: hideBackButton,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Tính năng AI đang được phát triển...'),
      ),
    );
  }
}
