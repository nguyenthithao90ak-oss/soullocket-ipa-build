import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/web_helpers.dart';

import 'private_media_url_service.dart';
import 'storage/private_memory_download_helper.dart';
import 'storage/private_memory_lifecycle_policy.dart';

enum DiaryExportFormat { pdf, html }

/// ============================================================
///  ExportService — GRA (Hệ thống)
///  Xuất dữ liệu Nhật ký (PDF/HTML) — (Phase 24)
/// ============================================================
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal() : this.withDependencies();

  @visibleForTesting
  ExportService.withDependencies({
    FirebaseFirestore? firestore,
    this.databaseReference,
    String? Function()? currentUid,
    Stream<String?> Function()? authChanges,
    this.privateMediaUrls,
    http.Client Function()? clientFactory,
    this.exportDirectory,
    this.isWeb = kIsWeb,
    void Function(String, List<int>, String)? downloadFile,
  }) : _firestoreOverride = firestore,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _authChanges =
           authChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           )),
       _clientFactory = clientFactory ?? http.Client.new,
       _downloadFile = downloadFile ?? downloadWebFile;

  static const _pageSize = 200;
  static const _maxArchiveBytes = 128 * 1024 * 1024;
  final FirebaseFirestore? _firestoreOverride;
  final DatabaseReference? databaseReference;
  final String? Function() _currentUid;
  final Stream<String?> Function() _authChanges;
  final PrivateMediaUrlService? privateMediaUrls;
  final http.Client Function() _clientFactory;
  final Future<io.Directory> Function()? exportDirectory;
  final bool isWeb;
  final void Function(String, List<int>, String) _downloadFile;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  DatabaseReference get _dbRef =>
      databaseReference ?? FirebaseDatabase.instance.ref();

  static String errorMessage(Object error) {
    if (error is UiCopyException) return error.message;
    if (error is FirebaseException) {
      if (error.code == 'unauthenticated') {
        return UiCopy.text('copy_99c1b9afbfb7');
      }
      if (error.code == 'permission-denied') {
        return UiCopy.text('copy_cb72ed85751d');
      }
    }
    return L10nService().translate('util_chathxutdl_223d08');
  }

  Future<_DiaryExportScope> _beginScope(String houseId) async {
    if (houseId.isEmpty || RegExp(r'[.#$\[\]/\\\x00-\x1f]').hasMatch(houseId)) {
      throw const UiCopyException('copy_f15d7c99a3c3');
    }
    final scope = _DiaryExportScope(houseId, _currentUid, _authChanges());
    try {
      scope.preferences = await SharedPreferences.getInstance();
      scope.check();
      return scope;
    } catch (_) {
      await scope.close();
      rethrow;
    }
  }

  /// Lưu file export vào thư mục documents để xem lại sau
  Future<io.Directory> _getExportDir() async {
    if (exportDirectory != null) return exportDirectory!();
    final docDir = await getApplicationDocumentsDirectory();
    final exportDir = io.Directory('${docDir.path}/SoulLocket_Exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  Future<String> resolveDiaryHouseName(
    String houseId, {
    String fallbackName = 'SoulHouse',
  }) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      return fallbackName;
    }

    try {
      final snapshot = await _dbRef
          .child('houses/$resolvedHouseId/settings/houseName')
          .get()
          .timeout(const Duration(seconds: 8));
      final houseName = snapshot.value?.toString().trim() ?? '';
      if (houseName.isNotEmpty) return houseName;
    } catch (error) {
      debugPrint(
        '[ExportService] Không đọc được tên nhà (${error.runtimeType}).',
      );
    }

    return fallbackName;
  }

  Future<String?> exportDiary({
    required String houseId,
    required DiaryExportFormat format,
    String? houseName,
  }) async {
    final resolvedHouseName = houseName?.trim().isNotEmpty == true
        ? houseName!.trim()
        : await resolveDiaryHouseName(houseId);

    switch (format) {
      case DiaryExportFormat.pdf:
        return await exportDiaryToPdf(houseId, resolvedHouseName);
      case DiaryExportFormat.html:
        return await exportDiaryToHtml(houseId, resolvedHouseName);
    }
  }

  Future<String?> exportDiaryToPdf(String houseId, String houseName) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      throw const UiCopyException('copy_f15d7c99a3c3');
    }

    final resolvedHouseName = houseName.trim().isNotEmpty
        ? houseName.trim()
        : 'SoulHouse';
    final scope = await _beginScope(resolvedHouseId);
    try {
      final entries = await _loadDiaryEntries(scope);
      if (entries.isEmpty) {
        throw const UiCopyException('copy_1a95ec8dce23');
      }
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'NHAT KY TINH YEU - $resolvedHouseName',
                style: const pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            ...entries.map((entry) {
              final date = entry['time'] ?? '';
              final author =
                  entry['authorName'] ??
                  entry['author'] ??
                  UiCopy.text('copy_7f0ab3a994bf');
              final mood = entry['mood'] ?? '';
              final content = entry['content'] ?? entry['c'] ?? '';

              return pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.pink, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '$date | $author',
                          style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.pink,
                          ),
                        ),
                        pw.Text(mood, style: const pw.TextStyle(fontSize: 16)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(content, style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      );

      final filename = _buildExportFilename(
        prefix: 'NhatKy',
        houseName: resolvedHouseName,
        extension: 'pdf',
      );
      final bytes = await pdf.save();

      return await _saveOutput(scope, filename, bytes, 'application/pdf');
    } finally {
      await scope.close();
    }
  }

  Future<String?> exportDiaryToHtml(String houseId, String houseName) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      throw const UiCopyException('copy_f15d7c99a3c3');
    }

    final resolvedHouseName = houseName.trim().isNotEmpty
        ? houseName.trim()
        : 'SoulHouse';
    final scope = await _beginScope(resolvedHouseId);
    try {
      final entries = await _loadDiaryEntries(scope);
      if (entries.isEmpty) {
        throw const UiCopyException('copy_1a95ec8dce23');
      }

      final htmlContent = _buildHtml(entries, resolvedHouseName);
      final filename = _buildExportFilename(
        prefix: 'NhatKy',
        houseName: resolvedHouseName,
        extension: 'html',
      );

      return await _saveOutput(
        scope,
        filename,
        utf8.encode(htmlContent),
        'text/html',
      );
    } finally {
      await scope.close();
    }
  }

  Future<List<Map<String, dynamic>>> _loadDiaryEntries(
    _DiaryExportScope scope,
  ) async {
    final entries = <Map<String, dynamic>>[];
    final baseQuery = _firestore
        .collection('houses')
        .doc(scope.houseId)
        .collection('diaries')
        .orderBy(FieldPath.documentId)
        .limit(_pageSize);
    DocumentSnapshot<Map<String, dynamic>>? lastDocument;
    while (true) {
      scope.check();
      final query = lastDocument == null
          ? baseQuery
          : baseQuery.startAfterDocument(lastDocument);
      final snapshot = await _getDiaryPage(query);
      scope.check();
      for (final document in snapshot.docs) {
        final entry = _jsonValue(document.data()) as Map<String, dynamic>;
        entry['id'] = document.id;
        entry['ts'] = _timestamp(entry);
        entries.add(entry);
      }
      if (snapshot.docs.length < _pageSize) break;
      lastDocument = snapshot.docs.last;
    }

    entries.sort(
      (first, second) => _timestamp(first).compareTo(_timestamp(second)),
    );
    return entries;
  }

  static Object? _jsonValue(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonValue(item)),
      );
    }
    if (value is List) return value.map(_jsonValue).toList();
    return value;
  }

  static int _timestamp(Map<String, dynamic> entry) {
    final value = entry['ts'] ?? entry['timestamp'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Future<String?> _saveOutput(
    _DiaryExportScope scope,
    String filename,
    List<int> bytes,
    String mimeType,
  ) async {
    scope.check();
    await _verifyHouseMembership(scope);
    scope.check();
    if (isWeb) {
      _downloadFile(filename, bytes, mimeType);
      return null;
    }
    final exportDir = await _getExportDir();
    scope.check();
    final file = io.File(p.join(exportDir.path, filename));
    try {
      await file.writeAsBytes(bytes, flush: true);
      scope.check();
      return file.path;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  String _buildExportFilename({
    required String prefix,
    required String houseName,
    required String extension,
  }) {
    final safeHouseName = houseName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final baseName = safeHouseName.isNotEmpty ? safeHouseName : 'SoulHouse';
    return '${prefix}_${baseName}_${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  String _buildHtml(List<Map<String, dynamic>> entries, String houseName) {
    final formatter = LocaleDateFormat.dateTimeFormat();
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln(
        '<html lang="${L10nService().locale.toLanguageTag()}" '
        'dir="${L10nService().locale.languageCode == 'ar' ? 'rtl' : 'ltr'}">',
      )
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln(
        UiCopy.text('copy_d42342ea9f14', {'value1': _escapeHtml(houseName)}),
      )
      ..writeln('<style>')
      ..writeln(
        'body{font-family:Arial,sans-serif;background:#fff7fb;color:#3f3f46;padding:24px;}',
      )
      ..writeln('.wrap{max-width:880px;margin:0 auto;}')
      ..writeln(
        '.card{background:#fff;border:1px solid #f9a8d4;border-radius:16px;padding:16px;margin-bottom:16px;box-shadow:0 8px 24px rgba(216,27,96,.08);}',
      )
      ..writeln(
        '.head{display:flex;justify-content:space-between;gap:12px;margin-bottom:8px;font-weight:700;color:#d81b60;}',
      )
      ..writeln('.mood{font-size:24px;}')
      ..writeln('.content{white-space:pre-wrap;line-height:1.7;color:#27272a;}')
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="wrap">')
      ..writeln(
        UiCopy.text('copy_7bcf5ee1baec', {'value1': _escapeHtml(houseName)}),
      );

    for (final entry in entries) {
      final timestamp = entry['ts'] as int? ?? entry['timestamp'] as int? ?? 0;
      final date = timestamp > 0
          ? formatter.format(DateTime.fromMillisecondsSinceEpoch(timestamp))
          : (entry['time']?.toString() ?? '');
      final author =
          entry['authorName']?.toString() ??
          entry['author']?.toString() ??
          UiCopy.text('copy_7f0ab3a994bf');
      final mood = entry['mood']?.toString() ?? '';
      final content =
          entry['content']?.toString() ?? entry['c']?.toString() ?? '';

      buffer
        ..writeln('<section class="card">')
        ..writeln(
          '<div class="head"><span>${_escapeHtml(date)} • ${_escapeHtml(author)}</span><span class="mood">${_escapeHtml(mood)}</span></div>',
        )
        ..writeln('<div class="content">${_escapeHtml(content)}</div>')
        ..writeln('</section>');
    }

    buffer
      ..writeln('</div>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Export tat ca ky niem (diary + memories anh) thanh file ZIP
  Future<String> exportAllMemories({
    required String houseId,
    required String houseName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      throw const UiCopyException('copy_f15d7c99a3c3');
    }

    final resolvedHouseName = houseName.trim().isNotEmpty
        ? houseName.trim()
        : 'SoulHouse';
    final scope = await _beginScope(resolvedHouseId);
    final urls = privateMediaUrls ?? PrivateMediaUrlService();
    try {
      onProgress?.call(0.05, UiCopy.text('copy_927331615e0a'));
      final entries = await _loadDiaryEntries(scope);
      onProgress?.call(0.1, UiCopy.text('copy_7fe65f51958e'));
      final memories = await _loadMemories(scope);
      if (entries.isEmpty && memories.isEmpty) {
        throw const UiCopyException('copy_1a95ec8dce23');
      }

      final archive = Archive();
      var archiveBytes = 0;
      void addFile(String filename, List<int> bytes) {
        if (archiveBytes + bytes.length > _maxArchiveBytes) {
          throw FirebaseException(plugin: 'export', code: 'resource-exhausted');
        }
        archiveBytes += bytes.length;
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }

      addFile(
        'diary.json',
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert({
            'houseName': resolvedHouseName,
            'exportedAt': DateTime.now().toIso8601String(),
            'entries': entries,
          }),
        ),
      );
      addFile(
        'diary.html',
        utf8.encode(_buildHtml(entries, resolvedHouseName)),
      );

      final metadata = <Map<String, dynamic>>[];
      var downloadedCount = 0;
      onProgress?.call(
        0.2,
        UiCopy.text('copy_d1bdd0b9a45b', {'value1': memories.length}),
      );
      for (var index = 0; index < memories.length; index++) {
        scope.check();
        final memory = memories[index];
        String? filename;
        Uint8List? bytes;
        try {
          bytes = await _downloadMemory(scope, memory, urls);
        } on FirebaseException catch (error) {
          if (const {
            'unauthenticated',
            'permission-denied',
            'cancelled',
            'resource-exhausted',
          }.contains(error.code)) {
            rethrow;
          }
        }
        scope.check();
        if (bytes != null) {
          filename =
              'memories/memory_${index + 1}.${_mediaExtension(memory, bytes)}';
          addFile(filename, bytes);
          downloadedCount++;
        }
        final timestamp = _timestamp(memory);
        metadata.add({
          'id': memory['id'],
          'author': memory['authorName'] ?? memory['author'] ?? '',
          'ts': timestamp,
          'date': timestamp > 0
              ? LocaleDateFormat.dateTimeFormat().format(
                  DateTime.fromMillisecondsSinceEpoch(timestamp),
                )
              : '',
          'caption': memory['caption'] ?? '',
          'mediaType': memory['mediaType'] ?? memory['type'] ?? '',
          'file': filename,
          'downloaded': filename != null,
        });
        onProgress?.call(
          0.2 + 0.7 * (index + 1) / memories.length,
          UiCopy.text('copy_58c93ec30d62', {
            'value1': index + 1,
            'value2': memories.length,
          }),
        );
      }
      if (entries.isEmpty && memories.isNotEmpty && downloadedCount == 0) {
        throw FirebaseException(plugin: 'export', code: 'unavailable');
      }
      addFile(
        'memories/metadata.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(metadata)),
      );
      scope.check();
      onProgress?.call(0.92, UiCopy.text('copy_b0a804b6d3d9'));
      final zipData = ZipEncoder().encode(archive);
      final filename = _buildExportFilename(
        prefix: 'SoulLocket_All',
        houseName: resolvedHouseName,
        extension: 'zip',
      );
      final filePath = await _saveOutput(
        scope,
        filename,
        zipData,
        'application/zip',
      );
      onProgress?.call(1, UiCopy.text('copy_73feb527bf4b'));
      return filePath ?? '';
    } finally {
      if (privateMediaUrls == null) urls.dispose();
      await scope.close();
    }
  }

  Future<List<Map<String, dynamic>>> _loadMemories(
    _DiaryExportScope scope,
  ) async {
    final memories = <Map<String, dynamic>>[];
    final baseQuery = _dbRef
        .child('houses/${scope.houseId}/memories')
        .orderByKey()
        .limitToFirst(_pageSize);
    String? lastKey;
    while (true) {
      scope.check();
      final snapshot =
          await (lastKey == null ? baseQuery : baseQuery.startAfter(lastKey))
              .get()
              .timeout(const Duration(seconds: 20));
      scope.check();
      final children = snapshot.children.toList();
      for (final child in children) {
        if (child.value is! Map) continue;
        final memory = _jsonValue(child.value) as Map<String, dynamic>;
        if (memory['deletedAt'] != null) continue;
        memory['id'] = child.key;
        memories.add(memory);
      }
      if (children.length < _pageSize) break;
      lastKey = children.last.key;
    }
    memories.sort(
      (first, second) => _timestamp(first).compareTo(_timestamp(second)),
    );
    return memories;
  }

  Future<Uint8List> _downloadMemory(
    _DiaryExportScope scope,
    Map<String, dynamic> memory,
    PrivateMediaUrlService urls,
  ) async {
    final isPrivate =
        memory['privateMedia'] == true ||
        memory['storageAccess'] == 'signed' ||
        memory['privateUploadVersion'] == 1 ||
        PrivateMemoryLifecyclePolicy.isPrivateId('${memory['id']}');
    final client = _clientFactory();
    try {
      final downloaded = await const PrivateMemoryDownloadHelper().download(
        resolve: () async {
          scope.check();
          if (isPrivate) {
            return urls.resolve(
              houseId: scope.houseId,
              mediaId: '${memory['id']}',
              kind: 'memory_image',
              forceRefresh: true,
            );
          }
          return PrivateMediaUrlResult(
            url: _memoryUrl(memory),
            expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
          );
        },
        client: client,
        currentUid: _currentUid,
        authChanges: _authChanges(),
        scopeIsCurrent: () => scope.isCurrent,
        maxBytes: _maxArchiveBytes,
      );
      return downloaded.bytes;
    } finally {
      client.close();
    }
  }

  String _mediaExtension(Map<String, dynamic> memory, Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        ascii.decode(bytes.sublist(1, 4), allowInvalid: true) == 'PNG') {
      return 'png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'webp';
    }
    if (bytes.length >= 6 &&
        ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'GIF') {
      return 'gif';
    }
    final type = '${memory['contentType'] ?? memory['mimeType'] ?? ''}'
        .toLowerCase();
    final extension = p
        .extension(
          Uri.tryParse(
                '${memory['url'] ?? memory['storagePath'] ?? ''}',
              )?.path ??
              '',
        )
        .replaceFirst('.', '')
        .toLowerCase();
    if (const {
      'mp4',
      'mov',
      'webm',
      'm4v',
      'heic',
      'heif',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
    }.contains(extension)) {
      return extension;
    }
    if (type == 'video/mp4') return 'mp4';
    if (type == 'video/quicktime') return 'mov';
    if (type == 'video/webm') return 'webm';
    return 'bin';
  }

  String _memoryUrl(Map<String, dynamic> memory) {
    for (final key in const [
      'url',
      'downloadUrl',
      'download_url',
      'mediaUrl',
      'media_url',
      'imageUrl',
      'fileUrl',
      'file_url',
    ]) {
      final value = memory[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getDiaryPage(
    Query<Map<String, dynamic>> query,
  ) async {
    return query
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _verifyHouseMembership(_DiaryExportScope scope) async {
    scope.check();
    final uid = scope.uid;
    if (uid == null || uid.isEmpty) {
      throw FirebaseException(plugin: 'export', code: 'unauthenticated');
    }

    final membership = await _firestore
        .collection('house_memberships')
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    scope.check();
    final data = membership.data();
    final membershipHouseId =
        (data?['houseId'] ?? data?['house_id'])?.toString().trim() ?? '';
    if (!membership.exists ||
        data?['revoked'] == true ||
        membershipHouseId != scope.houseId) {
      throw FirebaseException(plugin: 'export', code: 'permission-denied');
    }
  }
}

class _DiaryExportScope {
  _DiaryExportScope(this.houseId, this._currentUid, Stream<String?> authChanges)
    : uid = _currentUid() {
    _subscription = authChanges.listen((nextUid) {
      if (nextUid != uid) _changed = true;
    }, onError: (Object _) => _changed = true);
  }

  final String houseId;
  final String? uid;
  final String? Function() _currentUid;
  late final StreamSubscription<String?> _subscription;
  SharedPreferences? preferences;
  bool _changed = false;

  bool get isCurrent =>
      uid != null &&
      uid!.isNotEmpty &&
      !_changed &&
      _currentUid() == uid &&
      (preferences?.getString('il_house_id') == null ||
          preferences?.getString('il_house_id') == houseId);

  void check() {
    if (uid == null || uid!.isEmpty || _changed || _currentUid() != uid) {
      throw FirebaseException(plugin: 'export', code: 'unauthenticated');
    }
    if (!isCurrent) {
      throw FirebaseException(plugin: 'export', code: 'cancelled');
    }
  }

  Future<void> close() => _subscription.cancel();
}
