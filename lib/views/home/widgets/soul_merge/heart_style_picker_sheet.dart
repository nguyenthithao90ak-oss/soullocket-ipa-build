import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class HeartStylePickerSheet extends StatefulWidget {
  final String activeStyle;
  final bool showHeartNotif;
  final bool isVip;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<bool> onNotifChanged;

  const HeartStylePickerSheet({
    super.key,
    required this.activeStyle,
    required this.showHeartNotif,
    required this.isVip,
    required this.onStyleChanged,
    required this.onNotifChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required String activeStyle,
    required bool showHeartNotif,
    required bool isVip,
    required ValueChanged<String> onStyleChanged,
    required ValueChanged<bool> onNotifChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HeartStylePickerSheet(
        activeStyle: activeStyle,
        showHeartNotif: showHeartNotif,
        isVip: isVip,
        onStyleChanged: onStyleChanged,
        onNotifChanged: onNotifChanged,
      ),
    );
  }

  @override
  State<HeartStylePickerSheet> createState() => _HeartStylePickerSheetState();
}

class _HeartStylePickerSheetState extends State<HeartStylePickerSheet> {
  late int _activeTab;
  late String _selectedStyle;
  late bool _showNotif;

  @override
  void initState() {
    super.initState();
    _activeTab = 0;
    _selectedStyle = widget.activeStyle;
    _showNotif = widget.showHeartNotif;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C0B3E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              L10nService().translate('heart_style_title'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L10nService().translate('heart_style_desc'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildTabSelector(),
            const SizedBox(height: 20),
            if (_activeTab == 0) ...[
              _buildStyleItem(
                title: L10nService().translate('heart_style_basic_title'),
                desc: L10nService().translate('heart_style_basic_desc'),
                styleKey: 'basic',
                isPremium: false,
                color: const Color(0xFFFFB7D5),
              ),
              const SizedBox(height: 12),
              _buildStyleItem(
                title: L10nService().translate('heart_style_aurora_title'),
                desc: L10nService().translate('heart_style_aurora_desc'),
                styleKey: 'aurora',
                isPremium: false,
                color: const Color(0xFF00FFCC),
              ),
              const SizedBox(height: 12),
              _buildStyleItem(
                title: L10nService().translate('heart_style_cosmic_title'),
                desc: L10nService().translate('heart_style_cosmic_desc'),
                styleKey: 'cosmic',
                isPremium: false,
                color: const Color(0xFFFFD700),
              ),
            ] else ...[
              _buildToggleRow(
                title: L10nService().translate('heart_style_show_cat_dialog'),
                subtitle:
                    L10nService().translate('heart_style_show_cat_dialog_desc'),
                value: _showNotif,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('soul_merge_show_heart_notif', val);
                  setState(() => _showNotif = val);
                  widget.onNotifChanged(val);
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(21),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == 0
                      ? const Color(0xFFFF4F93)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  L10nService().translate('heart_style_tab_effect'),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == 1
                      ? const Color(0xFFFF4F93)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  L10nService().translate('heart_style_tab_config'),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleItem({
    required String title,
    required String desc,
    required String styleKey,
    required bool isPremium,
    required Color color,
  }) {
    final bool isSelected = (_selectedStyle == styleKey);

    return InkWell(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('soul_merge_heart_style', styleKey);
        setState(() => _selectedStyle = styleKey);
        widget.onStyleChanged(styleKey);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : Colors.white24,
                  width: 2.0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium && !widget.isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PRO (TEST)',
                            style: SLTheme.quicksand(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFF7FB2),
            activeTrackColor: const Color(0xFFFF7FB2).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
