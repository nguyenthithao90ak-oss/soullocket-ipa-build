import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/services/ai_sticker_service.dart';
import '../../core/sl_theme.dart';

class StickerMakerScreen extends StatefulWidget {
  const StickerMakerScreen({super.key});

  @override
  State<StickerMakerScreen> createState() => _StickerMakerScreenState();
}

class _StickerMakerScreenState extends State<StickerMakerScreen> {
  final AiStickerService _aiService = AiStickerService();
  File? _originalImage;
  File? _resultSticker;
  bool _isProcessing = false;

  Future<void> _pickAndProcess() async {
    final image = await _aiService.pickImage();
    if (image == null) return;

    setState(() {
      _originalImage = image;
      _resultSticker = null;
      _isProcessing = true;
    });

    final sticker = await _aiService.createSticker(image);

    setState(() {
      _resultSticker = sticker;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text('Tạo Sticker AI ✂️', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context, _resultSticker),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_originalImage == null)
              GestureDetector(
                onTap: _pickAndProcess,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.white),
                      SizedBox(height: 12),
                      Text('Chọn ảnh để tạo Sticker', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              )
            else if (_isProcessing)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF5C9E)),
                  SizedBox(height: 20),
                  Text('AI đang tách nền và tạo viền...', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              )
            else if (_resultSticker != null)
              Column(
                children: [
                  const Text('✨ Sticker của bạn ✨', style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 20),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background pattern de nhin thay nen trong suot
                        const GridPaper(color: Colors.white12, divisions: 1, subdivisions: 2),
                        Image.file(_resultSticker!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickAndProcess,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, _resultSticker);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C9E),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
                        label: const Text('Lưu Sticker', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              )
            else
              const Text('Không tìm thấy chủ thể nào!', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
