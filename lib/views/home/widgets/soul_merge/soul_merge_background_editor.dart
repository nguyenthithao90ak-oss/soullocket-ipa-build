import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soullocket_app/widgets/sl_image_crop_editor.dart';

export 'package:soullocket_app/widgets/sl_image_crop_editor.dart'
    show SLImageCropEditor, SLImageCropEditorState;

// Giữ API đã có cho caller và kiểm thử nền Soul Merge.
typedef SoulMergeBackgroundEditor = SLImageCropEditor;
typedef SoulMergeBackgroundEditorState = SLImageCropEditorState;

Future<Uint8List?> showSoulMergeBackgroundEditor({
  required BuildContext context,
  required XFile image,
  required Size backgroundSize,
  required bool Function() isScopeCurrent,
}) => showSLImageCropEditor(
  context: context,
  image: image,
  aspectRatio: backgroundSize.aspectRatio,
  isScopeCurrent: isScopeCurrent,
  cropHintKey: 'soul_background_crop_hint',
  confirmHintKey: 'soul_background_preview_hint',
  previewDimAlpha: .18,
  previewTintAlpha: .08,
);
