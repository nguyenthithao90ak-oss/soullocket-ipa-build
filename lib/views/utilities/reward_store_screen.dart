import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:soullocket_app/utils/services/admob_service.dart';
import 'package:soullocket_app/utils/services/daily_quest_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/security_service.dart';

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
  final math.Random random = math.Random();
  bool _isWatchingAd = false;
  bool _isRedeeming = false;
  bool _isCheckingIn = false;

  Map<String, bool> _checkinDays = {};
  bool _checkedInToday = false;
  int _streak = 0;

  // Daily ad limit tracking
  int _dailyAdCount = 0;
  final int _dailyAdLimit = AdMobService.dailyRewardedAdLimit;

  static const List<_RewardPlan> _plans = [
    _RewardPlan(
      id: 'pro_12h',
      title: 'Gói 12 giờ',
      subtitle: 'Tăng nhanh thời gian PRO',
      icon: '12h',
      points: 300,
      duration: Duration(hours: 12),
    ),
    _RewardPlan(
      id: 'pro_1d',
      title: 'Gói 1 ngày',
      subtitle: 'Dùng cho dịp đặc biệt',
      icon: '1d',
      points: 500,
      duration: Duration(days: 1),
    ),
    _RewardPlan(
      id: 'pro_3d',
      title: 'Gói 3 ngày',
      subtitle: 'Cuối tuần ngọt ngào hơn',
      icon: '3d',
      points: 1000,
      duration: Duration(days: 3),
    ),
    _RewardPlan(
      id: 'pro_7d',
      title: 'Gói 7 ngày',
      subtitle: 'Trải nghiệm trọn vẹn 1 tuần',
      icon: '7d',
      points: 2000,
      duration: Duration(days: 7),
    ),
  ];

  Timer? _cooldownTimer;
  bool _isAdCooldown = false;
  int _adCooldownSeconds = 0;
  int _adCooldownEndTimeMs = 0;
  int _consecutiveAdsWatched = 0;
  int _lastAdWatchTimeMs = 0;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _proUntilStream = _dbRef
          .child('users/$uid/proUntil')
          .onValue
          .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
      _pointsStream = _dbRef
          .child('users/$uid/points')
          .onValue
          .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
      _questsStream = _dailyQuestService.streamQuests();

      _userSubscription = _dbRef.child('users/$uid').onValue.listen((event) {
        if (!mounted) return;
        final data = event.snapshot.value as Map? ?? {};
        setState(() {
          _checkinDays = Map<String, bool>.from(
              (data['checkinDays'] as Map?)?.cast<String, bool>() ?? {});
          _streak = (data['checkinStreak'] as num?)?.toInt() ?? 0;
          _dailyAdCount = (data['dailyAdCount'] as num?)?.toInt() ?? 0;
          _lastAdWatchTimeMs = (data['lastAdWatchTimeMs'] as num?)?.toInt() ?? 0;
          _consecutiveAdsWatched =
              (data['consecutiveAdsWatched'] as num?)?.toInt() ?? 0;

          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          _checkedInToday = _checkinDays[today] == true;
        });
      });
    } else {
      _proUntilStream = Stream.value(0);
      _pointsStream = Stream.value(0);
      _questsStream = Stream.value({});
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String _formatDate(int timestamp) {
    if (timestamp <= 0) return 'Chưa kích hoạt';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm dd/MM/yyyy').format(dt);
  }

  String _getErrorMessage(RewardClaimResult result) {
    if (result.networkIssue) {
      return 'Không kết nối được máy chủ nhận thưởng. Kiểm tra mạng rồi thử lại.';
    }
    if (result.rateLimited) {
      return 'Máy chủ đang giới hạn lần nhận thưởng. Hãy chờ ít phút rồi thử lại.';
    }
    if (result.unauthenticated) {
      return 'Phiên làm việc hết hạn. Vui lòng đăng nhập lại.';
    }
    if (result.alreadyClaimed) {
      return 'Bạn đã nhận phần thưởng này rồi.';
    }
    switch (result.error) {
      case 'rewarded_ad_temporarily_disabled':
      case 'rewarded_ad_disabled':
      case 'source_disabled':
        return 'Điểm thưởng từ quảng cáo đang tạm tắt trên máy chủ.';
      case 'duplicate_claim':
      case 'replay_detected':
        return 'Lượt xem này đã được ghi nhận trước đó.';
      case 'invalid_source':
      case 'invalid_nonce':
      case 'invalid_proof':
        return 'Máy chủ từ chối yêu cầu nhận điểm cho lượt quảng cáo này.';
      default:
        return 'Máy chủ chưa xác nhận điểm cho lượt xem này.';
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
          content: Text('Vui lòng đợi ${_adCooldownSeconds}s để xem quảng cáo tiếp theo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_dailyAdCount >= _dailyAdLimit) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Bạn đã đạt giới hạn xem quảng cáo nhận điểm hôm nay.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isWatchingAd = true);

    try {
      final adResult = await _adMob.showRewardedAd();
      if (!mounted) return;

      if (!adResult) {
        setState(() => _isWatchingAd = false);
        return;
      }

      final claimResult = await _adMob.claimRewardedAdPoints();
      if (!mounted) return;

      if (claimResult.ok) {
        _startAdCooldown();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Tuyệt vời! Bạn nhận được ${claimResult.granted} điểm.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(claimResult)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Watch ad error: $e');
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _redeemPlan(_RewardPlan plan, int currentPoints) async {
    if (_isRedeeming) return;
    if (currentPoints < plan.points) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa đủ điểm để đổi gói này.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi ${plan.title}'),
        content: Text('Bạn có chắc chắn muốn dùng ${plan.points} điểm để đổi gói PRO này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRedeeming = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final success = await _adMob.redeemProPlan(planId: plan.id);
      if (!mounted) return;

      if (success.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kích hoạt thành công ${plan.title}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi đổi điểm. Vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Redeem error: $e');
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  Future<void> _checkIn() async {
    if (_isCheckingIn || _checkedInToday) return;

    setState(() => _isCheckingIn = true);

    try {
      final result = await _dailyQuestService.checkIn();
      if (!mounted) return;

      if (result['success'] == true) {
        final points = result['points'] as int;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Điểm danh thành công! Bạn nhận được $points điểm.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Có lỗi xảy ra khi điểm danh.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Check-in error: $e');
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _proUntilStream,
      builder: (context, proSnapshot) {
        final proUntil = proSnapshot.data ?? 0;
        final isPro = proUntil > DateTime.now().millisecondsSinceEpoch;

        return StreamBuilder<int>(
          stream: _pointsStream,
          builder: (context, pointsSnapshot) {
            final points = pointsSnapshot.data ?? 0;

            return Scaffold(
              body: Stack(
                children: [
                  SLTheme.meshBackground(
                    context,
                    color: isPro ? const Color(0xFFFF78A8) : const Color(0xFF4BA7FF),
                  ),
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildAppBar(points, proUntil, isPro),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCheckInCard(),
                              const SizedBox(height: 28),
                              _buildAdSection(proUntil),
                              const SizedBox(height: 32),
                              _buildQuestsSection(),
                              const SizedBox(height: 32),
                              _buildPlansSection(points),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppBar(int points, int proUntil, bool isPro) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CỬA HÀNG ĐIỂM THƯỞNG',
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.yellow, size: 36),
                  const SizedBox(width: 10),
                  Text(
                    '$points',
                    style: SLTheme.quicksand(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPro ? 'PRO đến: ${_formatDate(proUntil)}' : 'Bạn chưa có PRO',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Text(
                'ĐIỂM DANH NHẬN ĐIỂM',
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'Chuỗi: $_streak ngày',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isDone = index < (_streak % 7);
              final isToday = index == (_streak % 7);

              return Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.green.withOpacity(0.4)
                          : (isToday && !_checkedInToday
                              ? Colors.yellow.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone
                            ? Colors.green.withOpacity(0.6)
                            : (isToday && !_checkedInToday
                                ? Colors.yellow.withOpacity(0.6)
                                : Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : Text(
                            '+${10 + index * 2}',
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isToday ? Colors.yellow : Colors.white60,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ngày $dayNum',
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.white : Colors.white38,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _checkedInToday ? null : _checkIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isCheckingIn
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _checkedInToday ? 'ĐÃ ĐIỂM DANH HÔM NAY' : 'ĐIỂM DANH NGAY',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSection(int proUntil) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'NHIỆM VỤ QUẢNG CÁO',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _watchAd(proUntil),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_filled_rounded, color: Colors.orange, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xem quảng cáo nhận điểm',
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nhận ngẫu nhiên 10 - 25 điểm\nGiới hạn: $_dailyAdCount/$_dailyAdLimit lượt',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isWatchingAd)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else if (_isAdCooldown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_adCooldownSeconds}s',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestsSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _questsStream,
      builder: (context, snapshot) {
        final quests = snapshot.data ?? {};
        final questConfigs = DailyQuestService.getQuestConfigs();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'NHIỆM VỤ HÀNG NGÀY',
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...questConfigs.entries.map((entry) {
              final config = entry.value;
              final questData = quests[entry.key] as Map? ?? {};
              final current = (questData['progress'] as num?)?.toInt() ?? 0;
              final target = config.target;
              final isClaimed = questData['claimed'] == true;
              final progress = (current / target).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.title,
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              config.description,
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 1.0 ? Colors.green : Colors.white.withOpacity(0.5),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '$current/$target',
                                  style: SLTheme.quicksand(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: (current >= target && !isClaimed)
                              ? () async {
                                  final result = await _dailyQuestService.claimQuestReward(entry.key);
                                  if (!mounted) return;
                                  if (result['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã nhận ${result['points']} điểm!'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow,
                            foregroundColor: Colors.black87,
                            disabledBackgroundColor: Colors.white.withOpacity(0.1),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isClaimed ? 'ĐÃ NHẬN' : (current >= target ? 'NHẬN +${config.points}' : '+${config.points} P'),
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isClaimed ? Colors.white38 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildPlansSection(int currentPoints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'ĐỔI GÓI PRO',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            final plan = _plans[index];
            final canAfford = currentPoints >= plan.points;

            return InkWell(
              onTap: () => _redeemPlan(plan, currentPoints),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: canAfford ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        plan.icon,
                        style: SLTheme.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      plan.title,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.subtitle,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: canAfford ? Colors.yellow : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: canAfford ? Colors.black87 : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${plan.points}',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: canAfford ? Colors.black87 : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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
