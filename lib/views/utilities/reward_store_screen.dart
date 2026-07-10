import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../utils/services/admob_service.dart';
import '../../utils/services/daily_quest_service.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/security_service.dart';
import '../../utils/app_error_mapper.dart';

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> {
  final AdMobService _adMob = AdMobService();
  final DailyQuestService _dailyQuestService = DailyQuestService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final Stream<int> _proUntilStream;
  late final Stream<int> _pointsStream;
  late final Stream<Map<String, dynamic>> _questsStream;
  StreamSubscription<DatabaseEvent>? _userSubscription;
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

  static final List<_RewardPlan> _plans = [
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
    _proUntilStream = _adMob.streamCurrentProUntil().asBroadcastStream();
    _pointsStream = _adMob.streamUserPoints().asBroadcastStream();
    _questsStream = _dailyQuestService.streamQuests().asBroadcastStream();
    _loadCheckinData();
    _loadDailyAdCount();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _loadDailyAdCount() async {
    final count = await _adMob.getDailyRewardedAdCount();
    if (mounted) {
      setState(() {
        _dailyAdCount = count;
      });
    }
  }

  void _loadCheckinData() {
    final user = _auth.currentUser;
    if (user == null) return;

    _userSubscription =
        _dbRef.child('users/${user.uid}/checkinDays').onValue.listen(
      (event) {
        final rawData = event.snapshot.value;
        final data = rawData is Map ? Map<dynamic, dynamic>.from(rawData) : {};
        if (mounted) {
          final nextDays = _parseCheckinDays(data);
          final nextCheckedInToday = nextDays[_todayKey()] == true;
          final nextStreak = _calculateStreak(nextDays);

          if (_isCheckingIn && !nextCheckedInToday) {
            return;
          }

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
          'Reward check-in listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: L10nService().translate('util_khngththeo_fed732'),
          ).message}',
        );
      },
    );
  }

  String _todayKey([DateTime? date]) {
    return DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
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
    DateTime checkDate = DateTime.now();
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

  void _markCheckedInToday() {
    if (!mounted) return;
    final today = _todayKey();
    final nextDays = Map<String, bool>.from(_checkinDays)..[today] = true;
    setState(() {
      _checkinDays = nextDays;
      _checkedInToday = true;
      _streak = _calculateStreak(nextDays);
    });
  }

  Future<void> _executeCheckin() async {
    if (_isCheckingIn) return;

    if (_checkedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(L10nService().translate('util_hmnaybnimd_35fac7'))),
      );
      return;
    }

    if (_auth.currentUser == null) return;

    // Save previous state for reverting in case of failure
    final previousCheckinDays = Map<String, bool>.from(_checkinDays);
    final previousCheckedInToday = _checkedInToday;
    final previousStreak = _streak;

    // Optimistically mark checked-in locally to provide instant response
    _markCheckedInToday();
    setState(() => _isCheckingIn = true);

    try {
      if (!await SecurityService()
          .guardAction(context, 'reward_daily_checkin')) {
        if (mounted) {
          setState(() {
            _checkinDays = previousCheckinDays;
            _checkedInToday = previousCheckedInToday;
            _streak = previousStreak;
            _isCheckingIn = false;
          });
        }
        return;
      }
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      RewardClaimResult result;
      try {
        result = await _adMob.claimDailyCheckinReward();
      } catch (error) {
        debugPrint(
          'Daily check-in failed: ${AppErrorMapper.resolve(error).message}',
        );
        result = const RewardClaimResult(
          ok: false,
          error: 'network_error',
        );
      }
      debugPrint(
        'Daily check-in result: ok=${result.ok} error=${result.error} '
        'status=${result.statusCode} granted=${result.granted}',
      );
      if (!mounted) return;

      if (result.alreadyClaimed) {
        // Keep optimistic state since they are checked-in anyway
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(L10nService().translate('util_hmnaybnimd_35fac7')),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      if (!result.ok) {
        if (kDebugMode &&
            (result.networkIssue ||
                result.appCheckIssue ||
                result.endpointMissing)) {
          final user = _auth.currentUser;
          if (user != null) {
            final today = _todayKey();
            try {
              await _dbRef.update({
                'users/${user.uid}/points': ServerValue.increment(50),
                'users/${user.uid}/checkinDays/$today': true,
              });
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content:
                      Text(L10nService().translate('util_imdanhdebu_ef8981')),
                  backgroundColor: Colors.green,
                ),
              );
              // Fallback update succeeded, keep the optimistic check-in
              return;
            } catch (error) {
              debugPrint(
                'Debug check-in fallback write failed: ${AppErrorMapper.resolve(error).message}',
              );
              if (!mounted) return;
              setState(() {
                _checkinDays = previousCheckinDays;
                _checkedInToday = previousCheckedInToday;
                _streak = previousStreak;
              });
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    L10nService().translate('util_bndebugcha_3d3468'),
                  ),
                ),
              );
            }
            return;
          }
        }

        // Revert optimistic update on failure
        setState(() {
          _checkinDays = previousCheckinDays;
          _checkedInToday = previousCheckedInToday;
          _streak = previousStreak;
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(_checkinFailureMessage(result))),
        );
        return;
      }

      // Success, keep the optimistic update
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(L10nService().translate('util_imdanhthnh_93f64e')),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
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
      if (kDebugMode) {
        return 'Thiết bị test chưa qua App Check (${result.error}). ${L10nService().translate('util_nuangchybn_c52bf0')}';
      }
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
      if (kDebugMode) {
        return 'Máy test chưa được Firebase App Check cho phép (${result.error}). ${L10nService().translate('util_thmdebugto_3b76d4')}';
      }
      return L10nService().translate('util_thitbchasn_1e1378');
    }
    if (result.rateLimited) {
      return L10nService().translate('util_mychanggii_968084');
    }
    if (result.networkIssue) {
      return L10nService().translate('util_khngktnicm_805f8a');
    }
    switch (result.error) {
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

    if (_consecutiveAdsWatched <= 2) {
      // 2 lần đầu không có cooldown
      return;
    }

    // Tính thời gian cooldown tăng dần ngẫu nhiên
    // Lần 3: 15-30s
    // Lần 4: 30-60s
    // Lần 5: 60-120s
    // Lần 6: 120-240s
    // Lần 7+: 300-600s (5-10 phút)
    int baseSeconds;
    int rangeSeconds;

    if (_consecutiveAdsWatched == 3) {
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
    _adCooldownSeconds = baseSeconds + random.nextInt(rangeSeconds + 1);
    _adCooldownEndTimeMs =
        DateTime.now().millisecondsSinceEpoch + (_adCooldownSeconds * 1000);

    setState(() {
      _isAdCooldown = true;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: _adCooldownSeconds), () {
      if (!mounted) return;
      setState(() {
        _isAdCooldown = false;
        _adCooldownSeconds = 0;
        _adCooldownEndTimeMs = 0;
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
    if (_isWatchingAd) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isAdCooldown) {
      final secondsLeft = _remainingAdCooldownSeconds();
      if (secondsLeft <= 0) {
        setState(() {
          _isAdCooldown = false;
          _adCooldownSeconds = 0;
          _adCooldownEndTimeMs = 0;
        });
      } else {
        _adCooldownSeconds = secondsLeft;
      }
    }

    if (_isAdCooldown) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Chờ $_adCooldownSeconds giây nữa để xem quảng cáo tiếp theo nhé ⏳',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (AppConfig.isPurchaseEnabled &&
        proUntil > DateTime.now().millisecondsSinceEpoch) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            L10nService().translate('util_hydngimdan_c203ca'),
          ),
        ),
      );
      return;
    }

    if (_dailyAdCount >= _dailyAdLimit) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            L10nService().translate('util_bnchmmcltx_bdf8ba'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isWatchingAd = true);
    try {
      if (!await SecurityService().guardAction(context, 'reward_watch_ad')) {
        return;
      }
      if (!mounted) return;

      bool worked = false;

      if (kIsWeb) {
        worked = await _showWebRewardDialog();
      } else {
        final navigator = Navigator.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: SLTheme.primary),
          ),
        );
        worked = await _adMob.showRewardedAd();
        if (mounted && navigator.canPop()) {
          navigator.pop();
        }

        // Fallback for real ad if it fails to play (no fill)
        if (!worked) {
          debugPrint(
              'AdMobService: Real ad failed to load/play. Falling back to simulated web ad dialog.');
          if (mounted) {
            worked = await _showWebRewardDialog();
          }
        }
      }

      if (worked) {
        var result = await _adMob.claimRewardedAdPoints();
        if (!mounted) return;

        // Fallback points grant in debug mode if claim fails
        if (!result.ok && kDebugMode) {
          try {
            final debugRes = await FirebaseFunctions.instance
                .httpsCallable('grantRewardPointsHttp')
                .call({
              'source': 'debug_ad',
              'debug_secret': 'SoulLocketTest2026',
            });
            if (debugRes.data != null && debugRes.data['ok'] == true) {
              result = const RewardClaimResult(
                ok: true,
                granted: AdMobService.rewardedMainPoints,
              );
              debugPrint(
                  'AdMobService: Debug mode fallback points grant succeeded (+50 points).');
              await _adMob.incrementDailyRewardedAdCountDebug();
            } else {
              debugPrint(
                  'AdMobService: Debug mode fallback points grant failed from server. Trying direct RTDB write.');
              final user = _auth.currentUser;
              if (user != null) {
                await _dbRef.update({
                  'users/${user.uid}/points': ServerValue.increment(AdMobService.rewardedMainPoints),
                });
                result = const RewardClaimResult(
                  ok: true,
                  granted: AdMobService.rewardedMainPoints,
                );
                await _adMob.incrementDailyRewardedAdCountDebug();
              }
            }
          } catch (fallbackError) {
            debugPrint(
                'AdMobService: Debug mode fallback points grant exception: $fallbackError. Trying direct RTDB write.');
            final user = _auth.currentUser;
            if (user != null) {
              try {
                await _dbRef.update({
                  'users/${user.uid}/points': ServerValue.increment(AdMobService.rewardedMainPoints),
                });
                result = const RewardClaimResult(
                  ok: true,
                  granted: AdMobService.rewardedMainPoints,
                );
                await _adMob.incrementDailyRewardedAdCountDebug();
              } catch (rtdbErr) {
                debugPrint('Direct RTDB fallback write failed: $rtdbErr');
              }
            }
          }
        }

        if (!result.ok) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(_rewardedAdFailureMessage(result))),
          );
          return;
        }
        _startAdCooldown();
        _loadDailyAdCount();
        final grantedPoints = result.granted > 0
            ? result.granted
            : AdMobService.rewardedMainPoints;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Nhận được +$grantedPoints điểm!',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(L10nService().translate('util_khngticqun_ce9d80'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWatchingAd = false);
      }
    }
  }

  Future<bool> _showWebRewardDialog() async {
    bool canClose = false;
    bool earned = false;
    bool unlockScheduled = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!unlockScheduled) {
              unlockScheduled = true;
              Future<void>.delayed(const Duration(seconds: 5), () {
                if (!ctx.mounted || canClose) return;
                setDialogState(() {
                  canClose = true;
                });
              });
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F7),
                      borderRadius: SLRadius.xlAll,
                    ),
                    child: const Icon(
                      Icons.ondemand_video_rounded,
                      color: SLTheme.primary,
                      size: 40,
                    ),
                  ),
                  SLSpacing.h16,
                  Text(
                    L10nService().translate('util_qungcomphn_198acc'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: SLTheme.textMain,
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    canClose
                        ? L10nService().translate('util_bnxemthigi_1e583b')
                        : L10nService().translate('util_videosmthn_f06a76'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SLTheme.textMuted,
                      height: 1.45,
                    ),
                  ),
                  SLSpacing.h16,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canClose
                          ? () {
                              earned = true;
                              Navigator.of(ctx).pop();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: SLTheme.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        minimumSize: const Size(double.infinity, 46),
                      ),
                      child: Text(
                        canClose
                            ? 'Đóng & Nhận ${AdMobService.rewardedMainPoints} điểm'
                            : L10nService().translate('util_ihontt_4d59a1'),
                        style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return earned;
  }

  Future<void> _redeemPlan(_RewardPlan plan) async {
    if (_isRedeeming) return;
    if (!AppConfig.isPurchaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gói nâng cấp chưa khả dụng trên phiên bản này.'),
        ),
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
          SnackBar(
            content: Text(
              _buildInsufficientRedeemMessage(plan, latestPointsBeforeRedeem),
            ),
          ),
        );
        return;
      }

      var result = await _adMob.redeemProPlan(
        planId: plan.id,
      );
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
          result = await _adMob.redeemProPlan(
            planId: plan.id,
          );
          if (!mounted) return;
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
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
          SnackBar(content: Text('Đã đổi thành công ${plan.title}! 👑')),
        );
      } else {
        debugPrint(
          'Redeem plan failed: plan=${plan.id}, error=${result.error}, status=${result.statusCode}',
        );
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(_redeemErrorMessage(plan, result))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  String _buildInsufficientRedeemMessage(_RewardPlan plan, int currentPoints) {
    return 'Điểm hiện tại của bạn là ${_formatPointAmount(currentPoints)}. '
        'Cần ${_formatPointAmount(plan.points)} điểm để đổi ${plan.title}.';
  }

  String _redeemErrorMessage(_RewardPlan plan, RewardClaimResult result) {
    switch (result.error) {
      case 'not_enough_points':
        return 'Bạn không đủ điểm để đổi ${plan.title}.';
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
        return 'Không thể đổi ${plan.title} lúc này. Hãy thử lại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: SLTheme.appBar(
        context,
        L10nService().translate('util_cahngvtphm_a6a4f6'),
        actions: [
          StreamBuilder<int>(
            stream: _pointsStream,
            builder: (ctx, snapshot) {
              final val = snapshot.data ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 15, top: 10, bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: SLRadius.pillAll,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: SLTheme.primary, size: 20),
                    SLSpacing.w4,
                    Text('$val',
                        style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            color: SLTheme.textMain,
                            fontSize: 16)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _buildStoreBackground(
        child: SafeArea(
          child: StreamBuilder<int>(
            stream: _proUntilStream,
            builder: (context, proSnapshot) {
              final proUntil = proSnapshot.data ?? 0;
              return StreamBuilder<int>(
                stream: _pointsStream,
                builder: (context, pointSnapshot) {
                  final points = pointSnapshot.data ?? 0;
                  return ListView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(900.0),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildWatchAdCard(proUntil),
                      SLSpacing.h20,
                      _buildCheckinSection(),
                      SLSpacing.h20,
                      _buildStatusCard(points, proUntil),
                      if (AppConfig.isPurchaseEnabled) ...[
                        SLSpacing.h16,
                        _buildProRedeemSection(points),
                      ],
                      SLSpacing.h20,
                      _buildDailyQuestsCard(),
                      if (kIsWeb)
                        Container(
                          padding: SLSpacing.all12,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(color: SLTheme.glassBorderThin),
                          ),
                          child: Text(
                            L10nService().translate('util_trnlocalho_b7eee3'),
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SLTheme.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStoreBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF4E1),
            Color(0xFFFFE8F1),
            Color(0xFFF7E8FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -72,
            right: -48,
            child: _StoreGlow(
              size: 210,
              color: Color(0xFFFFC85C),
              opacity: 0.34,
            ),
          ),
          const Positioned(
            top: 128,
            left: -80,
            child: _StoreGlow(
              size: 190,
              color: Color(0xFFFF7BA8),
              opacity: 0.22,
            ),
          ),
          const Positioned(
            bottom: -86,
            right: -62,
            child: _StoreGlow(
              size: 240,
              color: Color(0xFFB67CFF),
              opacity: 0.18,
            ),
          ),
          Positioned(
            top: 28,
            left: 24,
            child: Icon(
              Icons.local_mall_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 172,
            right: 28,
            child: Icon(
              Icons.stars_rounded,
              size: 42,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: 118,
            left: 34,
            child: Icon(
              Icons.redeem_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusCard(int points, int proUntil) {
    final isPro = AppConfig.isPurchaseEnabled &&
        proUntil > DateTime.now().millisecondsSinceEpoch;
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8FB), Color(0xFFFFEEF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: SLTheme.glassBorder),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: SLSpacing.all12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE2EF),
                  borderRadius: SLRadius.lgAll,
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: SLTheme.primary, size: 28),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10nService().translate('util_imquynli_2a770a'),
                        style: SLTheme.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: SLTheme.textMain)),
                    Text(
                      isPro
                          ? 'PRO đang hoạt động đến ${_formatDateTime(proUntil)}'
                          : L10nService().translate('util_bnanggithn_6ed061'),
                      style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  L10nService().translate('util_imhinc_915e21'),
                  '${_formatPointAmount(points)} điểm',
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildMiniStat(
                  L10nService().translate('util_trngthi_0fbc27'),
                  isPro ? 'PRO' : L10nService().translate('util_thng_c10b85'),
                  accent: isPro ? const Color(0xFF8E24AA) : SLTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? accent}) {
    final color = accent ?? SLTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: SLRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SLTheme.textMuted)),
          SLSpacing.h4,
          Text(value,
              style: SLTheme.quicksand(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildWatchAdCard(int proUntil) {
    final isPro = AppConfig.isPurchaseEnabled &&
        proUntil > DateTime.now().millisecondsSinceEpoch;
    final isLimitReached = _dailyAdCount >= _dailyAdLimit;

    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: SLTheme.glassCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SLTheme.glassBorder),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  padding: SLSpacing.all16,
                  decoration: BoxDecoration(
                      color: SLTheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.play_circle_filled,
                      color: SLTheme.primary, size: 36)),
              SLSpacing.w16,
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L10nService().translate('util_xemvideonh_dd1fb1'),
                          style: SLTheme.quicksand(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: SLTheme.textMain)),
                      Text(
                          isPro
                              ? (AppConfig.isPurchaseEnabled
                                  ? L10nService()
                                      .translate('util_tikhonnykh_357e73')
                                  : L10nService()
                                      .translate('util_tikhonnykh_357e73'))
                              : isLimitReached
                                  ? L10nService()
                                      .translate('util_bntgiihnng_fd08ae')
                                  : 'Mỗi video +${AdMobService.rewardedMainPoints} điểm thưởng.',
                          style: SLTheme.quicksand(
                              color: SLTheme.textMuted,
                              fontSize: 12,
                              height: 1.4)),
                    ]),
              ),
              SLTheme.primaryButton(
                  label: isPro
                      ? 'PRO'
                      : isLimitReached
                          ? L10nService().translate('util_hmnayri_46d3f2')
                          : _isWatchingAd
                              ? L10nService().translate('util_angm_112640')
                              : 'Xem ngay',
                  onPressed: isPro || _isWatchingAd || isLimitReached
                      ? () {}
                      : () => _watchAd(proUntil),
                  width: 112),
            ],
          ),
          if (!isPro && !isLimitReached)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _dailyAdCount / _dailyAdLimit,
                        minHeight: 6,
                        backgroundColor: SLTheme.primary.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SLTheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$_dailyAdCount/$_dailyAdLimit',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SLTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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

  Widget _buildCheckinSection() {
    final List<DateTime> last7Days = List.generate(
        7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));

    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: SLTheme.glassCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SLTheme.glassBorder),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: SLSpacing.all12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F7),
                  borderRadius: SLRadius.lgAll,
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: SLTheme.primary, size: 28),
              ),
              SLSpacing.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10nService().translate('util_imdanhhngn_d32a8b'),
                        style: SLTheme.quicksand(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: SLTheme.textMain)),
                    Text(
                        _checkedInToday
                            ? 'Bạn đã điểm danh hôm nay! ✨\nChuỗi hiện tại: $_streak ngày'
                            : L10nService().translate('util_imdanhngay_da87d4'),
                        style: SLTheme.quicksand(
                            color: SLTheme.textMuted,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Text(L10nService().translate('util_lchs7ngy_03e02e'),
              style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SLTheme.textMuted)),
          SLSpacing.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last7Days.map((date) {
              final key = _todayKey(date);
              final checked = _checkinDays[key] == true;
              final now = DateTime.now();
              final isToday = date.day == now.day &&
                  date.month == now.month &&
                  date.year == now.year;

              return Column(
                children: [
                  Text(
                    isToday
                        ? 'Nay'
                        : 'T${date.weekday + 1 > 7 ? 1 : date.weekday + 1}',
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isToday ? SLTheme.primary : SLTheme.textMuted,
                    ),
                  ),
                  SLSpacing.h8,
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: checked
                          ? const Color(0xFFEAFBF2)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: SLRadius.mdAll,
                      border: Border.all(
                        color: checked
                            ? const Color(0xFF79D6A3)
                            : SLTheme.outlineSoft,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      checked ? Icons.check : Icons.close,
                      color:
                          checked ? const Color(0xFF2EA86B) : SLTheme.textLight,
                      size: 18,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SLSpacing.h16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!_isCheckinLoaded || _checkedInToday || _isCheckingIn)
                  ? null
                  : _executeCheckin,
              style: ElevatedButton.styleFrom(
                backgroundColor: SLTheme.primary,
                disabledBackgroundColor:
                    SLTheme.primary.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: SLRadius.pillAll),
                elevation: 0,
              ),
              child: _isCheckingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      !_isCheckinLoaded
                          ? L10nService().translate('util_angtiimdan_3fdaf8')
                          : _checkedInToday
                              ? L10nService().translate('util_imdanh_682dd9')
                              : L10nService().translate('util_bmimdanh_d15143'),
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuestsCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _questsStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};

        final quests = DailyQuestService.questsConfig.entries.map((e) {
          final id = e.key;
          final config = e.value;
          final questData = data[id] is Map ? data[id] as Map : {};
          final progress = (questData['progress'] as num?)?.toInt() ?? 0;
          final done = questData['done'] == true;
          final target = config['target'] as int;

          return {
            'id': id,
            'title': config['title'],
            'desc': config['desc'],
            'points': config['points'],
            'progress': '${progress > target ? target : progress}/$target',
            'done': done,
            'icon': config['icon'],
          };
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10nService().translate('util_nhimvhngng_beafae'),
                style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: SLTheme.textMain)),
            SLSpacing.h8,
            Text(L10nService().translate('util_honthnhccn_0999c5'),
                style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLTheme.textMuted)),
            SLSpacing.h8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: SLRadius.mdAll,
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFD81B60)),
                  SLSpacing.w8,
                  Expanded(
                    child: Text(
                      L10nService().translate('util_luc2philmc_8df71e'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SLSpacing.h12,
            ...quests.map((q) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SLTheme.glassBorderThin),
                    boxShadow: SLShadow.subtle,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SLColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(q['icon'] as String,
                            style: const TextStyle(fontSize: 20)),
                      ),
                      SLSpacing.w16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q['title'] as String,
                                style: SLTheme.quicksand(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: SLTheme.textMain)),
                            SLSpacing.h4,
                            Text(q['desc'] as String,
                                style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: SLTheme.textMuted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: SLColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: SLColors.warningGold
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text(
                                '+${q['points']} ${L10nService().translate('util_im_4e6ac8')}',
                                style: SLTheme.quicksand(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB45309))),
                          ),
                          SLSpacing.h8,
                          SizedBox(
                            height: 28,
                            child: FilledButton(
                              onPressed: () {},
                              style: FilledButton.styleFrom(
                                backgroundColor: (q['done'] as bool)
                                    ? const Color(0xFF2EA86B)
                                        .withValues(alpha: 0.15)
                                    : SLColors.primaryLight,
                                foregroundColor: (q['done'] as bool)
                                    ? const Color(0xFF2EA86B)
                                    : SLTheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                  (q['done'] as bool)
                                      ? L10nService()
                                          .translate('util_honthnh_eb889c')
                                      : (q['progress'] as String),
                                  style: SLTheme.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
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
                        'Cần $planPointText điểm',
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
                            : 'Thiếu $missingPointText điểm',
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
                  'Bạn có $balancePointText điểm',
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
              onPressed:
                  affordable && !_isRedeeming ? () => _redeemPlan(plan) : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      affordable ? SLTheme.primary : Colors.grey.shade400,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape:
                      RoundedRectangleBorder(borderRadius: SLRadius.pillAll)),
              icon: const Icon(Icons.stars, color: Colors.white, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  affordable
                      ? 'Đổi $planPointText điểm'
                      : 'Thiếu $missingPointText điểm',
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

class _StoreGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _StoreGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
