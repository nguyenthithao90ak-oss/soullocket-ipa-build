import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/core/app_router.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

import 'package:soullocket_app/core/fast_backdrop_filter.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateListenable = Listenable.merge([
      L10nService(),
      UiPrefs.notifier,
    ]);
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    return ListenableBuilder(
      listenable: appStateListenable,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'SoulLocket',
          routerConfig: AppRouter.router,
          locale: L10nService().locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10nService().supportedLocales,
          scrollBehavior: const SoulLocketScrollBehavior(),
          themeAnimationDuration: const Duration(milliseconds: 160),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final screenWidth = mediaQuery.size.width;
            final textScaler = SLResponsive.textScalerFor(context);
            final content = MediaQuery(
              data: mediaQuery.copyWith(textScaler: textScaler),
              child: L10nScope(
                notifier: L10nService(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      globalScrollingNotifier.value = true;
                    } else if (notification is ScrollEndNotification) {
                      globalScrollingNotifier.value = false;
                    }
                    return false; // let the notification bubble up further if needed
                  },
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );

            if (kIsWeb) {
              final maxWidth =
                  SLResponsive.maxContentWidthForWidth(screenWidth);
              final outerPadding =
                  SLResponsive.horizontalPaddingForWidth(screenWidth);
              return Container(
                color: const Color(0xFFFDFDFD),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: outerPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          child: ClipRect(child: content),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ColoredBox(
              color: SLColors.bgMain,
              child: content,
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: SLColors.primary,
              primary: SLColors.primary,
              secondary: SLColors.secondary,
              tertiary: SLColors.accentPurple,
              surface: SLColors.bgCard,
              surfaceContainerHighest: SLColors.bgSubtle,
              error: SLColors.danger,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: SLColors.bgMain,
            dividerColor: SLColors.border,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            splashFactory: NoSplash.splashFactory,
            splashColor: SLColors.primary.withValues(alpha: 0.05),
            highlightColor: SLColors.primary.withValues(alpha: 0.02),
            hoverColor: SLColors.primary.withValues(alpha: 0.02),
            focusColor: SLColors.primary.withValues(alpha: 0.03),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              },
            ),
            textTheme: SLTypography.textTheme(baseTextTheme),
            appBarTheme: AppBarTheme(
              systemOverlayStyle: const SystemUiOverlayStyle(
                // ⚠️ Android 15 deprecates statusBarColor / navigationBarColor.
                //     Omitted — edge-to-edge handles these automatically.
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              backgroundColor: SLColors.bgElevated.withValues(alpha: 0.92),
              foregroundColor: SLColors.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: SLTypography.titleMedium,
            ),
            cardTheme: CardThemeData(
              color: SLColors.bgCard,
              elevation: 0,
              margin: EdgeInsets.zero,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: SLRadius.xlAll,
                side: const BorderSide(color: SLColors.borderLight),
              ),
            ),
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: const BorderSide(color: SLColors.border),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return SLColors.primary;
                }
                return Colors.white;
              }),
              checkColor: WidgetStateProperty.all(Colors.white),
            ),
            dropdownMenuTheme: DropdownMenuThemeData(
              textStyle: SLTheme.quicksand(
                color: SLColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              menuStyle: MenuStyle(
                backgroundColor: WidgetStateProperty.all(SLColors.bgElevated),
                surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: SLColors.borderLight),
                ),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: SLColors.borderLight,
              thickness: 1,
              space: 1,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: SLColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: SLRadius.xlAll,
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: SLColors.bgElevated,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: SLColors.bgElevated,
              hintStyle: SLTheme.quicksand(
                color: SLColors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
              labelStyle: SLTheme.quicksand(
                color: SLColors.textSecond,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: SLColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide:
                    const BorderSide(color: SLColors.primary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: SLColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide:
                    const BorderSide(color: SLColors.danger, width: 1.6),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: SLColors.textInverse,
                backgroundColor: SLColors.primary,
                disabledForegroundColor:
                    SLColors.textInverse.withValues(alpha: 0.7),
                disabledBackgroundColor:
                    SLColors.primary.withValues(alpha: 0.45),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.pillAll,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: SLColors.textPrimary,
                side: const BorderSide(color: SLColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.pillAll,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: SLColors.primary,
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: SLColors.bgElevated.withValues(alpha: 0.96),
              surfaceTintColor: Colors.transparent,
              indicatorColor: SLColors.primarySoft,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? SLColors.textPrimary : SLColors.textSecond,
                );
              }),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
              backgroundColor: SLColors.textPrimary,
              contentTextStyle: SLTheme.quicksand(
                color: SLColors.textInverse,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  final String title;
  final String message;
  final List<String> details;

  const StartupErrorApp({
    super.key,
    required this.title,
    required this.message,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: const SoulLocketScrollBehavior(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: SLColors.bgSubtle,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: SLSpacing.all24,
              child: Container(
                padding: SLSpacing.all24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFFD6E7)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB83280).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4F0),
                            borderRadius: SLRadius.lgAll,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD81B60),
                            size: 32,
                          ),
                        ),
                        SLSpacing.w16,
                        Expanded(
                          child: Text(
                            title,
                            style: SLTheme.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF3A1330),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h16,
                    Text(
                      message,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B4A5D),
                        height: 1.5,
                      ),
                    ),
                    SLSpacing.h16,
                    ...details.map(
                      (detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.circle,
                                size: 8,
                                color: Color(0xFFD81B60),
                              ),
                            ),
                            SLSpacing.w8,
                            Expanded(
                              child: Text(
                                detail,
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6B4A5D),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SLSpacing.h12,
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFFE53935).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'SoulLocket © ${DateTime.now().year} — Tame Trương Việt Hoàng.\nMọi hành vi crack, mod, can thiệp trái phép đều vi phạm bản quyền.',
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8E1B1B),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SoulLocketScrollBehavior extends MaterialScrollBehavior {
  const SoulLocketScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const ClampingScrollPhysics(
        parent: RangeMaintainingScrollPhysics(),
      );
    }

    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
    }
  }
}
