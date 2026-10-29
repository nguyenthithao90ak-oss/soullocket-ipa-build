import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/services/love_insight_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/utility_service.dart';
import '../../widgets/pro_upsell_dialog.dart';
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
  bool? _isPro;
  int _loadGeneration = 0;
  StreamSubscription<User?>? _authSubscription;
  String? _screenUid;
  String? _localeCode;

  @override
  void initState() {
    super.initState();
    _screenUid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _screenUid) return;
      _screenUid = user?.uid;
      _loadGeneration++;
      setState(() {
        _insight = null;
        _isLoading = false;
        _errorText = L10nService().translate('insight_error_load');
        _isPro = null;
      });
    });
    _loadInsight();
    final proUid = _screenUid;
    unawaited(
      checkProAccess().then((isPro) {
        if (mounted &&
            proUid == _screenUid &&
            proUid == FirebaseAuth.instance.currentUser?.uid) {
          setState(() => _isPro = isPro);
        }
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final changed = _localeCode != null && _localeCode != locale;
    _localeCode = locale;
    if (changed) {
      _insight = null;
      _loadInsight();
    }
  }

  @override
  void didUpdateWidget(covariant LoveInsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.relationshipMode != widget.relationshipMode) {
      _insight = null;
      _loadInsight();
    }
  }

  Future<void> _loadInsight({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = widget.houseId;
    final mode = widget.relationshipMode;
    bool isCurrent() =>
        mounted &&
        generation == _loadGeneration &&
        uid == FirebaseAuth.instance.currentUser?.uid &&
        houseId == widget.houseId &&
        mode == widget.relationshipMode;
    final cached = _insightService.loadCachedInsight(houseId, mode);
    setState(() {
      _insight ??= cached;
      _isLoading = _insight == null;
      _errorText = null;
    });

    try {
      final insight = await _insightService.computeInsights(
        houseId,
        mode,
        forceRefresh: forceRefresh,
      );

      if (!isCurrent()) return;
      setState(() {
        _insight = insight;
        _isLoading = false;
      });
    } catch (_) {
      if (!isCurrent()) return;
      setState(() {
        if (_insight == null) {
          _isLoading = false;
          _errorText = L10nService().translate('insight_error_load');
        } else {
          _isLoading = false;
          _insight = LoveInsightData.fromMap({
            ..._insight!.toMap(),
            'isStale': true,
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoveInsightsView(
      data: _insight,
      isLoading: _isLoading,
      errorText: _errorText,
      onRefresh: () => _loadInsight(forceRefresh: true),
      nameU1: widget.nameU1,
      nameU2: widget.nameU2,
      avatarU1: widget.avatarU1,
      avatarU2: widget.avatarU2,
      loveDays: widget.loveDays,
      relationshipMode: widget.relationshipMode,
      isPro: _isPro ?? UtilityService.proAccess.value ?? true,
      onUpgrade: () => showProUpsell(
        context,
        houseId: widget.houseId,
        message: L10nService().translate('pro_insights_desc'),
      ),
    );
  }
}
