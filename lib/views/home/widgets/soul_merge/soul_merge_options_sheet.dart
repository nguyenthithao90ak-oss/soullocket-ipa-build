import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

enum SoulMergeOption { avatar, background, removeBackground, overlay, heartStyle }

class SoulMergeOptionsSheet extends StatelessWidget {
  const SoulMergeOptionsSheet({
    super.key,
    this.hasAvatar = false,
    required this.hasBackground,
    required this.overlayEnabled,
    this.isUploadingBackground = false,
    this.isUploadingAsset = false,
  });

  final bool hasAvatar;
  final bool hasBackground;
  final bool overlayEnabled;
  final bool isUploadingBackground;
  final bool isUploadingAsset;

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      data: const ListTileThemeData(
        iconColor: Color(0xFFE9577D),
        textColor: Color(0xFF71354D),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7CDD5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('settings'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71354D),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: isUploadingAsset
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasAvatar
                            ? Icons.account_circle_rounded
                            : Icons.add_a_photo_rounded,
                      ),
                title: Text(context.tr('p5_profile_change_avatar')),
                enabled: !isUploadingAsset,
                onTap: () => Navigator.pop(context, SoulMergeOption.avatar),
              ),
              ListTile(
                leading: isUploadingAsset
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wallpaper_rounded),
                title: Text(context.tr('home_tinn_ca8199')),
                enabled: !isUploadingAsset,
                onTap: () => Navigator.pop(context, SoulMergeOption.background),
              ),
              if (hasBackground)
                ListTile(
                  leading: const Icon(Icons.hide_image_outlined),
                  title: Text(context.tr('theme_remove_bg')),
                  enabled: !isUploadingAsset,
                  onTap: () =>
                      Navigator.pop(context, SoulMergeOption.removeBackground),
                ),
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android)
                SwitchListTile(
                  secondary: const Icon(Icons.chat_bubble_outline_rounded),
                  title: Text(context.tr('p4_soul_overlay_title')),
                  value: overlayEnabled,
                  activeThumbColor: const Color(0xFFE9577D),
                  onChanged: (_) =>
                      Navigator.pop(context, SoulMergeOption.overlay),
                ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(context.tr('heart_style_title')),
                onTap: () => Navigator.pop(context, SoulMergeOption.heartStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
