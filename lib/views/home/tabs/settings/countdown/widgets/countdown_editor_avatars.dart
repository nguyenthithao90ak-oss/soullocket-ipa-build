// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension AvatarsEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorAvatars(BuildContext context, _CountdownModeThemeData themeData) {
    return [
      _sectionCard(
                            icon: Icons.check_circle_rounded,
                            title: L10nService()
                                .translate('home_thaotcnhan_c45625'),
                            subtitle: context.tr('home_lucuhnhcho_40e113'),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction.save,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon:
                                        const Icon(Icons.check_circle_rounded),
                                    label:
                                        Text(context.tr('home_luthayi_0dc3cc')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction
                                            .backToSpaces,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF243041),
                                      side: const BorderSide(
                                        color: Color(0xFFF2C3D7),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.grid_view_rounded),
                                    label: Text(
                                        context.tr('home_vdanhschkh_0a2542')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction.exit,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF8A5B76),
                                      side: const BorderSide(
                                        color: Color(0xFFF2C3D7),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: Text(
                                      context.tr('home_thotkhnggi_4055ed'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
    ];
  }
}
