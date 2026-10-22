// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension DateEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorDate(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) {
    final palette = SLSettingsPalette.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    return [
      _sectionCard(
        icon: Icons.edit_note_rounded,
        title: context.tr('p7_countdown_display_content_title'),
        subtitle: context.tr('p7_countdown_display_content_subtitle'),
        iconGradient: const [Color(0xFFF472B6), Color(0xFFEC4899)],
        child: Column(
          children: [
            TextField(
              controller: _leftCtrl,
              maxLength: 22,
              decoration: _fieldDecoration(
                label: context.tr('home_tnbntri_538c6b'),
                hint: context.tr('home_bn_1fd75b'),
              ),
              onChanged: (_) => _safeSetState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rightCtrl,
              maxLength: 22,
              decoration: _fieldDecoration(
                label: context.tr('home_tnbnphi_855cc7'),
                hint: context.tr('home_ngiy_5bab37'),
              ),
              onChanged: (_) => _safeSetState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingAvatarRole == null
                        ? () => _pickAvatarImage(isLeft: true)
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.tint(const Color(0xFF2563EB)),
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _uploadingAvatarRole == 'left'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      _uploadingAvatarRole == 'left' &&
                              _avatarUploadProgress != null
                          ? context
                                .tr('p7_countdown_uploading_percent')
                                .replaceAll(
                                  '{percent}',
                                  (_avatarUploadProgress! * 100)
                                      .toInt()
                                      .toString(),
                                )
                          : context.tr('home_tinhtri_3bb821'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingAvatarRole == null
                        ? () => _pickAvatarImage(isLeft: false)
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.accent,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _uploadingAvatarRole == 'right'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      _uploadingAvatarRole == 'right' &&
                              _avatarUploadProgress != null
                          ? context
                                .tr('p7_countdown_uploading_percent')
                                .replaceAll(
                                  '{percent}',
                                  (_avatarUploadProgress! * 100)
                                      .toInt()
                                      .toString(),
                                )
                          : context.tr('home_tinhphi_3b6cd5'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.tr('home_icongia_641af3'),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  color: palette.inkSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(13) > 20;
                final columns = constraints.maxWidth >= 340 && !largeText
                    ? 3
                    : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _kCountdownModeCenterIconPresets.map((preset) {
                    final selected = preset.type == _centerIconType;
                    final label = context.tr(preset.labelKey);
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: label,
                      excludeSemantics: true,
                      child: SizedBox(
                        key: ValueKey('space_editor_sticker_${preset.type}'),
                        width: width,
                        child: Material(
                          color: selected
                              ? palette.accentSoft
                              : palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _safeSetState(
                              () => _centerIconType = preset.type,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                12,
                                10,
                                12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? palette.accent
                                      : palette.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: AlignmentDirectional.topEnd,
                                    children: [
                                      Center(
                                        child:
                                            _buildCountdownModeCenterIconVisual(
                                              preset: preset,
                                              size: 68,
                                              emojiSize: 42,
                                            ),
                                      ),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: palette.accent,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: palette.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ];
  }
}
