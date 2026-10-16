import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/utils/local_guide_route_tracker.dart';

/// Custom page route với slide từ phải + fade nhẹ.
/// Thay thế MaterialPageRoute để transition mượt hơn trên cả Android & iOS.
/// Đã được cập nhật để hỗ trợ vuốt trái để quay lại (swipe-to-back) giống TikTok/iOS trên mọi nền tảng.
///
/// Dùng:
///   Navigator.of(context).push(SLRoute(builder: (_) => TargetScreen()));
class SLRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  final WidgetBuilder builder;
  final bool _fullscreenDialog;

  SLRoute({required this.builder, bool? fullscreenDialog, super.settings})
    : _fullscreenDialog = fullscreenDialog ?? false;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  bool get popGestureEnabled => true; // Luôn bật tính năng vuốt để back trên Android/iOS
}

/// Shorthand push helper — thay Navigator.of(context).push(MaterialPageRoute(...))
Future<T?> slPush<T>(
  BuildContext context,
  Widget screen, {
  bool fullscreenDialog = false,
}) {
  return slPushRoute<T>(
    context,
    SLRoute<T>(builder: (_) => screen, fullscreenDialog: fullscreenDialog),
    identity: _SlRouteIdentity(screen.runtimeType, screen.key),
    localGuideScreenType: screen.runtimeType.toString(),
  );
}

/// Mở route tùy chỉnh qua cùng cơ chế chống mở trùng của [slPush].
/// Giữ nguyên transition, overlay và Navigator mà tính năng đang sử dụng.
Future<T?> slPushRoute<T>(
  BuildContext context,
  PageRoute<T> route, {
  required Object identity,
  bool rootNavigator = false,
  String? localGuideScreenType,
}) {
  if (!context.mounted) return Future<T?>.value(null);
  final navigator = Navigator.of(context, rootNavigator: rootNavigator);
  // Khóa theo màn hình hiện tại và loại màn hình đích. Nhờ vậy các cú chạm
  // lặp từ cùng một màn hình không tạo route trùng, nhưng màn hình con vẫn
  // có thể mở bình thường sau khi màn hình cha đã hiển thị.
  final source = ModalRoute.of(context) ?? navigator;
  var gates = _slRouteGates[source];
  if (gates == null) {
    gates = <Object, SingleOpenGate>{};
    _slRouteGates[source] = gates;
  }
  var openingGate = _slRouteOpeningGates[source];
  if (openingGate == null) {
    openingGate = SingleOpenGate();
    _slRouteOpeningGates[source] = openingGate;
  }
  // Bỏ cú chạm vào đích khác trong khi route nguồn đang chuyển màn.
  // Khóa này chỉ giữ lúc mở; callback màn con vẫn hoạt động sau đó.
  final activeGate = gates[identity];
  if (activeGate?.isBusy != true && openingGate.isBusy) {
    return Future<T?>.value(null);
  }
  final gate = gates.putIfAbsent(identity, SingleOpenGate.new);
  final entryGate = openingGate;
  var didTrackLocalGuideRoute = false;
  return gate
      .runValue<T>(() async {
        late Future<T?> result;
        await entryGate.run(() async {
          result = navigator.push<T>(route);
          if (localGuideScreenType != null) {
            LocalGuideRouteTracker.instance.didPushScreen(localGuideScreenType);
            didTrackLocalGuideRoute = true;
          }
          await _waitForRouteEntry(route);
        });
        final value = await result;
        // Navigator.push hoàn tất khi bắt đầu pop. Chờ overlay được gỡ để
        // cú chạm còn sót trong hiệu ứng đóng không mở lại màn hình.
        await route.completed;
        return value;
      })
      .whenComplete(() {
        if (didTrackLocalGuideRoute) {
          LocalGuideRouteTracker.instance.didPopScreen(localGuideScreenType!);
        }
        if (!gate.isBusy && identical(gates![identity], gate)) {
          gates.remove(identity);
        }
      });
}

final Expando<Map<Object, SingleOpenGate>> _slRouteGates =
    Expando<Map<Object, SingleOpenGate>>();
final Expando<SingleOpenGate> _slRouteOpeningGates = Expando<SingleOpenGate>();

Future<void> _waitForRouteEntry(PageRoute<dynamic> route) async {
  final animation = route.animation;
  if (animation == null || animation.status == AnimationStatus.completed) {
    return;
  }
  final entered = Completer<void>();
  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !entered.isCompleted) {
      entered.complete();
    }
  }

  animation.addStatusListener(onStatus);
  try {
    // Route có thể bị pop/remove trước khi hiệu ứng mở chạy xong.
    await Future.any<void>([entered.future, route.popped.then((_) {})]);
  } finally {
    animation.removeStatusListener(onStatus);
  }
}

class _SlRouteIdentity {
  const _SlRouteIdentity(this.type, this.key);

  final Type type;
  final Key? key;

  @override
  bool operator ==(Object other) {
    return other is _SlRouteIdentity && other.type == type && other.key == key;
  }

  @override
  int get hashCode => Object.hash(type, key);
}
