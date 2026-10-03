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
import 'reward_pro_exchange.dart';
import '../../models/reward_pro_plan.dart';

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
  bool _hasPendingAdReward = false;
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
    unawaited(_recoverAdReward());
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
      if (!_isWatchingAd) unawaited(_recoverAdReward());
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

  Future<void> _recoverAdReward() async {
    if (_isWatchingAd || !mounted) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isWatchingAd = true);
    try {
      final result = await _adMob.recoverPendingAdReward();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      final pending = await _adMob.pendingAdRewardPurpose();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      setState(() => _hasPendingAdReward = pending != null);
      if (result != null) {
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
      }
    } catch (_) {
      // Giữ pending; lần mở lại/nút kiểm tra sẽ đọc receipt server.
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _watchAd(int proUntil) async {
    if (_hasPendingAdReward) {
      await _recoverAdReward();
      return;
    }
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
      if (await _adMob.pendingAdRewardPurpose() != null) {
        if (!mounted || _auth.currentUser?.uid != uid) return;
        setState(() => _hasPendingAdReward = true);
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
      final pending = await _adMob.pendingAdRewardPurpose();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      setState(() => _hasPendingAdReward = pending != null);
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

  Future<void> _redeemPlan(RewardProPlan plan) async {
    if (_isRedeeming) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (!AppConfig.isPurchaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('p5_premium_unavailable'))),
      );
      return;
    }
    setState(() => _isRedeeming = true);
    try {
      if (!await SecurityService().guardAction(
        context,
        'reward_redeem_${plan.id}',
      ))
        return;
      if (!mounted || _auth.currentUser?.uid != uid) return;
      final latestPoints = await _adMob.getUserPoints();
      if (!mounted || _auth.currentUser?.uid != uid) return;
      if (latestPoints < plan.points) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(_buildInsufficientRedeemMessage(plan, latestPoints)),
          ),
        );
        return;
      }
      // Không tự gửi lại giao dịch khi mất phản hồi: server có thể đã trừ điểm.
      final result = await _adMob.redeemProPlan(
        planId: plan.id,
        expectedUid: uid,
      );
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            result.ok
                ? '${context.tr('reward_store_completed')} · ${context.tr(plan.titleKey)}'
                : _redeemErrorMessage(plan, result),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _auth.currentUser?.uid != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_khngktnicm_155696'))),
      );
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  String _buildInsufficientRedeemMessage(
    RewardProPlan plan,
    int currentPoints,
  ) {
    return '${context.tr('not_enough_points')} · '
        '${context.tr('reward_store_balance')}: ${_formatPointAmount(currentPoints)} / '
        '${_formatPointAmount(plan.points)}';
  }

  String _redeemErrorMessage(RewardProPlan plan, RewardClaimResult result) {
    switch (result.error) {
      case 'not_enough_points':
        return context.tr('not_enough_points');
      case 'points_sync_retry':
        return L10nService().translate('util_imvacngbli_8a0f32');
      case 'house_not_found':
      case 'house_mismatch':
      case 'forbidden':
      case 'house_membership_changed':
        return L10nService().translate('util_dliunginhc_bf4d03');
      case 'missing_app_check':
      case 'invalid_app_check':
        return L10nService().translate('util_xcthcthitb_e94ae1');
      case 'network_error':
      case 'network_timeout':
      case 'reward_server_unavailable':
        return context.tr('reward_store_redeem_uncertain');
      case 'unauthenticated':
        return context.tr('util_phinngnhph_c11b0a');
      case 'endpoint_not_found':
      case 'endpoint_not_configured':
        return context.tr('p5_premium_unavailable');
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
    final message = _hasPendingAdReward
        ? context.tr('ad_reward_verification_pending')
        : isPro
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
        : _hasPendingAdReward
        ? context.tr('reward_store_check_reward')
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
      onWatch: _hasPendingAdReward && !_isWatchingAd
          ? _recoverAdReward
          : unavailable ||
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

  Widget _buildProRedeemSection(int points) => RewardProExchange(
    points: points,
    busy: _isRedeeming,
    onRedeem: _redeemPlan,
  );

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatPointAmount(int value) {
    return NumberFormat.decimalPattern(
      L10nService().locale.toString(),
    ).format(value);
  }
}
