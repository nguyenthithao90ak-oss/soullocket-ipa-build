// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../services/house_service.dart';
import '../../services/social_service.dart';
import '../../utils/app_error_mapper.dart';
import '../visitors/visitor_profile_screen.dart';

class TopHotScreen extends StatefulWidget {
  const TopHotScreen({super.key});

  @override
  State<TopHotScreen> createState() => _TopHotScreenState();
}

class _TopHotScreenState extends State<TopHotScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _houseService = HouseService();
  final _socialService = SocialService();

  late final TabController _tabController;

  bool _isLoading = true;
  String? _myHouseId;
  String _currentPeriod = 'day';
  List<_HouseEntry> _sorted = [];

  static const _periods = ['day', 'week', 'month', 'year'];
  static final _periodLabels = [
    L10nService().translate('comm_ngy_b9474a'),
    L10nService().translate('comm_tun_c54621'),
    L10nService().translate('comm_thng_570330'),
    L10nService().translate('comm_nm_d1301c'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final period = _periods[_tabController.index];
      if (period != _currentPeriod) {
        setState(() => _currentPeriod = period);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _myHouseId ??= await _houseService.getCurrentHouseId();

    try {
      // 1. Lấy tất cả điểm lửa
      final fireSnap = await _db.ref('uploads/fire_totals').get();
      if (!fireSnap.exists || fireSnap.value is! Map) {
        setState(() {
          _sorted = [];
          _isLoading = false;
        });
        return;
      }

      final fireData = Map<String, dynamic>.from(
        Map<dynamic, dynamic>.from(fireSnap.value as Map),
      );

      // 2. Sắp xếp theo điểm lửa (giảm dần)
      final sortedIds = fireData.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));

      // Lấy Top 50
      final topIds = sortedIds.take(50).toList();

      // 3. Lấy thông tin profile cho từng nhà
      final List<_HouseEntry> entries = [];
      for (var entry in topIds) {
        final houseId = entry.key;
        final hearts = (entry.value as num).toInt();

        final profileSnap = await _db.ref('house_profiles/$houseId').get();
        if (profileSnap.exists && profileSnap.value is Map) {
          final profile = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(profileSnap.value as Map),
          );
          final settings = profile['settings'] is Map
              ? Map<String, dynamic>.from(
                  Map<dynamic, dynamic>.from(profile['settings'] as Map),
                )
              : <String, dynamic>{};

          entries.add(_HouseEntry(
            id: houseId,
            name: profile['houseName']?.toString() ??
                profile['name']?.toString() ??
                houseId,
            avatar: settings['houseAvatar']?.toString() ??
                profile['houseAvatar']?.toString() ??
                profile['avatar']?.toString(),
            bio: (settings['bio'] ?? profile['bio'] ?? '').toString().trim(),
            hearts: hearts,
            updatedAt: profile['updatedAt'] ?? 0,
            isPro: (((settings['proUntil'] ?? profile['proUntil']) as num?)
                        ?.toInt() ??
                    0) >
                DateTime.now().millisecondsSinceEpoch,
            adminTick: settings['adminFireTick'] == true ||
                settings['redTickPro'] == true,
            rankTicks: settings['rankTicks'] is Map
                ? Map<String, dynamic>.from(
                    Map<dynamic, dynamic>.from(settings['rankTicks'] as Map),
                  )
                : {},
            rankPersistentGold: settings['rankPersistentGold'] is Map
                ? Map<String, dynamic>.from(
                    Map<dynamic, dynamic>.from(
                      settings['rankPersistentGold'] as Map,
                    ),
                  )
                : {},
            hotScore: (profile['hotScore'] as num?)?.toInt() ?? 0,
          ));
        } else {
          // Fallback nếu không có profile
          entries.add(_HouseEntry(
            id: houseId,
            name: 'Nhà ẩn danh',
            avatar: null,
            bio: '',
            hearts: hearts,
            updatedAt: 0,
            isPro: false,
            adminTick: false,
            rankTicks: {},
            rankPersistentGold: {},
            hotScore: 0,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _sorted = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải BXH: ${AppErrorMapper.resolve(e).message}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _hotLevelColor(int percent) {
    if (percent >= 75) return const Color(0xFFF2645A);
    if (percent >= 40) return const Color(0xFFF7A458);
    return const Color(0xFFD39AA0);
  }

  int? _currentPeriodRank(_HouseEntry entry) {
    if (_currentPeriod == 'year' && entry.rankPersistentGold['year'] == true) {
      return 1;
    }
    if (_currentPeriod == 'month' &&
        entry.rankPersistentGold['month'] == true) {
      return 1;
    }

    final tick = entry.rankTicks[_currentPeriod];
    if (tick is! Map) return null;
    final rank = (tick['rank'] as num?)?.toInt();
    if (rank == null || rank < 1 || rank > 3) return null;
    return rank;
  }

  List<_HouseEntry> _entriesForCurrentPeriod() {
    final entries = List<_HouseEntry>.from(_sorted);
    final hasPeriodRanks =
        entries.any((entry) => _currentPeriodRank(entry) != null);
    entries.sort((a, b) {
      if (hasPeriodRanks) {
        final rankA = _currentPeriodRank(a);
        final rankB = _currentPeriodRank(b);
        if (rankA != null && rankB != null) {
          final diff = rankA.compareTo(rankB);
          if (diff != 0) return diff;
        } else if (rankA != null) {
          return -1;
        } else if (rankB != null) {
          return 1;
        }
      }

      final heartDiff = b.hearts.compareTo(a.hearts);
      if (heartDiff != 0) return heartDiff;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return entries;
  }

  Widget _currentPeriodBadge(_HouseEntry entry) {
    final rank = _currentPeriodRank(entry);
    if (rank == null) return const SizedBox.shrink();

    final color = switch (rank) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF38BDF8),
      _ => const Color(0xFFB45309),
    };
    return _chip('Top $rank ${_labelForPeriod(_currentPeriod)}', color);
  }

  Widget _rankPill(int rank) {
    final isTop = rank <= 3;
    final colors = switch (rank) {
      1 => const [Color(0xFFFFFAE8), Color(0xFFFFE4A8)],
      2 => const [Color(0xFFFAFCFF), Color(0xFFDCEBFF)],
      3 => const [Color(0xFFFFF5EE), Color(0xFFF4D1B4)],
      _ => const [Color(0xFFFFFFFF), Color(0xFFFFF6F1)],
    };
    final textColor = switch (rank) {
      1 => const Color(0xFFB45309),
      2 => const Color(0xFF2563EB),
      3 => const Color(0xFFA16207),
      _ => const Color(0xFF5B6474),
    };
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTop ? textColor.withValues(alpha: 0.22) : const Color(0xFFEDE1DA),
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: isTop ? 0.12 : 0.06),
            blurRadius: isTop ? 18 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        '#$rank',
        style: SLTheme.quicksand(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildHeatBar(double progress, Color hotColor) {
    final fillStart = Color.lerp(hotColor, Colors.white, 0.12) ?? hotColor;
    final fillEnd =
        Color.lerp(hotColor, const Color(0xFFFFB491), 0.32) ?? hotColor;

    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final resolvedWidth = (maxWidth * progress).clamp(18.0, maxWidth);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFF3EE),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: resolvedWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [fillStart, fillEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: hotColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tickBadge(Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(Icons.verified_rounded, size: 16, color: color),
    );
  }

  String _labelForPeriod(String period) {
    switch (period) {
      case 'week':
        return context.tr('comm_tun_3e01ac');
      case 'month':
        return context.tr('comm_thng_59900e');
      case 'year':
        return context.tr('comm_nm_923e10');
      default:
        return context.tr('comm_ngy_41ec10');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _entriesForCurrentPeriod();
    final maxVisibleHearts = visibleEntries.fold<int>(
      0,
      (maxValue, entry) => entry.hearts > maxValue ? entry.hearts : maxValue,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFA07D),
                Color(0xFFF56F87),
                Color(0xFFFFB487),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: SLSpacing.all8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            SLSpacing.w8,
            Text(
              'TOP HOT',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Container(
              padding: SLSpacing.all8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ),
          IconButton(
            onPressed: _showLegend,
            icon: Container(
              padding: SLSpacing.all8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.info_outline_rounded, size: 18),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: TabBar(
                controller: _tabController,
                padding: const EdgeInsets.all(6),
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFFF7F3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w900),
                unselectedLabelStyle:
                    SLTheme.quicksand(fontWeight: FontWeight.w700),
                labelColor: const Color(0xFFF0677D),
                unselectedLabelColor: Colors.white.withValues(alpha: 0.86),
                dividerColor: Colors.transparent,
                tabs: _periodLabels.map((l) => Tab(text: l)).toList(),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFCFA),
              Color(0xFFFFF4EE),
              Color(0xFFFFFAF7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFFF45B7A),
                      strokeWidth: 2.5,
                    ),
                    SLSpacing.h16,
                    Text(
                      context.tr('comm_angtibngxp_f19b2e'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFF8B5E6C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFFF45B7A),
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
                  children: [
                    if (visibleEntries.isEmpty)
                      _buildEmpty()
                    else ...[
                      ...List.generate(
                        visibleEntries.length,
                        (index) => _buildCompactRankItem(
                          visibleEntries[index],
                          index,
                          maxVisibleHearts,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCompactRankItem(_HouseEntry entry, int index, int maxHearts) {
    final safeMaxHearts = maxHearts > 0 ? maxHearts.toDouble() : 1.0;
    final progress = (entry.hearts / safeMaxHearts).clamp(0.04, 1.0);
    final hotPercent = (progress * 100).round();
    final hotColor = _hotLevelColor(hotPercent);
    final isSelf = entry.id == _myHouseId;
    final rank = index + 1;

    final cardGradient = switch (rank) {
      1 => const [Color(0xFFFFFCF2), Color(0xFFFFF1CC), Color(0xFFFFFFFF)],
      2 => const [Color(0xFFFCFDFF), Color(0xFFEAF2FF), Color(0xFFFFFFFF)],
      3 => const [Color(0xFFFFFAF5), Color(0xFFFFE9D8), Color(0xFFFFFFFF)],
      _ => const [Color(0xFFFFFFFF), Color(0xFFFFFAF7)],
    };
    final borderColor = switch (rank) {
      1 => const Color(0xFFF4C886),
      2 => const Color(0xFFC7DAFF),
      3 => const Color(0xFFF0C7A7),
      _ => isSelf ? const Color(0xFFF3B1BC) : const Color(0xFFF2DFD8),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitorProfileScreen(targetHouseId: entry.id),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: borderColor,
                width: rank <= 3 || isSelf ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: rank <= 3 ? 0.18 : 0.1),
                  blurRadius: rank <= 3 ? 24 : 16,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.72),
                  blurRadius: 12,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rankPill(rank),
                      SLSpacing.w12,
                      _buildAvatar(entry, index),
                      SLSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  entry.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.2,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                if (isSelf)
                                  _chip(context.tr('comm_bn_1fd75b'), Color(0xFF16A34A)),
                                _currentPeriodBadge(entry),
                              ],
                            ),
                            SLSpacing.h4,
                            Text(
                              entry.bio.isNotEmpty
                                  ? entry.bio
                                  : context.tr('comm_chathmtius_0ede4b'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.45,
                                color: const Color(0xFF86636D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SLSpacing.w12,
                      Container(
                        constraints: const BoxConstraints(minWidth: 66),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFFBF7),
                              Color(0xFFFFFBF8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: hotColor.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hotColor.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14,
                                  color: hotColor,
                                ),
                                SLSpacing.w4,
                                Text(
                                  _formatHearts(entry.hearts),
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                    color: hotColor,
                                  ),
                                ),
                              ],
                            ),
                            SLSpacing.h4,
                            Text(
                              context.tr('comm_la_67f0e2'),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: const Color(0xFFA07A84),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h12,
                  _buildHeatBar(progress, hotColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem(_HouseEntry entry, int index) {
    final maxHearts = (_sorted.isNotEmpty && _sorted.first.hearts > 0)
        ? _sorted.first.hearts.toDouble()
        : 1.0;
    final hotPercent = ((entry.hearts / maxHearts) * 100).clamp(2, 100).round();
    final hotColor = _hotLevelColor(hotPercent);
    final isSelf = entry.id == _myHouseId;

    final medal = switch (index) {
      0 => _medalBadge(
          background: const [Color(0xFFFFF7CC), Color(0xFFFEF08A)],
          icon: '🏆',
        ),
      1 => _medalBadge(
          background: const [Color(0xFFF1F5F9), Color(0xFFDBE4EE)],
          icon: '🥈',
        ),
      2 => _medalBadge(
          background: const [Color(0xFFFDE7D7), Color(0xFFF6C39A)],
          icon: '🥉',
        ),
      _ => Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: SLRadius.mdAll,
          ),
          child: Text(
            'TOP\n${index + 1}',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF475569),
            ),
          ),
        ),
    };

    final cardGradient = switch (index) {
      0 => const [Color(0xFFFFF7CC), Color(0xFFFEEA8A), Color(0xFFFFF8DB)],
      1 => const [Color(0xFFF8FBFF), Color(0xFFE8F2FB)],
      2 => const [Color(0xFFFFF2E8), Color(0xFFFDE0C3)],
      _ => const [Color(0xFFECF6FF), Color(0xFFE1F0FF)],
    };

    final leftAccent = switch (index) {
      0 => const Color(0xFFF59E0B),
      1 => const Color(0xFF4FC3F7),
      2 => const Color(0xFFCD7F32),
      _ => isSelf ? const Color(0xFF22C55E) : const Color(0x00000000),
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisitorProfileScreen(targetHouseId: entry.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: SLSpacing.all12,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: SLRadius.xlAll,
          border: Border.all(
            color: isSelf
                ? const Color(0xFF86EFAC)
                : (index == 0
                    ? const Color(0xFFFFD166)
                    : Colors.white.withValues(alpha: 0.9)),
            width: isSelf ? 2.0 : (index == 0 ? 2.0 : 1),
          ),
          boxShadow: [
            if (index == 0)
              BoxShadow(
                color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: hotColor.withValues(alpha: index < 3 ? 0.22 : 0.1),
              blurRadius: index < 3 ? 20 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 98,
              decoration: BoxDecoration(
                color: leftAccent,
                borderRadius: SLRadius.pillAll,
              ),
            ),
            SLSpacing.w12,
            SizedBox(width: 42, child: medal),
            SLSpacing.w8,
            _buildAvatar(entry, index),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              entry.name,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: entry.isPro
                                    ? const Color(0xFFF7C948)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (isSelf) _chip(context.tr('comm_bn_1fd75b'), Color(0xFF16A34A)),
                            if (entry.adminTick)
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 16,
                                color: Color(0xFFFF3D00),
                              ),
                            _savedRankTick(entry),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h8,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: Color(0xFFFF6A00),
                          ),
                          SLSpacing.w4,
                          Text(
                            '${entry.hearts} Lửa',
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF475569),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      _chip(
                        '$hotPercent% ${_hotLevelLabel(hotPercent)}',
                        hotColor,
                      ),
                      if (entry.hotScore > 0)
                        _chip('HOT ${entry.hotScore}', const Color(0xFFD81B60)),
                      if (index == 0)
                        _chip(context.tr('comm_qunqun_1b53f8'), Color(0xFFFF7B00),
                            isGold: true),
                    ],
                  ),
                  SLSpacing.h8,
                  ClipRRect(
                    borderRadius: SLRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: hotPercent / 100,
                      minHeight: 7,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(hotColor),
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.w8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF2F2), Color(0xFFFFE8E0)],
                ),
                borderRadius: SLRadius.pillAll,
                border: Border.all(
                  color: const Color(0xFFFF9E7A).withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF6A00),
                    size: 16,
                  ),
                  Text(
                    _formatHearts(entry.hearts),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(_HouseEntry entry, int index) {
    final borderColor = switch (index) {
      0 => const Color(0xFFF59E0B),
      1 => const Color(0xFF4FC3F7),
      2 => const Color(0xFFCD7F32),
      _ => const Color(0xFFE2E8F0),
    };

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: index < 3 ? 2.6 : 1.3),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF6F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: entry.avatar != null
            ? CachedNetworkImage(
                memCacheWidth: 540,
                imageUrl: entry.avatar!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorWidget: (_, __, ___) => _avatarFallback(entry.name),
              )
            : _avatarFallback(entry.name),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final firstChar = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFB9C8),
            Color(0xFFFF96B0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        firstChar,
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _medalBadge({
    required List<Color> background,
    required String icon,
  }) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: background),
        borderRadius: SLRadius.mdAll,
      ),
      child: Text(icon, style: const TextStyle(fontSize: 24)),
    );
  }

  Widget _chip(String text, Color color, {bool isGold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: isGold ? const Color(0xFFFFFAF0) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isGold ? const Color(0xFFFFD166) : color.withValues(alpha: 0.18),
          width: isGold ? 1.2 : 0.8,
        ),
        boxShadow: isGold
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.2),
                  blurRadius: 8,
                )
              ]
            : null,
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          color: isGold ? const Color(0xFFB45309) : color,
          fontWeight: FontWeight.w900,
          fontSize: 10.2,
        ),
      ),
    );
  }

  Widget _savedRankTick(_HouseEntry entry) => const SizedBox.shrink();

  String _hotLevelLabel(int percent) => 'hot';

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF4DED6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5CFC5).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 58)),
          SLSpacing.h12,
          Text(
            context.tr('comm_chacdliuxp_afecdc'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: const Color(0xFF5F4150),
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr('comm_khiccnhbtu_a6da85'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8D6A77),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHearts(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  void _showLegend() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: SLSpacing.all16,
          decoration: BoxDecoration(
            borderRadius: SLRadius.xlAll,
            border: Border.all(color: const Color(0xFFFFD3C9)),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF3EE), Color(0xFFFFF8FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9E63), Color(0xFFF45B7A)],
                      ),
                      borderRadius: SLRadius.mdAll,
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('comm_niquytopho_629576'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: const Color(0xFF5B3242),
                          ),
                        ),
                        Text(
                          context.tr('comm_cpnhttngth_44330b'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: const Color(0xFF8D6A77),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SLSpacing.h12,
              ...[
                context.tr('comm_top1nhncpv_8e9a68'),
                context.tr('comm_top2nhncpb_20b79d'),
                context.tr('comm_top3nhncpn_e24132'),
                context.tr('comm_ticklcquyn_e7c99a'),
                context.tr('comm_mithnghthn_6a3298'),
                context.tr('comm_mimchintht_fa11a0'),
                context.tr('comm_mi3thngres_71ddd9'),
              ].map(
                (rule) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    rule,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                      color: const Color(0xFF334155),
                    ),
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

class _HouseEntry {
  final String id;
  final String name;
  final String? avatar;
  final String bio;
  final int hearts;
  final int updatedAt;
  final bool isPro;
  final bool adminTick;
  final Map<String, dynamic> rankTicks;
  final Map<String, dynamic> rankPersistentGold;
  final int hotScore;

  const _HouseEntry({
    required this.id,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.hearts,
    required this.updatedAt,
    required this.isPro,
    required this.adminTick,
    required this.rankTicks,
    required this.rankPersistentGold,
    required this.hotScore,
  });
}
