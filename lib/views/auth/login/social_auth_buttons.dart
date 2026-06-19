import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialAuthButtons extends StatelessWidget {
  final ValueChanged<String> onProviderTap;

  const SocialAuthButtons({
    super.key,
    required this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final providers = <_SocialProviderData>[
      const _SocialProviderData(
        providerId: 'Google',
        caption: 'Google',
        iconKind: _SocialIconKind.google,
      ),
      if (!isAndroid)
        const _SocialProviderData(
          providerId: 'Apple',
          caption: 'Apple',
          iconKind: _SocialIconKind.apple,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        final isCompact = availableWidth < 360;
        final buttonSize = isCompact ? 52.0 : 58.0;
        final spacing = isCompact ? 8.0 : 14.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < providers.length; index++) ...[
              _SocialAuthTile(
                provider: providers[index],
                size: buttonSize,
                compact: isCompact,
                onTap: () => onProviderTap(providers[index].providerId),
              ),
              if (index != providers.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}

class _SocialAuthTile extends StatelessWidget {
  final _SocialProviderData provider;
  final VoidCallback onTap;
  final double size;
  final bool compact;

  const _SocialAuthTile({
    required this.provider,
    required this.onTap,
    required this.size,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tileRadius = compact ? 16.0 : 18.0;
    final surfaceRadius = compact ? 18.0 : 20.0;
    final labelStyle = TextStyle(
      color: const Color(0xFF7A7483),
      fontSize: compact ? 10.0 : 11.0,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
    );
    return Semantics(
      button: true,
      label: provider.providerId,
      child: Tooltip(
        message: provider.providerId,
        child: SizedBox(
          width: compact ? 74.0 : 86.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(tileRadius),
                    onTap: onTap,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF0F5).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(surfaceRadius),
                          border: Border.all(
                            color: const Color(0xFFFFFFFF).withValues(alpha: 0.65),
                            width: 1,
                          ),
                        ),
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: Center(
                            child: ExcludeSemantics(
                              child: _buildIcon(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 6.0 : 8.0),
              Text(
                provider.caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final iconSize = compact ? 29.0 : 32.0;
    switch (provider.iconKind) {
      case _SocialIconKind.google:
        return SvgPicture.string(
          _googleLogo,
          width: iconSize + 1.5,
          height: iconSize + 1.5,
        );
      case _SocialIconKind.facebook:
        return SvgPicture.string(
          _facebookLogo,
          width: iconSize,
          height: iconSize,
        );
      case _SocialIconKind.apple:
        return SvgPicture.string(
          _appleLogo,
          width: iconSize,
          height: iconSize,
        );
    }
  }
}

enum _SocialIconKind {
  google,
  facebook,
  apple,
}

class _SocialProviderData {
  final String providerId;
  final String caption;
  final _SocialIconKind iconKind;

  const _SocialProviderData({
    required this.providerId,
    required this.caption,
    required this.iconKind,
  });
}

const String _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#FFC107" d="M43.61 20.08H42V20H24v8h11.3C33.65 32.66 29.19 36 24 36c-6.63 0-12-5.37-12-12s5.37-12 12-12c3.06 0 5.84 1.15 7.96 3.04l5.66-5.66C34.05 6.05 29.27 4 24 4 12.95 4 4 12.95 4 24s8.95 20 20 20 20-8.95 20-20c0-1.34-.14-2.65-.39-3.92z"/>
  <path fill="#FF3D00" d="M6.31 14.69l6.57 4.82C14.66 15.11 18.96 12 24 12c3.06 0 5.84 1.15 7.96 3.04l5.66-5.66C34.05 6.05 29.27 4 24 4 16.32 4 9.66 8.34 6.31 14.69z"/>
  <path fill="#4CAF50" d="M24 44c5.09 0 9.79-1.95 13.36-5.12l-6.18-5.23C29.1 35.1 26.64 36 24 36c-5.17 0-9.62-3.32-11.28-7.94l-6.52 5.02C9.51 39.56 16.21 44 24 44z"/>
  <path fill="#1976D2" d="M43.61 20.08H42V20H24v8h11.3c-.8 2.28-2.27 4.24-4.12 5.65l.01-.01 6.18 5.23C36.93 39.19 44 34 44 24c0-1.34-.14-2.65-.39-3.92z"/>
</svg>
''';

const String _facebookLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#1877F2" d="M24 12.073C24 5.405 18.627 0 12 0S0 5.405 0 12.073C0 18.099 4.388 23.094 10.125 24v-8.438H7.078v-3.49h3.047V9.413c0-3.022 1.792-4.693 4.533-4.693 1.313 0 2.686.235 2.686.235v2.97h-1.514c-1.491 0-1.956.931-1.956 1.887v2.26h3.328l-.532 3.49h-2.796V24C19.612 23.094 24 18.099 24 12.073z"/>
</svg>
''';

const String _appleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#111111" d="M7.078 23.55c-.473-.316-.893-.703-1.244-1.15-.383-.463-.738-.95-1.064-1.454-.766-1.12-1.365-2.345-1.78-3.636-.5-1.502-.743-2.94-.743-4.347 0-1.57.34-2.94 1.002-4.09.49-.9 1.22-1.653 2.1-2.182.85-.53 1.84-.82 2.84-.84.35 0 .73.05 1.13.15.29.08.64.21 1.07.37.55.21.85.34.95.37.32.12.59.17.8.17.16 0 .39-.05.645-.13.145-.05.42-.14.81-.31.386-.14.692-.26.935-.35.37-.11.728-.21 1.05-.26.39-.06.777-.08 1.148-.05.71.05 1.36.2 1.94.42 1.02.41 1.843 1.05 2.457 1.96-.26.16-.5.346-.725.55-.487.43-.9.94-1.23 1.505-.43.77-.65 1.64-.644 2.52.015 1.083.29 2.035.84 2.86.387.6.904 1.114 1.534 1.536.31.21.582.355.84.45-.12.375-.252.74-.405 1.1-.347.807-.76 1.58-1.25 2.31-.432.63-.772 1.1-1.03 1.41-.402.48-.79.84-1.18 1.097-.43.285-.935.436-1.452.436-.35.015-.7-.03-1.034-.127-.29-.095-.576-.202-.856-.323-.293-.134-.596-.248-.905-.34-.38-.1-.77-.148-1.164-.147-.4 0-.79.05-1.16.145-.31.088-.61.196-.907.325-.42.175-.695.29-.855.34-.324.096-.656.154-.99.175-.52 0-1.004-.15-1.486-.45zm6.854-18.46c-.68.34-1.326.484-1.973.436-.1-.646 0-1.31.27-2.037.24-.62.56-1.18 1-1.68.46-.52 1.01-.95 1.63-1.26.66-.34 1.29-.52 1.89-.55.08.68 0 1.35-.25 2.07-.228.64-.568 1.23-1 1.76-.435.52-.975.95-1.586 1.26z"/>
</svg>
''';
