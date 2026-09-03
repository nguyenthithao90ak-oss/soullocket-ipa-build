import 'package:flutter/material.dart';

import 'aurora_social_buttons.dart';

/// Legacy API adapter so the original authentication callbacks are preserved.
class SocialAuthButtons extends StatelessWidget {
  final ValueChanged<String> onProviderTap;

  const SocialAuthButtons({
    super.key,
    required this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraSocialButtons(onProviderTap: onProviderTap);
  }
}
