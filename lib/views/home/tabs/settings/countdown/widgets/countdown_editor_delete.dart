// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension DeleteEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorDelete(
      BuildContext context, _CountdownModeThemeData themeData) {
    return [
      if (widget.showDeleteSection) ...[
        _sectionCard(
          icon: Icons.delete_outline_rounded,
          title: L10nService().translate('home_xakhnggian_e79cf3'),
          subtitle: context.tr('home_giyucuxayb_e0eb6b'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.deleteStatusTitle.trim().isNotEmpty ||
                  widget.deleteStatusDescription.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFF3CDD8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.deleteStatusTitle.trim().isNotEmpty)
                        Text(
                          widget.deleteStatusTitle,
                          style: SLTheme.quicksand(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFB4234F),
                          ),
                        ),
                      if (widget.deleteStatusDescription.trim().isNotEmpty) ...[
                        if (widget.deleteStatusTitle.trim().isNotEmpty)
                          const SizedBox(height: 6),
                        Text(
                          widget.deleteStatusDescription,
                          style: SLTheme.quicksand(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C6D76),
                            height: 1.42,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (widget.canRequestDelete) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _buildResult(
                        _CountdownModeSettingsAction.requestDeleteSpace,
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
                    icon: const Icon(
                      Icons.mail_rounded,
                    ),
                    label: Text(
                      context.tr('home_giyucuxa_d2e564'),
                    ),
                  ),
                ),
              ],
              if (widget.canAcceptDelete) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _buildResult(
                        _CountdownModeSettingsAction.acceptDeleteSpace,
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
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                    ),
                    label: Text(
                      context.tr('home_xcnhnxanga_0b6891'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }
}
