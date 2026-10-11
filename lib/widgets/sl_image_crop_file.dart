import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'sl_feedback.dart';

import 'sl_image_crop_editor.dart';

/// Caller sở hữu tệp đã xác nhận, để luồng upload giữ được tệp khi cần retry.
/// Hủy/chỉnh lại chỉ dùng RAM; không tạo tệp hoặc phiên upload.
Future<XFile?> cropAndConfirmImage({
  required BuildContext context,
  required XFile image,
  required double aspectRatio,
  required String titleKey,
  required bool Function() isScopeCurrent,
  bool circular = false,
  Size maxOutputSize = const Size(1440, 2560),
}) async {
  File? outputFile;
  try {
    final bytes = await showSLImageCropEditor(
      context: context,
      image: image,
      aspectRatio: aspectRatio,
      titleKey: titleKey,
      circular: circular,
      maxOutputSize: maxOutputSize,
      isScopeCurrent: isScopeCurrent,
    );
    if (bytes == null || !context.mounted || !isScopeCurrent()) return null;
    if (kIsWeb) {
      return XFile.fromData(
        bytes,
        name: 'soullocket_crop.png',
        mimeType: 'image/png',
      );
    }
    final directory = await getTemporaryDirectory();
    if (!context.mounted || !isScopeCurrent()) return null;
    outputFile = File(
      path.join(
        directory.path,
        'soullocket_crop_${DateTime.now().microsecondsSinceEpoch}.png',
      ),
    );
    await outputFile.writeAsBytes(bytes);
    if (!context.mounted || !isScopeCurrent()) {
      await outputFile.delete();
      return null;
    }
    return XFile(outputFile.path, mimeType: 'image/png');
  } catch (_) {
    if (outputFile != null) {
      try {
        await outputFile.delete();
      } catch (_) {
        debugPrint('[ImageCrop] Tệp tạm chờ hệ điều hành dọn.');
      }
    }
    if (context.mounted && isScopeCurrent()) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SLSnackBar(content: Text(context.tr('core_image_load_failed'))),
      );
    }
    // Không dùng ảnh gốc để upload khi người dùng chưa xác nhận ảnh cắt.
    return null;
  }
}

/// Chỉ dọn PNG do editor tạo trong cache app; giữ nguyên ảnh nguồn của picker.
/// Caller chỉ gọi sau commit thành công để tệp pending vẫn dùng được khi retry.
Future<void> discardConfirmedCropImage(XFile? image) async {
  if (kIsWeb || image == null) return;
  if (!RegExp(
    r'^soullocket_crop_[0-9]+\.png$',
  ).hasMatch(path.basename(image.path))) {
    return;
  }
  try {
    final directory = await getTemporaryDirectory();
    final file = File(image.path).absolute;
    if (!path.equals(file.parent.path, directory.absolute.path)) return;
    if (await file.exists()) await file.delete();
  } catch (_) {
    debugPrint('[ImageCrop] Hệ điều hành sẽ dọn tệp cache còn lại.');
  }
}
