// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension DateEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorDate(BuildContext context, _CountdownModeThemeData themeData) {
    return [
      _sectionCard(
                            icon: Icons.edit_note_rounded,
                            title: 'Nội dung hiển thị',
                            subtitle: 'Tên, avatar và icon trung tâm',
                            iconGradient: const [
                              Color(0xFFF472B6),
                              Color(0xFFEC4899),
                            ],
                            child: Column(
                              children: [
                                TextField(
                                  controller: _leftCtrl,
                                  maxLength: 22,
                                  decoration: _fieldDecoration(
                                    label: context.tr('home_tnbntri_538c6b'),
                                    hint: context.tr('home_bn_1fd75b'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _rightCtrl,
                                  maxLength: 22,
                                  decoration: _fieldDecoration(
                                    label: context.tr('home_tnbnphi_855cc7'),
                                    hint: context.tr('home_ngiy_5bab37'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _uploadingAvatarRole == null
                                            ? () => _pickAvatarImage(
                                                  isLeft: true,
                                                )
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF2563EB),
                                          side: const BorderSide(
                                            color: Color(0xFFCFE0FF),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: _uploadingAvatarRole == 'left'
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.upload_rounded,
                                                size: 18,
                                              ),
                                        label: Text(_uploadingAvatarRole ==
                                                    'left' &&
                                                _avatarUploadProgress != null
                                            ? 'ĐANG TẢI... ${(_avatarUploadProgress! * 100).toInt()}%'
                                            : context
                                                .tr('home_tinhtri_3bb821')),
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
                                            ? () => _pickAvatarImage(
                                                  isLeft: false,
                                                )
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFD81B60),
                                          side: const BorderSide(
                                            color: Color(0xFFF2C3D7),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: _uploadingAvatarRole == 'right'
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.upload_rounded,
                                                size: 18,
                                              ),
                                        label: Text(_uploadingAvatarRole ==
                                                    'right' &&
                                                _avatarUploadProgress != null
                                            ? 'ĐANG TẢI... ${(_avatarUploadProgress! * 100).toInt()}%'
                                            : context
                                                .tr('home_tinhphi_3b6cd5')),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    context.tr('home_icongia_641af3'),
                                    style: SLTheme.quicksand(
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF8A5B76),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _kCountdownModeCenterIconPresets
                                      .map((preset) {
                                    final isSelected =
                                        preset.type == _centerIconType;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _centerIconType = preset.type,
                                      ),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        width: 62,
                                        height: 62,
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white
                                              .withValues(alpha: 0.94),
                                          border: Border.all(
                                            color: isSelected
                                                ? preset.accent
                                                : Colors.white
                                                    .withValues(alpha: 0.78),
                                            width: isSelected ? 2.2 : 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: preset.accent.withValues(
                                                alpha: isSelected ? 0.22 : 0.10,
                                              ),
                                              blurRadius: isSelected ? 18 : 11,
                                              offset: const Offset(0, 7),
                                            ),
                                          ],
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: preset.gradient,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.84),
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child:
                                                _buildCountdownModeCenterIconVisual(
                                              preset: preset,
                                              size: 36,
                                              emojiSize: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
      const SizedBox(height: 10),
    ];
  }
}
