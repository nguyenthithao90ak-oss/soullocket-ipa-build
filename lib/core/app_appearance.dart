import 'dart:async';

import 'package:flutter/material.dart';

/// Quy tắc dùng chung cho nền Home, Cài đặt và các thành phần Material.
abstract final class AppThemeSelection {
  static const rotatingThemes = <String>[
    'theme-pink-glow',
    'theme-default',
    'theme-sunset',
    'theme-ocean',
    'theme-night',
  ];

  static String resolve(String themeKey, {DateTime? at}) {
    final key = themeKey.trim();
    final now = at ?? DateTime.now();
    if (key == 'theme-vip-rotate') {
      final slot = now.millisecondsSinceEpoch ~/ 30000;
      return rotatingThemes[slot % rotatingThemes.length];
    }
    if (key != 'theme-auto') {
      return key.isEmpty ? 'theme-default' : key;
    }
    if (now.hour >= 19 || now.hour < 6) return 'theme-night';
    return switch (now.month) {
      12 || 1 || 2 => 'theme-pink-glow',
      6 || 7 || 8 => 'theme-ocean',
      9 || 10 || 11 => 'theme-sunset',
      _ => 'theme-default',
    };
  }

  static bool isDark(String themeKey, {DateTime? at}) =>
      switch (resolve(themeKey, at: at)) {
        'theme-night' ||
        'theme-dark' ||
        'theme-mystic-dark' ||
        'theme-true-black' => true,
        _ => false,
      };

  static DateTime? nextChange(String themeKey, DateTime now) {
    switch (themeKey.trim()) {
      case 'theme-vip-rotate':
        return now.add(
          Duration(milliseconds: 30000 - now.millisecondsSinceEpoch % 30000),
        );
      case 'theme-auto':
        if (now.hour < 6) {
          return DateTime(now.year, now.month, now.day, 6);
        }
        if (now.hour < 19) {
          return DateTime(now.year, now.month, now.day, 19);
        }
        return DateTime(now.year, now.month, now.day + 1, 6);
      default:
        return null;
    }
  }
}

/// Đánh thức UI đúng mốc đổi theme, không cần polling khi chọn Sáng/Tối.
class AppAppearanceScope extends StatefulWidget {
  const AppAppearanceScope({
    super.key,
    required this.themeKey,
    required this.builder,
    this.now = DateTime.now,
  });

  final String themeKey;
  final Widget Function(BuildContext context, bool isDark) builder;
  final DateTime Function() now;

  static String? watch(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ResolvedAppAppearance>()
      ?.themeKey;

  @override
  State<AppAppearanceScope> createState() => _AppAppearanceScopeState();
}

class _AppAppearanceScopeState extends State<AppAppearanceScope>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(AppAppearanceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final now = widget.now();
    final next = AppThemeSelection.nextChange(widget.themeKey, now);
    if (next == null) return;
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = AppThemeSelection.resolve(
      widget.themeKey,
      at: widget.now(),
    );
    return _ResolvedAppAppearance(
      themeKey: resolved,
      child: Builder(
        builder: (context) =>
            widget.builder(context, AppThemeSelection.isDark(resolved)),
      ),
    );
  }
}

class _ResolvedAppAppearance extends InheritedWidget {
  const _ResolvedAppAppearance({required this.themeKey, required super.child});

  final String themeKey;

  @override
  bool updateShouldNotify(_ResolvedAppAppearance oldWidget) =>
      themeKey != oldWidget.themeKey;
}
