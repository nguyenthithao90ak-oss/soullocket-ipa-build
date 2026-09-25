import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/purchase_service.dart';
import 'premium_store_view.dart';

class PremiumStoreScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const PremiumStoreScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends State<PremiumStoreScreen> {
  String _t(String key) => L10nService().translate(key);
  String _tf(String key, Map<String, Object?> params) =>
      L10nService().format(key, params);

  final PurchaseService _purchaseService = PurchaseService();

  StreamSubscription<VipPurchaseState>? _purchaseStatusSubscription;

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isVip = false;
  List<ProductDetails> _products = [];
  String _storeHintKey = 'p5_premium_unavailable';
  // ignore: unused_field
  bool _storeConfigured = false;

  bool get _isAppleStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroidStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get _storeDisplayName {
    if (_isAppleStorePlatform) {
      return _t('p5_premium_store_in_app');
    }
    if (_isAndroidStorePlatform) {
      return _t('p5_premium_store_in_app');
    }
    return _t('p5_premium_store_on_device');
  }

  bool _isConfiguredStoreAvailable(bool available) {
    if (!available) return false;
    if (_isAppleStorePlatform) {
      return AppConfig.purchaseVerifyUrl.isNotEmpty;
    }
    return true;
  }

  String _buildStoreHintKey({
    required bool available,
    required List<ProductDetails> products,
  }) {
    if (!available) {
      return 'p5_premium_unavailable';
    }

    if (products.isEmpty) {
      return 'p5_premium_load_failed';
    }

    return 'p5_premium_store_connected';
  }

  List<ProductDetails> get _sortedProducts {
    const planOrder = <String, int>{
      VipProduct.weekly: 0,
      VipProduct.monthly: 1,
      VipProduct.sixMonths: 2,
      VipProduct.yearly: 3,
      VipProduct.lifetime: 4,
    };

    final itemsByPlan = <String, ProductDetails>{};
    for (final product in _products) {
      // Một subscription Play có nhiều base plan; chỉ hiển thị các gói đã biết.
      if (product is GooglePlayProductDetails &&
          product.id == VipProduct.monthly &&
          !_knownGoogleBasePlan(product)) {
        continue;
      }
      final planId = _planIdForProduct(product);
      final existing = itemsByPlan[planId];
      if (existing == null ||
          _productPriority(product) < _productPriority(existing)) {
        itemsByPlan[planId] = product;
      }
    }

    final items = itemsByPlan.values.toList();
    items.sort(
      (a, b) => (planOrder[_planIdForProduct(a)] ?? 999).compareTo(
        planOrder[_planIdForProduct(b)] ?? 999,
      ),
    );
    return items;
  }

  int _productIdPriority(String productId) {
    switch (productId) {
      case VipProduct.sixMonthsAlt:
      case VipProduct.lifetimeLegacy:
        return 1;
      default:
        return 0;
    }
  }

  int _productPriority(ProductDetails product) {
    var priority = _productIdPriority(product.id);
    final offerDetails = _googlePlayOfferDetails(product);
    if (offerDetails?.offerId != null) {
      priority += 10;
    }
    return priority;
  }

  SubscriptionOfferDetailsWrapper? _googlePlayOfferDetails(
    ProductDetails product,
  ) {
    if (product is! GooglePlayProductDetails) {
      return null;
    }
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null ||
        offers == null ||
        index < 0 ||
        index >= offers.length) {
      return null;
    }
    return offers[index];
  }

  bool _knownGoogleBasePlan(ProductDetails product) {
    switch (_googlePlayOfferDetails(product)?.basePlanId) {
      case 'vip-weekly':
      case 'vip-monthly':
      case 'vip-6months':
      case 'vip-yearly':
        return true;
      default:
        return false;
    }
  }

  PricingPhaseWrapper? _googlePlayPricingPhase(ProductDetails product) {
    final phases = _googlePlayOfferDetails(product)?.pricingPhases;
    if (phases == null || phases.isEmpty) {
      return null;
    }
    for (var index = phases.length - 1; index >= 0; index--) {
      if (phases[index].priceAmountMicros > 0) {
        return phases[index];
      }
    }
    return phases.last;
  }

  String _planIdForProduct(ProductDetails product) {
    if (product is GooglePlayProductDetails &&
        product.id == VipProduct.monthly) {
      switch (_googlePlayOfferDetails(product)?.basePlanId) {
        case 'vip-weekly':
          return VipProduct.weekly;
        case 'vip-monthly':
          return VipProduct.monthly;
        case 'vip-6months':
          return VipProduct.sixMonths;
        case 'vip-yearly':
          return VipProduct.yearly;
      }
    }
    // — Android: Google Play billingPeriod --------------------------------
    final pricingPhase = _googlePlayPricingPhase(product);
    final billingPeriod = pricingPhase?.billingPeriod.toUpperCase() ?? '';
    if (billingPeriod.isNotEmpty) {
      return _matchBillingPeriod(billingPeriod, product);
    }

    // — iOS StoreKit 2: SK2Product.subscription.subscriptionPeriod ---------
    if (product is AppStoreProduct2Details) {
      final period = product.sk2Product.subscription?.subscriptionPeriod;
      if (period != null) {
        return _matchIosPeriod(
          value: period.value,
          unit: period.unit.name,
          fallback: product,
        );
      }
    }

    // — iOS StoreKit 1: SKProductWrapper.subscriptionPeriod -----------------
    if (product is AppStoreProductDetails) {
      final period = product.skProduct.subscriptionPeriod;
      if (period != null) {
        return _matchIosPeriod(
          value: period.numberOfUnits,
          unit: period.unit.name,
          fallback: product,
        );
      }
    }

    // — Fallback: string matching trên ID/title ---------------------------
    return _matchHaystack(product);
  }

  /// Dùng [billingPeriod] ISO 8601 từ Google Play (P1W, P1M, P6M, P1Y, …)
  String _matchBillingPeriod(String billingPeriod, ProductDetails product) {
    final haystack = _buildHaystack(product);
    if (billingPeriod.contains('P1W') ||
        haystack.contains('week') ||
        haystack.contains('weekly') ||
        haystack.contains('1_tuan') ||
        haystack.contains('1tuan')) {
      return VipProduct.weekly;
    }
    if (billingPeriod.contains('P6M') ||
        haystack.contains('6_month') ||
        haystack.contains('6month') ||
        haystack.contains('6-month') ||
        haystack.contains('half')) {
      return VipProduct.sixMonths;
    }
    if (billingPeriod.contains('P1Y') ||
        billingPeriod.contains('P12M') ||
        haystack.contains('year') ||
        haystack.contains('yearly') ||
        haystack.contains('annual') ||
        haystack.contains('12_month') ||
        haystack.contains('12month')) {
      return VipProduct.yearly;
    }
    if (billingPeriod.contains('P1M') ||
        haystack.contains('month') ||
        haystack.contains('monthly')) {
      return VipProduct.monthly;
    }
    return _fallbackPlan(product);
  }

  /// Dùng [SK2SubscriptionPeriodUnit] / [SKSubscriptionPeriodUnit] từ iOS
  String _matchIosPeriod({
    required int value,
    required String unit,
    required ProductDetails fallback,
  }) {
    if (value == 1 && unit == 'week') return VipProduct.weekly;
    if (value == 1 && unit == 'month') return VipProduct.monthly;
    if (value == 6 && unit == 'month') return VipProduct.sixMonths;
    if (value == 3 && unit == 'month') return VipProduct.sixMonths;
    if (value == 1 && unit == 'year') return VipProduct.yearly;
    if (value == 12 && unit == 'month') return VipProduct.yearly;
    return _fallbackPlan(fallback);
  }

  String _buildHaystack(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final offerDetails = _googlePlayOfferDetails(product);
      final basePlanId = offerDetails?.basePlanId.toLowerCase() ?? '';
      final offerId = offerDetails?.offerId?.toLowerCase() ?? '';
      final tags = offerDetails?.offerTags.join(' ').toLowerCase() ?? '';
      return '$basePlanId $offerId $tags '
          '${product.id.toLowerCase()} ${product.title.toLowerCase()}';
    }
    return '${product.id.toLowerCase()} ${product.title.toLowerCase()}';
  }

  String _matchHaystack(ProductDetails product) {
    final haystack = _buildHaystack(product);
    if (haystack.contains('week') ||
        haystack.contains('weekly') ||
        haystack.contains('1_tuan') ||
        haystack.contains('1tuan')) {
      return VipProduct.weekly;
    }
    if (haystack.contains('6_month') ||
        haystack.contains('6month') ||
        haystack.contains('6-month') ||
        haystack.contains('half')) {
      return VipProduct.sixMonths;
    }
    if (haystack.contains('year') ||
        haystack.contains('yearly') ||
        haystack.contains('annual') ||
        haystack.contains('12_month') ||
        haystack.contains('12month')) {
      return VipProduct.yearly;
    }
    if (haystack.contains('month') || haystack.contains('monthly')) {
      return VipProduct.monthly;
    }
    return _fallbackPlan(product);
  }

  String _fallbackPlan(ProductDetails product) {
    final canonical = VipProduct.canonicalPlanId(product.id);
    if (VipProduct.planInfo.containsKey(canonical)) {
      return canonical;
    }
    return canonical;
  }

  @override
  void initState() {
    super.initState();
    _purchaseStatusSubscription = _purchaseService.statusStream.listen(
      _handlePurchaseState,
    );
    _loadData();
  }

  @override
  void dispose() {
    _purchaseStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!AppConfig.isPurchaseEnabled) {
      if (!mounted) return;
      setState(() {
        _products = const <ProductDetails>[];
        _isVip = false;
        _storeHintKey = 'p5_premium_unavailable';
        _storeConfigured = false;
        _isLoading = false;
      });
      return;
    }

    try {
      final available = await InAppPurchase.instance.isAvailable();
      await _purchaseService.initialize();
      final products = await _purchaseService.getProducts();
      final isVip = await _purchaseService.isVip();
      final storeHintKey = _buildStoreHintKey(
        available: available,
        products: products,
      );

      if (!mounted) return;
      setState(() {
        _products = products;
        _isVip = isVip;
        _storeHintKey = storeHintKey;
        _storeConfigured = _isConfiguredStoreAvailable(available);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const <ProductDetails>[];
        _storeHintKey = 'p5_premium_load_failed';
        _storeConfigured = false;
        _isLoading = false;
      });
      _showMessage(_t('p5_premium_pro_load_failed'), isError: true);
    }
  }

  void _handlePurchaseState(VipPurchaseState state) {
    if (!mounted) return;
    switch (state) {
      case VipPurchaseState.loading:
        setState(() => _isPurchasing = true);
        break;
      case VipPurchaseState.success:
        setState(() => _isPurchasing = false);
        _showMessage(_t('p5_premium_purchase_success'));
        unawaited(_loadData());
        break;
      case VipPurchaseState.error:
        setState(() => _isPurchasing = false);
        _showMessage(_t('p5_premium_purchase_incomplete'), isError: true);
        break;
      case VipPurchaseState.idle:
        if (_isPurchasing) {
          setState(() => _isPurchasing = false);
        }
        break;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFC62828)
            : const Color(0xFF1D7D55),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (_isLoading || _isPurchasing) return;
    setState(() => _isLoading = true);
    try {
      await _purchaseService.restorePurchases();
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(_t('p5_premium_restore_failed'), isError: true);
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    if (!AppConfig.isPurchaseEnabled) {
      if (!mounted) return;
      _showMessage(_t('p5_premium_unavailable'), isError: true);
      return;
    }

    final url = Uri.parse(rawUrl);
    if (!await canLaunchUrl(url)) {
      if (!mounted) return;
      _showMessage(_t('p5_premium_link_open_failed'), isError: true);
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  VipPlanInfo? _planInfoFor(ProductDetails product) {
    return VipProduct.infoOf(_planIdForProduct(product));
  }

  String _resolvedPlanLabel(VipPlanInfo? info) {
    if (info == null) return 'PRO';
    switch (info.durationDays) {
      case 7:
        return _t('p5_premium_plan_week');
      case 30:
        return _t('p5_premium_plan_month');
      case 180:
        return _t('p5_premium_plan_six_months');
      case 365:
        return _t('p5_premium_plan_year');
      default:
        return info.durationDays == null
            ? _t('p5_premium_plan_lifetime')
            : info.label;
    }
  }

  String _planSubtitle(ProductDetails product) {
    switch (_planIdForProduct(product)) {
      case VipProduct.weekly:
        return _t('p5_premium_weekly_subtitle');
      case VipProduct.monthly:
        return _t('p5_premium_monthly_subtitle');
      case VipProduct.sixMonths:
        return _t('p5_premium_six_months_subtitle');
      case VipProduct.yearly:
        return _t('p5_premium_yearly_subtitle');
      case VipProduct.lifetime:
        return _t('p5_premium_lifetime_subtitle');
      default:
        break;
    }

    switch (product.id) {
      case VipProduct.weekly:
        return _t('p5_premium_weekly_subtitle_alt');
      case VipProduct.monthly:
        return _t('p5_premium_monthly_subtitle_alt');
      case VipProduct.yearly:
        return _t('p5_premium_yearly_subtitle_alt');
      case VipProduct.lifetime:
        return _t('p5_premium_lifetime_subtitle_alt');
      default:
        return _t('p5_premium_default_subtitle');
    }
  }

  String _purchaseModeText(ProductDetails product, VipPlanInfo? info) {
    if (_planIdForProduct(product) == VipProduct.lifetime ||
        info?.durationDays == null) {
      return _t('p5_premium_one_time_payment');
    }
    return _t('p5_premium_auto_renewable');
  }

  String _securityNote(ProductDetails product) {
    final planId = _planIdForProduct(product);
    if (VipProduct.isLifetimeProduct(planId)) {
      return _tf('p5_premium_lifetime_security_note', {
        'store': _storeDisplayName,
      });
    }
    return _tf('p5_premium_subscription_security_note', {
      'store': _storeDisplayName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = _sortedProducts;
    return PremiumStoreView(
      plans: [
        for (final product in products)
          PremiumPlanOption(
            id: _planIdForProduct(product),
            title: _planInfoFor(product) == null
                ? product.title
                : _resolvedPlanLabel(_planInfoFor(product)),
            price: product.price,
            billing: _purchaseModeText(product, _planInfoFor(product)),
            description: _planSubtitle(product),
            disclosure: _securityNote(product),
          ),
      ],
      isActive: _isVip,
      isLoading: _isLoading,
      isProcessing: _isPurchasing,
      isEnabled: AppConfig.isPurchaseEnabled,
      unavailableMessage: _t(_storeHintKey),
      footerNote: _tf('p5_premium_footer_note', {'store': _storeDisplayName}),
      restoreLabel: _t(
        _isAppleStorePlatform
            ? 'p5_premium_restore_purchases'
            : 'p5_premium_refresh_status',
      ),
      onClose: () => Navigator.pop(context),
      onRetry: () {
        setState(() => _isLoading = true);
        _loadData();
      },
      onRestore: _isAndroidStorePlatform || _isAppleStorePlatform
          ? _restorePurchases
          : null,
      onTerms: () => _openExternalUrl(
        AppConfig.legalDocumentUri(
          'terms.html',
          languageCode: L10nService().localeCode,
        ).toString(),
      ),
      onPrivacy: () => _openExternalUrl(
        AppConfig.legalDocumentUri(
          'privacy.html',
          languageCode: L10nService().localeCode,
        ).toString(),
      ),
      onPurchase: (planId) {
        if (_isPurchasing || _isLoading) return;
        final product = products.firstWhere(
          (item) => _planIdForProduct(item) == planId,
        );
        _purchaseService.buyProduct(product);
      },
    );
  }
}
