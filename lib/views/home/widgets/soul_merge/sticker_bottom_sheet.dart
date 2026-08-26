import 'package:flutter/material.dart';

class StickerBottomSheet extends StatelessWidget {
  final ValueChanged<String> onStickerSelected;

  const StickerBottomSheet({
    super.key,
    required this.onStickerSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onStickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerBottomSheet(
        onStickerSelected: onStickerSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validStickers = [
      for (int i = 1; i <= 35; i++)
        if (![4, 5, 10, 11, 19, 26, 29].contains(i)) i
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gửi Nhãn Dán',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: validStickers.length,
              itemBuilder: (context, index) {
                final stickerPath =
                    'assets/images/anhtomau_stickers/sticker_${validStickers[index]}.gif';
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onStickerSelected(stickerPath);
                  },
                  child: Image.asset(stickerPath),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
