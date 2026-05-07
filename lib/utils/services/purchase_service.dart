import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants/app_config.dart';
import 'app_check_http_headers.dart';
import 'revenue_security_telemetry_service.dart';

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
    if (!isVip) return 365;
    return isLifetime ? 1000 : 500;
  }

  int get dailyMemoryUploadLimit {
    return isVip ? 30 : 10;
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

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();

  factory PurchaseService() => _instance;

  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;
  Future<void>? _initializing;

  final StreamController<VipPurchaseState> _statusController =
      StreamController<VipPurchaseState>.broadcast();

  Stream<VipPurchaseState> get statusStream => _statusController.stream;

  Future<void> initialize() async {
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

    final available = await _iap.isAvailable();
    if (!available) {
      await syncVipEntitlements();
      return;
    }

    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) => _statusController.add(VipPurchaseState.error),
      );

      await _iap.restorePurchases();
      await syncVipEntitlements();
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('PurchaseService initialize error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _statusController.add(VipPurchaseState.error);
    }
  }

  Future<void> syncVipEntitlements() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final idToken = await user.getIdToken() ?? '';
      if (idToken.isEmpty) {
        return;
      }

      final headers = await AppCheckHttpHeaders.withRequiredToken(
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        forceRefresh: true,
      );

      final response = await http.post(
        Uri.parse(AppConfig.vipSyncUrl),
        headers: headers,
        body: jsonEncode({'uid': user.uid}),
      );
      await getVipAccessInfo();

      if (response.statusCode != 200) {
        debugPrint('VIP sync failed: ${response.statusCode} ${response.body}');
      }
    } catch (error) {
      debugPrint('VIP sync error: $error');
    }
  }

  Future<void> refreshVipEntitlements() async {
    await syncVipEntitlements();
  }

  Future<bool> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) {
      await syncVipEntitlements();
      return false;
    }

    if (!_initialized) {
      await initialize();
    } else {
      await _iap.restorePurchases();
      await syncVipEntitlements();
    }

    return true;
  }

  Future<List<ProductDetails>> getProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      return [];
    }

    final response = await _iap.queryProductDetails(VipProduct.allIds);
    if (response.error != null) {
      return [];
    }

    return response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    _statusController.add(VipPurchaseState.loading);
    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      _statusController.add(VipPurchaseState.error);
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyAndGrantVip(purchase);
        if (purchase.pendingCompletePurchase && verified) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _statusController.add(VipPurchaseState.error);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyAndGrantVip(PurchaseDetails purchase) async {
    final user = _auth.currentUser;
    if (user == null) {
      _statusController.add(VipPurchaseState.error);
      return false;
    }

    try {
      final token = purchase.verificationData.serverVerificationData;
      final source = purchase.verificationData.source;
      final idToken = await user.getIdToken() ?? '';

      if (token.isEmpty || idToken.isEmpty) {
        _statusController.add(VipPurchaseState.error);
        return false;
      }

      final headers = await AppCheckHttpHeaders.withRequiredToken(
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        forceRefresh: true,
      );

      final response = await http.post(
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
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Server verification failed: ${response.statusCode} ${response.body}',
        );
        await RevenueSecurityTelemetryService.instance.logEvent(
          type: 'purchase_verify_failed',
          reason: 'server_rejected',
          severity: response.statusCode == 401 || response.statusCode == 403
              ? 'high'
              : 'medium',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
            'productId': purchase.productID,
          },
        );
        _statusController.add(VipPurchaseState.error);
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        debugPrint('Server verification returned invalid payload: $decoded');
        _statusController.add(VipPurchaseState.error);
        return false;
      }

      _statusController.add(VipPurchaseState.success);
      return true;
    } catch (e) {
      debugPrint('Error verifying purchase with server: $e');
      _statusController.add(VipPurchaseState.error);
      return false;
    }
  }

  Future<String?> _resolveCurrentHouseId(String uid) async {
    final primarySnap = await _db.ref('users/$uid/houseId').get();
    final primaryValue = primarySnap.value?.toString().trim() ?? '';
    if (primaryValue.isNotEmpty) {
      return primaryValue;
    }

    final legacySnap = await _db.ref('users/$uid/house_id').get();
    final legacyValue = legacySnap.value?.toString().trim() ?? '';
    if (legacyValue.isNotEmpty) {
      await _db.ref('users/$uid').update({'houseId': legacyValue});
      return legacyValue;
    }

    return null;
  }

  // ignore: unused_element
  Future<bool> _isHouseVip(String houseId) async {
    final info = await _getHouseVipAccessInfo(houseId);
    return info.isVip;
  }

  // ignore: unused_element
  bool _isVipPayload(Map<String, dynamic> data) {
    if (data['isVip'] != true) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _toInt(data['vipExpiresAt']);
    if (expiresAt != null) {
      return expiresAt > now;
    }

    final plan = _normalizePlanId(
      data['vipPlan']?.toString() ?? data['plan']?.toString(),
    );
    return plan.isEmpty || plan == VipProduct.lifetime;
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

    if (value.contains('forever') ||
        value.contains('lifetime') ||
        value.contains('permanent') ||
        value.contains('vinh')) {
      return VipProduct.lifetime;
    }
    if (value.contains('6') &&
        (value.contains('month') ||
            value.contains('thang') ||
            value.contains('tháng') ||
            value.contains('half'))) {
      return VipProduct.sixMonths;
    }
    if (value.contains('week')) return VipProduct.weekly;
    if (value.contains('month')) return VipProduct.monthly;
    if (value.contains('year')) return VipProduct.yearly;
    return value;
  }

  VipAccessInfo _vipAccessFromPayload(
    Map<String, dynamic> data, {
    String? planField,
  }) {
    if (data['isVip'] != true) {
      return const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
    }

    final expiresAt = _toInt(data['vipExpiresAt']) ?? _toInt(data['expiresAt']);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiresAt != null && expiresAt <= now) {
      return const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
    }

    var planId = _normalizePlanId(
      planField == null ? null : data[planField]?.toString(),
    );
    if (planId.isEmpty) {
      planId = _normalizePlanId(
        data['vipPlan']?.toString() ?? data['plan']?.toString(),
      );
    }

    final isTimedPlan = planId == 'trial' ||
        planId == 'legacy_pro' ||
        VipProduct.isTimedProduct(planId);
    final hasServerManagedMarker =
        expiresAt != null || planId.isNotEmpty || data['grantedAt'] != null;

    if (!hasServerManagedMarker) {
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'vip_payload_rejected',
          reason: 'missing_server_marker',
          severity: 'high',
          extra: <String, Object?>{
            'planField': planField,
          },
        ),
      );
      return const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
    }

    if (expiresAt == null && !isTimedPlan) {
      planId = VipProduct.lifetime;
    }

    return VipAccessInfo(
      isVip: true,
      planId: planId,
      expiresAtMs: expiresAt,
    );
  }

  Future<VipAccessInfo> _getHouseVipAccessInfo(String houseId) async {
    final vipSnap = await _db.ref('houses/$houseId/vip').get();
    if (vipSnap.exists) {
      final vipData = _toMap(vipSnap.value);
      final access = _vipAccessFromPayload(vipData, planField: 'plan');
      if (access.isVip) {
        return access;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final proSnap = await _db.ref('houses/$houseId/proUntil').get();
    final proUntil = _toInt(proSnap.value);
    if (proUntil != null && proUntil > now) {
      return VipAccessInfo(
        isVip: true,
        planId: 'legacy_pro',
        expiresAtMs: proUntil,
      );
    }

    return const VipAccessInfo(
      isVip: false,
      planId: '',
      expiresAtMs: null,
    );
  }

  Future<VipAccessInfo> getVipAccessInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
    }

    final userVipSnap = await _db.ref('users/${user.uid}/vip').get();
    if (userVipSnap.exists) {
      final userVipData = _toMap(userVipSnap.value);
      final access = _vipAccessFromPayload(userVipData, planField: 'vipPlan');
      if (access.isVip) {
        return access;
      }
    }

    final houseId = await _resolveCurrentHouseId(user.uid);
    if (houseId == null || houseId.isEmpty) {
      return const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
    }

    return _getHouseVipAccessInfo(houseId);
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
    final user = _auth.currentUser;
    if (user == null) {
      yield const VipAccessInfo(
        isVip: false,
        planId: '',
        expiresAtMs: null,
      );
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
    _purchaseSub?.cancel();
    _statusController.close();
  }
}
