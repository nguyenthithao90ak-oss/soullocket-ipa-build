import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_appearance.dart';
import '../../../../utils/services/l10n_service.dart';

/// Shell nhẹ của overlay; dùng cùng locale, RTL và cách phân giải theme với app.
class SoulBubbleApp extends StatelessWidget {
  const SoulBubbleApp({
    super.key,
    required this.l10n,
    required this.home,
    this.themeKey = 'theme-default',
  });

  final L10nService l10n;
  final Widget home;
  final String themeKey;

  ThemeData _theme(bool dark) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: const Color(0xFFB95D73),
    );
    return base.copyWith(
      textTheme: GoogleFonts.quicksandTextTheme(base.textTheme),
    );
  }

  @override
  Widget build(BuildContext context) => L10nScope(
    notifier: l10n,
    child: ListenableBuilder(
      listenable: l10n,
      builder: (context, child) => AppAppearanceScope(
        themeKey: themeKey,
        builder: (context, dark) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: l10n.locale,
          supportedLocales: l10n.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _theme(dark),
          home: home,
        ),
      ),
    ),
  );
}
