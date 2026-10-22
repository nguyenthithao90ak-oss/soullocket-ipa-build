import 'package:flutter/material.dart';

import 'aurora_social_buttons.dart';

/// Legacy API adapter so the original authentication callbacks are preserved.
class SocialAuthButtons extends StatelessWidget {
  final ValueChanged<String> onProviderTap;
  final bool enabled;

  const SocialAuthButtons({
    super.key,
    required this.onProviderTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraSocialButtons(onProviderTap: onProviderTap, enabled: enabled);
  }
}
