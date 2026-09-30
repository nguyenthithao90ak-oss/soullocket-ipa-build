import 'package:flutter/material.dart';
import '../../utils/services/love_insight_service.dart';
import '../../utils/services/offline_cache_service.dart';
import '../../utils/services/l10n_service.dart';
import 'love_insights_view.dart';

class LoveInsightsScreen extends StatefulWidget {
  final String houseId;
  final String nameU1;
  final String nameU2;
  final String avatarU1;
  final String avatarU2;
  final int loveDays;
  final String relationshipMode;

  const LoveInsightsScreen({
    super.key,
    required this.houseId,
    required this.nameU1,
    required this.nameU2,
    required this.avatarU1,
    required this.avatarU2,
    required this.loveDays,
    required this.relationshipMode,
  });

  @override
  State<LoveInsightsScreen> createState() => _LoveInsightsScreenState();
}

class _LoveInsightsScreenState extends State<LoveInsightsScreen> {
  final LoveInsightService _insightService = LoveInsightService();

  LoveInsightData? _insight;
  bool _isLoading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    final cacheKey = 'love_insight_${widget.houseId}';
    final cachedData = OfflineCacheService.loadCacheSync(cacheKey);
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _insight = LoveInsightData.fromMap(
            Map<String, dynamic>.from(cachedData),
          );
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final insight = await _insightService.computeInsights(
        widget.houseId,
        widget.relationshipMode,
      );

      OfflineCacheService.saveCache(cacheKey, insight.toMap());

      if (!mounted) return;
      setState(() {
        _insight = insight;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_insight == null) {
          _isLoading = false;
          _errorText = L10nService().translate('insight_error_load');
        } else {
          _isLoading =
              false; // keep showing cache if error occurs but cache exists
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoveInsightsView(
      data: _insight,
      isLoading: _isLoading,
      errorText: _errorText,
      onRefresh: _loadInsight,
      nameU1: widget.nameU1,
      nameU2: widget.nameU2,
      avatarU1: widget.avatarU1,
      avatarU2: widget.avatarU2,
      loveDays: widget.loveDays,
      relationshipMode: widget.relationshipMode,
    );
  }
}
