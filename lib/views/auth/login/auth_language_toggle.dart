import 'package:flutter/material.dart';

import '../../../services/l10n_service.dart';

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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: const Color(0xFFF7F1EA),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9C9BD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                context.tr('language'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A4444),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final code = _languages.keys.elementAt(index);
                    final name = _languages.values.elementAt(index);
                    final isSelected = code == currentLocale;

                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFE66F99)
                              : const Color(0xFF4A4444),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFFE66F99))
                          : null,
                      onTap: () {
                        onSelect(code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flag = _languages[currentLocale]?.split(' ')[0] ?? '🌐';

    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EA),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD9C9BD).withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE5DACD).withValues(alpha: 0.96),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Text(
              currentLocale.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE66F99),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFFE66F99),
            ),
          ],
        ),
      ),
    );
  }
}
