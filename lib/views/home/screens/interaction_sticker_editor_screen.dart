import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';

// sticker bắn
class InteractionStickerEditorScreen extends StatefulWidget {
  const InteractionStickerEditorScreen({super.key});

  @override
  State<InteractionStickerEditorScreen> createState() =>
      _InteractionStickerEditorScreenState();
}

class _InteractionStickerEditorScreenState
    extends State<InteractionStickerEditorScreen> {
  final List<Map<String, dynamic>> _activeSlots = [
    {
      'type': 'miss',
      'label': 'Yêu',
      'emoji': '💖',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_1.gif',
      'path': '',
      'gradient': [const Color(0xFFFFD8E6), const Color(0xFFFFF3F7)],
      'accent': const Color(0xFFD94C86),
    },
    {
      'type': 'angry',
      'label': 'Thích',
      'emoji': '😻',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_27.gif',
      'path': '',
      'gradient': [const Color(0xFFFFE6DC), const Color(0xFFFFF6F2)],
      'accent': const Color(0xFFE26A3A),
    },
    {
      'type': 'furious',
      'label': 'Cười',
      'emoji': '😆',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_3.gif',
      'path': '',
      'gradient': [const Color(0xFFFFD7DC), const Color(0xFFFFF1F3)],
      'accent': const Color(0xFFE53935),
    },
    {
      'type': 'kiss',
      'label': 'Hôn',
      'emoji': '💋',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_12.gif',
      'path': '',
      'gradient': [const Color(0xFFFFE1EC), const Color(0xFFFFF7FA)],
      'accent': const Color(0xFFE14A8B),
    },
    {
      'type': 'tease',
      'label': 'Trêu',
      'emoji': '🤡',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_13.gif',
      'path': '',
      'gradient': [const Color(0xFFE8E1FF), const Color(0xFFF8F5FF)],
      'accent': const Color(0xFF7B61D9),
    },
    {
      'type': 'hug',
      'label': 'Ôm',
      'emoji': '🐨',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_6.gif',
      'path': '',
      'gradient': [const Color(0xFFDDF3FF), const Color(0xFFF5FBFF)],
      'accent': const Color(0xFF2D8FE3),
    },
    {
      'type': 'cry',
      'label': 'Cute',
      'emoji': '🥰',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_7.gif',
      'path': '',
      'gradient': [const Color(0xFFDDEBFF), const Color(0xFFF4F8FF)],
      'accent': const Color(0xFF5B8DEF),
    },
    {
      'type': 'poop',
      'label': 'Quậy',
      'emoji': '🤪',
      'defaultPath': 'assets/images/anhtomau_stickers/sticker_8.gif',
      'path': '',
      'gradient': [const Color(0xFFFFE1B9), const Color(0xFFFFF4E6)],
      'accent': const Color(0xFFB96B2C),
    },
  ];

  static const List<String> _rawStickerLibrary = [
    'assets/images/anhtomau_stickers/sticker_1.gif',
    'assets/images/anhtomau_stickers/sticker_2.gif',
    'assets/images/anhtomau_stickers/sticker_3.gif',
    'assets/images/anhtomau_stickers/sticker_6.gif',
    'assets/images/anhtomau_stickers/sticker_7.gif',
    'assets/images/anhtomau_stickers/sticker_8.gif',
    'assets/images/anhtomau_stickers/sticker_9.gif',
    'assets/images/anhtomau_stickers/sticker_12.gif',
    'assets/images/anhtomau_stickers/sticker_13.gif',
    'assets/images/anhtomau_stickers/sticker_14.gif',
    'assets/images/anhtomau_stickers/sticker_15.gif',
    'assets/images/anhtomau_stickers/sticker_16.gif',
    'assets/images/anhtomau_stickers/sticker_17.gif',
    'assets/images/anhtomau_stickers/sticker_18.gif',
    'assets/images/anhtomau_stickers/sticker_20.gif',
    'assets/images/anhtomau_stickers/sticker_21.gif',
    'assets/images/anhtomau_stickers/sticker_22.gif',
    'assets/images/anhtomau_stickers/sticker_23.gif',
    'assets/images/anhtomau_stickers/sticker_24.gif',
    'assets/images/anhtomau_stickers/sticker_25.gif',
    'assets/images/anhtomau_stickers/sticker_27.gif',
    'assets/images/anhtomau_stickers/sticker_28.gif',
    'assets/images/anhtomau_stickers/sticker_30.gif',
    'assets/images/anhtomau_stickers/sticker_31.gif',
    'assets/images/anhtomau_stickers/sticker_32.gif',
    'assets/images/anhtomau_stickers/sticker_33.gif',
    'assets/images/anhtomau_stickers/sticker_34.gif',
    'assets/images/anhtomau_stickers/sticker_35.gif',
  ];

  late final List<String> _stickerPool;
  int _selectedActiveIndex = 0; // Default select first slot (Nhớ)
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Get 20 random stickers from the pool
    final random = Random();
    final tempPool = List<String>.from(_rawStickerLibrary);
    tempPool.shuffle(random);
    _stickerPool = tempPool.take(20).toList();

    _loadSavedStickers();
  }

  Future<void> _loadSavedStickers() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (var slot in _activeSlots) {
        final saved = prefs.getString('custom_sticker_${slot['type']}');
        slot['path'] = saved ?? slot['defaultPath'];
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var slot in _activeSlots) {
        await prefs.setString('custom_sticker_${slot['type']}', slot['path']);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lưu thay đổi thất bại, vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetToDefault(int index) {
    setState(() {
      _activeSlots[index]['path'] = _activeSlots[index]['defaultPath'];
    });
  }

  void _replaceSticker(String newPath) {
    setState(() {
      _activeSlots[_selectedActiveIndex]['path'] = newPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F8FF), // Xanh dương nhạt (Alice Blue)
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: SLColors.primary),
          title: Text(
            'Tùy chỉnh Sticker',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: SLColors.primary,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Instructions Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFCEE0).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: SLColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nhấn chọn 1 ô sticker hoạt động ở trên, sau đó chọn sticker bất kỳ ở dưới kho để thay thế nhé! 💕',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecond,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Slots Header
              Padding(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 12, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sticker Đang Sử Dụng (8 ô)',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Nhấn để chọn ô chỉnh sửa',
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SLColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Slots Grid (4x2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeSlots.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    final slot = _activeSlots[index];
                    final isSelected = _selectedActiveIndex == index;
                    final isCustomized = slot['path'] != slot['defaultPath'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedActiveIndex = index;
                        });
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Base container
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: slot['gradient'] as List<Color>,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? (slot['accent'] as Color)
                                    : const Color(0xFFF3E6EC),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: (slot['accent'] as Color)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 4),
                                Expanded(
                                  child: slot['path'].toString().isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Image.asset(
                                            slot['path'].toString(),
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : Text(
                                          slot['emoji'].toString(),
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                ),
                                Text(
                                  slot['label'].toString(),
                                  style: SLTheme.quicksand(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: SLColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),

                          // Reset (Minus) Badge if customized
                          if (isCustomized)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => _resetToDefault(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF5350),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Library Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kho Sticker Gợi Ý (20 ngẫu nhiên)',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sticker Pool Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    itemCount: _stickerPool.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final path = _stickerPool[index];
                      return GestureDetector(
                        onTap: () => _replaceSticker(path),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF3E6EC),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            children: [
                              Center(child: Image.asset(path)),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Reset All
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFFFB6D3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            for (var slot in _activeSlots) {
                              slot['path'] = slot['defaultPath'];
                            }
                          });
                        },
                        child: Text(
                          'Mặc định',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: SLColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SLColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveChanges,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Lưu thay đổi',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
