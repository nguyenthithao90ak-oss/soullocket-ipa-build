import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DiaryPhotoQuality { economy, balanced, high }

@immutable
class MediaDataSettings {
  const MediaDataSettings({
    this.photoQuality = DiaryPhotoQuality.balanced,
    this.wifiOnlyVideos = false,
  });

  final DiaryPhotoQuality photoQuality;
  final bool wifiOnlyVideos;

  MediaDataSettings copyWith({
    DiaryPhotoQuality? photoQuality,
    bool? wifiOnlyVideos,
  }) => MediaDataSettings(
    photoQuality: photoQuality ?? this.photoQuality,
    wifiOnlyVideos: wifiOnlyVideos ?? this.wifiOnlyVideos,
  );

  ({int width, int height, int quality}) imageOptions({
    required int width,
    required int height,
    required int quality,
  }) => switch (photoQuality) {
    DiaryPhotoQuality.economy => (
      width: width.clamp(1, 1080),
      height: height.clamp(1, 1080),
      quality: quality.clamp(1, 70),
    ),
    DiaryPhotoQuality.balanced => (
      width: width,
      height: height,
      quality: quality,
    ),
    DiaryPhotoQuality.high => (width: 2200, height: 2200, quality: 88),
  };

  bool allowsVideo(Iterable<ConnectivityResult> connections) =>
      !wifiOnlyVideos || connections.contains(ConnectivityResult.wifi);

  Map<String, Object> toJson() => {
    'photoQuality': photoQuality.name,
    'wifiOnlyVideos': wifiOnlyVideos,
  };

  static MediaDataSettings fromJson(Object? value) {
    if (value is! Map) return const MediaDataSettings();
    return MediaDataSettings(
      photoQuality: DiaryPhotoQuality.values.firstWhere(
        (quality) => quality.name == value['photoQuality'],
        orElse: () => DiaryPhotoQuality.balanced,
      ),
      wifiOnlyVideos: value['wifiOnlyVideos'] == true,
    );
  }
}

/// Tùy chọn mạng trên từng máy/tài khoản; không thêm listener hoặc dữ liệu cloud.
class MediaDataPreferences extends ChangeNotifier {
  MediaDataPreferences({
    required this.currentUid,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static final instance = MediaDataPreferences(
    currentUid: () {
      try {
        return FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        return null;
      }
    },
  );

  final String? Function() currentUid;
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _writes = Future<void>.value();

  static String key(String uid) => 'media_data_v1_$uid';

  Future<MediaDataSettings> read() async {
    final uid = currentUid();
    if (uid == null || uid.isEmpty) return const MediaDataSettings();
    final prefs = await _preferences();
    if (currentUid() != uid) return const MediaDataSettings();
    try {
      return MediaDataSettings.fromJson(
        jsonDecode(prefs.getString(key(uid)) ?? '{}'),
      );
    } catch (_) {
      return const MediaDataSettings();
    }
  }

  Future<void> update(MediaDataSettings settings) {
    final uid = currentUid();
    final work = _writes.then((_) async {
      if (uid == null || uid.isEmpty || currentUid() != uid) {
        throw StateError('Media preferences session changed');
      }
      final prefs = await _preferences();
      if (currentUid() != uid) {
        throw StateError('Media preferences session changed');
      }
      final saved = await prefs.setString(
        key(uid),
        jsonEncode(settings.toJson()),
      );
      if (!saved) throw StateError('Media preferences write failed');
      if (currentUid() == uid) notifyListeners();
    });
    _writes = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<bool> canStartVideo({
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
  }) async {
    final settings = await read();
    if (!settings.wifiOnlyVideos) return true;
    try {
      final connections =
          await (checkConnectivity ?? Connectivity().checkConnectivity)()
              .timeout(const Duration(seconds: 3));
      return settings.allowsVideo(connections);
    } catch (_) {
      return false;
    }
  }
}
