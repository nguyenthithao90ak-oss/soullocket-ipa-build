// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../main_home_tab.dart';

extension _MainHomeMapCardExt on _MainHomeTabState {
  Widget _buildMapPreviewMarker(
    String emoji,
    Color color, {
    String? avatarUrl,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasAvatar
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    maxWidthDiskCache: 64,
                    maxHeightDiskCache: 64,
                    memCacheWidth: 128,
                    memCacheHeight: 128,
                    errorWidget: (context, url, error) =>
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                  )
                : Text(emoji, style: const TextStyle(fontSize: 12)),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
