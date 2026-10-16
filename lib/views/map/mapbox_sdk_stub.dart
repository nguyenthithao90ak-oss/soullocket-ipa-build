// ignore_for_file: constant_identifier_names

// Bản thay thế rỗng cho package mapbox_maps_flutter (gỡ khỏi app ngày 14/10/2026).
//
// SDK Mapbox nặng khoảng 10 MB mỗi máy tải về nhưng đang bị tắt cứng
// (`_canUseMapboxSdk => false` trong map_screen.dart), bản đồ thật dùng FlutterMap.
// File này chỉ khai báo đúng các tên mà code bản đồ đang gọi để vẫn biên dịch được;
// không đoạn nào ở đây được chạy vì nhánh Mapbox luôn tắt.
//
// Bật lại Mapbox: xem docs/MAPBOX_REMOVAL_2026-10-14.md (thêm lại dòng
// `mapbox_maps_flutter` trong pubspec.yaml và đổi 2 import về package thật).
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class MapboxOptions {
  static void setAccessToken(String token) {}
}

class MapboxStyles {
  static const String STANDARD = 'mapbox://styles/mapbox/standard';
  static const String STANDARD_SATELLITE =
      'mapbox://styles/mapbox/standard-satellite';
}

class Position {
  Position(this.lng, this.lat);
  final num lng;
  final num lat;
}

class Point {
  Point({required this.coordinates});
  final Position coordinates;
}

class LineString {
  LineString({required this.coordinates});
  final List<Position> coordinates;
}

class MbxEdgeInsets {
  MbxEdgeInsets({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });
  final double top;
  final double left;
  final double bottom;
  final double right;
}

class CameraOptions {
  CameraOptions({this.center, this.padding, this.zoom, this.pitch});
  final Point? center;
  final MbxEdgeInsets? padding;
  final double? zoom;
  final double? pitch;
}

class CameraState {
  CameraState(this.center);
  final Point center;
}

class MapAnimationOptions {
  MapAnimationOptions({this.duration});
  final int? duration;
}

enum IconAnchor { BOTTOM }

enum TextAnchor { BOTTOM }

enum LineJoin { ROUND }

enum OrnamentPosition { BOTTOM_LEFT, BOTTOM_RIGHT }

class LogoSettings {
  LogoSettings({this.enabled, this.position, this.marginLeft, this.marginBottom});
  final bool? enabled;
  final OrnamentPosition? position;
  final double? marginLeft;
  final double? marginBottom;
}

class AttributionSettings {
  AttributionSettings({
    this.enabled,
    this.position,
    this.marginRight,
    this.marginBottom,
  });
  final bool? enabled;
  final OrnamentPosition? position;
  final double? marginRight;
  final double? marginBottom;
}

class OrnamentSettings {
  Future<void> updateSettings(Object settings) async {}
}

class PointAnnotation {
  PointAnnotation({this.customData});
  final Map<String, Object>? customData;
}

class PointAnnotationOptions {
  PointAnnotationOptions({
    this.geometry,
    this.image,
    this.iconAnchor,
    this.iconSize,
    this.textField,
    this.textSize,
    this.textColor,
    this.textHaloColor,
    this.textHaloWidth,
    this.textOffset,
    this.textAnchor,
    this.customData,
  });
  final Point? geometry;
  final Uint8List? image;
  final IconAnchor? iconAnchor;
  final double? iconSize;
  final String? textField;
  final double? textSize;
  final int? textColor;
  final int? textHaloColor;
  final double? textHaloWidth;
  final List<double?>? textOffset;
  final TextAnchor? textAnchor;
  final Map<String, Object>? customData;
}

class PolylineAnnotationOptions {
  PolylineAnnotationOptions({
    this.geometry,
    this.lineColor,
    this.lineWidth,
    this.lineBorderColor,
    this.lineBorderWidth,
    this.lineJoin,
  });
  final LineString? geometry;
  final int? lineColor;
  final double? lineWidth;
  final int? lineBorderColor;
  final double? lineBorderWidth;
  final LineJoin? lineJoin;
}

class AnnotationTapSubscription {
  void cancel() {}
}

class PointAnnotationManager {
  Future<void> deleteAll() async {}
  Future<void> setTextAllowOverlap(bool value) async {}
  Future<void> setTextIgnorePlacement(bool value) async {}
  Future<void> createMulti(List<PointAnnotationOptions> options) async {}
  AnnotationTapSubscription tapEvents({
    required void Function(PointAnnotation annotation) onTap,
  }) => AnnotationTapSubscription();
}

class PolylineAnnotationManager {
  Future<void> deleteAll() async {}
  Future<void> createMulti(List<PolylineAnnotationOptions> options) async {}
}

class AnnotationManagers {
  Future<PointAnnotationManager> createPointAnnotationManager({
    String? id,
  }) async => PointAnnotationManager();
  Future<PolylineAnnotationManager> createPolylineAnnotationManager({
    String? id,
  }) async => PolylineAnnotationManager();
}

class MapContentGestureContext {
  MapContentGestureContext(this.point);
  final Point point;
}

class TapInteraction {
  static TapInteraction onMap(
    void Function(MapContentGestureContext context) action,
  ) => TapInteraction();
}

class LongTapInteraction {
  static LongTapInteraction onMap(
    void Function(MapContentGestureContext context) action,
  ) => LongTapInteraction();
}

class MapboxMap {
  final AnnotationManagers annotations = AnnotationManagers();
  final OrnamentSettings logo = OrnamentSettings();
  final OrnamentSettings attribution = OrnamentSettings();

  void addInteraction(Object interaction, {String? interactionID}) {}
  Future<CameraOptions> cameraForCoordinatesPadding(
    List<Point> coordinates,
    CameraOptions camera,
    MbxEdgeInsets? coordinatesPadding,
    double? maxZoom,
    Object? offset,
  ) async => camera;
  Future<void> easeTo(CameraOptions camera, MapAnimationOptions? options) async {}
  Future<CameraState> getCameraState() async =>
      CameraState(Point(coordinates: Position(108.2772, 14.0583)));
  Future<void> setStyleURI(String uri) async {}
  Future<void> setStyleImportConfigProperty(
    String importId,
    String config,
    Object value,
  ) async {}
  Future<bool> styleSourceExists(String sourceId) async => false;
  Future<void> addStyleSource(String sourceId, String properties) async {}
  Future<void> setStyleTerrain(String properties) async {}
  Future<void> removeStyleTerrain() async {}
  Future<void> removeStyleSource(String sourceId) async {}
}

class CameraViewportState {
  const CameraViewportState({this.center, this.zoom, this.padding, this.pitch});
  final Point? center;
  final double? zoom;
  final EdgeInsets? padding;
  final double? pitch;
}

class MapLoadingErrorEventData {
  MapLoadingErrorEventData(this.message);
  final String message;
}

/// Không bao giờ được dựng (nhánh Mapbox tắt); trả về khung rỗng nếu lỡ dựng.
class MapWidget extends StatelessWidget {
  const MapWidget({
    super.key,
    this.viewport,
    this.styleUri,
    this.onMapCreated,
    this.onStyleLoadedListener,
    this.onMapLoadedListener,
    this.onMapLoadErrorListener,
  });

  final CameraViewportState? viewport;
  final String? styleUri;
  final void Function(MapboxMap map)? onMapCreated;
  final void Function(Object event)? onStyleLoadedListener;
  final void Function(Object event)? onMapLoadedListener;
  final void Function(MapLoadingErrorEventData event)? onMapLoadErrorListener;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
