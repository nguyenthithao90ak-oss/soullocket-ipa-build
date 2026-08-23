import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../services/remote_config_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/purchase_service.dart';
import '../../widgets/skeleton_container.dart';

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
  bool get _isEnglish => L10nService().locale.languageCode == 'en';
  String _tr(String vi, String en) => _isEnglish ? en : vi;

  final PurchaseService _purchaseService = PurchaseService();

  StreamSubscription<VipPurchaseState>? _purchaseStatusSubscription;

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isVip = false;
  List<ProductDetails> _products = [];
  late String _storeHint = _tr(
      'Tính năng chưa khả dụng trong bản phát hành hiện tại.',
      'Feature not available in current release.');
  // ignore: unused_field
  bool _storeConfigured = false;

  bool get _isAppleStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroidStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get _storeDisplayName {
    if (_isAppleStorePlatform) {
      return _tr('cửa hàng trong ứng dụng', 'in-app store');
    }
    if (_isAndroidStorePlatform) {
      return _tr('cửa hàng trong ứng dụng', 'in-app store');
    }
    return _tr('cửa hàng trên thiết bị', 'on-device store');
  }

  String get _checkoutLabel {
    if (_isAppleStorePlatform) {
      return _tr('Thanh toán trong ứng dụng', 'In-app purchases');
    }
    if (_isAndroidStorePlatform) {
      return _tr('Thanh toán trong ứng dụng', 'In-app purchases');
    }
    return _tr('Thanh toán trong ứng dụng', 'In-app purchases');
  }

  bool _isConfiguredStoreAvailable(bool available) {
    if (!available) return false;
    if (_isAppleStorePlatform) {
      return AppConfig.purchaseVerifyUrl.isNotEmpty;
    }
    return true;
  }

  String _buildStoreHint({
    required bool available,
    required List<ProductDetails> products,
  }) {
    if (!available) {
      return 'Tính năng này chưa khả dụng trong bản phát hành hiện tại.';
    }

    if (products.isEmpty) {
      return _tr(
          'Chưa tải được dữ liệu. Vui lòng thử lại sau ít phút hoặc kiểm tra kết nối mạng.',
          'Failed to load data. Please check connection and try again.');
    }

    return _tr(
        'Cửa hàng đã kết nối thành công.', 'Store connected successfully.');
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
      final planId = _planIdForProduct(product);
      final existing = itemsByPlan[planId];
      if (existing == null ||
          _productPriority(product) < _productPriority(existing)) {
        itemsByPlan[planId] = product;
      }
    }

    final items = itemsByPlan.values.toList();
    items.sort(
      (a, b) => (planOrder[_planIdForProduct(a)] ?? 999)
          .compareTo(planOrder[_planIdForProduct(b)] ?? 999),
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
    if (index == null || offers == null || index >= offers.length) {
      return null;
    }
    return offers[index];
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
        _storeHint = _tr(
            'Tính năng chưa khả dụng trong bản phát hành hiện tại.',
            'Feature not available in current release.');
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
      final storeHint = _buildStoreHint(
        available: available,
        products: products,
      );

      if (!mounted) return;
      setState(() {
        _products = products;
        _isVip = isVip;
        _storeHint = storeHint;
        _storeConfigured = _isConfiguredStoreAvailable(available);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const <ProductDetails>[];
        _storeHint = _tr(
            'Chưa tải được dữ liệu. Vui lòng thử lại sau ít phút hoặc kiểm tra kết nối mạng.',
            'Failed to load data. Please check connection and try again.');
        _storeConfigured = false;
        _isLoading = false;
      });
      _showMessage(
        _tr('Chưa tải được dữ liệu PRO. Vui lòng thử lại sau.',
            'Failed to load PRO data. Please try again.'),
        isError: true,
      );
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
        _showMessage(
          _tr('Thanh toán thành công. Quyền lợi PRO sẽ được cập nhật trong giây lát.',
              'Purchase successful. PRO benefits will be updated shortly.'),
        );
        unawaited(_loadData());
        break;
      case VipPurchaseState.error:
        setState(() => _isPurchasing = false);
        _showMessage(
          _tr('Chưa hoàn tất thao tác. Vui lòng thử lại sau ít phút.',
              'Transaction incomplete. Please try again later.'),
          isError: true,
        );
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
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF1D7D55),
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
      _showMessage(
        _tr('Chưa thể khôi phục giao dịch. Vui lòng thử lại sau.',
            'Could not restore purchases. Please try again later.'),
        isError: true,
      );
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    if (!AppConfig.isPurchaseEnabled) {
      if (!mounted) return;
      _showMessage(
        'Tính năng này chưa khả dụng trong bản phát hành hiện tại.',
        isError: true,
      );
      return;
    }

    final url = Uri.parse(rawUrl);
    if (!await canLaunchUrl(url)) {
      if (!mounted) return;
      _showMessage(
          _tr('Không thể mở liên kết này ngay bây giờ.',
              'Cannot open this link right now.'),
          isError: true);
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  VipPlanInfo? _planInfoFor(ProductDetails product) {
    return VipProduct.infoOf(_planIdForProduct(product));
  }

  bool _isFeaturedPlan(ProductDetails product) {
    final planId = _planIdForProduct(product);
    if (_sortedProducts.length == 1) return true;
    if (_sortedProducts
        .any((item) => _planIdForProduct(item) == VipProduct.yearly)) {
      return planId == VipProduct.yearly;
    }
    if (_sortedProducts.any(
      (item) => _planIdForProduct(item) == VipProduct.sixMonths,
    )) {
      return planId == VipProduct.sixMonths;
    }
    if (_sortedProducts
        .any((item) => _planIdForProduct(item) == VipProduct.monthly)) {
      return planId == VipProduct.monthly;
    }
    return planId == VipProduct.lifetime;
  }

  String _resolvedPlanLabel(VipPlanInfo? info) {
    if (info == null) return 'PRO';
    switch (info.durationDays) {
      case 7:
        return _tr('1 tuần', '1 week');
      case 30:
        return _tr('1 tháng', '1 month');
      case 180:
        return _tr('6 tháng', '6 months');
      case 365:
        return _tr('1 năm', '1 year');
      default:
        return info.durationDays == null
            ? _tr('Vĩnh viễn', 'Lifetime')
            : info.label;
    }
  }

  String _planTitle(ProductDetails product, VipPlanInfo? info) {
    if (info != null) {
      return 'SoulLocket PRO ${_resolvedPlanLabel(info)}';
    }

    return product.title
        .replaceAll('(SoulLocket)', '')
        .replaceAll('(SoulLocket Lưu giữ kỷ niệm)', '')
        .trim();
  }

  String _planSubtitle(ProductDetails product) {
    switch (_planIdForProduct(product)) {
      case VipProduct.weekly:
        return _tr('Gói ngắn hạn để mở nhanh toàn bộ quyền lợi PRO.',
            'Short-term plan for quick access to all PRO benefits.');
      case VipProduct.monthly:
        return _tr('Dễ bắt đầu, đủ dùng hằng ngày và giữ mức chi phí nhẹ.',
            'Easy to start, sufficient for daily use with light cost.');
      case VipProduct.sixMonths:
        return _tr(
            'Phù hợp khi hai bạn dùng ổn định và muốn tiết kiệm hơn gói tháng.',
            'Suitable for stable use and better savings than monthly plan.');
      case VipProduct.yearly:
        return _tr('Tối ưu chi phí cho nhu cầu dùng lâu dài suốt cả năm.',
            'Optimized cost for long-term use throughout the year.');
      case VipProduct.lifetime:
        return _tr('Thanh toán một lần để giữ quyền lợi PRO lâu dài.',
            'Pay once to keep PRO benefits permanently.');
      default:
        break;
    }

    switch (product.id) {
      case VipProduct.weekly:
        return _tr('Gói ngắn hạn để trải nghiệm trọn bộ tính năng PRO.',
            'Short-term plan to experience all PRO features.');
      case VipProduct.monthly:
        return _tr('Dễ bắt đầu, cân bằng giữa chi phí và quyền lợi hằng ngày.',
            'Easy to start, balanced cost and daily benefits.');
      case VipProduct.yearly:
        return _tr('Phù hợp khi hai bạn dùng lâu dài và muốn tối ưu chi phí.',
            'Suitable for long-term use with optimized cost.');
      case VipProduct.lifetime:
        return _tr('Thanh toán một lần để mở khóa quyền lợi PRO lâu dài.',
            'Pay once to unlock PRO benefits permanently.');
      default:
        return _tr('Mở khóa toàn bộ trải nghiệm PRO cho hai bạn.',
            'Unlock full PRO experience for both of you.');
    }
  }

  String _planDurationLabel(VipPlanInfo? info) {
    if (info != null) {
      return _resolvedPlanLabel(info);
    }
    return _tr('Tính năng', 'Features');
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final showPurchaseUi = AppConfig.isPurchaseEnabled;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          showPurchaseUi
              ? _tr('SoulLocket PRO', 'SoulLocket PRO')
              : _tr('Tính năng tài khoản', 'Account Features'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: compact ? 18 : 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF111426),
              Color(0xFF171D38),
              Color(0xFF10294A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -110,
              right: -70,
              child: _buildBackdropOrb(
                size: 240,
                color: const Color(0xFFF9C15A),
              ),
            ),
            Positioned(
              top: 220,
              left: -90,
              child: _buildBackdropOrb(
                size: 220,
                color: const Color(0xFFCE6BE8),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: _buildBackdropOrb(
                size: 260,
                color: const Color(0xFF4FB9FF),
              ),
            ),
            SafeArea(
              child: showPurchaseUi
                  ? (_isLoading
                      ? const Center(
                          child: SkeletonContainer.circle(size: 48),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            compact ? 14 : 20,
                            12,
                            compact ? 14 : 20,
                            compact ? 20 : 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (RemoteConfigService().showWebTopup)
                                _buildWebTopupBanner(),
                              _buildHeroSection(),
                              const SizedBox(height: 22),
                              _buildBenefitsSection(),
                              const SizedBox(height: 20),
                              _buildComparisonSection(),
                              const SizedBox(height: 24),
                              if (_isVip)
                                _buildVipActiveStatus()
                              else
                                _buildProductSection(),
                              const SizedBox(height: 20),
                              _buildFooter(),
                            ],
                          ),
                        ))
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFF9C15A),
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _tr('Tính năng tài khoản chưa khả dụng',
                                    'Account Features Unavailable'),
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _tr('Mục này đang tạm ẩn trong bản phát hành hiện tại.',
                                    'This section is hidden in the current release.'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFFD8DDF0),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            if (_isPurchasing && showPurchaseUi)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A31).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFFF9C15A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _tr('Đang xử lý thanh toán...',
                                'Processing payment...'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  String _badgeLabel(ProductDetails product, VipPlanInfo? info) {
    final planId = _planIdForProduct(product);
    if (planId == VipProduct.yearly && info != null && info.savePercent > 0) {
      return _tr('Tiết kiệm ${info.savePercent}%', 'Save ${info.savePercent}%');
    }
    if (planId == VipProduct.sixMonths &&
        info != null &&
        info.savePercent > 0) {
      return _tr('Tiết kiệm ${info.savePercent}%', 'Save ${info.savePercent}%');
    }
    if (planId == VipProduct.monthly) {
      return _tr('Phổ biến', 'Popular');
    }
    if (planId == VipProduct.lifetime) {
      return _tr('Trọn đời', 'Lifetime');
    }
    return info?.badge ?? '';
  }

  String _purchaseModeText(ProductDetails product, VipPlanInfo? info) {
    if (_planIdForProduct(product) == VipProduct.lifetime ||
        info?.durationDays == null) {
      return _tr('Thanh toán 1 lần', 'One-time payment');
    }
    return _tr('Gia hạn theo chu kỳ', 'Auto-renewable subscription');
  }

  String _securityNote(ProductDetails product) {
    final planId = _planIdForProduct(product);
    if (VipProduct.isLifetimeProduct(planId)) {
      return 'Gói Vĩnh Viễn: Tải lên tới 40MB ảnh & 100MB video/ngày, kho 1024MB (1GB). $_storeDisplayName xử lý thanh toán một lần và bạn có thể khôi phục trên cùng tài khoản.';
    }
    return 'Gói VIP: Tải lên 20MB ảnh & 50MB video/ngày, kho 512MB. $_storeDisplayName xử lý thanh toán an toàn và tự quản lý chu kỳ gia hạn cho gói này.';
  }

  String _formatVnd(int amount) {
    final formatter = NumberFormat.decimalPattern('vi_VN');
    return '${formatter.format(amount)}đ';
  }

  String _displayPrice(ProductDetails product, VipPlanInfo? info) {
    return product.price;
  }

  String _calculatePricePerDay(ProductDetails product, VipPlanInfo? info) {
    final durationDays = info?.durationDays;
    if (durationDays == null || durationDays <= 0) {
      return 'Thanh toán một lần';
    }

    try {
      final rawPrice = product.rawPrice;
      if (rawPrice > 0) {
        final perDay = rawPrice / durationDays;
        if (product.currencyCode == 'VND') {
          final formatter = NumberFormat.currency(
            locale: 'vi_VN',
            symbol: 'đ',
            decimalDigits: 0,
          );
          return '~${formatter.format(perDay).replaceAll(' ', '')}/ngày';
        }

        final formatter =
            NumberFormat.simpleCurrency(name: product.currencyCode);
        return '~${formatter.format(perDay).replaceAll(' ', '')}/ngày';
      }
    } catch (_) {}

    if (info != null &&
        (product.currencyCode.isEmpty || product.currencyCode == 'VND')) {
      final perDay = (info.priceVnd / durationDays).round();
      return '~${_formatVnd(perDay)}/ngày';
    }

    return 'Tính theo ngày';
  }

  Widget _buildWebTopupBanner() {
    return GestureDetector(
      onTap: () async {
        const url = 'https://nap-soullockket.web.app';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr('Ưu đãi Nạp Web', 'Web Topup Offer'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tr('Giảm ngay 15% khi nạp VIP qua web', 'Get 15% off via Web topup'),
                    style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF9C15A).withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTopChip(
                icon: Icons.workspace_premium_rounded,
                label: 'PRO',
              ),
              _buildTopChip(
                icon: Icons.verified_user_rounded,
                label: _isVip ? 'Đang hoạt động' : _checkoutLabel,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF9C15A), Color(0xFFFFB347)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF9C15A).withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF1D2036),
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mở khóa trải nghiệm trọn vẹn',
                      style: SLTheme.quicksand(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SoulLocket PRO giúp hai bạn dùng app mượt hơn, lưu được nhiều hơn và có giao diện riêng tinh gọn.',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        color: const Color(0xFFD8DDF0),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PremiumInfoPill(
                icon: Icons.block_rounded,
                label: 'Không quảng cáo',
              ),
              _PremiumInfoPill(
                icon: Icons.cloud_done_rounded,
                label: 'Kho lưu trữ 512MB - 1GB',
              ),
              _PremiumInfoPill(
                icon: Icons.refresh_rounded,
                label: 'Khôi phục dễ dàng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = <Map<String, Object>>[
      {
        'icon': Icons.cloud_upload_rounded,
        'title': 'Kho lưu trữ mở rộng',
        'desc':
            'VIP: 20MB ảnh & 50MB video/ngày, kho 512MB. Gói Vĩnh Viễn: Tải lên x2 (40MB ảnh, 100MB video/ngày), kho x2 (1024MB/1GB).',
      },
      {
        'icon': Icons.palette_rounded,
        'title': 'Theme & hiệu ứng',
        'desc':
            'Mở khóa toàn bộ giao diện cao cấp, hiệu ứng tình yêu và tùy chỉnh không gian riêng của hai bạn.',
      },
      {
        'icon': Icons.style_rounded,
        'title': 'Love card & kỷ niệm',
        'desc':
            'Dùng không giới hạn mẫu thiệp, collage/video export và công cụ lưu giữ khoảnh khắc nâng cao.',
      },
      {
        'icon': Icons.block_rounded,
        'title': 'Không quảng cáo',
        'desc':
            'Trải nghiệm mượt mà, riêng tư, tập trung 100% cho hai bạn không bị làm phiền.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          title: 'Quyền lợi SoulLocket PRO',
          subtitle:
              'Mở khóa giao diện, hiệu ứng và kho lưu trữ kỷ niệm chất lượng cao cho hai bạn.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final itemWidth = isCompact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: benefits.map((benefit) {
                return SizedBox(
                  width: itemWidth,
                  child: _buildBenefitCard(
                    icon: benefit['icon'] as IconData,
                    title: benefit['title'] as String,
                    desc: benefit['desc'] as String,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildComparisonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'So sánh quyền lợi',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildComparisonRow(
            title: 'Tài khoản thường (Miễn phí)',
            items: const [
              'Tải lên mỗi ngày: 5MB ảnh & 15MB video',
              'Dung lượng kho: 182MB ảnh & 182MB video',
              'Theme mặc định, tiện ích cơ bản',
              'Có quảng cáo trải nghiệm',
            ],
          ),
          const SizedBox(height: 12),
          _buildComparisonRow(
            title: 'Gói VIP (Tuần / Tháng / 6 Tháng / Năm)',
            highlight: true,
            items: const [
              'Tải lên mỗi ngày: 20MB ảnh & 50MB video (gấp 4 lần)',
              'Dung lượng kho mở rộng: 512MB ảnh & 512MB video',
              'Mở khóa tất cả Theme, Hiệu ứng & Love Card PRO',
              'Không có quảng cáo làm phiền',
            ],
          ),
          const SizedBox(height: 12),
          _buildComparisonRow(
            title: 'Gói VIP VĨNH VIỄN (Gấp đôi quyền lợi VIP)',
            highlight: true,
            items: const [
              'Tải lên mỗi ngày: 40MB ảnh & 100MB video (gấp đôi VIP)',
              'Dung lượng kho tối đa: 1024MB (1GB) ảnh & 1GB video',
              'Mở khóa vĩnh viễn trọn đời toàn bộ tính năng PRO',
              'Thanh toán duy nhất 1 lần, không gia hạn định kỳ',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String title,
    required List<String> items,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFF9C15A).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? const Color(0xFFF9C15A).withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              color: highlight ? const Color(0xFFF9C15A) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    highlight
                        ? Icons.check_circle_rounded
                        : Icons.check_rounded,
                    size: 16,
                    color: highlight
                        ? const Color(0xFFF9C15A)
                        : const Color(0xFFC4CBDE),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: SLTheme.quicksand(
                        color: const Color(0xFFC4CBDE),
                        fontSize: 11.8,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF9C15A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFFF9C15A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: SLTheme.quicksand(
                    color: const Color(0xFFC4CBDE),
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF9C15A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đang kết nối tới App Store...',
                style: SLTheme.quicksand(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sortedProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF9C15A),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                _storeHint,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9C15A),
                  foregroundColor: const Color(0xFF1E1124),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Thử lại',
                  style: SLTheme.quicksand(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          title: 'Chọn gói phù hợp',
          subtitle:
              'Giá trên thẻ được chuẩn hóa theo bảng gói hiện tại. $_storeDisplayName sẽ xác nhận lại trước khi thanh toán.',
        ),
        const SizedBox(height: 14),
        ..._sortedProducts.map(_buildProductCard),
      ],
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final info = _planInfoFor(product);
    final featured = _isFeaturedPlan(product);
    final badge = _badgeLabel(product, info);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: featured
              ? [
                  const Color(0x26F8C14E),
                  const Color(0x22F37B9B),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: featured
              ? const Color(0xFFF9C15A).withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: featured
                ? const Color(0xFFF9C15A).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (badge.isNotEmpty)
                _buildPlanBadge(
                  label: badge,
                  bright: featured,
                ),
              _buildPlanBadge(
                label: _planDurationLabel(info),
              ),
              _buildPlanBadge(
                label: _purchaseModeText(product, info),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final infoColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planTitle(product, info),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: stacked ? 19 : 22,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _planSubtitle(product),
                    style: SLTheme.quicksand(
                      color: const Color(0xFFD6DCEF),
                      fontWeight: FontWeight.w600,
                      fontSize: stacked ? 12 : 12.5,
                      height: 1.42,
                    ),
                  ),
                ],
              );
              final priceColumn = Column(
                crossAxisAlignment:
                    stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    _displayPrice(product, info),
                    style: SLTheme.quicksand(
                      color: const Color(0xFFFFD36D),
                      fontWeight: FontWeight.w900,
                      fontSize: stacked ? 22 : 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _calculatePricePerDay(product, info),
                    style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoColumn,
                    const SizedBox(height: 10),
                    priceColumn
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: infoColumn),
                  const SizedBox(width: 14),
                  Flexible(flex: 0, child: priceColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFFF9C15A),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _securityNote(product),
                    style: SLTheme.quicksand(
                      color: const Color(0xFFC4CBDE),
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPurchasing
                  ? null
                  : () => _purchaseService.buyProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: featured
                    ? const Color(0xFFF9C15A)
                    : const Color(0xFF242A46),
                foregroundColor:
                    featured ? const Color(0xFF1E2138) : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                context.tr('premium_buy_now'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildStoreUnavailableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF9C15A).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.store_mall_directory_rounded,
              color: Color(0xFFF9C15A),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Dữ liệu đang được cập nhật',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _storeHint,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFFC4CBDE),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipActiveStatus() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x2BF9C15A),
            Color(0x1847C9A2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: const Color(0xFFF9C15A).withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF9C15A).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 38,
              color: Color(0xFFF9C15A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bạn đang dùng PRO',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toàn bộ quyền lợi đã được kích hoạt. Cảm ơn hai bạn đã đồng hành cùng SoulLocket.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFFD8DDF0),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            _tr('Mọi giao dịch được xử lý bởi $_storeDisplayName. Bạn có thể khôi phục lại gói đã mua trên cùng tài khoản bất cứ lúc nào.',
                'All transactions are processed by $_storeDisplayName. You can restore your purchases anytime.'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFFC4CBDE),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (_isAndroidStorePlatform || _isAppleStorePlatform)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isLoading || _isPurchasing ? null : _restorePurchases,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isAppleStorePlatform
                          ? _tr('Khôi phục giao dịch', 'Restore purchases')
                          : _tr('Làm mới trạng thái', 'Refresh status'),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFooterLink(
                label: _tr('Điều khoản sử dụng', 'Terms of Use (EULA)'),
                onTap: () => _openExternalUrl(AppConfig.termsOfUseUrl),
              ),
              Text(
                '•',
                style: SLTheme.quicksand(
                  color: Colors.white38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _buildFooterLink(
                label: _tr('Chính sách bảo mật', 'Privacy Policy'),
                onTap: () => _openExternalUrl(AppConfig.privacyPolicyUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: SLTheme.quicksand(
            color: const Color(0xFFC4CBDE),
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildTopChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFF9C15A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge({
    required String label,
    bool bright = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bright
            ? const Color(0xFFF9C15A)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: bright
              ? const Color(0xFFF9C15A)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: bright ? const Color(0xFF1E2138) : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildFooterLink({
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: const Color(0xFFF9C15A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildBackdropOrb({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFF9C15A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
