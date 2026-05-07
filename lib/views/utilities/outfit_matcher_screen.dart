import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';

// ============================================================
// PHASE 33: OUTFIT MATCHER — GRA FULLSTACK
// Backend Service + UI Screen cùng 1 file
// ============================================================

class OutfitMatcherService {
  static final OutfitMatcherService _i = OutfitMatcherService._();
  factory OutfitMatcherService() => _i;
  OutfitMatcherService._();

  final _db = FirebaseDatabase.instance;

  Future<void> saveOutfit(
      String houseId, String uid, Map<String, int> outfit) async {
    // outfit = { 'top': 0xFFFF5733, 'bottom': 0xFF333333, 'shoes': 0xFFFFFFFF }
    await _db.ref('houses/$houseId/outfits/$uid').set({
      ...outfit,
      'ts': ServerValue.timestamp,
    });
  }

  Stream<Map<dynamic, dynamic>?> listenToCoupleOutfits(String houseId) {
    return _db.ref('houses/$houseId/outfits').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return null;
      return Map<dynamic, dynamic>.from(raw);
    });
  }

  /// Gợi ý màu đồng điệu đơn giản
  Color suggestMatchingColor(Color myColor) {
    // Complementary color trick
    return Color.fromARGB(
      255,
      255 - (myColor.r * 255.0).round().clamp(0, 255),
      255 - (myColor.g * 255.0).round().clamp(0, 255),
      255 - (myColor.b * 255.0).round().clamp(0, 255),
    );
  }
}

class OutfitMatcherScreen extends StatefulWidget {
  final String houseId;
  final String myUid;
  const OutfitMatcherScreen(
      {super.key, required this.houseId, required this.myUid});

  @override
  State<OutfitMatcherScreen> createState() => _OutfitMatcherScreenState();
}

class _OutfitMatcherScreenState extends State<OutfitMatcherScreen> {
  final _svc = OutfitMatcherService();
  Color _topColor = Colors.red;
  Color _bottomColor = Colors.blue;
  Color _shoesColor = Colors.white;

  final List<Color> _palette = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.yellow,
    Colors.orange,
    Colors.brown,
    Colors.grey,
    Colors.black,
    Colors.white,
  ];

  Widget _colorPicker(
      String label, Color current, ValueChanged<Color> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: SLTheme.quicksand(
                color: Colors.white70, fontWeight: FontWeight.w700)),
        SLSpacing.h8,
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _palette.length,
            itemBuilder: (ctx, i) {
              final c = _palette[i];
              final selected = c.toARGB32() == current.toARGB32();
              return GestureDetector(
                onTap: () => onSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  width: selected ? 44 : 36,
                  height: selected ? 44 : 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: c.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2)
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: SLSpacing.all24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white)),
                  Text('Tủ Đồ Cặp Đôi 👗',
                      style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22)),
                ]),
                SLSpacing.gapH(30),
                // Preview nhân vật
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 240,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(colors: [
                            Colors.white12,
                            Colors.white.withValues(alpha: 0.05)
                          ]),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Đầu
                              const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.amber,
                                  child: Text('😊',
                                      style: TextStyle(fontSize: 28))),
                              SLSpacing.h8,
                              // Áo
                              Container(
                                  width: 80,
                                  height: 50,
                                  decoration: BoxDecoration(
                                      color: _topColor,
                                      borderRadius: SLRadius.smAll)),
                              // Quần
                              Container(
                                  width: 80,
                                  height: 60,
                                  decoration: BoxDecoration(
                                      color: _bottomColor,
                                      borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(6),
                                          bottomRight: Radius.circular(6)))),
                              SLSpacing.h4,
                              // Giày
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                        width: 30,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: _shoesColor,
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                    SLSpacing.w8,
                                    Container(
                                        width: 30,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: _shoesColor,
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                  ]),
                            ]),
                      ),
                    ],
                  ),
                ),
                SLSpacing.gapH(30),
                _colorPicker(
                    '🧥 Áo', _topColor, (c) => setState(() => _topColor = c)),
                SLSpacing.h20,
                _colorPicker('👖 Quần', _bottomColor,
                    (c) => setState(() => _bottomColor = c)),
                SLSpacing.h20,
                _colorPicker('👟 Giày', _shoesColor,
                    (c) => setState(() => _shoesColor = c)),
                SLSpacing.gapH(30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      await _svc.saveOutfit(widget.houseId, widget.myUid, {
                        'top': _topColor.toARGB32(),
                        'bottom': _bottomColor.toARGB32(),
                        'shoes': _shoesColor.toARGB32(),
                      });
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(const SnackBar(
                          content:
                              Text('💪 Outfit đã lưu! Crush nhìn thấy rồi!')));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.pinkAccent,
                      shape:
                          RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                    ),
                    child: Text('LƯU OUTFIT HÔM NAY',
                        style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
