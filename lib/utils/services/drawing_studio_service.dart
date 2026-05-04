import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';

class DrawingStudioGalleryItem {
  final String id;
  final String path;
  final String? inlineBase64;
  final String? remoteUrl;
  final int createdAtMs;
  final String mode;
  final String syncStatus;
  final String? storagePath;

  const DrawingStudioGalleryItem({
    required this.id,
    required this.path,
    required this.createdAtMs,
    required this.mode,
    this.inlineBase64,
    this.remoteUrl,
    this.syncStatus = 'local',
    this.storagePath,
  });

  bool get isPendingUpload => false;

  bool get isLegacyCloudItem =>
      (remoteUrl?.isNotEmpty ?? false) &&
      path.isEmpty &&
      (inlineBase64?.isEmpty ?? true);

  bool get isValidForCurrentPlatform {
    if (kIsWeb) {
      return (inlineBase64?.isNotEmpty ?? false) ||
          (remoteUrl?.isNotEmpty ?? false);
    }
    return path.isNotEmpty || (remoteUrl?.isNotEmpty ?? false);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'inlineBase64': inlineBase64,
      'remoteUrl': remoteUrl,
      'createdAtMs': createdAtMs,
      'mode': mode,
      'syncStatus': syncStatus,
      'storagePath': storagePath,
    };
  }

  factory DrawingStudioGalleryItem.fromJson(Map<String, dynamic> json) {
    return DrawingStudioGalleryItem(
      id: (json['id'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      inlineBase64: json['inlineBase64'] as String?,
      remoteUrl: json['remoteUrl']?.toString(),
      createdAtMs: int.tryParse((json['createdAtMs'] ?? '').toString()) ?? 0,
      mode: (json['mode'] ?? 'pic').toString(),
      syncStatus: (json['syncStatus'] ?? 'local').toString(),
      storagePath: json['storagePath']?.toString(),
    );
  }

  DrawingStudioGalleryItem copyWith({
    String? id,
    String? path,
    String? inlineBase64,
    String? remoteUrl,
    int? createdAtMs,
    String? mode,
    String? syncStatus,
    String? storagePath,
  }) {
    return DrawingStudioGalleryItem(
      id: id ?? this.id,
      path: path ?? this.path,
      inlineBase64: inlineBase64 ?? this.inlineBase64,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      mode: mode ?? this.mode,
      syncStatus: syncStatus ?? this.syncStatus,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

class DrawingStudioBackground {
  const DrawingStudioBackground({
    required this.id,
    this.type = 'template',
    this.imageUrl = '',
    this.storagePath = '',
    this.updatedAt = 0,
    this.updatedBy = '',
  });

  final String id;
  final String type;
  final String imageUrl;
  final String storagePath;
  final int updatedAt;
  final String updatedBy;

  static const fallback = DrawingStudioBackground(id: 'paper_grid');

  factory DrawingStudioBackground.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return fallback;
    final id = (map['id'] ?? '').toString().trim();
    return DrawingStudioBackground(
      id: id.isEmpty ? fallback.id : id,
      type: (map['type'] ?? 'template').toString().trim(),
      imageUrl: (map['imageUrl'] ?? '').toString().trim(),
      storagePath: (map['storagePath'] ?? '').toString().trim(),
      updatedAt: _readInt(map['updatedAt']),
      updatedBy: (map['updatedBy'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) {
    return {
      'id': id,
      'type': type,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'updatedBy': updatedBy,
      'updatedAt': ServerValue.timestamp,
    };
  }
}

class DrawingStudioStroke {
  const DrawingStudioStroke({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.colorValue,
    required this.width,
    required this.points,
    this.tool = 'pen',
    this.createdAt = 0,
    this.endedAt = 0,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final int colorValue;
  final double width;
  final List<List<double>> points;
  final String tool;
  final int createdAt;
  final int endedAt;

  factory DrawingStudioStroke.fromMap(String id, Map<dynamic, dynamic>? map) {
    final rawPoints = map?['points'];
    final points = <List<double>>[];
    if (rawPoints is List) {
      for (final point in rawPoints) {
        if (point is List && point.length >= 2) {
          final x = _readDouble(point[0]).clamp(0.0, 1.0).toDouble();
          final y = _readDouble(point[1]).clamp(0.0, 1.0).toDouble();
          points.add([x, y]);
        }
      }
    }

    return DrawingStudioStroke(
      id: id,
      authorUid: (map?['authorUid'] ?? '').toString().trim(),
      authorName: (map?['authorName'] ?? '').toString().trim(),
      colorValue: _readInt(map?['color'], fallback: 0xFFFF3B4D),
      width: _readDouble(map?['width'], fallback: 8).clamp(1.0, 40.0),
      tool: (map?['tool'] ?? 'pen').toString().trim(),
      points: points,
      createdAt: _readInt(map?['createdAt']),
      endedAt: _readInt(map?['endedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'color': colorValue,
      'width': width,
      'tool': tool,
      'points': points,
      'createdAt': createdAt,
      'endedAt': ServerValue.timestamp,
    };
  }
}

class DrawingStudioPresence {
  const DrawingStudioPresence({
    required this.uid,
    required this.name,
    required this.isDrawing,
    required this.colorValue,
    required this.updatedAt,
  });

  final String uid;
  final String name;
  final bool isDrawing;
  final int colorValue;
  final int updatedAt;

  factory DrawingStudioPresence.fromMap(String uid, Map<dynamic, dynamic>? map) {
    return DrawingStudioPresence(
      uid: uid,
      name: (map?['name'] ?? '').toString().trim(),
      isDrawing: map?['isDrawing'] == true,
      colorValue: _readInt(map?['color'], fallback: 0xFFFF3B4D),
      updatedAt: _readInt(map?['updatedAt']),
    );
  }
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class DrawingStudioService {
  DrawingStudioService({
    FirebaseDatabase? database,
    Object? storageService,
  }) : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  static const int maxGalleryItems = 20;
  static const String _galleryPrefsKey = 'drawing_studio_gallery_v2';
  static const String _cachePrefix = 'drawing_studio_gallery_cloud_v1_';
  static const String _migratedPrefix = 'drawing_studio_gallery_migrated_v1_';

  DatabaseReference _studioRef(String houseId) =>
      _db.ref('houses/${houseId.trim()}/drawing_studio');

  Stream<DrawingStudioBackground> streamBackground(String houseId) {
    return _studioRef(houseId).child('background').onValue.map((event) {
      final value = event.snapshot.value;
      return DrawingStudioBackground.fromMap(value is Map ? value : null);
    });
  }

  Stream<List<DrawingStudioStroke>> streamStrokes(String houseId) {
    return _studioRef(houseId)
        .child('strokes')
        .limitToLast(1000)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <DrawingStudioStroke>[];
      final strokes = <DrawingStudioStroke>[];
      for (final entry in value.entries) {
        final stroke = DrawingStudioStroke.fromMap(
          entry.key.toString(),
          entry.value is Map ? entry.value as Map : null,
        );
        if (stroke.points.isNotEmpty) {
          strokes.add(stroke);
        }
      }
      strokes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return strokes;
    });
  }

  Stream<List<DrawingStudioPresence>> streamPresence(String houseId) {
    return _studioRef(houseId).child('presence').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <DrawingStudioPresence>[];
      return value.entries
          .map((entry) => DrawingStudioPresence.fromMap(
                entry.key.toString(),
                entry.value is Map ? entry.value as Map : null,
              ))
          .toList();
    });
  }

  Future<void> updatePresence({
    required String houseId,
    required String uid,
    required String name,
    required bool isDrawing,
    required int colorValue,
  }) async {
    final ref = _studioRef(houseId).child('presence/$uid');
    await ref.onDisconnect().remove();
    await ref.set({
      'name': name,
      'isDrawing': isDrawing,
      'color': colorValue,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> removePresence({
    required String houseId,
    required String uid,
  }) async {
    await _studioRef(houseId).child('presence/$uid').remove();
  }

  Future<void> setBackground({
    required String houseId,
    required String uid,
    required DrawingStudioBackground background,
  }) async {
    await _studioRef(houseId)
        .child('background')
        .set(background.toMap(updatedBy: uid));
  }

  Future<String> pushStroke({
    required String houseId,
    required DrawingStudioStroke stroke,
  }) async {
    final ref = _studioRef(houseId).child('strokes').push();
    await ref.set(stroke.toMap());
    return ref.key ?? stroke.id;
  }

  Future<void> deleteStroke({
    required String houseId,
    required String strokeId,
  }) async {
    await _studioRef(houseId).child('strokes/$strokeId').remove();
  }

  Future<void> clearRealtimeCanvas({
    required String houseId,
    required String uid,
  }) async {
    final ref = _studioRef(houseId);
    final sessionRef = ref.child('session');
    await ref.child('strokes').remove();
    await sessionRef.update({
      'version': ServerValue.increment(1),
      'clearedBy': uid,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<List<DrawingStudioGalleryItem>> loadGallery(String houseId) async {
    await _clearCloudMarkers(houseId);
    return _loadLocalGallery();
  }

  Future<DrawingStudioGalleryItem> saveDrawing(
    String houseId,
    Uint8List data, {
    required String mode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'drawing_$now';
    final item = await _buildLocalItem(
      id: id,
      bytes: data,
      createdAtMs: now,
      mode: mode,
    );

    final next = _normalizeGallery([item, ...await _loadLocalGallery()]);
    await _persistLocalGallery(next);
    await _clearCloudMarkers(houseId);
    return item;
  }

  Future<String?> saveBytesToDevice(
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Trình duyệt hiện chưa hỗ trợ lưu trực tiếp.');
    }

    final name = fileName ??
        'soullocket_drawing_${DateTime.now().millisecondsSinceEpoch}';
    final result = await VisionGallerySaver.saveImage(
      bytes,
      quality: 100,
      name: name,
      androidRelativePath: 'Pictures/SoulLocket/DrawingStudio',
    );

    final filePath = result['filePath']?.toString();
    final isSuccess =
        result['isSuccess'] == true || (filePath?.isNotEmpty ?? false);
    if (!isSuccess) {
      final errorMessage = result['errorMessage']?.toString();
      throw Exception(
        errorMessage?.isNotEmpty == true ? errorMessage : 'Lỗi khi lưu ảnh',
      );
    }
    return filePath;
  }

  Future<String?> exportGalleryItemToDevice(
    DrawingStudioGalleryItem item, {
    String? fileName,
  }) async {
    final bytes = await _readItemBytes(item);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Không đọc được dữ liệu tranh để lưu ra máy.');
    }
    return saveBytesToDevice(
      bytes,
      fileName: fileName ?? 'soullocket_drawing_${item.createdAtMs}',
    );
  }

  Future<void> deleteGalleryItem(
    String houseId,
    DrawingStudioGalleryItem item,
  ) async {
    if (!kIsWeb && item.path.isNotEmpty) {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final next = (await _loadLocalGallery())
        .where((entry) => entry.id != item.id)
        .toList();
    await _persistLocalGallery(next);
    await _clearCloudMarkers(houseId);
  }

  Future<void> syncPendingLocalGallery(String houseId) async {
    await _clearCloudMarkers(houseId);
  }

  Future<void> migrateLegacyLocalGallery(String houseId) async {
    await _clearCloudMarkers(houseId);
  }

  Future<List<DrawingStudioGalleryItem>> _loadLocalGallery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_galleryPrefsKey);
      if (raw == null || raw.isEmpty) {
        return const <DrawingStudioGalleryItem>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return _normalizeGallery(
        list
            .whereType<Map>()
            .map(
              (item) => DrawingStudioGalleryItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return const <DrawingStudioGalleryItem>[];
    }
  }

  Future<void> _persistLocalGallery(
      List<DrawingStudioGalleryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _galleryPrefsKey,
      jsonEncode(
          _normalizeGallery(items).map((item) => item.toJson()).toList()),
    );
  }

  Future<DrawingStudioGalleryItem> _buildLocalItem({
    required String id,
    required Uint8List bytes,
    required int createdAtMs,
    required String mode,
  }) async {
    if (kIsWeb) {
      return DrawingStudioGalleryItem(
        id: id,
        path: '',
        inlineBase64: base64Encode(bytes),
        createdAtMs: createdAtMs,
        mode: mode,
        syncStatus: 'local',
      );
    }

    final dir = await _ensureGalleryDirectory();
    final file = File('${dir.path}/$id.png');
    await file.writeAsBytes(bytes, flush: true);
    return DrawingStudioGalleryItem(
      id: id,
      path: file.path,
      createdAtMs: createdAtMs,
      mode: mode,
      syncStatus: 'local',
    );
  }

  Future<Uint8List?> _readItemBytes(DrawingStudioGalleryItem item) async {
    if (item.inlineBase64 != null && item.inlineBase64!.isNotEmpty) {
      return base64Decode(item.inlineBase64!);
    }
    if (!kIsWeb && item.path.isNotEmpty) {
      final file = File(item.path);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }
    if (!kIsWeb && (item.remoteUrl?.isNotEmpty ?? false)) {
      return _downloadRemoteBytes(item.remoteUrl!);
    }
    return null;
  }

  Future<Uint8List?> _downloadRemoteBytes(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCloudMarkers(String houseId) async {
    final trimmedHouseId = houseId.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmedHouseId.isNotEmpty) {
      await prefs.remove('$_cachePrefix$trimmedHouseId');
      await prefs.remove('$_migratedPrefix$trimmedHouseId');
    }
  }

  Future<Directory> _ensureGalleryDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/drawing_studio_gallery');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  List<DrawingStudioGalleryItem> _normalizeGallery(
    List<DrawingStudioGalleryItem> items,
  ) {
    final byId = <String, DrawingStudioGalleryItem>{};
    for (final item in items) {
      final id = item.id.isNotEmpty
          ? item.id
          : 'drawing_${item.createdAtMs}_${item.mode}';
      byId[id] = item.copyWith(
        id: id,
        syncStatus: item.syncStatus.isEmpty ? 'local' : item.syncStatus,
      );
    }

    final values = byId.values
        .where((item) => item.isValidForCurrentPlatform)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    if (values.length > maxGalleryItems) {
      return values.take(maxGalleryItems).toList();
    }
    return values;
  }
}
