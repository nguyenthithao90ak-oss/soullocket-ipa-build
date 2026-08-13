import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import '../../core/sl_theme.dart';
import 'sticker_maker_screen.dart';
import 'dart:io';

class StickerLibraryScreen extends StatelessWidget {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(Icons.info_outline_rounded,
          color: Color(0xFF24324A), size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Thư viện nhãn dán',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Nơi quản lý và thêm các bộ nhãn dán độc quyền dùng để ném vào người ấy trên màn hình chính.\n- Mở khóa nhãn dán hiếm thông qua vòng quay hoặc điểm tình yêu.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Duyệt qua các bộ nhãn dán, bấm Tải về để thêm vào bộ sưu tập.\n- Tại màn hình chính, mở ngăn kéo nhãn dán và ném chúng để tạo hiệu ứng tương tác.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  const StickerLibraryScreen({super.key});

  static const List<String> _stickers = <String>[
    'assets/images/interaction_stickers/custom/numbered/sticker_001.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_002.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_003.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_004.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_045.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_046.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_047.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_048.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_049.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_050.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_051.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_052.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_053.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_054.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_055.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_056.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_057.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_058.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_059.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_060.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_089.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_090.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_091.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_092.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_093.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_094.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_095.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_096.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_097.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_098.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_099.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_100.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_101.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_102.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_103.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_104.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_105.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_106.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_107.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_108.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_129.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_130.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_131.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_132.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_133.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_134.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_135.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_136.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_137.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_138.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_139.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_140.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_141.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_142.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_143.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_144.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_145.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_146.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_147.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_148.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_149.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_150.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_151.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_152.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_153.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_154.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_155.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_156.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_157.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_158.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_159.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_160.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_161.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_162.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_163.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_164.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_165.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_166.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_167.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_168.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_169.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_170.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_171.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_172.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_173.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_174.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_175.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_176.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_177.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_178.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_180.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_181.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_182.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_183.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_185.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_186.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_188.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_190.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_191.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_192.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_193.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_195.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_196.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_199.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_210.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_215.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_216.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_217.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_218.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_219.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_220.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_221.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_222.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_223.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_224.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_225.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_226.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_227.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_228.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_229.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_230.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_231.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_232.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_233.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_234.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_235.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_236.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_237.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_238.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_239.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_240.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_241.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_242.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_243.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_244.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_245.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_246.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_247.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_248.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_249.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_250.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_251.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_252.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_253.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_254.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_255.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_256.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_257.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_258.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_260.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_261.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_262.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_263.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_264.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_265.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_267.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_268.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_269.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_270.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_271.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_272.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_273.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_274.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_275.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_276.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_277.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_278.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_279.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_280.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_281.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_282.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_283.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_284.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_285.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_286.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_287.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_288.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_289.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_290.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_291.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_292.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_293.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_294.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_295.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_296.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_297.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_298.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_299.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_300.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_301.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_302.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_303.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_304.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_305.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_306.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_307.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_308.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_309.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_310.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_311.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_312.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_313.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_315.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_316.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_318.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_319.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_320.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_321.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_322.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_323.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_324.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_325.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_326.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_327.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_328.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_329.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_330.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_331.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_332.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_333.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_334.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_335.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_336.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_337.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_338.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_339.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_340.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_341.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_342.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_343.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_344.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_345.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_346.webp',
    'assets/images/interaction_stickers/custom/numbered/sticker_348.webp',
    'assets/images/sticker_import/cutout/sheet_01/_preview_check.webp',
    'assets/images/sticker_import/cutout/sheet_01/_preview_zoom_dark.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_01.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_01.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_01.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_01.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_02.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_02.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_02.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_02.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_03.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_03.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_03.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_03.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_04.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_04.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_04.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_04.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_05.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_05.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_05.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_05.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_06.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_06.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_06.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_06.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_07.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_07.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_07.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_07.webp',
    'assets/images/sticker_import/cutout/sheet_01/sticker_08.webp',
    'assets/images/sticker_import/cutout/sheet_02/sticker_08.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_08.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_08.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_09.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_09.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_10.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_10.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_11.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_11.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_12.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_12.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_13.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_13.webp',
    'assets/images/sticker_import/cutout/sheet_04/sticker_14.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_14.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_15.webp',
    'assets/images/sticker_import/cutout/sheet_03/sticker_16.webp',
  ];

  static const int previewStickerLimit = 30;

  static List<String> get stickers => List<String>.unmodifiable(_stickers);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF24324A),
        title: Text(
          'Kho sticker',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF24324A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cut_rounded, color: Color(0xFF24324A)),
            tooltip: 'Tạo Sticker AI',
            onPressed: () async {
              final File? result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StickerMakerScreen()),
              );
              if (result != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã lưu Sticker AI thành công!')),
                  );
                }
              }
            },
          ),
          _buildInfoIcon(context),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                ),
                child: Text(
                  'Đã nạp ${_stickers.length} sticker local từ bộ tương tác và các sheet cutout. Không lấy ảnh preview.',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5D6B82),
                    height: 1.45,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: _stickers.length,
                itemBuilder: (context, index) {
                  final assetPath = _stickers[index];
                  return _StickerLibraryTile(
                    assetPath: assetPath,
                    index: index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerLibraryTile extends StatelessWidget {
  const _StickerLibraryTile({
    required this.assetPath,
    required this.index,
  });

  final String assetPath;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _StickerPreviewScreen(assetPath: assetPath),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFD),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE3E5E8),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _StickerArt(
                    assetPath: assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(
                _getStickerLabel(assetPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5A6780),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStickerLabel(String path) {
    final filename = path.split('/').last.split('.').first;
    final numberMatch = RegExp(r'\d+').firstMatch(filename);
    if (numberMatch != null) {
      return 'Sticker ${numberMatch.group(0)}';
    }
    return filename;
  }
}

class _StickerArt extends StatelessWidget {
  const _StickerArt({
    required this.assetPath,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: R2StickerImage(
        assetPath,
        fit: fit,
      ),
    );
  }
}

class _StickerPreviewScreen extends StatelessWidget {
  const _StickerPreviewScreen({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: -10,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.78,
                height: MediaQuery.sizeOf(context).width * 0.78,
                child: _StickerArt(
                  assetPath: assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
