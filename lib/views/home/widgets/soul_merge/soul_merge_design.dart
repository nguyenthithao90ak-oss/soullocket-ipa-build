import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soul_merge_mark.dart';

/// Bảng màu của cuộc trò chuyện, thích ứng với theme của app.
class SoulMergeColors {
  SoulMergeColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF211D25) : const Color(0xFFFFF9F5);
  Color get surface => dark ? const Color(0xFF302935) : const Color(0xFFFFFEFC);
  Color get ink => dark ? const Color(0xFFF7EDEB) : const Color(0xFF49383D);
  Color get muted => dark ? const Color(0xFFC0ADB7) : const Color(0xFF927F85);
  Color get line => dark ? const Color(0xFF493B49) : const Color(0xFFF0E2DC);
  Color get rose => dark ? const Color(0xFFF599AA) : const Color(0xFFBA566E);
  Color get blush => dark ? const Color(0xFF44303C) : const Color(0xFFFCECEB);
  Color get sent => dark ? const Color(0xFF995166) : const Color(0xFFB95D73);
}

class SoulMergeHeader extends StatelessWidget {
  static double contentHeight(BuildContext context) {
    final text = MediaQuery.textScalerOf(context);
    return (text.scale(17) * 1.4 + text.scale(12) * 1.4 + 12).clamp(
      72.0,
      double.infinity,
    );
  }

  const SoulMergeHeader({
    super.key,
    required this.partnerName,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onOptions,
    this.onSearch,
    this.avatarUrl,
    this.onAvatarTap,
  });
  final String partnerName;
  final VoidCallback onBack;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final VoidCallback onOptions;
  final VoidCallback? onSearch;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: contentHeight(context),
          padding: const EdgeInsetsDirectional.only(start: 4, end: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: context.tr('p4_back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                color: colors.ink,
              ),
              if (MediaQuery.sizeOf(context).width >= 350) ...[
                _SoulMergeHeaderAvatar(url: avatarUrl, onTap: onAvatarTap),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('p4_soul_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.rose,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('p4_soul_voice_call'),
                onPressed: onVoiceCall,
                icon: const Icon(Icons.call_rounded, size: 21),
                style: IconButton.styleFrom(backgroundColor: colors.blush),
                color: colors.rose,
              ),
              IconButton(
                tooltip: context.tr('p4_soul_video_call'),
                onPressed: onVideoCall,
                icon: const Icon(Icons.videocam_rounded, size: 23),
                color: colors.rose,
              ),
              if (onSearch != null && MediaQuery.sizeOf(context).width >= 380)
                IconButton(
                  tooltip: context.tr('p4_soul_search_hint'),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded, size: 22),
                  color: colors.rose,
                ),
              IconButton(
                key: const ValueKey('soul-merge-options'),
                tooltip: context.tr('settings'),
                onPressed: onOptions,
                icon: const Icon(Icons.more_horiz_rounded, size: 23),
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoulMergeHeaderAvatar extends StatelessWidget {
  const _SoulMergeHeaderAvatar({required this.url, this.onTap});

  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim() ?? '';
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: normalized.startsWith('https://')
          ? Image.network(
              normalized,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SoulMergeMark(size: 38),
            )
          : const SoulMergeMark(size: 38),
    );
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: context.tr('p5_profile_change_avatar'),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}
