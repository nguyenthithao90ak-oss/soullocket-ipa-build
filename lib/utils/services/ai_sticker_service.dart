import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AiStickerService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<File?> createSticker(File inputImageFile, {int strokeWidth = 10, Color strokeColor = Colors.white}) async {
    final inputImage = InputImage.fromFile(inputImageFile);

    final options = SubjectSegmenterOptions(
      enableForegroundBitmap: false,
      enableForegroundConfidenceMask: true,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    );

    final segmenter = SubjectSegmenter(options: options);

    try {
      final result = await segmenter.processImage(inputImage);
      final mask = result.foregroundConfidenceMask;
      if (mask == null || mask.isEmpty) {
        return null; // Khong tim thay chu the
      }

      final originalImageBytes = await inputImageFile.readAsBytes();
      var originalImg = img.decodeImage(originalImageBytes);
      if (originalImg == null) return null;
      
      originalImg = img.bakeOrientation(originalImg);

      final width = originalImg.width;
      final height = originalImg.height;

      // 1. Tach nen
      final stickerImg = img.Image(width: width, height: height, numChannels: 4);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          int maskIndex = y * width + x;
          double confidence = 0.0;
          if (maskIndex < mask.length) {
            confidence = mask[maskIndex];
          }
          
          final pixel = originalImg.getPixel(x, y);
          
          if (confidence > 0.5) {
             stickerImg.setPixel(x, y, img.ColorRgba8(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255));
          } else {
             stickerImg.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }

      // 2. Tao vien (Stroke)
      if (strokeWidth > 0) {
        final strokedImg = img.Image.from(stickerImg);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            if (stickerImg.getPixel(x, y).a == 0) {
              bool isEdge = false;
              for (int dy = -strokeWidth; dy <= strokeWidth; dy++) {
                for (int dx = -strokeWidth; dx <= strokeWidth; dx++) {
                  if (dx * dx + dy * dy <= strokeWidth * strokeWidth) {
                    int nx = x + dx;
                    int ny = y + dy;
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                      if (stickerImg.getPixel(nx, ny).a > 0) {
                        isEdge = true;
                        break;
                      }
                    }
                  }
                }
                if (isEdge) break;
              }
              if (isEdge) {
                strokedImg.setPixel(x, y, img.ColorRgba8(strokeColor.r.toInt(), strokeColor.g.toInt(), strokeColor.b.toInt(), 255));
              }
            }
          }
        }
        
        // CROP
        int minX = width, minY = height, maxX = 0, maxY = 0;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            if (strokedImg.getPixel(x, y).a > 0) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        
        if (maxX >= minX && maxY >= minY) {
          final cropped = img.copyCrop(strokedImg, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
          final webpBytes = img.encodePng(cropped); 
          
          final dir = await getTemporaryDirectory();
          final tempFile = File('${dir.path}/sticker_${const Uuid().v4()}.png');
          await tempFile.writeAsBytes(webpBytes);
          return tempFile;
        }
      }

      return null;
    } catch (e) {
      debugPrint('ML Kit Error: $e');
      return null;
    } finally {
      segmenter.close();
    }
  }
}
