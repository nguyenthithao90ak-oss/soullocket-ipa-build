// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension StylesEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorStyles(
      BuildContext context, _CountdownModeThemeData themeData) {
    return [
      _sectionCard(
        icon: Icons.event_available_rounded,
        title: 'Mốc thời gian & kiểu hiển thị',
        subtitle: 'Chọn ngày mốc, theme, vòng đếm, kính mờ',
        iconGradient: const [
          Color(0xFF14B8A6),
          Color(0xFF06B6D4),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  selected: _singleMode,
                  label: Text(context.tr('home_cnhn_9d6cf4')),
                  labelStyle: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: _singleMode ? Colors.white : const Color(0xFF7C6D76),
                  ),
                  selectedColor: const Color(0xFFD81B60),
                  onSelected: (_) => setState(() => _singleMode = true),
                ),
                ChoiceChip(
                  selected: !_singleMode,
                  label: Text(context.tr('home_cpi_d525b0')),
                  labelStyle: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color:
                        !_singleMode ? Colors.white : const Color(0xFF7C6D76),
                  ),
                  selectedColor: const Color(0xFFD81B60),
                  onSelected: (_) => setState(() => _singleMode = false),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(context.tr('countdown_today')),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _anchorDate = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      );
                    });
                  },
                ),
                ActionChip(
                  label: Text(context.tr('countdown_default_love_date')),
                  onPressed: () {
                    final parsed = DateInputUtils.parse(
                      widget.anchorDate == null
                          ? ''
                          : DateInputUtils.formatIsoDate(
                              widget.anchorDate!,
                            ),
                    );
                    if (parsed == null) return;
                    setState(() {
                      _anchorDate = DateTime(
                        parsed.year,
                        parsed.month,
                        parsed.day,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFF4D2E1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('home_ngymchinti_2f583e'),
                          style: SLTheme.quicksand(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF8A5B76),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _anchorDate == null
                              ? context.tr('home_chachn_cf29c8')
                              : DateInputUtils.formatDisplayDate(
                                  _anchorDate!,
                                ),
                          style: SLTheme.quicksand(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF243041),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickAnchorDate,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.event_rounded,
                      size: 18,
                    ),
                    label: Text(context.tr('home_chnngy_d2cce5')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }
}
