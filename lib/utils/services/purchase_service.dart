import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'app_check_http_headers.dart';
import 'revenue_security_telemetry_service.dart';
import 'purchase_access_policy.dart';
import 'purchase_processing_queue.dart';

class VipProduct {
  static const weekly = 'soullocket_vip_weekly';
  static const monthly = 'soullocket_vip_monthly';
  static const sixMonths = 'soullocket_vip_6_month';
  static const sixMonthsAlt = 'soullocket_vip_6_months';
  static const yearly = 'soullocket_vip_yearly';
  static const lifetime = 'soullocket_vip_lifetime';
  static const lifetimeLegacy = 'soullocket_vip_forever';

  static const List<String> displayOrder = <String>[
    weekly,
    monthly,
    sixMonths,
    yearly,
    lifetime,
  ];

  static const Set<String> allIds = <String>{
    weekly,
    monthly,
    sixMonths,
    sixMonthsAlt,
    yearly,
    lifetime,
    lifetimeLegacy,
  };

  static const Map<String, VipPlanInfo> planInfo = {
    weekly: VipPlanInfo(
      label: '1 tuần',
      durationDays: 7,
      badge: '',
      savePercent: 0,
      priceVnd: 29000,
      memoryLimit: 500,
    ),
    monthly: VipPlanInfo(
      label: '1 tháng',
      durationDays: 30,
      badge: 'Phổ biến',
      savePercent: 0,
      priceVnd: 69000,
      memoryLimit: 500,
    ),
    sixMonths: VipPlanInfo(
      label: '6 tháng',
      durationDays: 180,
      badge: 'Tiết kiệm 28%',
      savePercent: 28,
      priceVnd: 299000,
      memoryLimit: 500,
    ),
    yearly: VipPlanInfo(
      label: '1 năm',
      durationDays: 365,
      badge: 'Tiết kiệm 40%',
      savePercent: 40,
      priceVnd: 499000,
      memoryLimit: 500,
    ),
    lifetime: VipPlanInfo(
      label: 'Vĩnh viễn',
      durationDays: null,
      badge: 'Trọn đời',
      savePercent: 0,
      priceVnd: 1799000,
      memoryLimit: 1000,
    ),
  };

  static String canonicalPlanId(String? productId) {
    final value = (productId ?? '').trim().toLowerCase();
    switch (value) {
      case weekly:
      case monthly:
      case sixMonths:
      case yearly:
      case lifetime:
        return value;
      case sixMonthsAlt:
        return sixMonths;
      case lifetimeLegacy:
        return lifetime;
      default:
        return value;
    }
  }

  static VipPlanInfo? infoOf(String? productId) {
    return planInfo[canonicalPlanId(productId)];
  }

  static bool isLifetimeProduct(String? productId) {
    return canonicalPlanId(productId) == lifetime;
  }

  static bool isTimedProduct(String? productId) {
    switch (canonicalPlanId(productId)) {
      case weekly:
      case monthly:
      case sixMonths:
      case yearly:
        return true;
      default:
        return false;
    }
  }

  static Duration? durationOf(String productId) {
    switch (canonicalPlanId(productId)) {
      case weekly:
        return const Duration(days: 7);
      case monthly:
        return const Duration(days: 30);
      case sixMonths:
        return const Duration(days: 180);
      case yearly:
        return const Duration(days: 365);
      case lifetime:
        return null;
      default:
        return null;
    }
  }
}

class VipPlanInfo {
  final String label;
  final int? durationDays;
  final String badge;
  final int savePercent;
  final int priceVnd;
  final int memoryLimit;

  const VipPlanInfo({
    required this.label,
    this.durationDays,
    required this.badge,
    required this.savePercent,
    required this.priceVnd,
    required this.memoryLimit,
  });
}

class VipAccessInfo {
  final bool isVip;
  final String planId;
  final int? expiresAtMs;

  const VipAccessInfo({
    required this.isVip,
    required this.planId,
    required this.expiresAtMs,
  });

  bool get isLifetime {
    if (!isVip) return false;
    if (planId == 'trial') return false;
    return VipProduct.isLifetimeProduct(planId);
  }

  int? get memoryVaultLimit {
    if (!isVip) return 182;
    return isLifetime ? 500 : 250;
  }

  int get dailyMemoryUploadLimit {
    // Không giới hạn số lượng ảnh nữa — giới hạn bằng dung lượng (MB)
    return isVip ? 999 : 999;
  }

  /// Giới hạn dung lượng ảnh (sau nén) upload mỗi ngày (bytes)
  int get dailyImageUploadLimitBytes {
    if (!isVip) return 5 * 1024 * 1024;
    return isLifetime ? 40 * 1024 * 1024 : 20 * 1024 * 1024;
  }

  /// Giới hạn dung lượng video (sau nén) upload mỗi ngày (bytes)
  int get dailyVideoUploadLimitBytes {
    if (!isVip) return 15 * 1024 * 1024;
    return isLifetime ? 100 * 1024 * 1024 : 50 * 1024 * 1024;
  }

  int get dailyMemorySizeLimitMb {
    if (!isVip) return 25;
    return isLifetime ? 400 : 200;
  }

  int get totalMemoryStorageCapMb {
    if (!isVip) return 182;
    return isLifetime ? 1024 : 512;
  }

  int get totalMemoryVideoCapMb {
    if (!isVip) return 182;
    return isLifetime ? 1024 : 512;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VipAccessInfo &&
        other.isVip == isVip &&
        other.planId == planId &&
        other.expiresAtMs == expiresAtMs;
  }

  @override
  int get hashCode => Object.hash(isVip, planId, expiresAtMs);
}

enum VipPurchaseState { idle, loading, success, error }

enum _VerificationResult { active, inactive, retry }

class PurchaseService with WidgetsBindingObserver {
  static final PurchaseService _instance = PurchaseService._internal();

  factory PurchaseService() => _instance;

  PurchaseService._internal() : _testHeaders = null, _observeEnabled = true;

  @visibleForTesting
  PurchaseService.forTesting({
    required InAppPurchase iap,
    required FirebaseAuth auth,
    required FirebaseDatabase database,
    required http.Client client,
    required Future<Map<String, String>> Function(Map<String, String>) headers,
  }) : _iapInstance = iap,
       _authInstance = auth,
       _dbInstance = database,
       _httpClient = client,
       _testHeaders = headers,
       _observeEnabled = false;

  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _iapInstance ??= InAppPurchase.instance;
  FirebaseDatabase? _dbInstance;
  FirebaseDatabase get _db => _dbInstance ??= FirebaseDatabase.instance;
  FirebaseAuth? _authInstance;
  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  http.Client? _httpClient;
  http.Client get _http => _httpClient ??= http.Client();
  final Future<Map<String, String>> Function(Map<String, String>)? _testHeaders;
  final bool _observeEnabled;

  Future<Map<String, String>> _headers(
    Map<String, String> values, {
    bool forceRefresh = true,
  }) =>
      _testHeaders?.call(values) ??
      AppCheckHttpHeaders.withOptionalToken(values, forceRefresh: forceRefresh);

  VipAccessInfo? _cachedAccessInfo;
  String? _cachedAccessUid;
  int? _cachedAccessCheckedAt;
  final PurchaseProcessingQueue _purchaseQueue = PurchaseProcessingQueue();
  final Map<String, String> _purchaseOwners = <String, String>{};
  bool _openingPurchase = false;
  bool _observing = false;
  StreamSubscription<User?>? _authSub;
  Future<void>? _syncing;
  String? _syncingUid;
  static const _requestTimeout = Duration(seconds: 60);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;
  Future<void>? _initializing;

  final StreamController<VipPurchaseState> _statusController =
      StreamController<VipPurchaseState>.broadcast();

  Stream<VipPurchaseState> get statusStream => _statusController.stream;

  void _observeLifecycle() {
    if (_observing || !_observeEnabled) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth.authStateChanges().listen((user) {
      _cachedAccessInfo = null;
      _cachedAccessUid = null;
      _cachedAccessCheckedAt = null;
      if (user != null && AppConfig.isPurchaseEnabled) {
        unawaited(initialize().catchError((Object _) {}));
        unawaited(syncVipEntitlements());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AppConfig.isPurchaseEnabled) {
      _cachedAccessCheckedAt = null;
      unawaited(syncVipEntitlements());
    }
  }

  Future<void> initialize() async {
    if (!AppConfig.isPurchaseEnabled) return;
    _observeLifecycle();
    if (_initialized) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }

    final task = _initializeInternal();
    _initializing = task;
    try {
      await task;
    } finally {
      if (identical(_initializing, task)) {
        _initializing = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (_initialized) return;

    if (kIsWeb) {
      await syncVipEntitlements();
      return;
    }

    final available = await _iap.isAvailable();
    if (!available) {
      await syncVipEntitlements();
      return;
    }

    try {
      await _purchaseSub?.cancel();
      _purchaseSub = _iap.purchaseStream.listen((purchases) {
        final callbackUid = _auth.currentUser?.uid;
        unawaited(
          _purchaseQueue
              .add(() => _handlePurchaseUpdates(purchases, callbackUid))
              .catchError((Object _) {
                _statusController.add(VipPurchaseState.error);
              }),
        );
      }, onError: (_) => _statusController.add(VipPurchaseState.error));

      _initialized = true;
      await _iap.restorePurchases().timeout(_requestTimeout);
      await _purchaseQueue.drained.timeout(_requestTimeout);
      await syncVipEntitlements();
    } catch (error) {
      await _purchaseSub?.cancel();
      _purchaseSub = null;
      _initialized = false;
      debugPrint(
        'PurchaseService initialize error: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể khởi tạo mua hàng lúc này.').message}',
      );
      _statusController.add(VipPurchaseState.error);
    }
  }

  Future<void> syncVipEntitlements() async {
    final uid = _auth.currentUser?.uid;
    if (_syncing != null && _syncingUid == uid) return _syncing!;
    final task = _syncVipEntitlements();
    _syncing = task;
    _syncingUid = uid;
    try {
      await task;
    } finally {
      if (identical(_syncing, task)) _syncing = null;
    }
  }

  Future<void> _syncVipEntitlements() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final idToken = await user.getIdToken() ?? '';
      if (idToken.isEmpty) {
        return;
      }

      final headers = await _headers({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }, forceRefresh: true);

      final response = await _http
          .post(
            Uri.parse(AppConfig.vipSyncUrl),
            headers: headers,
            body: jsonEncode({'uid': user.uid}),
          )
          .timeout(_requestTimeout);
      await getVipAccessInfo(forceRefresh: true);

      if (response.statusCode != 200) {
        debugPrint(
          'VIP sync failed: ${AppErrorMapper.resolve(response.body, fallbackMessage: 'Đồng bộ VIP thất bại.').message} (status=${response.statusCode})',
        );
      }
    } catch (error) {
      final msg = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể đồng bộ VIP lúc này.',
      ).message;
      if (!msg.contains('Too many attempts')) {
        debugPrint('VIP sync error: $msg');
      }
    }
  }

  Future<void> refreshVipEntitlements() async {
    await syncVipEntitlements();
  }

  Future<bool> restorePurchases() async {
    if (kIsWeb) {
      await syncVipEntitlements();
      return false;
    }
    final available = await _iap.isAvailable();
    if (!available) {
      await syncVipEntitlements();
      return false;
    }

    if (!_initialized) {
      await initialize();
    } else {
      await _iap.restorePurchases().timeout(_requestTimeout);
      await _purchaseQueue.drained.timeout(_requestTimeout);
      await syncVipEntitlements();
    }

    return (await getVipAccessInfo(forceRefresh: true)).isVip;
  }

  Future<List<ProductDetails>> getProducts() async {
    if (kIsWeb) return [];
    final available = await _iap.isAvailable();
    if (!available) {
      return [];
    }

    final productIds = defaultTargetPlatform == TargetPlatform.iOS
        ? VipProduct.displayOrder.toSet()
        : VipProduct.allIds;
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      return [];
    }

    return response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    if (kIsWeb) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null || _openingPurchase || !AppConfig.isPurchaseEnabled) return;
    _openingPurchase = true;
    _statusController.add(VipPurchaseState.loading);
    try {
      await initialize();
      if (!_initialized) throw StateError('billing_not_ready');
      await _registerPurchaseAccount(uid);
      if (_auth.currentUser?.uid != uid) throw StateError('account_changed');
      // Chỉ giữ chủ giao dịch khi chuẩn bị mở store; lỗi đăng ký trước đó
      // không được chặn khôi phục của tài khoản đăng nhập tiếp theo.
      _purchaseOwners[product.id] = uid;
      final launched = await _iap
          .buyNonConsumable(
            purchaseParam: PurchaseParam(
              productDetails: product,
              applicationUserName: purchaseAccountToken(uid),
            ),
          )
          .timeout(_requestTimeout);
      if (!launched) {
        _purchaseOwners.remove(product.id);
        _statusController.add(VipPurchaseState.error);
      }
    } catch (_) {
      _statusController.add(VipPurchaseState.error);
    } finally {
      _openingPurchase = false;
    }
  }

  Future<void> _registerPurchaseAccount(String uid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) throw StateError('account_changed');
    final token = await user.getIdToken();
    final headers = await _headers({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, forceRefresh: true);
    final response = await _http
        .post(
          Uri.parse(AppConfig.vipSyncUrl),
          headers: headers,
          body: jsonEncode({'uid': uid, 'registerOnly': true}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) throw StateError('billing_not_ready');
    final data = jsonDecode(response.body);
    if (data is! Map ||
        data['ok'] != true ||
        data['accountToken'] != purchaseAccountToken(uid)) {
      throw StateError('billing_not_ready');
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    String? callbackUid,
  ) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          // Store sẽ gửi callback mới khi thanh toán được duyệt/hủy.
          _statusController.add(VipPurchaseState.idle);
          continue;
        }
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final ownerUid = _purchaseOwners[purchase.productID] ?? callbackUid;
          if (ownerUid == null || _auth.currentUser?.uid != ownerUid) {
            _statusController.add(VipPurchaseState.error);
            continue;
          }
          var result = _VerificationResult.retry;
          for (var attempt = 0; attempt < 3; attempt++) {
            if (_auth.currentUser?.uid != ownerUid) break;
            if (attempt > 0) {
              await Future<void>.delayed(Duration(seconds: attempt * 2));
            }
            result = await _verifyAndGrantVip(purchase, ownerUid);
            if (result != _VerificationResult.retry) break;
          }
          if (result == _VerificationResult.retry) {
            _statusController.add(VipPurchaseState.error);
            continue;
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase).timeout(_requestTimeout);
          }
          _purchaseOwners.remove(purchase.productID);
          if (_auth.currentUser?.uid != ownerUid) continue;
          await getVipAccessInfo(forceRefresh: true);
          // Tài khoản có thể đổi trong lúc chờ tải quyền PRO từ máy chủ.
          if (_auth.currentUser?.uid != ownerUid) continue;
          _statusController.add(
            result == _VerificationResult.active
                ? VipPurchaseState.success
                : VipPurchaseState.idle,
          );
          continue;
        }
        if (purchase.status == PurchaseStatus.error ||
            purchase.status == PurchaseStatus.canceled) {
          _purchaseOwners.remove(purchase.productID);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase).timeout(_requestTimeout);
          }
          _statusController.add(
            purchase.status == PurchaseStatus.error
                ? VipPurchaseState.error
                : VipPurchaseState.idle,
          );
        }
      } catch (_) {
        // Store giữ giao dịch chưa complete để phục hồi ở lần mở app sau.
        _statusController.add(VipPurchaseState.error);
      }
    }
  }

  Future<_VerificationResult> _verifyAndGrantVip(
    PurchaseDetails purchase,
    String expectedUid,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != expectedUid) {
      debugPrint('[IAP] verify skipped: no authenticated user');
      return _VerificationResult.retry;
    }

    try {
      final token = purchase.verificationData.serverVerificationData;
      final source = purchase.verificationData.source;
      final idToken = await user.getIdToken() ?? '';

      if (token.isEmpty || idToken.isEmpty) {
        debugPrint(
          '[IAP] verify skipped: '
          'token=${token.isEmpty ? "EMPTY" : "OK(${token.length}chars)"}, '
          'idToken=${idToken.isEmpty ? "EMPTY" : "OK"}, '
          'source=$source, productId=${purchase.productID}',
        );
        return _VerificationResult.retry;
      }

      final headers = await _headers({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }, forceRefresh: true);

      final response = await _http
          .post(
            Uri.parse(AppConfig.purchaseVerifyUrl),
            headers: headers,
            body: jsonEncode({
              'uid': user.uid,
              'productId': purchase.productID,
              'purchaseToken': token,
              'source': source,
              'purchaseId': purchase.purchaseID,
              'transactionDate': purchase.transactionDate,
              'status': purchase.status.name,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        // Parse server error code safely for diagnostics
        String serverError = 'unknown';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map) {
            serverError = (errorBody['error'] ?? 'unknown').toString();
          }
        } catch (_) {
          // response body not JSON
        }

        debugPrint(
          '[IAP] Server verify FAILED: '
          'HTTP ${response.statusCode}, '
          'error=$serverError, '
          'source=$source, '
          'productId=${purchase.productID}, '
          'platform=${defaultTargetPlatform.name}, '
          'purchaseStatus=${purchase.status.name}',
        );
        await RevenueSecurityTelemetryService.instance.logEvent(
          type: 'purchase_verify_failed',
          reason: serverError,
          severity: response.statusCode == 401 || response.statusCode == 403
              ? 'high'
              : 'medium',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
            'productId': purchase.productID,
            'source': source,
            'platform': defaultTargetPlatform.name,
            'serverError': serverError,
          },
        );
        return _VerificationResult.retry;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['verified'] != true ||
          decoded['uid'] != expectedUid ||
          decoded['productId'] != purchase.productID ||
          decoded['shouldComplete'] != true) {
        debugPrint(
          '[IAP] Server verify returned invalid payload: '
          'source=$source, productId=${purchase.productID}',
        );
        return _VerificationResult.retry;
      }

      debugPrint(
        '[IAP] Server verify SUCCESS: '
        'source=$source, productId=${purchase.productID}, '
        'isVip=${decoded['isVip']}',
      );

      return decoded['isVip'] == true
          ? _VerificationResult.active
          : _VerificationResult.inactive;
    } catch (e) {
      debugPrint(
        '[IAP] verify EXCEPTION: '
        'source=${purchase.verificationData.source}, '
        'productId=${purchase.productID}, '
        'platform=${defaultTargetPlatform.name}, '
        'error=${AppErrorMapper.resolve(e, fallbackMessage: 'verify_exception').message}',
      );
      return _VerificationResult.retry;
    }
  }

  Future<String?> _resolveCurrentHouseId(String uid) async {
    final snapshot = await _db
        .ref('users/$uid/houseId')
        .get()
        .timeout(_requestTimeout);
    final value = snapshot.value?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    final legacy = await _db
        .ref('users/$uid/house_id')
        .get()
        .timeout(_requestTimeout);
    final legacyValue = legacy.value?.toString().trim() ?? '';
    return legacyValue.isEmpty ? null : legacyValue;
  }

  String _normalizePlanId(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return '';

    switch (value) {
      case VipProduct.weekly:
      case VipProduct.monthly:
      case VipProduct.sixMonths:
      case VipProduct.sixMonthsAlt:
      case VipProduct.yearly:
      case VipProduct.lifetime:
      case VipProduct.lifetimeLegacy:
      case 'trial':
      case 'legacy_pro':
        return VipProduct.canonicalPlanId(value);
      case 'vip_6_month':
      case 'vip_6_months':
      case '6_month':
      case '6_months':
      case '6month':
      case '6months':
      case '6 thang':
      case '6 tháng':
      case 'half_year':
      case 'half-year':
      case 'halfyear':
        return VipProduct.sixMonths;
      case 'lifetime':
      case 'forever':
      case 'permanent':
      case 'vip_lifetime':
      case 'vinh_vien':
      case 'vinh vien':
        return VipProduct.lifetime;
      case 'premium':
      case 'pro':
        return VipProduct.monthly;
    }

    return value;
  }

  VipAccessInfo _vipAccessFromPayload(
    Map<String, dynamic> data, {
    String? planField,
  }) {
    if (data['isVip'] != true) {
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }

    final expiresAt = _toInt(data['vipExpiresAt']) ?? _toInt(data['expiresAt']);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiresAt != null && expiresAt <= now) {
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }

    var planId = _normalizePlanId(
      planField == null ? null : data[planField]?.toString(),
    );
    if (planId.isEmpty) {
      planId = _normalizePlanId(
        data['vipPlan']?.toString() ?? data['plan']?.toString(),
      );
    }

    if (!isPurchasePayloadUsable(
      isVip: data['isVip'] == true,
      isKnownLifetime: VipProduct.isLifetimeProduct(planId),
      expiresAtMs: expiresAt,
      nowMs: now,
    )) {
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }

    return VipAccessInfo(isVip: true, planId: planId, expiresAtMs: expiresAt);
  }

  Future<VipAccessInfo> _getHouseVipAccessInfo(String houseId) async {
    final memberSnap = await _db
        .ref('houses/$houseId/members')
        .get()
        .timeout(_requestTimeout);
    final members = _toMap(memberSnap.value);
    final uid = _auth.currentUser?.uid;
    final member =
        uid != null &&
        (members.containsKey(uid) ||
            members.values.any((value) => value is Map && value['uid'] == uid));
    if (!member) {
      final owner = await _db
          .ref('houses/$houseId/owner_uid')
          .get()
          .timeout(_requestTimeout);
      if (uid == null || owner.value != uid) {
        return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
      }
    }
    final vipSnap = await _db
        .ref('houses/$houseId/vip')
        .get()
        .timeout(_requestTimeout);
    if (vipSnap.exists) {
      final vipData = _toMap(vipSnap.value);
      final access = _vipAccessFromPayload(vipData, planField: 'plan');
      if (access.isVip) {
        return access;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final proSnap = await _db
        .ref('houses/$houseId/proUntil')
        .get()
        .timeout(_requestTimeout);
    final proUntil = _toInt(proSnap.value);
    if (proUntil != null && proUntil > now) {
      return VipAccessInfo(
        isVip: true,
        planId: 'legacy_pro',
        expiresAtMs: proUntil,
      );
    }

    return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
  }

  Future<VipAccessInfo> getVipAccessInfo({bool forceRefresh = false}) async {
    if (!AppConfig.isPurchaseEnabled) {
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }

    _observeLifecycle();

    final user = _auth.currentUser;
    if (user == null) {
      _cachedAccessInfo = null;
      _cachedAccessUid = null;
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }

    if (!forceRefresh &&
        _cachedAccessInfo != null &&
        canReusePurchaseAccess(
          uid: user.uid,
          cachedUid: _cachedAccessUid,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          checkedAtMs: _cachedAccessCheckedAt,
          expiresAtMs: _cachedAccessInfo!.expiresAtMs,
        )) {
      return _cachedAccessInfo!;
    }

    VipAccessInfo access = const VipAccessInfo(
      isVip: false,
      planId: '',
      expiresAtMs: null,
    );

    final userVipSnap = await _db
        .ref('users/${user.uid}/vip')
        .get()
        .timeout(_requestTimeout);
    if (userVipSnap.exists) {
      final userVipData = _toMap(userVipSnap.value);
      final userAccess = _vipAccessFromPayload(
        userVipData,
        planField: 'vipPlan',
      );
      if (userAccess.isVip) {
        access = userAccess;
      }
    }

    if (!access.isVip) {
      final houseId = await _resolveCurrentHouseId(user.uid);
      if (houseId != null && houseId.isNotEmpty) {
        access = await _getHouseVipAccessInfo(houseId);
      }
    }

    if (_auth.currentUser?.uid != user.uid) {
      return const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
    }
    _cachedAccessCheckedAt = DateTime.now().millisecondsSinceEpoch;
    _cachedAccessInfo = access;
    _cachedAccessUid = user.uid;
    return access;
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Future<bool> isVip() async {
    final access = await getVipAccessInfo();
    return access.isVip;
  }

  Stream<VipAccessInfo> vipAccessStream() async* {
    if (!AppConfig.isPurchaseEnabled) {
      yield const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      yield const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null);
      return;
    }

    VipAccessInfo? lastValue;
    final initialValue = await getVipAccessInfo();
    lastValue = initialValue;
    yield initialValue;

    await for (final value in Stream.periodic(
      const Duration(seconds: 2),
    ).asyncMap((_) => getVipAccessInfo())) {
      if (value == lastValue) {
        continue;
      }
      lastValue = value;
      yield value;
    }
  }

  Stream<bool> vipStatusStream() {
    return vipAccessStream().map((access) => access.isVip);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _purchaseSub?.cancel();
    _statusController.close();
  }
}
