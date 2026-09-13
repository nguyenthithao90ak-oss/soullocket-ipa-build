import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/services/consent_service.dart';
import '../utils/services/infrastructure/admob_service.dart';

/// Gỡ native ad view ngay khi rút đồng ý, không tái gắn banner đã hủy.
class ConsentAdView extends StatelessWidget {
  const ConsentAdView({super.key, required this.ad});
  final BannerAd ad;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      ConsentService.optionalCollectionAllowed,
      AdMobService().adRevision,
    ]),
    builder: (_, _) =>
        ConsentService.optionalCollectionAllowed.value &&
            AdMobService().isBannerUsable(ad)
        ? LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < ad.size.width ||
                constraints.maxHeight < ad.size.height) {
              return const SizedBox.shrink();
            }
            return AdWidget(ad: ad);
          })
        : const SizedBox.shrink(),
  );
}
