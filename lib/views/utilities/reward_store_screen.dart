import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../utils/services/admob_service.dart';
import '../../utils/services/daily_quest_service.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/security_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../models/reward_missions.dart';
import '../../utils/services/consent_service.dart';
import 'reward_store_panels.dart';

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen>
    with WidgetsBindingObserver {
  final AdMobService _adMob = AdMobService();
  final DailyQuestService _dailyQuestService = DailyQuestService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final Stream<int> _proUntilStream;
  late final Stream<int> _pointsStream;
  late Stream<Map<String, dynamic>> _questsStream;
  String _rewardDay = rewardDayKey();
  Timer? _dayTimer;
  StreamSubscription<DatabaseEvent>? _userSubscription;
  StreamSubscription<DatabaseEvent>? _adRewardsSubscription;
  bool _isWatchingAd = false;
  bool _isRedeeming = false;
  bool _isCheckingIn = false;

  Map<String, bool> _checkinDays = {};
  bool _checkedInToday = false;
  bool _isCheckinLoaded = false;
  int _streak = 0;

  // Daily ad limit tracking
  int _dailyAdCount = 0;
  final int _dailyAdLimit = AdMobService.dailyRewardedAdLimit;
  bool _isAdRewardsLoaded = false;
  bool _adRewardsHasError = false;

  List<_RewardPlan> get _plans => [
    _RewardPlan(
      id: 'pro_12h',
      title: L10nService().translate('util_gi12gi_9c0202'),
      subtitle: L10nService().translate('util_tngnhanhth_1c7acb'),
      icon: '12h',
      points: 600,
      duration: const Duration(hours: 12),
    ),
    _RewardPlan(
      id: 'pro_1d',
      title: L10nService().translate('util_gi1ngy_a2dd38'),
      subtitle: L10nService().translate('util_dngchodpcb_e94421'),
      icon: '1d',
      points: 1000,
      duration: const Duration(days: 1),
    ),
    _RewardPlan(
      id: 'pro_3d',
      title: L10nService().translate('util_gi3ngy_5c09fc'),
      subtitle: L10nService().translate('util_cuitunngtn_9e3793'),
      icon: '3d',
      points: 2000,
      duration: const Duration(days: 3),
    ),
    _RewardPlan(
      id: 'pro_7d',
      title: L10nService().translate('util_gi7ngy_c8c2d1'),
      subtitle: L10nService().translate('util_mttunmfull_fdb897'),
      icon: '7d',
      points: 4000,
      duration: const Duration(days: 7),
    ),
    _RewardPlan(
      id: 'pro_30d',
      title: L10nService().translate('util_gi1thng_1e6ebe'),
      subtitle: L10nService().translate('util_lachntitki_ad5ee5'),
      icon: '30d',
      points: 10000,
      duration: const Duration(days: 30),
    ),
  ];

  int _consecutiveAdsWatched = 0;
  bool _isAdCooldown = false;
  int _adCooldownSeconds = 0;
  Timer? _cooldownTimer;
  int _lastAdWatchTimeMs = 0;
  int _adCooldownEndTimeMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConsentService.optionalCollectionAllowed.addListener(_refreshPrivacy);
    _proUntilStream = _adMob.streamCurrentProUntil().asBroadcastStream();
    _pointsStream = _adMob.streamUserPoints().asBroadcastStream();
    _questsStream = _dailyQuestService.streamQuests();
    _loadCheckinData();
    _listenAdRewardData();
    _scheduleRewardDayRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConsentService.optionalCollectionAllowed.removeListener(_refreshPrivacy);
    _dayTimer?.cancel();
    _cooldownTimer?.cancel();
    _userSubscription?.cancel();
    _adRewardsSubscription?.cancel();
    super.dispose();
  }

  void _refreshPrivacy() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRewardDay();
      _scheduleRewardDayRefresh();
    }
  }

  void _scheduleRewardDayRefresh() {
    _dayTimer?.cancel();
    final now = rewardCalendarNow();
    final midnight = DateTime.utc(now.year, now.month, now.day + 1);
    _dayTimer = Timer(midnight.difference(now), () {
      if (!mounted) return;
      _refreshRewardDay();
      _scheduleRewardDayRefresh();
    });
  }

  void _refreshRewardDay() {
    final day = rewardDayKey();
    if (!mounted || _rewardDay == day) return;
    setState(() {
      _rewardDay = day;
      _questsStream = _dailyQuestService.streamQuests();
      _dailyAdCount = 0;
      _isAdRewardsLoaded = false;
      _checkedInToday = _checkinDays[day] == true;
      _streak = _calculateStreak(_checkinDays);
    });
    _adRewardsSubscription?.cancel();
    _listenAdRewardData();
  }

  void _listenAdRewardData() {
    final user = _auth.currentUser;
    if (user == null) return;

    _adRewardsSubscription = _dbRef
        .child('users/${user.uid}/adRewards')
        .onValue
        .listen(
          (event) {
            final rawValue = event.snapshot.value;
            final data = rawValue is Map
                ? Map<dynamic, dynamic>.from(rawValue)
                : <dynamic, dynamic>{};
            final day = data['day']?.toString();
            final count = day == rewardDayKey()
                ? (data['count'] as num?)?.toInt() ?? 0
                : 0;
            if (!mounted) return;
            setState(() {
              _dailyAdCount = count.clamp(0, _dailyAdLimit);
              _isAdRewardsLoaded = true;
              _adRewardsHasError = false;
            });
          },
          onError: (Object error) {
            debugPrint(
              'Reward ad quota listener failed: ${AppErrorMapper.resolve(error).message}',
            );
            if (!mounted) return;
            setState(() {
              _isAdRewardsLoaded = true;
              _adRewardsHasError = true;
            });
          },
        );
  }

  void _loadCheckinData() {
    final user = _auth.currentUser;
    if (user == null) return;

    _userSubscription = _dbRef
        .child('users/${user.uid}/checkinDays')
        .onValue
        .listen(
          (event) {
            final rawData = event.snapshot.value;
            final data = rawData is Map
                ? Map<dynamic, dynamic>.from(rawData)
                : {};
            if (mounted) {
              final nextDays = _parseCheckinDays(data);
              final nextCheckedInToday = nextDays[_todayKey()] == true;
              final nextStreak = _calculateStreak(nextDays);

              if (!_isCheckinLoaded ||
                  _checkedInToday != nextCheckedInToday ||
                  _streak != nextStreak ||
                  !_sameCheckinDays(_checkinDays, nextDays)) {
                setState(() {
                  _checkinDays = nextDays;
                  _checkedInToday = nextCheckedInToday;
                  _streak = nextStreak;
                  _isCheckinLoaded = true;
                });
              }
            }
          },
          onError: (Object error) {
            debugPrint(
              'Reward check-in listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('util_khngththeo_fed732')).message}',
            );
          },
        );
  }

  String _todayKey([DateTime? date]) {
    return rewardDayKey(date);
  }

  Map<String, bool> _parseCheckinDays(Object? rawValue) {
    if (rawValue is! Map) return {};
    final days = <String, bool>{};
    rawValue.forEach((key, value) {
      if (value == true) {
        days[key.toString()] = true;
      }
    });
    return days;
  }

  bool _sameCheckinDays(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  int _calculateStreak(Map<String, bool> dayMap) {
    int streak = 0;
    DateTime checkDate = DateTime.now().toUtc();
    while (true) {
      final key = _todayKey(checkDate);
      if (dayMap[key] == true) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _executeCheckin() async {
    _refreshRewardDay();
    if (_isCheckingIn || !_isCheckinLoaded || _checkedInToday) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isCheckingIn = true);
    try {
      if (!await SecurityService().guardAction(
        context,
        'reward_daily_checkin',
      )) {
        return;
      }
      if (!mounted || _auth.currentUser?.uid != uid) return;
      final result = await _adMob.claimDailyCheckinReward();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            result.alreadyClaimed
                ? context.tr('util_hmnaybnimd_35fac7')
                : result.ok
                ? context
                      .tr('ad_reward_points_received')
                      .replaceAll('{points}', '${result.granted}')
                : _checkinFailureMessage(result),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            AppErrorMapper.resolve(
              error,
              fallbackMessage: context.tr('util_imdanhchat_39e77b'),
            ).message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  String _checkinFailureMessage(RewardClaimResult result) {
    if (result.endpointMissing) {
      return L10nService().translate('util_mychimdanh_13bd22');
    }
    if (result.unauthenticated) {
      return L10nService().translate('util_phinngnhph_d65516');
    }
    if (result.appCheckIssue) {
      return L10nService().translate('util_thitbchasn_1e1378');
    }
    if (result.rateLimited) {
      return L10nService().translate('util_bnimdanhhi_302b12');
    }
    if (result.networkIssue) {
      return L10nService().translate('util_khngthktni_12d6d1');
    }
    return L10nService().translate('util_imdanhchat_39e77b');
  }

  String _rewardedAdFailureMessage(RewardClaimResult result) {
    if (result.endpointMissing) {
      return L10nService().translate('util_mychthngqu_15402b');
    }
    if (result.unauthenticated) {
      return L10nService().translate('util_phinngnhph_c11b0a');
    }
    if (result.appCheckIssue) {
      return L10nService().translate('util_thitbchasn_1e1378');
    }
    if (result.rateLimited) {
      return L10nService().translate('util_mychanggii_968084');
    }
    if (result.networkIssue) {
      return L10nService().translate('util_khngktnicm_805f8a');
    }
    switch (result.error) {
      case 'reward_pending':
        return L10nService().translate('ad_reward_verification_pending');
      case 'rewarded_ad_temporarily_disabled':
      case 'rewarded_ad_disabled':
      case 'source_disabled':
        return L10nService().translate('util_imthngtqun_f6049f');
      case 'already_claimed':
      case 'duplicate_claim':
      case 'replay_detected':
        return L10nService().translate('util_ltxemnycgh_1d8b7c');
      case 'invalid_source':
      case 'invalid_nonce':
      case 'invalid_proof':
        return L10nService().translate('util_mychtchiyu_4cbf86');
      default:
        return L10nService().translate('util_mychchaxcn_47b243');
    }
  }

  void _startAdCooldown() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Nếu thời gian kể từ lần xem cuối đã quá 2 giờ (7200000 ms), reset chuỗi
    if (_lastAdWatchTimeMs > 0 && (nowMs - _lastAdWatchTimeMs > 7200000)) {
      _consecutiveAdsWatched = 0;
    }

    _consecutiveAdsWatched++;
    _lastAdWatchTimeMs = nowMs;

    // Tính thời gian cooldown tăng dần ngẫu nhiên
    // Lần 3: 15-30s
    // Lần 4: 30-60s
    // Lần 5: 60-120s
    // Lần 6: 120-240s
    // Lần 7+: 300-600s (5-10 phút)
    int baseSeconds;
    int rangeSeconds;

    if (_consecutiveAdsWatched <= 3) {
      baseSeconds = 15;
      rangeSeconds = 15;
    } else if (_consecutiveAdsWatched == 4) {
      baseSeconds = 30;
      rangeSeconds = 30;
    } else if (_consecutiveAdsWatched == 5) {
      baseSeconds = 60;
      rangeSeconds = 60;
    } else if (_consecutiveAdsWatched == 6) {
      baseSeconds = 120;
      rangeSeconds = 120;
    } else {
      baseSeconds = 300;
      rangeSeconds = 300;
    }

    final random = math.Random();
    _adCooldownSeconds = math.max(
      45,
      baseSeconds + random.nextInt(rangeSeconds + 1),
    );
    _adCooldownEndTimeMs =
        DateTime.now().millisecondsSinceEpoch + (_adCooldownSeconds * 1000);

    setState(() {
      _isAdCooldown = true;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _adCooldownSeconds = _remainingAdCooldownSeconds();
        if (_adCooldownSeconds == 0) {
          _isAdCooldown = false;
          _adCooldownEndTimeMs = 0;
          timer.cancel();
        }
      });
    });
  }

  int _remainingAdCooldownSeconds() {
    if (!_isAdCooldown || _adCooldownEndTimeMs <= 0) return 0;
    final diffMs = _adCooldownEndTimeMs - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / 1000).ceil();
  }

  Future<void> _watchAd(int proUntil) async {
    _refreshRewardDay();
    if (_isWatchingAd ||
        kIsWeb ||
        !_isAdRewardsLoaded ||
        _adRewardsHasError ||
        _dailyAdCount >= _dailyAdLimit ||
        !ConsentService.optionalCollectionAllowed.value ||
        _remainingAdCooldownSeconds() > 0 ||
        (AppConfig.isPurchaseEnabled &&
            proUntil > DateTime.now().millisecondsSinceEpoch)) {
      return;
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isWatchingAd = true);
    try {
      if (!await SecurityService().guardAction(context, 'reward_watch_ad')) {
        return;
      }
      if (!mounted || _auth.currentUser?.uid != uid) return;
      final worked = await _adMob.showRewardedAd(verifiedPurpose: 'points');
      if (!mounted || _auth.currentUser?.uid != uid) return;
      if (!worked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('util_khngticqun_ce9d80'))),
        );
        return;
      }
      _startAdCooldown();
      final result = await _adMob.claimRewardedAdPoints();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            result.ok
                ? context
                      .tr('ad_reward_points_received')
                      .replaceAll('{points}', '${result.granted}')
                : _rewardedAdFailureMessage(result),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            AppErrorMapper.resolve(
              error,
              fallbackMessage: context.tr('util_khngticqun_ce9d80'),
            ).message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _redeemPlan(_RewardPlan plan) async {
    if (_isRedeeming) return;
    if (!AppConfig.isPurchaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('p5_premium_unavailable'))),
      );
      return;
    }

    setState(() => _isRedeeming = true);
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (!await SecurityService().guardAction(
        context,
        'reward_redeem_${plan.id}',
      )) {
        return;
      }
      if (!mounted) return;

      final latestPointsBeforeRedeem = await _adMob.getUserPoints();
      if (!mounted) return;
      if (latestPointsBeforeRedeem < plan.points) {
        scaffoldMessenger.showSnackBar(
          SLSnackBar(
            content: Text(
              _buildInsufficientRedeemMessage(plan, latestPointsBeforeRedeem),
            ),
          ),
        );
        return;
      }

      var result = await _adMob.redeemProPlan(planId: plan.id);
      if (!mounted) return;
      if (result.error == 'not_enough_points') {
        final latestPointsAfterFailure = await _adMob.getUserPoints();
        if (!mounted) return;
        if (latestPointsAfterFailure >= plan.points) {
          debugPrint(
            'Redeem plan retrying after mismatch: '
            'plan=${plan.id}, localBefore=$latestPointsBeforeRedeem, '
            'latestAfterFailure=$latestPointsAfterFailure',
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (!mounted) return;
          result = await _adMob.redeemProPlan(planId: plan.id);
          if (!mounted) return;
        } else {
          scaffoldMessenger.showSnackBar(
            SLSnackBar(
              content: Text(
                _buildInsufficientRedeemMessage(plan, latestPointsAfterFailure),
              ),
            ),
          );
          return;
        }
      }
      if (result.ok) {
        scaffoldMessenger.showSnackBar(
          SLSnackBar(
            content: Text(
              '${context.tr('reward_store_completed')} · ${plan.title}',
            ),
          ),
        );
      } else {
        debugPrint(
          'Redeem plan failed: plan=${plan.id}, error=${result.error}, status=${result.statusCode}',
        );
        scaffoldMessenger.showSnackBar(
          SLSnackBar(content: Text(_redeemErrorMessage(plan, result))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  String _buildInsufficientRedeemMessage(_RewardPlan plan, int currentPoints) {
    return '${context.tr('not_enough_points')} · '
        '${context.tr('reward_store_balance')}: ${_formatPointAmount(currentPoints)} / '
        '${_formatPointAmount(plan.points)}';
  }

  String _redeemErrorMessage(_RewardPlan plan, RewardClaimResult result) {
    switch (result.error) {
      case 'not_enough_points':
        return context.tr('not_enough_points');
      case 'points_sync_retry':
        return L10nService().translate('util_imvacngbli_8a0f32');
      case 'house_not_found':
      case 'house_mismatch':
      case 'forbidden':
        return L10nService().translate('util_dliunginhc_bf4d03');
      case 'missing_app_check':
      case 'invalid_app_check':
        return L10nService().translate('util_xcthcthitb_e94ae1');
      case 'network_error':
      case 'network_timeout':
      case 'reward_server_unavailable':
        return L10nService().translate('util_khngktnicm_155696');
      case 'invalid_plan':
        return L10nService().translate('util_giiimkhngh_64e725');
      default:
        return context.tr('util_khngktnicm_155696');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF7F8),
    appBar: SLTheme.appBar(context, context.tr('util_cahngvtphm_a6a4f6')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: StreamBuilder<int>(
            stream: _proUntilStream,
            builder: (context, proSnapshot) => StreamBuilder<int>(
              stream: _pointsStream,
              builder: (context, pointSnapshot) {
                final proUntil = proSnapshot.data ?? 0;
                final isPro =
                    AppConfig.isPurchaseEnabled &&
                    proUntil > DateTime.now().millisecondsSinceEpoch;
                final status = proSnapshot.hasError
                    ? context.tr('reward_store_error')
                    : !proSnapshot.hasData
                    ? context.tr('reward_store_loading')
                    : !isPro
                    ? context.tr('util_thng_c10b85')
                    : DateTime.fromMillisecondsSinceEpoch(proUntil).year >= 9999
                    ? context.tr('reward_store_pro_lifetime')
                    : context
                          .tr('reward_store_pro_until')
                          .replaceAll('{date}', _formatDateTime(proUntil));
                final points = pointSnapshot.data ?? 0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    RewardWalletCard(
                      balance: pointSnapshot.hasError
                          ? context.tr('reward_store_error')
                          : pointSnapshot.hasData
                          ? _formatPointAmount(points)
                          : '—',
                      status: status,
                      streak: _streak,
                    ),
                    const SizedBox(height: 20),
                    RewardCheckinCard(
                      days: _checkinDays,
                      loaded: _isCheckinLoaded,
                      busy: _isCheckingIn,
                      streak: _streak,
                      onCheckin: _executeCheckin,
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<Map<String, dynamic>>(
                      key: ValueKey(_rewardDay),
                      stream: _questsStream,
                      builder: (context, snapshot) => RewardMissionsPanel(
                        data: snapshot.data ?? const {},
                        loading: !snapshot.hasData && !snapshot.hasError,
                        hasError: snapshot.hasError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildVideoCard(proSnapshot, isPro),
                    if (AppConfig.isPurchaseEnabled &&
                        pointSnapshot.hasData &&
                        !pointSnapshot.hasError) ...[
                      const SizedBox(height: 24),
                      _buildProRedeemSection(points),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildVideoCard(AsyncSnapshot<int> proSnapshot, bool isPro) {
    final seconds = _remainingAdCooldownSeconds();
    final privacyAllowed = ConsentService.optionalCollectionAllowed.value;
    final limitReached = _dailyAdCount >= _dailyAdLimit;
    final unavailable =
        !proSnapshot.hasData ||
        proSnapshot.hasError ||
        !_isAdRewardsLoaded ||
        _adRewardsHasError;
    final message = isPro
        ? context.tr('reward_store_pro')
        : kIsWeb
        ? context.tr('reward_store_web')
        : !privacyAllowed
        ? context.tr('reward_store_consent')
        : _adRewardsHasError || proSnapshot.hasError
        ? context.tr('reward_store_error')
        : unavailable
        ? context.tr('reward_store_loading')
        : limitReached
        ? context.tr('util_bntgiihnng_fd08ae')
        : null;
    final label = _isWatchingAd
        ? context.tr('util_angm_112640')
        : seconds > 0
        ? context.tr('reward_store_wait').replaceAll('{seconds}', '$seconds')
        : limitReached
        ? context
              .tr('reward_store_ad_count')
              .replaceAll('{count}', '$_dailyAdCount')
              .replaceAll('{limit}', '$_dailyAdLimit')
        : context
              .tr('reward_store_watch')
              .replaceAll('{points}', '${AdMobService.rewardedMainPoints}');
    return RewardVideoCard(
      count: _dailyAdCount,
      limit: _dailyAdLimit,
      points: AdMobService.rewardedMainPoints,
      buttonLabel: label,
      message: message,
      busy: _isWatchingAd,
      onWatch:
          unavailable ||
              isPro ||
              kIsWeb ||
              !privacyAllowed ||
              limitReached ||
              _isWatchingAd ||
              seconds > 0
          ? null
          : () => _watchAd(proSnapshot.data!),
    );
  }

  Widget _buildProRedeemSection(int points) {
    return RepaintBoundary(
      child: Container(
        padding: SLSpacing.all16,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: SLTheme.glassBorderThin),
          boxShadow: SLShadow.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE6F1),
                    borderRadius: SLRadius.lgAll,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: SLTheme.primary,
                    size: 23,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nService().translate('util_giiimpro_28acbc'),
                        style: SLTheme.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        L10nService().translate('util_iimly12gi1_6f15ee'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SLSpacing.h12,
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390;
                final itemWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final plan in _plans)
                      SizedBox(
                        width: itemWidth,
                        child: _buildPlanItem(plan, points, compact: true),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanItem(_RewardPlan plan, int points, {bool compact = false}) {
    final affordable = points >= plan.points;
    final missingPoints = math.max(0, plan.points - points);
    final planPointText = _formatPointAmount(plan.points);
    final balancePointText = _formatPointAmount(points);
    final missingPointText = _formatPointAmount(missingPoints);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 150 : 178),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: affordable
            ? Colors.white.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(
          color: affordable
              ? SLTheme.primary.withValues(alpha: 0.26)
              : SLTheme.glassBorderThin,
        ),
        boxShadow: compact ? SLShadow.subtle : SLTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 38 : 44,
                height: compact ? 38 : 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7AAE), Color(0xFFD81B60)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  plan.icon,
                  style: SLTheme.quicksand(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              SLSpacing.gapW(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 13.5 : 14,
                        color: SLTheme.textMain,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      plan.subtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 11 : 11.5,
                        height: 1.25,
                        color: SLTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.gapH(10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: affordable
                  ? const Color(0xFFEAF8EF)
                  : const Color(0xFFFFEEF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: affordable
                    ? const Color(0xFF43A047).withValues(alpha: 0.24)
                    : SLTheme.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 15,
                      color: affordable
                          ? const Color(0xFF2E7D32)
                          : SLTheme.primary,
                    ),
                    SLSpacing.gapW(5),
                    Expanded(
                      child: Text(
                        context
                            .tr('reward_store_points')
                            .replaceAll('{points}', planPointText),
                        style: SLTheme.quicksand(
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        affordable
                            ? L10nService().translate('util_im_e5cb90')
                            : context.tr('not_enough_points'),
                        textAlign: TextAlign.right,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 10.5 : 11,
                          fontWeight: FontWeight.w900,
                          color: affordable
                              ? const Color(0xFF2E7D32)
                              : SLTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SLSpacing.gapH(3),
                Text(
                  '${context.tr('reward_store_balance')}: $balancePointText',
                  style: SLTheme.quicksand(
                    fontSize: compact ? 10.5 : 11,
                    fontWeight: FontWeight.w700,
                    color: SLTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.gapH(8),
          SizedBox(
            width: double.infinity,
            height: compact ? 34 : 36,
            child: ElevatedButton.icon(
              onPressed: affordable && !_isRedeeming
                  ? () => _redeemPlan(plan)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: affordable
                    ? SLTheme.primary
                    : Colors.grey.shade400,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: SLRadius.pillAll),
              ),
              icon: const Icon(Icons.stars, color: Colors.white, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  affordable
                      ? '${context.tr('redeem')} · $planPointText'
                      : '−$missingPointText',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatPointAmount(int value) {
    return NumberFormat.decimalPattern('vi_VN').format(value);
  }
}

class _RewardPlan {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final int points;
  final Duration duration;

  const _RewardPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.points,
    required this.duration,
  });
}
