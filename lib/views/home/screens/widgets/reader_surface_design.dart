import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/sl_theme.dart';

/// Surface trung tính cho tìm kiếm và tài liệu, giữ nền trắng ở chế độ sáng.
class ReaderSurfacePalette {
  ReaderSurfacePalette.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get canvas => dark ? SLColors.darkBgMain : Colors.white;
  Color get surface => dark ? SLColors.darkBgCard : const Color(0xFFF4F0F1);
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecond;
  Color get line => dark ? SLColors.darkBorder : SLColors.borderLight;
  Color get accent => dark ? const Color(0xFFE7B5C5) : const Color(0xFF864758);
  Color get accentWash =>
      Color.alphaBlend(accent.withValues(alpha: .12), canvas);

  static AppBar appBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
  }) {
    final palette = ReaderSurfacePalette.of(context);
    final style = SLTheme.quicksand(
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: palette.ink,
    );
    final painter =
        TextPainter(
          text: TextSpan(text: title, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: math.max(
            1,
            MediaQuery.sizeOf(context).width - 88 - (actions?.length ?? 0) * 48,
          ),
        );
    final height = math.max(56.0, painter.height + 20);
    painter.dispose();
    return AppBar(
      title: MediaQuery(
        data: MediaQuery.of(context),
        child: Text(
          title,
          style: style,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
      actions: actions,
      toolbarHeight: height,
      titleSpacing: 8,
      centerTitle: false,
      backgroundColor: palette.canvas,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: palette.dark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}

/// Bổ sung style sau HTML gốc, không thay nội dung, liên kết hay script tài liệu.
class DocumentReaderAppearance {
  const DocumentReaderAppearance({
    required this.dark,
    this.textScale = 1,
    this.reduceMotion = false,
  });
  factory DocumentReaderAppearance.of(BuildContext context) =>
      DocumentReaderAppearance(
        dark: Theme.of(context).brightness == Brightness.dark,
        textScale: MediaQuery.textScalerOf(context).scale(16) / 16,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      );
  final bool dark;
  final double textScale;
  final bool reduceMotion;

  String get css {
    final scale = textScale.isFinite && textScale > 0 ? textScale : 1.0;
    String size(double value) => (value * scale).toStringAsFixed(2);
    return '''
:root {
  color-scheme: ${dark ? 'dark' : 'light'};
  --ink: ${dark ? '#FAF5F8' : '#3B2830'};
  --muted: ${dark ? '#B5A8B2' : '#79646D'};
  --accent: ${dark ? '#E7B5C5' : '#864758'};
  --line: ${dark ? '#403648' : '#E8D7CE'};
  --paper: ${dark ? '#2A2430' : '#FFFFFF'};
  --bg: ${dark ? '#1E1A22' : '#FFFFFF'};
}
html { scroll-behavior: ${reduceMotion ? 'auto' : 'smooth'}; }
body { background: var(--bg); color: var(--ink); font-size: ${size(16)}px; }
h1 { font-size: clamp(${size(26)}px, 5vw, ${size(36)}px); }
h2 { font-size: ${size(21)}px; }
h3 { font-size: ${size(17)}px; }
.meta, .small, nav a, table { font-size: ${size(14)}px; }
.brand { font-size: ${size(13)}px; }
a { color: var(--accent); }
header, section, footer { background: var(--paper); border-color: var(--line); }
th, .note { background: ${dark ? '#372C39' : '#FFF1F1'}; }
.warning { background: ${dark ? '#3D3328' : '#FFF6E8'}; border-color: ${dark ? '#E9C38F' : '#80622F'}; }
input:not([type=checkbox]), textarea { background: var(--paper); color: var(--ink); border-color: var(--line); }
.skip { background: var(--paper); }
ul, ol { padding-left: 0; padding-right: 0; padding-inline-start: 24px; }
button, .button { color: ${dark ? '#2A2430' : '#FFFFFF'}; }
a:focus-visible, button:focus-visible, input:focus-visible, textarea:focus-visible { outline-color: var(--accent); }
.status.success { background: ${dark ? '#243B32' : '#EAF7EF'}; color: ${dark ? '#A3DBC0' : '#245635'}; }
.status.error { background: ${dark ? '#41282E' : '#FFF0F0'}; color: ${dark ? '#F0BBC3' : '#96323C'}; }
''';
  }

  String applyTo(String html) {
    final style = '<style id="sl-reader-appearance">$css</style>';
    final headEnd = RegExp(r'</head\s*>', caseSensitive: false);
    return headEnd.hasMatch(html)
        ? html.replaceFirst(headEnd, '$style</head>')
        : '$style$html';
  }
}
