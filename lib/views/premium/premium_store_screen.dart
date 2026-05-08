import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../services/purchase_service.dart';

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
  final PurchaseService _purchaseService = PurchaseService();

  StreamSubscription<VipPurchaseState>? _purchaseStatusSubscription;

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isVip = false;
  List<ProductDetails> _products = [];
  String _storeHint = 'Hiện chưa có gói PRO khả dụng trên cửa hàng này.';
  bool _storeConfigured = false;

  bool get _isAppleStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroidStorePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get _storeDisplayName {
    if (_isAppleStorePlatform) {
      return 'cửa hàng trong ứng dụng';
    }
    if (_isAndroidStorePlatform) {
      return 'cửa hàng trong ứng dụng';
    }
    return 'cửa hàng trên thiết bị';
  }

  String get _checkoutLabel {
    if (_isAppleStorePlatform) {
      return 'Thanh toán trong ứng dụng';
    }
    if (_isAndroidStorePlatform) {
      return 'Thanh toán trong ứng dụng';
    }
    return 'Thanh toán trong ứng dụng';
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
      if (kIsWeb) {
        return 'Tính năng nâng cấp PRO chưa hỗ trợ trên phiên bản web. Hãy mở ứng dụng trên điện thoại để mua gói.';
      }
      return 'Cửa hàng thanh toán trên thiết bị này chưa sẵn sàng. Vui lòng kiểm tra kết nối mạng, tài khoản cửa hàng rồi thử lại.';
    }

    if (products.isEmpty) {
      if (_isAppleStorePlatform) {
        return 'Cửa hàng trên thiết bị chưa trả về gói PRO. Vui lòng kiểm tra cấu hình IAP và gắn gói mua vào bản phát hành đang gửi duyệt.';
      }
      return 'Hiện chưa tải được danh sách gói PRO. Vui lòng thử lại sau ít phút.';
    }

    return 'Hiện chưa có gói PRO khả dụng trên cửa hàng này.';
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
    final offerDetails = _googlePlayOfferDetails(product);
    final pricingPhase = _googlePlayPricingPhase(product);
    final billingPeriod = pricingPhase?.billingPeriod.toUpperCase() ?? '';
    final basePlanId = offerDetails?.basePlanId.toLowerCase() ?? '';
    final offerId = offerDetails?.offerId?.toLowerCase() ?? '';
    final tags = offerDetails?.offerTags.join(' ').toLowerCase() ?? '';
    final canonicalFromId = VipProduct.canonicalPlanId(product.id);
    final haystack =
        '$basePlanId $offerId $tags ${product.id.toLowerCase()} ${product.title.toLowerCase()}';

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

    if (VipProduct.planInfo.containsKey(canonicalFromId)) {
      return canonicalFromId;
    }

    return canonicalFromId;
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
          'Thanh toán thành công. Quyền lợi PRO sẽ được cập nhật trong giây lát.',
        );
        unawaited(_loadData());
        break;
      case VipPurchaseState.error:
        setState(() => _isPurchasing = false);
        _showMessage(
          'Chưa hoàn tất được giao dịch: có thể thanh toán bị hủy, cửa hàng chưa phản hồi hoặc giao dịch vẫn đang chờ xác nhận. Bạn có thể thử lại hoặc dùng Khôi phục mua hàng.',
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
    await _purchaseService.restorePurchases();
    await _loadData();
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final url = Uri.parse(rawUrl);
    if (!await canLaunchUrl(url)) {
      if (!mounted) return;
      _showMessage('Không thể mở liên kết này ngay bây giờ.', isError: true);
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
        return '1 tuần';
      case 30:
        return '1 tháng';
      case 180:
        return '6 tháng';
      case 365:
        return '1 năm';
      default:
        return info.durationDays == null ? 'Vĩnh viễn' : info.label;
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
        return 'Gói ngắn hạn để mở nhanh toàn bộ quyền lợi PRO.';
      case VipProduct.monthly:
        return 'Dễ bắt đầu, đủ dùng hằng ngày và giữ mức chi phí nhẹ.';
      case VipProduct.sixMonths:
        return 'Phù hợp khi hai bạn dùng ổn định và muốn tiết kiệm hơn gói tháng.';
      case VipProduct.yearly:
        return 'Tối ưu chi phí cho nhu cầu dùng lâu dài suốt cả năm.';
      case VipProduct.lifetime:
        return 'Thanh toán một lần để giữ quyền lợi PRO lâu dài.';
      default:
        break;
    }

    switch (product.id) {
      case VipProduct.weekly:
        return 'Gói ngắn hạn để trải nghiệm trọn bộ tính năng PRO.';
      case VipProduct.monthly:
        return 'Dễ bắt đầu, cân bằng giữa chi phí và quyền lợi hằng ngày.';
      case VipProduct.yearly:
        return 'Phù hợp khi hai bạn dùng lâu dài và muốn tối ưu chi phí.';
      case VipProduct.lifetime:
        return 'Thanh toán một lần để mở khóa quyền lợi PRO lâu dài.';
      default:
        return 'Mở khóa toàn bộ trải nghiệm PRO cho hai bạn.';
    }
  }

  String _planDurationLabel(VipPlanInfo? info) {
    if (info != null) {
      return _resolvedPlanLabel(info);
    }
    return 'Gói PRO';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    const showPurchaseUi = AppConfig.showPurchaseUi;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'SoulLocket PRO',
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
                          child: CircularProgressIndicator(
                            color: Color(0xFFF9C15A),
                          ),
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
                              _buildHeroSection(),
                              const SizedBox(height: 22),
                              _buildBenefitsSection(),
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
                                Icons.workspace_premium_outlined,
                                color: Color(0xFFF9C15A),
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Mục PRO đang tạm ẩn',
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bản review hiện không hiển thị nút mua hay giao diện PRO.',
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
                            'Đang xử lý thanh toán...',
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



  Widget _buildStoreNotConfiguredCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: Color(0xFFF9C15A),
            size: 32,
          ),
          const SizedBox(height: 14),
          Text(
            'Mua PRO chưa sẵn sàng trên bản phát hành này',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phần thanh toán đang được tạm ẩn vì cửa hàng chưa thiết lập sản phẩm IAP đầy đủ. Khi cấu hình xong phần mua trong hệ thống phát hành, mục này sẽ tự mở lại.',
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

  String _badgeLabel(ProductDetails product, VipPlanInfo? info) {
    final planId = _planIdForProduct(product);
    if (planId == VipProduct.yearly && (info?.savePercent ?? 0) > 0) {
      return 'Tiết kiệm ${info!.savePercent}%';
    }
    if (planId == VipProduct.sixMonths && (info?.savePercent ?? 0) > 0) {
      return 'Tiết kiệm ${info!.savePercent}%';
    }
    if (planId == VipProduct.monthly) {
      return 'Phổ biến';
    }
    if (planId == VipProduct.lifetime) {
      return 'Trọn đời';
    }
    return info?.badge ?? '';
  }

  String _purchaseModeText(ProductDetails product, VipPlanInfo? info) {
    if (_planIdForProduct(product) == VipProduct.lifetime ||
        info?.durationDays == null) {
      return 'Thanh toán 1 lần';
    }
    return 'Gia hạn theo chu kỳ';
  }

  String _securityNote(ProductDetails product) {
    final info = _planInfoFor(product);
    final planId = _planIdForProduct(product);
    final memoryNote =
        info == null ? '' : 'Tối đa ${info.memoryLimit} ảnh Kỷ niệm. ';
    if (VipProduct.isLifetimeProduct(planId)) {
      return '$memoryNote$_storeDisplayName xử lý thanh toán một lần và bạn có thể khôi phục trên cùng tài khoản.';
    }
    if (info != null) {
      return '$memoryNote$_storeDisplayName xử lý thanh toán an toàn và tự quản lý chu kỳ gia hạn cho gói này.';
    }
    if (planId == VipProduct.lifetime) {
      return '$_storeDisplayName xử lý thanh toán một lần và bạn có thể khôi phục trên cùng tài khoản.';
    }
    return '$_storeDisplayName xử lý thanh toán an toàn và tự quản lý chu kỳ gia hạn cho gói này.';
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

    if (info != null) {
      final perDay = (info.priceVnd / durationDays).round();
      return '~${_formatVnd(perDay)}/ngày';
    }

    try {
      final perDay = product.rawPrice / durationDays;
      if (product.currencyCode == 'VND') {
        final formatter = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: '₫',
          decimalDigits: 0,
        );
        return '~${formatter.format(perDay).replaceAll(' ', '')}/ngày';
      }

      final formatter = NumberFormat.currency(
        symbol: product.currencyCode,
        decimalDigits: 2,
      );
      return '~${formatter.format(perDay)}/ngày';
    } catch (_) {
      return 'Tính theo ngày';
    }
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
                label: 'Lưu trữ rộng hơn',
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
        'icon': Icons.block_rounded,
        'title': 'Không quảng cáo',
        'desc': 'Giữ trải nghiệm liền mạch và tập trung hơn mỗi ngày.',
      },
      {
        'icon': Icons.cloud_sync_rounded,
        'title': 'Lưu trữ rộng hơn',
        'desc': 'Thoải mái lưu ảnh kỷ niệm, Nhật ký và dữ liệu quan trọng; PRO giữ ảnh nét hơn với nén nhẹ hơn.',
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Chủ đề độc quyền',
        'desc': 'Giao diện PRO gọn gàng, đồng bộ và chỉn chu hơn.',
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Huy hiệu PRO',
        'desc': 'Hiển thị nổi bật hơn ở hồ sơ và khu vực Cộng đồng.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          title: 'Quyền lợi nổi bật',
          subtitle:
              'Các quyền lợi thiết thực, không rườm rà, tập trung vào trải nghiệm dùng thật.',
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
    if (!_storeConfigured) {
      return _buildStoreNotConfiguredCard();
    }

    if (_sortedProducts.isEmpty) {
      return _buildStoreUnavailableCard();
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
                'Mua ngay',
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
            'Chưa tải được gói PRO',
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
        border: Border.all(color: const Color(0xFFF9C15A).withValues(alpha: 0.35)),
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
            'Mọi giao dịch được xử lý bởi $_storeDisplayName. Bạn có thể khôi phục lại gói đã mua trên cùng tài khoản bất cứ lúc nào.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFFC4CBDE),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading || _isPurchasing ? null : _restorePurchases,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Khôi phục mua hàng',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFooterLink(
                label: 'Điều khoản sử dụng',
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
                label: 'Chính sách bảo mật',
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
        color:
            bright ? const Color(0xFFF9C15A) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              bright ? const Color(0xFFF9C15A) : Colors.white.withValues(alpha: 0.08),
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
