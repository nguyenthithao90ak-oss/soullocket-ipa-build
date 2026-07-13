import 'package:flutter/material.dart';

import 'package:soullocket_app/views/auth/house_onboarding_screen.dart';

class HouseChoiceScreen extends StatelessWidget {
  final Future<void> Function()? onHouseCreated;
  final Future<void> Function()? onSignedOut;

  const HouseChoiceScreen({
    super.key,
    this.onHouseCreated,
    this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) {
    return HouseOnboardingScreen(
      autoCreateOnly: true,
      initialHouseName: 'Chúng mình',
      onHouseCreated: onHouseCreated,
      onSignedOut: onSignedOut,
    );
  }
}
