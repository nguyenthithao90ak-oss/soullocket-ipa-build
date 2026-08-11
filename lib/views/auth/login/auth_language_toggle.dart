import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';

class AuthLanguageToggle extends StatelessWidget {
  final String currentLocale;
  final Function(String) onSelect;

  const AuthLanguageToggle({
    super.key,
    required this.currentLocale,
    required this.onSelect,
  });

  static const Map<String, String> _languages = {
    'vi': '🇻🇳 Tiếng Việt',
    'en': '🇬🇧 English',
    'zh': '🇨🇳 中文 (简体)',
    'zh-TW': '🇹🇼 中文 (繁體)',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'th': '🇹🇭 ภาษาไทย',
    'id': '🇮🇩 Bahasa Indonesia',
    'es': '🇪🇸 Español',
    'pt': '🇵🇹 Português',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
    'ru': '🇷🇺 Русский',
    'hi': '🇮🇳 हिन्दी',
    'tr': '🇹🇷 Türkçe',
    'ar': '🇸🇦 العربية',
  };

  void _showLanguagePicker(BuildContext context) {
    final l10n = L10nService();
    final isAuto = l10n.isAutoSystem;
    final systemCode = l10n.getSystemDetectedLocaleCode();
    final systemFullName = _languages[systemCode] ?? systemCode.toUpperCase();
    final systemCleanName = systemFullName.split(' ').skip(1).join(' ');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissLanguagePicker',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                margin: const EdgeInsets.only(top: 50, right: 16, left: 16),
                constraints: const BoxConstraints(maxWidth: 275, maxHeight: 430),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFD),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF4B91).withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFFD6E0),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0F5),
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFFFE2EC),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded,
                                size: 18, color: Color(0xFFFF4B91)),
                            const SizedBox(width: 8),
                            Text(
                              l10n.translate('language'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4A4444),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Language list
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // 1. Tự động nhận dạng thông minh
                            _buildItem(
                              context: ctx,
                              icon: '🌐',
                              title: 'Tự động (Hệ thống)',
                              subtitle: 'Đang chọn theo máy: $systemCleanName',
                              isSelected: isAuto,
                              onTap: () {
                                onSelect('auto');
                                Navigator.pop(ctx);
                              },
                            ),
                            const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: Color(0xFFF3E4ED),
                            ),

                            // 2. Danh sách ngôn ngữ cố định
                            ..._languages.entries.map((entry) {
                              final code = entry.key;
                              final fullName = entry.value;
                              final isSelected =
                                  !isAuto && code == currentLocale;
                              final parts = fullName.split(' ');
                              final flag = parts.first;
                              final label = parts.skip(1).join(' ');

                              return _buildItem(
                                context: ctx,
                                icon: flag,
                                title: label,
                                isSelected: isSelected,
                                onTap: () {
                                  onSelect(code);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required String icon,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      highlightColor: const Color(0xFFFFF0F5),
      splashColor: const Color(0xFFFFE4EC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFFF4B91)
                          : const Color(0xFF334155),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFFF4B91).withValues(alpha: 0.8)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFFF4B91),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final isAuto = l10n.isAutoSystem;
    final flag = isAuto ? '🌐' : (_languages[currentLocale]?.split(' ')[0] ?? '🌐');
    final displayCode = currentLocale.toUpperCase();

    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4B91).withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFFD6E0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 4),
            Text(
              displayCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF4B91),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: Color(0xFFFF4B91),
            ),
          ],
        ),
      ),
    );
  }
}
