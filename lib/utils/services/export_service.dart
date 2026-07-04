import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:soullocket_app/utils/web_helpers.dart';

enum DiaryExportFormat {
  pdf,
  html,
}

/// ============================================================
///  ExportService — GRA (Hệ thống)
///  Xuất dữ liệu Nhật ký (PDF/HTML) — (Phase 24)
/// ============================================================
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Lưu file export vào thư mục documents để xem lại sau
  Future<io.Directory> _getExportDir() async {
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
      final snapshot =
          await _dbRef.child('houses/$resolvedHouseId/settings').get();
      if (snapshot.value is Map) {
        final settings = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final houseName = (settings['houseName'] ?? '').toString().trim();
        if (houseName.isNotEmpty) {
          return houseName;
        }
      }
    } catch (_) {}

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
      throw Exception('Chưa có mã nhà');
    }

    final resolvedHouseName =
        houseName.trim().isNotEmpty ? houseName.trim() : 'SoulHouse';
    final entries = await _loadDiaryEntries(resolvedHouseId);
    if (entries.isEmpty) {
      throw Exception('Chưa có nhật ký để xuất');
    }
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('NHAT KY TINH YEU - $resolvedHouseName',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          ...entries.map((entry) {
            final date = entry['time'] ?? '';
            final author = entry['author'] ?? 'Anonym';
            final mood = entry['mood'] ?? '';
            final content = entry['c'] ?? '';

            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 10),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.pink, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$date | $author',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.pink)),
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

    if (kIsWeb) {
      downloadWebFile(filename, bytes, 'application/pdf');
      return null;
    }

    final exportDir = await _getExportDir();
    final file = io.File('${exportDir.path}/$filename');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Xuất Nhật ký của $resolvedHouseName',
      ),
    );

    return file.path;
  }

  Future<String?> exportDiaryToHtml(String houseId, String houseName) async {
    final resolvedHouseId = houseId.trim();
    if (resolvedHouseId.isEmpty) {
      throw Exception('Chưa có mã nhà');
    }

    final resolvedHouseName =
        houseName.trim().isNotEmpty ? houseName.trim() : 'SoulHouse';
    final entries = await _loadDiaryEntries(resolvedHouseId);
    if (entries.isEmpty) {
      throw Exception('Chưa có nhật ký để xuất');
    }

    final htmlContent = _buildHtml(entries, resolvedHouseName);
    final filename = _buildExportFilename(
      prefix: 'NhatKy',
      houseName: resolvedHouseName,
      extension: 'html',
    );

    if (kIsWeb) {
      downloadWebFile(filename, utf8.encode(htmlContent), 'text/html');
      return null;
    }

    final exportDir = await _getExportDir();
    final file = io.File('${exportDir.path}/$filename');
    await file.writeAsString(htmlContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Xuất HTML Nhật ký của $resolvedHouseName',
      ),
    );

    return file.path;
  }

  Future<List<Map<String, dynamic>>> _loadDiaryEntries(String houseId) async {
    final snapshot = await _dbRef.child('houses/$houseId/diary').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final entries = <Map<String, dynamic>>[];
    data.forEach((key, value) {
      if (value is Map) {
        final entry = Map<String, dynamic>.from(value);
        entry['id'] = key.toString();
        entries.add(entry);
      }
    });

    entries
        .sort((a, b) => (a['ts'] as int? ?? 0).compareTo(b['ts'] as int? ?? 0));
    return entries;
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
    return '${prefix}_$baseName.$extension';
  }

  String _buildHtml(List<Map<String, dynamic>> entries, String houseName) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="vi">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
          '<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..writeln('<title>Nhật ký $houseName</title>')
      ..writeln('<style>')
      ..writeln(
          'body{font-family:Arial,sans-serif;background:#fff7fb;color:#3f3f46;padding:24px;}')
      ..writeln('.wrap{max-width:880px;margin:0 auto;}')
      ..writeln(
          '.card{background:#fff;border:1px solid #f9a8d4;border-radius:16px;padding:16px;margin-bottom:16px;box-shadow:0 8px 24px rgba(216,27,96,.08);}')
      ..writeln(
          '.head{display:flex;justify-content:space-between;gap:12px;margin-bottom:8px;font-weight:700;color:#d81b60;}')
      ..writeln('.mood{font-size:24px;}')
      ..writeln('.content{white-space:pre-wrap;line-height:1.7;color:#27272a;}')
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="wrap">')
      ..writeln('<h1>Nhật ký tình yêu - ${_escapeHtml(houseName)}</h1>');

    for (final entry in entries) {
      final timestamp = entry['ts'] as int? ?? entry['timestamp'] as int? ?? 0;
      final date = timestamp > 0
          ? formatter.format(DateTime.fromMillisecondsSinceEpoch(timestamp))
          : (entry['time']?.toString() ?? '');
      final author = entry['authorName']?.toString() ??
          entry['author']?.toString() ??
          'Ẩn danh';
      final mood = entry['mood']?.toString() ?? '';
      final content =
          entry['content']?.toString() ?? entry['c']?.toString() ?? '';

      buffer
        ..writeln('<section class="card">')
        ..writeln(
            '<div class="head"><span>${_escapeHtml(date)} • ${_escapeHtml(author)}</span><span class="mood">${_escapeHtml(mood)}</span></div>')
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
    if (resolvedHouseId.isEmpty) throw Exception('Chưa có mã nhà');

    final resolvedHouseName =
        houseName.trim().isNotEmpty ? houseName.trim() : 'SoulHouse';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportDir = io.Directory(
        '${(await getTemporaryDirectory()).path}/SoulLocket_Export_$timestamp');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create(recursive: true);

    final memoriesDir = io.Directory('${exportDir.path}/memories');
    await memoriesDir.create();

    // 1. Load diary entries
    onProgress?.call(0.05, 'Đang thu thập nhật ký...');
    final entries = await _loadDiaryEntries(resolvedHouseId);

    // 2. Write diary.json
    final diaryFile = io.File('${exportDir.path}/diary.json');
    await diaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'houseName': resolvedHouseName,
        'exportedAt': DateTime.now().toIso8601String(),
        'entries': entries,
      }),
    );

    // 3. Load memories
    onProgress?.call(0.1, 'Đang thu thập ảnh kỷ niệm...');
    final memoriesSnap =
        await _dbRef.child('houses/$resolvedHouseId/memories').get();
    final memoriesList = <Map<String, dynamic>>[];
    if (memoriesSnap.exists && memoriesSnap.value is Map) {
      final data = Map<dynamic, dynamic>.from(memoriesSnap.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          final mem = Map<String, dynamic>.from(value);
          mem['id'] = key.toString();
          memoriesList.add(mem);
        }
      });
      memoriesList.sort(
          (a, b) => (a['ts'] as int? ?? 0).compareTo(b['ts'] as int? ?? 0));
    }

    if (memoriesList.isEmpty) {
      throw Exception('Chưa có ảnh kỷ niệm để xuất');
    }

    // 4. Download memories images
    final totalMemories = memoriesList.length;
    onProgress?.call(0.2, 'Đang tải 0/$totalMemories ảnh...');

    for (var i = 0; i < memoriesList.length; i++) {
      final mem = memoriesList[i];
      final memUrl = (mem['url'] as String?)?.trim() ?? '';
      if (memUrl.isEmpty) continue;

      final memFileName = 'memory_${i + 1}';
      final memFile = io.File('${memoriesDir.path}/$memFileName.jpg');

      try {
        final response = await http
            .get(Uri.parse(memUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          await memFile.writeAsBytes(response.bodyBytes);
        }
      } catch (_) {
        // Skip failed downloads
      }

      final progress = 0.2 + (0.7 * (i + 1) / totalMemories);
      onProgress?.call(
        progress.clamp(0.2, 0.9),
        'Đang tải ${i + 1}/$totalMemories ảnh...',
      );
    }

    // 5. Write memories metadata
    final metaFile = io.File('${exportDir.path}/memories/metadata.json');
    final metadataList = memoriesList.map((m) {
      final ts = m['ts'] as int?;
      return <String, dynamic>{
        'id': m['id'],
        'author': m['author'] ?? '',
        'ts': ts,
        'date': ts != null
            ? DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(ts))
            : '',
      };
    }).toList();
    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadataList),
    );

    // 6. Create ZIP archive
    onProgress?.call(0.92, 'Đang nén ZIP...');
    final archive = Archive();
    await _addDirectoryToArchive(archive, exportDir, '');

    // Encode to ZIP bytes
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    final filename = _buildExportFilename(
      prefix: 'SoulLocket_All',
      houseName: resolvedHouseName,
      extension: 'zip',
    );

    if (kIsWeb) {
      downloadWebFile(filename, zipData, 'application/zip');
      onProgress?.call(1.0, 'Hoàn tất!');
      return '';
    }

    // Lưu vào thư mục exports lâu dài
    final exportDirPerm = await _getExportDir();
    final zipFile = io.File('${exportDirPerm.path}/$filename');
    await zipFile.writeAsBytes(zipData);

    // Cleanup temp export dir
    try {
      await exportDir.delete(recursive: true);
    } catch (_) {}

    onProgress?.call(1.0, 'Hoàn tất!');
    return zipFile.path;
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    io.Directory dir,
    String basePath,
  ) async {
    await for (final entity in dir.list()) {
      if (entity is io.File) {
        final bytes = await entity.readAsBytes();
        final relativePath = '$basePath${p.basename(entity.path)}';
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      } else if (entity is io.Directory) {
        await _addDirectoryToArchive(
          archive,
          entity,
          '$basePath${p.basename(entity.path)}/',
        );
      }
    }
  }
}
