import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_visual_style.dart';

class AuroraSocialButtons extends StatelessWidget {
  final ValueChanged<String> onProviderTap;
  final bool enabled;
  const AuroraSocialButtons({
    super.key,
    required this.onProviderTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Row(
      children: [
        for (final provider in ['Google', 'Apple']) ...[
          if (provider == 'Apple') const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: L10nService().format('auth_refresh_social_provider', {
                'provider': provider,
              }),
              child: OutlinedButton(
                onPressed: enabled ? () => onProviderTap(provider) : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: style.surface,
                  foregroundColor: style.ink,
                  side: BorderSide(color: style.border),
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: style.text(size: 14, weight: FontWeight.w500),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.string(
                        provider == 'Google' ? _googleLogo : _appleLogo,
                        width: 20,
                        height: 20,
                        colorFilter: provider == 'Apple'
                            ? ColorFilter.mode(style.ink, BlendMode.srcIn)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: Text(provider)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

const String _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#FFC107" d="M43.61 20.08H42V20H24v8h11.3C33.65 32.66 29.19 36 24 36c-6.63 0-12-5.37-12-12s5.37-12 12-12c3.06 0 5.84 1.15 7.96 3.04l5.66-5.66C34.05 6.05 29.27 4 24 4 12.95 4 4 12.95 4 24s8.95 20 20 20 20-8.95 20-20c0-1.34-.14-2.65-.39-3.92z"/>
  <path fill="#FF3D00" d="M6.31 14.69l6.57 4.82C14.66 15.11 18.96 12 24 12c3.06 0 5.84 1.15 7.96 3.04l5.66-5.66C34.05 6.05 29.27 4 24 4 16.32 4 9.66 8.34 6.31 14.69z"/>
  <path fill="#4CAF50" d="M24 44c5.09 0 9.79-1.95 13.36-5.12l-6.18-5.23C29.1 35.1 26.64 36 24 36c-5.17 0-9.62-3.32-11.28-7.94l-6.52 5.02C9.51 39.56 16.21 44 24 44z"/>
  <path fill="#1976D2" d="M43.61 20.08H42V20H24v8h11.3c-.8 2.28-2.27 4.24-4.12 5.65l.01-.01 6.18 5.23C36.93 39.19 44 34 44 24c0-1.34-.14-2.65-.39-3.92z"/>
</svg>
''';

const String _appleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#000000" d="M7.078 23.55c-.473-.316-.893-.703-1.244-1.15-.383-.463-.738-.95-1.064-1.454-.766-1.12-1.365-2.345-1.78-3.636-.5-1.502-.743-2.94-.743-4.347 0-1.57.34-2.94 1.002-4.09.49-.9 1.22-1.653 2.1-2.182.85-.53 1.84-.82 2.84-.84.35 0 .73.05 1.13.15.29.08.64.21 1.07.37.55.21.85.34.95.37.32.12.59.17.8.17.16 0 .39-.05.645-.13.145-.05.42-.14.81-.31.386-.14.692-.26.935-.35.37-.11.728-.21 1.05-.26.39-.06.777-.08 1.148-.05.71.05 1.36.2 1.94.42 1.02.41 1.843 1.05 2.457 1.96-.26.16-.5.346-.725.55-.487.43-.9.94-1.23 1.505-.43.77-.65 1.64-.644 2.52.015 1.083.29 2.035.84 2.86.387.6.904 1.114 1.534 1.536.31.21.582.355.84.45-.12.375-.252.74-.405 1.1-.347.807-.76 1.58-1.25 2.31-.432.63-.772 1.1-1.03 1.41-.402.48-.79.84-1.18 1.097-.43.285-.935.436-1.452.436-.35.015-.7-.03-1.034-.127-.29-.095-.576-.202-.856-.323-.293-.134-.596-.248-.905-.34-.38-.1-.77-.148-1.164-.147-.4 0-.79.05-1.16.145-.31.088-.61.196-.907.325-.42.175-.695.29-.855.34-.324.096-.656.154-.99.175-.52 0-1.004-.15-1.486-.45zm6.854-18.46c-.68.34-1.326.484-1.973.436-.1-.646 0-1.31.27-2.037.24-.62.56-1.18 1-1.68.46-.52 1.01-.95 1.63-1.26.66-.34 1.29-.52 1.89-.55.08.68 0 1.35-.25 2.07-.228.64-.568 1.23-1 1.76-.435.52-.975.95-1.586 1.26z"/>
</svg>
''';
