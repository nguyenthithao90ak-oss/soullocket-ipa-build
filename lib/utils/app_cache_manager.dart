import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static const key = 'slAppCacheKey';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 1500,
    ),
  );
}
