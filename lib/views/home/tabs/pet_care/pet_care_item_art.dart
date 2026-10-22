import 'package:flutter/material.dart';

/// Atlas đồ vẽ không chia ô đều; mỗi món có vùng cắt riêng để không lộ món bên cạnh.
class PetCareItemArt extends StatelessWidget {
  const PetCareItemArt({required this.index, this.size = 64, super.key});

  final int index;
  final double size;

  static const _regions = [
    Rect.fromLTRB(0, 205, 320, 615),
    Rect.fromLTRB(326, 270, 608, 610),
    Rect.fromLTRB(606, 205, 938, 615),
    Rect.fromLTRB(938, 260, 1254, 615),
    Rect.fromLTRB(15, 625, 291, 1045),
    Rect.fromLTRB(307, 672, 595, 1045),
    Rect.fromLTRB(603, 686, 964, 1045),
    Rect.fromLTRB(975, 700, 1254, 1045),
  ];

  @override
  Widget build(BuildContext context) {
    final item = index.clamp(0, 7);
    final region = _regions[item];
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: region.width,
            height: region.height,
            child: ClipPath(
              clipper: _ItemClipper(item),
              child: Stack(
                children: [
                  Positioned(
                    left: -region.left,
                    top: -region.top,
                    width: 1254,
                    height: 1254,
                    child: Image.asset(
                      'assets/images/pet_care/pet_care_items.png',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemClipper extends CustomClipper<Path> {
  const _ItemClipper(this.index);
  final int index;

  @override
  Path getClip(Size size) {
    if (index == 1) {
      // Lá cà rốt vươn sang góc trái ô táo trong atlas.
      return Path()
        ..moveTo(size.width * .2, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height * .42)
        ..lineTo(size.width * .16, size.height * .24)
        ..close();
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(_ItemClipper oldClipper) => oldClipper.index != index;
}
