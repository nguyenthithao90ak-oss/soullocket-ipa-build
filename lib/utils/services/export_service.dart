import 'dart:convert';
import 'dart:io' as io;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> exportDiary({
    required String houseId,
    required DiaryExportFormat format,
    String? houseName,
  }) async {
    final resolvedHouseName = houseName?.trim().isNotEmpty == true
        ? houseName!.trim()
        : await resolveDiaryHouseName(houseId);

    switch (format) {
      case DiaryExportFormat.pdf:
        await exportDiaryToPdf(houseId, resolvedHouseName);
        return;
      case DiaryExportFormat.html:
        await exportDiaryToHtml(houseId, resolvedHouseName);
        return;
    }
  }

  Future<void> exportDiaryToPdf(String houseId, String houseName) async {
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
      return;
    }

    final file = await _writeTempFile(
      filename: filename,
      bytes: bytes,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Xuất Nhật ký của $resolvedHouseName',
      ),
    );
  }

  Future<void> exportDiaryToHtml(String houseId, String houseName) async {
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
      return;
    }

    final file = await _writeTempFile(
      filename: filename,
      content: htmlContent,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Xuất HTML Nhật ký của $resolvedHouseName',
      ),
    );
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

  Future<io.File> _writeTempFile({
    required String filename,
    List<int>? bytes,
    String? content,
  }) async {
    final output = await getTemporaryDirectory();
    final file = io.File('${output.path}/$filename');
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    } else {
      await file.writeAsString(content ?? '');
    }
    return file;
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
}
