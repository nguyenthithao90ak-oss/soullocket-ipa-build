import 'package:flutter/material.dart';
import '../../core/sl_theme.dart';

class StickerLibraryScreen extends StatelessWidget {

  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF24324A), size: 22),
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
              Text('- Nơi quản lý và thêm các bộ nhãn dán độc quyền dùng để ném vào người ấy trên màn hình chính.\n- Mở khóa nhãn dán hiếm thông qua vòng quay hoặc điểm tình yêu.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Duyệt qua các bộ nhãn dán, bấm Tải về để thêm vào bộ sưu tập.\n- Tại màn hình chính, mở ngăn kéo nhãn dán và ném chúng để tạo hiệu ứng tương tác.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: SLColors.primary)),
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
    'assets/images/interaction_stickers/custom/numbered/sticker_005.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_006.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_007.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_008.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_009.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_010.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_011.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_012.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_013.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_014.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_015.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_016.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_017.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_018.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_019.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_020.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_021.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_022.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_023.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_024.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_025.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_026.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_027.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_028.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_029.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_030.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_031.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_032.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_033.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_034.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_035.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_036.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_037.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_038.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_039.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_040.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_041.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_042.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_043.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_044.png',
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
    'assets/images/interaction_stickers/custom/numbered/sticker_061.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_062.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_063.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_064.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_065.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_066.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_067.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_068.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_069.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_070.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_071.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_072.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_073.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_074.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_075.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_076.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_077.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_078.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_079.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_080.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_081.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_082.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_083.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_084.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_085.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_086.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_087.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_088.png',
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
    'assets/images/interaction_stickers/custom/numbered/sticker_109.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_110.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_111.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_112.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_113.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_114.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_115.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_116.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_117.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_118.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_119.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_120.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_121.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_122.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_123.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_124.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_125.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_126.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_127.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_128.png',
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
    'assets/images/sticker_import/cutout/sheet_02/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_02/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_09.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_10.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_11.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_12.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_13.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_14.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_15.png',
    'assets/images/sticker_import/cutout/sheet_03/sticker_16.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_01.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_02.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_03.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_04.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_05.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_06.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_07.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_08.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_09.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_10.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_11.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_12.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_13.png',
    'assets/images/sticker_import/cutout/sheet_04/sticker_14.png',
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
                'Sticker ${index + 1}',
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
      child: Image.asset(
        assetPath,
        fit: fit,
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
          ),
        ),
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
