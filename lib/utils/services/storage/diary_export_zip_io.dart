import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Chỉ chuyển hai đường dẫn sang isolate, không sao chép toàn bộ media/ZIP qua RAM.
Future<void> encodeDiaryExportZip(String sourcePath, String outputPath) =>
    Isolate.run(() => _encode(sourcePath, outputPath));

void _encode(String sourcePath, String outputPath) {
  final output = OutputFileStream(outputPath);
  try {
    final encoder = ZipEncoder()..startEncode(output);
    for (final entity in Directory(
      sourcePath,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final input = InputFileStream(entity.path);
      try {
        final name = p
            .relative(entity.path, from: sourcePath)
            .replaceAll('\\', '/');
        encoder.add(ArchiveFile.stream(name, input));
      } finally {
        input.closeSync();
      }
    }
    encoder.endEncode();
  } finally {
    output.closeSync();
  }
}
