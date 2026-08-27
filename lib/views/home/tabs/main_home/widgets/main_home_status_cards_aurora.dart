// ─────────────────────────────────────────────────────────────────────────────
// Phase 2.2 — Aurora Soft Main Home Status Cards
//
// File: lib/views/home/tabs/main_home/widgets/main_home_status_cards_aurora.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ HOW TO WIRE INTO main_home_tab.dart (Phase 3 will do this):                │
// │                                                                             │
// │ 1. Add this line to the imports section of main_home_tab.dart:             │
// │    import 'main_home/widgets/main_home_status_cards_aurora.dart';          │
// │                                                                             │
// │ 2. In the body section builder, detect uiVersion:                          │
// │    final useAurora = UiPrefs.notifier.value.uiVersion == 'v2';             │
// │                                                                             │
// │ 3. Replace calls to _buildModernHighlightCard with:                        │
// │    AuroraMainHomeCards.buildHighlightCard(context: context, data: ...)     │
// │                                                                             │
// │ 4. Replace calls to _buildModernInsightCard with:                           │
// │    AuroraMainHomeCards.buildInsightCard(context: context, data: ...)        │
// │                                                                             │
// │ 5. Replace calls to _buildModernMapCard with:                              │
// │    AuroraMainHomeCards.buildMapCard(context: context, data: ...)            │
// │                                                                             │
// │ 6. Replace calls to _buildShortcutDock with:                                │
// │    AuroraMainHomeCards.buildShortcutDock(context: context, shortcuts: ...)  │
// │                                                                             │
// │ 7. For StatusCard grid, use:                                               │
// │    AuroraMainHomeCards.buildStatusGrid(context: context, stats: ...)        │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/core/theme/design_tokens.dart';
import 'package:soullocket_app/core/theme/sl_typography.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

// ─── Animation Curves ─────────────────────────────────────────────────────────

/// Curve mở rộng từ design_tokens.dart
class SLauroraCurves {
  SLauroraCurves._();

  static const Curve soulSpring = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve gentleSpring = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

// ─── Aurora Shadows ───────────────────────────────────────────────────────────

/// Drop shadow với Aurora glow effect
class SLauroraShadow {
  SLauroraShadow._();

  /// Primary glow — rose tint, dùng cho card có gradient accent
  static List<BoxShadow> primaryGlow({
    Color? color,
    double blurRadius = 24,
    double spreadRadius = 0,
    Offset offset = const Offset(0, 8),
  }) {
    final glowColor = color ?? SLAuroraPalette.roseDeep.withValues(alpha: 0.18);
    return [
      BoxShadow(
        color: glowColor,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.6),
        blurRadius: 0,
        offset: const Offset(0, 0),
        spreadRadius: 0,
      ),
    ];
  }

  /// Glass shadow — dùng cho glass card thường
  static List<BoxShadow> glass({
    double blurRadius = 20,
    Offset offset = const Offset(0, 6),
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: blurRadius,
        offset: offset,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.5),
        blurRadius: 0,
        offset: const Offset(0, 0),
        spreadRadius: 0,
      ),
    ];
  }
}

// ─── Data Classes ────────────────────────────────────────────────────────────

/// Dữ liệu cho HighlightCard — kỷ niệm & countdown
class MainHomeHighlightData {
  final String? startDate;
  final String nameU1;
  final String nameU2;
  final int totalDays;
  final int albumCount;
  final List<MainHomeUpcomingEvent> upcomingEvents;
  final String? countdownText;
  final bool isSingle;
  final VoidCallback? onTap;

  const MainHomeHighlightData({
    this.startDate,
    required this.nameU1,
    required this.nameU2,
    this.totalDays = 0,
    this.albumCount = 0,
    this.upcomingEvents = const [],
    this.countdownText,
    this.isSingle = false,
    this.onTap,
  });
}

/// Sự kiện sắp tới trong HighlightCard
class MainHomeUpcomingEvent {
  final String title;
  final DateTime date;
  final String type; // 'calendar' | 'anniversary' | 'birthday' | 'holiday'

  const MainHomeUpcomingEvent({
    required this.title,
    required this.date,
    required this.type,
  });
}

/// Dữ liệu cho InsightCard — chỉ số tình yêu
class MainHomeInsightData {
  final int? loveScore;
  final int? loveU1;
  final int? loveU2;
  final String? suggestion;
  final int? updatedAt;
  final String? aiLabel;
  final bool isSingle;
  final String? nameU1;
  final String? nameU2;

  const MainHomeInsightData({
    this.loveScore,
    this.loveU1,
    this.loveU2,
    this.suggestion,
    this.updatedAt,
    this.aiLabel,
    this.isSingle = false,
    this.nameU1,
    this.nameU2,
  });
}

/// Dữ liệu cho MapCard — vị trí & khoảng cách
class MainHomeMapData {
  final String distanceText;
  final String? partnerBatteryText;
  final String? myBatteryText;
  final String? weatherText;
  final bool isSingle;
  final VoidCallback? onTap;

  const MainHomeMapData({
    required this.distanceText,
    this.partnerBatteryText,
    this.myBatteryText,
    this.weatherText,
    this.isSingle = false,
    this.onTap,
  });
}

/// Một stat item trong StatusCard grid
class MainHomeStatItem {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  const MainHomeStatItem({
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
  });
}

/// Một shortcut item trong ShortcutDock
class MainHomeShortcutItem {
  final String id;
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const MainHomeShortcutItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradientColors,
    this.onTap,
  });
}

// ─── Main Class ──────────────────────────────────────────────────────────────

/// Bộ widget Aurora Soft cho Main Home Status Cards.
/// Cung cấp 5 card variants với Aurora gradient styling.
class AuroraMainHomeCards {
  AuroraMainHomeCards._();

  // ─── HighlightCard ────────────────────────────────────────────────────────

  /// HighlightCard — hiển thị journey stats, upcoming events, countdown.
  /// Tương đương với _buildModernHighlightCard trong status_cards.dart cũ.
  static Widget buildHighlightCard({
    required BuildContext context,
    required MainHomeHighlightData data,
  }) {
    return RepaintBoundary(
      child: _AuroraHighlightCard(data: data),
    );
  }

  // ─── InsightCard ─────────────────────────────────────────────────────────

  /// InsightCard — hiển thị love score bubbles, action pills, AI suggestion.
  /// Tương đương với _buildModernInsightCard trong status_cards.dart cũ.
  static Widget buildInsightCard({
    required BuildContext context,
    required MainHomeInsightData data,
  }) {
    return RepaintBoundary(
      child: _AuroraInsightCard(data: data),
    );
  }

  // ─── MapCard ─────────────────────────────────────────────────────────────

  /// MapCard — hiển thị khoảng cách, battery, weather info.
  /// Tương đương với _buildModernMapCard trong status_cards.dart cũ.
  static Widget buildMapCard({
    required BuildContext context,
    required MainHomeMapData data,
  }) {
    return RepaintBoundary(
      child: _AuroraMapCard(data: data),
    );
  }

  // ─── StatusGrid ───────────────────────────────────────────────────────────

  /// StatusGrid — hiển thị stats grid với Aurora gradient pills.
  static Widget buildStatusGrid({
    required BuildContext context,
    required List<MainHomeStatItem> stats,
  }) {
    return RepaintBoundary(
      child: _AuroraStatusGrid(stats: stats),
    );
  }

  // ─── ShortcutDock ────────────────────────────────────────────────────────

  /// ShortcutDock — hiển thị pinned apps với Aurora gradient rings.
  /// Tương đương với _buildShortcutDock trong shortcut_dock.dart cũ.
  static Widget buildShortcutDock({
    required BuildContext context,
    required List<MainHomeShortcutItem> shortcuts,
  }) {
    return RepaintBoundary(
      child: _AuroraShortcutDock(shortcuts: shortcuts),
    );
  }
}

// ─── _AuroraHighlightCard ────────────────────────────────────────────────────

class _AuroraHighlightCard extends StatefulWidget {
  final MainHomeHighlightData data;

  const _AuroraHighlightCard({required this.data});

  @override
  State<_AuroraHighlightCard> createState() => _AuroraHighlightCardState();
}

class _AuroraHighlightCardState extends State<_AuroraHighlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _animationEnabled = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: SLauroraCurves.emphasized,
    );
    _checkAnimationPrefs();
    _animCtrl.forward();
  }

  void _checkAnimationPrefs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = UiPrefs.notifier.value;
      if (prefs.liteMode) {
        setState(() => _animationEnabled = false);
        _animCtrl.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_fadeAnim),
        child: GestureDetector(
          onTap: widget.data.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: SLauroraShadow.primaryGlow(),
            ),
            child: _AuroraGlassCard(
              borderGradient: SLAuroraPalette.roseDawn,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _HighlightHeader(
                      nameU1: widget.data.nameU1,
                      nameU2: widget.data.nameU2,
                      isSingle: widget.data.isSingle,
                    ),

                    const SizedBox(height: 14),

                    // Journey stats section
                    _JourneyStatsSection(
                      totalDays: widget.data.totalDays,
                      albumCount: widget.data.albumCount,
                      nameU1: widget.data.nameU1,
                      nameU2: widget.data.nameU2,
                    ),

                    // Upcoming events (next 7 days)
                    if (widget.data.upcomingEvents.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _UpcomingEventsSection(
                        events: widget.data.upcomingEvents,
                        todayMidnight: todayMidnight,
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Countdown banner
                    if (widget.data.countdownText != null)
                      _CountdownBanner(text: widget.data.countdownText!),
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

// ─── _AuroraInsightCard ───────────────────────────────────────────────────────

class _AuroraInsightCard extends StatefulWidget {
  final MainHomeInsightData data;

  const _AuroraInsightCard({required this.data});

  @override
  State<_AuroraInsightCard> createState() => _AuroraInsightCardState();
}

class _AuroraInsightCardState extends State<_AuroraInsightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _premiumEffects = true;
  bool _animationEnabled = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: SLauroraCurves.emphasized,
    );
    _checkAnimationPrefs();
    _animCtrl.forward();
  }

  void _checkAnimationPrefs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = UiPrefs.notifier.value;
      setState(() {
        _premiumEffects = !prefs.liteMode;
        _animationEnabled = !prefs.liteMode;
      });
      if (prefs.liteMode) {
        _animCtrl.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final hasData = widget.data.loveScore != null;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_fadeAnim),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: SLauroraShadow.glass(),
          ),
          child: _AuroraGlassCard(
            borderGradient: SLAuroraPalette.lavenderDusk,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _InsightHeader(isSingle: widget.data.isSingle),

                  const SizedBox(height: 16),

                  // Love score bubbles
                  if (hasData) ...[
                    _InsightBubbles(
                      data: widget.data,
                      enableMotion: _premiumEffects && _animationEnabled,
                    ),
                    const SizedBox(height: 16),

                    // Action pills
                    _ActionPills(),

                    const SizedBox(height: 16),

                    // AI suggestion
                    if (widget.data.suggestion != null)
                      _AISuggestionBlock(
                        suggestion: widget.data.suggestion!,
                        updatedAt: widget.data.updatedAt,
                        label: widget.data.aiLabel,
                      ),
                  ] else ...[
                    _InsightLoadingShimmer(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _AuroraMapCard ──────────────────────────────────────────────────────────

class _AuroraMapCard extends StatelessWidget {
  final MainHomeMapData data;

  const _AuroraMapCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            fallbackColor: Colors.white.withValues(alpha: 0.85),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE0FAFA).withValues(alpha: 0.85),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Map icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00ACC1).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.extension_rounded,
                        color: Color(0xFF0097A7),
                        size: 26,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.isSingle
                              ? L10nService().translate('home_vtrhinti_f5956d')
                              : L10nService().translate('home_bncahaia_12dcb1'),
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF007791),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.distanceText,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2A5F6E),
                            height: 1.4,
                          ),
                        ),
                        if (data.weatherText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.weatherText!,
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5A7B8C),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Battery indicators
                  if (data.myBatteryText != null || data.partnerBatteryText != null)
                    _BatteryIndicators(
                      myBattery: data.myBatteryText,
                      partnerBattery: data.partnerBatteryText,
                    ),

                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF00ACC1),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _AuroraStatusGrid ───────────────────────────────────────────────────────

class _AuroraStatusGrid extends StatelessWidget {
  final List<MainHomeStatItem> stats;

  const _AuroraStatusGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 300 ? 2 : 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.map((stat) {
            return _StatPill(
              stat: stat,
              crossAxisCount: crossAxisCount,
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final MainHomeStatItem stat;
  final int crossAxisCount;

  const _StatPill({
    required this.stat,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = stat.accentColor ?? SLAuroraPalette.roseDeep;
    final isCompact = crossAxisCount > 2;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: SLauroraCurves.gentleSpring,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + 0.2 * value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.12),
              accentColor.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stat.icon != null) ...[
              Icon(
                stat.icon,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 4),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.value,
                  style: SLTheme.quicksand(
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
                Text(
                  stat.label,
                  style: SLTheme.quicksand(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _AuroraShortcutDock ─────────────────────────────────────────────────────

class _AuroraShortcutDock extends StatelessWidget {
  final List<MainHomeShortcutItem> shortcuts;

  const _AuroraShortcutDock({required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) {
      return _ShortcutDockEmpty();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: SLauroraShadow.glass(),
      ),
      child: _AuroraGlassCard(
        borderGradient: SLAuroraPalette.mintBloom,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final crossAxisCount = availableWidth < 280
                ? 2
                : availableWidth < 420
                    ? 3
                    : 4;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shortcuts.length > 8 ? 8 : shortcuts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: crossAxisCount == 2 ? 0.98 : 0.94,
              ),
              itemBuilder: (context, index) {
                return _AuroraShortcutItem(
                  shortcut: shortcuts[index],
                  index: index,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ShortcutDockEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: SLauroraShadow.glass(),
      ),
      child: _AuroraGlassCard(
        borderGradient: SLAuroraPalette.mintBloom,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.push_pin_outlined,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  L10nService().translate('utilities_pin_hint'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuroraShortcutItem extends StatelessWidget {
  final MainHomeShortcutItem shortcut;
  final int index;

  const _AuroraShortcutItem({
    required this.shortcut,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + 60 * index),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.7 + 0.3 * value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: shortcut.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Stack(
            children: [
              // Gloss shine
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Badge dot
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container với Aurora gradient ring
                  _AuroraIconRing(
                    icon: shortcut.icon,
                    gradientColors: shortcut.gradientColors,
                    size: 40,
                  ),

                  const SizedBox(height: 4),

                  Expanded(
                    child: Center(
                      child: Text(
                        shortcut.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aurora Icon Ring ─────────────────────────────────────────────────────────

class _AuroraIconRing extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final double size;

  const _AuroraIconRing({
    required this.icon,
    required this.gradientColors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = gradientColors.isNotEmpty
        ? gradientColors.first
        : SLAuroraPalette.roseDeep;
    final secondaryColor = gradientColors.length > 1
        ? gradientColors[1]
        : SLAuroraPalette.lavender;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Aurora Glass Card ───────────────────────────────────────────────────────

/// Glass card với Aurora gradient border (1.5px)
class _AuroraGlassCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? borderGradient;

  const _AuroraGlassCard({
    required this.child,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final hasBorder = borderGradient != null;

    if (hasBorder) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: borderGradient,
          boxShadow: SLauroraShadow.primaryGlow(
            color: borderGradient!.colors.first.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.5),
          child: _GlassCardContent(child: child),
        ),
      );
    }

    return _GlassCardContent(child: child);
  }
}

class _GlassCardContent extends StatelessWidget {
  final Widget child;

  const _GlassCardContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.5),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        fallbackColor: Colors.white.withValues(alpha: 0.88),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Sub-Widgets ─────────────────────────────────────────────────────────────

// HighlightCard sub-widgets

class _HighlightHeader extends StatelessWidget {
  final String nameU1;
  final String nameU2;
  final bool isSingle;

  const _HighlightHeader({
    required this.nameU1,
    required this.nameU2,
    required this.isSingle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar icon
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SLAuroraPalette.roseDeep.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Image.asset(
              'assets/icons/cute_3d/icon_bubble_lol_cloud.png',
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10nService().translate('home_khonhkhcni_903ef3'),
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF263242),
                ),
              ),
              Text(
                L10nService().translate('home_nhngiungtn_061ab5'),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: Colors.black26,
          size: 24,
        ),
      ],
    );
  }
}

class _JourneyStatsSection extends StatelessWidget {
  final int totalDays;
  final int albumCount;
  final String nameU1;
  final String nameU2;

  const _JourneyStatsSection({
    required this.totalDays,
    required this.albumCount,
    required this.nameU1,
    required this.nameU2,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        fallbackColor: Colors.white.withValues(alpha: 0.7),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Row 1: Days + Albums
              Row(
                children: [
                  Expanded(
                    child: _JourneyStatTile(
                      imageAsset: 'assets/icons/cute_3d/card_ngay_yeu_calendar.png',
                      value: totalDays > 0 ? '$totalDays' : '--',
                      label: L10nService().translate('home_love_days'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _JourneyStatTile(
                      imageAsset: 'assets/icons/cute_3d/card_ky_niem_photos.png',
                      value: '$albumCount',
                      label: L10nService().translate('home_anniversary_memories'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Names
              Row(
                children: [
                  Expanded(
                    child: _JourneyStatTile(
                      imageAsset: 'assets/icons/cute_3d/card_ban_nam_boy.png',
                      value: nameU1,
                      label: nameU1,
                      isSmall: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _JourneyStatTile(
                      imageAsset: 'assets/icons/cute_3d/card_ban_nu_girl.png',
                      value: nameU2,
                      label: nameU2,
                      isSmall: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyStatTile extends StatelessWidget {
  final String? imageAsset;
  final String value;
  final String label;
  final bool isSmall;

  const _JourneyStatTile({
    this.imageAsset,
    required this.value,
    required this.label,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SLAuroraPalette.roseDeep.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset!,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            )
          else
            const SizedBox(width: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: isSmall ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF263242),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A6B84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventsSection extends StatelessWidget {
  final List<MainHomeUpcomingEvent> events;
  final DateTime todayMidnight;

  const _UpcomingEventsSection({
    required this.events,
    required this.todayMidnight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        fallbackColor: Colors.white.withValues(alpha: 0.7),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sắp tới có sự kiện gì',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF263242),
                ),
              ),
              const SizedBox(height: 8),
              ...events.take(5).map((e) {
                final daysUntil = e.date.difference(todayMidnight).inDays;
                final timeStr = daysUntil <= 0
                    ? L10nService().translate('home_hmnay_d87b33')
                    : (daysUntil == 1
                        ? L10nService().translate('home_ngymai_a3d820')
                        : L10nService().format('home_days_later', {'n': daysUntil}));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6D97),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF6D97),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  final String text;

  const _CountdownBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5277), Color(0xFFFF758C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4F87).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 13,
                  color: Color(0xFFFFE082),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFFF4F87),
            ),
          ),
        ],
      ),
    );
  }
}

// InsightCard sub-widgets

class _InsightHeader extends StatelessWidget {
  final bool isSingle;

  const _InsightHeader({required this.isSingle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0F5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF4F87),
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            isSingle
                ? L10nService().translate('home_tngquanhmn_0e1b6b')
                : L10nService().translate('home_hnhtrnhiqu_cbcf59'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1,
              color: const Color(0xFFFF4F87),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightBubbles extends StatelessWidget {
  final MainHomeInsightData data;
  final bool enableMotion;

  const _InsightBubbles({
    required this.data,
    required this.enableMotion,
  });

  @override
  Widget build(BuildContext context) {
    final specs = <_AuroraInsightBubbleSpec>[];

    if (!data.isSingle && data.loveU1 != null) {
      specs.add(_AuroraInsightBubbleSpec(
        label: data.nameU1 ?? '',
        value: data.loveU1!,
        color: const Color(0xFF42A5F5),
        phase: 0.2,
      ));
    }

    specs.add(_AuroraInsightBubbleSpec(
      label: data.isSingle ? 'LEVEL' : 'LOVE',
      value: data.loveScore ?? 0,
      color: SLColors.primary,
      phase: 1.4,
      emphasize: true,
    ));

    if (!data.isSingle && data.loveU2 != null) {
      specs.add(_AuroraInsightBubbleSpec(
        label: data.nameU2 ?? '',
        value: data.loveU2!,
        color: const Color(0xFF7B7FF6),
        phase: 2.5,
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < specs.length; index++) ...[
          Expanded(
            child: Center(
              child: _AuroraFloatingBubble(
                spec: specs[index],
                enableMotion: enableMotion,
              ),
            ),
          ),
          if (index < specs.length - 1) const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class _AuroraInsightBubbleSpec {
  final String label;
  final int value;
  final Color color;
  final double phase;
  final bool emphasize;

  const _AuroraInsightBubbleSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.phase,
    this.emphasize = false,
  });
}

class _AuroraFloatingBubble extends StatefulWidget {
  final _AuroraInsightBubbleSpec spec;
  final bool enableMotion;

  const _AuroraFloatingBubble({
    required this.spec,
    required this.enableMotion,
  });

  @override
  State<_AuroraFloatingBubble> createState() => _AuroraFloatingBubbleState();
}

class _AuroraFloatingBubbleState extends State<_AuroraFloatingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final double _bubbleSize = 60.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4200 + (widget.spec.phase * 240).round()),
    );
    if (widget.enableMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AuroraFloatingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      if (widget.enableMotion) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.spec.value.clamp(0, 100);
    final label = widget.spec.label.isEmpty ? 'LOVE' : widget.spec.label;
    final shouldUseLoveBlock = widget.spec.emphasize && label.toUpperCase() == 'LOVE';

    Widget content;
    if (shouldUseLoveBlock) {
      content = _buildLoveBlock(clampedValue, label);
    } else {
      content = _buildProgressBubble(clampedValue, label);
    }

    if (!widget.enableMotion) return content;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating) return child!;
        final angle = (_controller.value * 2 * math.pi) + widget.spec.phase;
        final verticalShift = math.sin(angle) * 1.8;
        final horizontalShift = math.cos(angle * 0.9) * 0.5;
        final scale = 1 + (math.sin(angle + 0.8) * 0.006);

        return Transform.translate(
          offset: Offset(horizontalShift, -verticalShift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: content,
    );
  }

  Widget _buildProgressBubble(int clampedValue, String label) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clampedValue / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _bubbleSize,
              height: _bubbleSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background bubble
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.98),
                            widget.spec.color.withValues(
                              alpha: widget.spec.emphasize ? 0.18 : 0.11,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.spec.color.withValues(
                              alpha: widget.spec.emphasize ? 0.16 : 0.1,
                            ),
                            blurRadius: widget.spec.emphasize ? 16 : 12,
                            offset: const Offset(0, 7),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.82),
                            blurRadius: 8,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Shine
                  Positioned(
                    top: _bubbleSize * 0.12,
                    left: _bubbleSize * 0.16,
                    child: Container(
                      width: _bubbleSize * 0.28,
                      height: _bubbleSize * 0.14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Progress ring
                  SizedBox(
                    width: _bubbleSize * 0.78,
                    height: _bubbleSize * 0.78,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4.6,
                      backgroundColor: widget.spec.color.withValues(alpha: 0.09),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.spec.color),
                    ),
                  ),
                  // Center dot
                  Container(
                    width: _bubbleSize * 0.52,
                    height: _bubbleSize * 0.52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          widget.spec.color.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                  // Value text
                  Text(
                    '$clampedValue',
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: widget.spec.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF74707A),
                  height: 1.1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoveBlock(int clampedValue, String label) {
    const blockWidth = 94.0;
    const blockHeight = 78.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: SLauroraCurves.soulSpring,
      builder: (context, animValue, _) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            width: blockWidth,
            height: blockHeight,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.3),
                radius: 0.85,
                colors: [
                  Color(0xFFFF85A1),
                  Color(0xFFFF4F87),
                  Color(0xFFE91E63),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F87).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gloss shine
                Positioned(
                  top: 6,
                  left: 12,
                  child: Container(
                    width: blockWidth * 0.45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          label,
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$clampedValue%',
                      style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionPill(
            icon: Icons.mail_rounded,
            label: 'Lời nhắn',
            color: SLColors.primary,
            borderColor: const Color(0xFFFFD1DF),
            isGradient: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.touch_app_rounded,
            label: 'Ấn vào',
            color: Colors.white,
            borderColor: Colors.transparent,
            isGradient: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.card_giftcard_rounded,
            label: 'Mở ngay',
            color: const Color(0xFF00838F),
            borderColor: const Color(0xFF80DEEA),
            isGradient: false,
            bgColor: const Color(0xFFE0F7FA),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final bool isGradient;
  final Color? bgColor;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.isGradient,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        gradient: isGradient
            ? const LinearGradient(
                colors: [Color(0xFFFF4F87), Color(0xFFFF758C)],
              )
            : null,
        color: isGradient ? null : (bgColor ?? Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isGradient ? const Color(0xFFFF4F87) : color)
                .withValues(alpha: isGradient ? 0.35 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AISuggestionBlock extends StatelessWidget {
  final String suggestion;
  final int? updatedAt;
  final String? label;

  const _AISuggestionBlock({
    required this.suggestion,
    this.updatedAt,
    this.label,
  });

  String _formatUpdatedAt(int updatedAt) {
    if (updatedAt <= 0) {
      return L10nService().translate('home_cpnhtgnnht_af26d6');
    }

    final now = DateTime.now();
    final updated = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final diff = now.difference(updated);

    if (diff.inMinutes < 1) {
      return L10nService().translate('home_cpnhtgnnht_d75b69');
    }
    if (diff.inHours < 1) {
      return L10nService().format('home_updated_minutes_ago', {'n': diff.inMinutes});
    }
    if (diff.inDays < 1) {
      return L10nService().format('home_updated_hours_ago', {'n': diff.inHours});
    }
    return L10nService().format('home_updated_days_ago', {'n': diff.inDays});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.86),
            const Color(0xFFFFF4F8).withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9BBC).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label ?? L10nService().translate('home_linhndudng_83e5d9'),
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: SLColors.accent.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 4),
          if (updatedAt != null)
            Text(
              _formatUpdatedAt(updatedAt!),
              style: SLTheme.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: SLColors.textTertiary,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            suggestion,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: SLColors.textSecondary,
              height: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightLoadingShimmer extends StatefulWidget {
  @override
  State<_InsightLoadingShimmer> createState() => _InsightLoadingShimmerState();
}

class _InsightLoadingShimmerState extends State<_InsightLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final value = 0.4 + (_shimmerCtrl.value * 0.6);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bubble placeholders
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: SLColors.primary.withValues(alpha: value * 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 18),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Text placeholders
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: SLColors.primary.withValues(alpha: value * 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 200,
              decoration: BoxDecoration(
                color: SLColors.primary.withValues(alpha: value * 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Battery indicators for MapCard

class _BatteryIndicators extends StatelessWidget {
  final String? myBattery;
  final String? partnerBattery;

  const _BatteryIndicators({
    this.myBattery,
    this.partnerBattery,
  });

  @override
  Widget build(BuildContext context) {
    final batteries = <String>[];
    if (myBattery != null) batteries.add(myBattery!);
    if (partnerBattery != null) batteries.add(partnerBattery!);

    if (batteries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: batteries.map((b) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            b,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5A7B8C),
            ),
          ),
        );
      }).toList(),
    );
  }
}
