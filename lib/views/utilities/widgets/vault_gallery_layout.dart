import 'package:flutter/material.dart';

/// Header và gallery cuộn cùng nhau; lưới vẫn dựng ảnh theo nhu cầu.
class VaultGalleryLayout extends StatelessWidget {
  const VaultGalleryLayout({
    super.key,
    required this.header,
    required this.gallerySlivers,
  });
  final Widget header;
  final List<Widget> gallerySlivers;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: header),
      ...gallerySlivers,
    ],
  );
}
