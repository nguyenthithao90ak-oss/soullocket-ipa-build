import 'package:flutter/cupertino.dart';

/// Custom page route với slide từ phải + fade nhẹ.
/// Thay thế MaterialPageRoute để transition mượt hơn trên cả Android & iOS.
/// Đã được cập nhật để hỗ trợ vuốt trái để quay lại (swipe-to-back) giống TikTok/iOS trên mọi nền tảng.
///
/// Dùng:
///   Navigator.of(context).push(SLRoute(builder: (_) => TargetScreen()));
class SLRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  final WidgetBuilder builder;

  SLRoute({
    required this.builder,
    super.settings,
  });

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  bool get popGestureEnabled =>
      true; // Luôn bật tính năng vuốt để back trên Android/iOS
}

/// Shorthand push helper — thay Navigator.of(context).push(MaterialPageRoute(...))
Future<T?> slPush<T>(BuildContext context, Widget screen) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    SLRoute<T>(builder: (_) => screen),
  );
}
