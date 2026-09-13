import 'dart:async';

import 'package:flutter/widgets.dart';

/// Dùng cùng ngân sách giải mã cho ảnh tải trước và ảnh hiển thị ở Home.
class HomeImagePolicy {
  HomeImagePolicy._();

  static const avatarPixels = 256;
  static const warmupTimeout = Duration(milliseconds: 1500);

  // Chỉ làm nóng tài nguyên đã đóng gói; sticker online tải khi thực sự cần.
  static const bundledAssets = <String>[
    'assets/images/avatar_male.jpg',
    'assets/images/avatar_female.jpg',
    'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_343.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_339.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_228.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_270.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_276.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_165.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_173.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_108.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_158.png',
  ];

  static ({int width, int height}) backgroundSize({BuildContext? context}) {
    final media = context == null ? null : MediaQuery.maybeOf(context);
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isEmpty ? null : views.first;
    final ratio = media?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;
    final logicalSize = media?.size ?? (view?.physicalSize ?? Size.zero) / ratio;
    return backgroundSizeFor(logicalSize, ratio);
  }

  static ({int width, int height}) backgroundSizeFor(
    Size logicalSize,
    double devicePixelRatio,
  ) {
    final scale = devicePixelRatio >= 2.5 ? 0.75 : 0.85;
    return (
      width: (logicalSize.width * devicePixelRatio * scale)
          .round()
          .clamp(600, 1280),
      height: (logicalSize.height * devicePixelRatio * scale)
          .round()
          .clamp(960, 1920),
    );
  }

  static ImageProvider<Object> resized(
    ImageProvider<Object> provider, {
    required int width,
    required int height,
  }) => ResizeImage(
    provider,
    width: width,
    height: height,
    policy: ResizeImagePolicy.fit,
  );

  /// Hết thời gian thì tháo listener; không giữ ảnh sống chỉ vì mạng/decoder chậm.
  static Future<void> warmImage(
    ImageProvider<Object> provider, {
    ImageConfiguration configuration = ImageConfiguration.empty,
    Duration timeout = warmupTimeout,
  }) async {
    final stream = provider.resolve(configuration);
    final ready = Completer<void>();
    final listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      },
    );
    try {
      stream.addListener(listener);
      await ready.future.timeout(timeout);
    } finally {
      stream.removeListener(listener);
    }
  }
}
