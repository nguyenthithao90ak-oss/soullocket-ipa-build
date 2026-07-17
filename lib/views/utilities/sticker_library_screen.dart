import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import '../../core/sl_theme.dart';

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
    'assets/images/interaction_stickers/custom/numbered/sticker_001.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_002.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_003.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_004.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_045.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_046.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_047.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_048.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_049.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_050.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_051.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_052.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_053.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_054.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_055.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_056.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_057.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_058.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_059.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_060.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_089.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_090.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_091.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_092.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_093.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_094.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_095.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_096.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_097.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_099.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_100.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_101.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_102.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_103.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_104.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_105.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_106.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_107.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_108.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_129.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_130.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_131.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_132.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_133.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_134.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_135.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_136.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_137.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_138.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_139.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_140.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_141.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_142.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_143.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_144.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_145.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_146.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_147.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_148.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_149.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_150.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_151.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_152.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_153.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_154.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_155.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_156.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_157.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_158.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_159.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_160.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_161.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_162.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_163.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_164.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_165.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_166.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_167.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_168.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_169.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_170.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_171.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_172.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_173.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_174.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_175.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_176.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_177.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_178.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_180.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_181.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_182.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_183.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_185.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_186.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_188.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_190.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_191.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_192.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_193.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_195.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_196.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_199.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_210.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_215.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_216.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_217.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_218.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_219.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_220.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_221.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_222.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_223.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_224.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_225.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_226.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_227.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_228.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_229.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_230.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_231.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_232.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_233.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_234.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_235.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_236.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_237.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_238.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_239.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_240.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_241.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_242.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_243.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_244.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_245.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_246.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_247.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_248.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_249.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_250.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_251.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_252.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_253.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_254.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_255.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_256.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_257.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_258.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_260.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_261.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_262.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_263.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_264.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_265.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_267.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_268.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_269.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_270.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_271.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_272.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_273.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_274.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_275.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_276.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_277.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_278.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_279.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_280.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_281.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_282.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_283.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_284.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_285.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_286.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_287.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_288.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_289.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_290.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_291.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_292.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_293.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_294.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_295.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_296.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_297.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_298.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_299.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_300.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_301.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_302.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_303.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_304.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_305.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_306.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_307.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_308.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_309.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_310.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_311.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_312.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_313.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_315.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_316.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_318.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_319.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_320.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_321.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_322.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_323.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_324.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_325.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_326.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_327.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_328.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_329.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_330.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_331.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_332.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_333.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_334.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_335.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_336.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_337.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_338.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_339.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_340.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_341.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_342.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_343.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_344.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_345.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_346.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_348.png',
    'assets/images/sticker_import/cutout/sheet_01/_preview_check.png',
    'assets/images/sticker_import/cutout/sheet_01/_preview_zoom_dark.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_01/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_09.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_09.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_10.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_10.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_11.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_11.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_12.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_12.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_13.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_13.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_14.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_14.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_15.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_16.png',
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
        actions: [_buildInfoIcon(context)],
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
