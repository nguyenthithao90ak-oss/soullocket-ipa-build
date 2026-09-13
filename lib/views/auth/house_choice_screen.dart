import 'package:flutter/material.dart';

import 'package:soullocket_app/views/auth/house_onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/services/auth_service.dart';
import 'widgets/account_deletion_gate.dart';

class HouseChoiceScreen extends StatelessWidget {
  final Future<void> Function()? onHouseCreated;
  final Future<void> Function()? onSignedOut;

  const HouseChoiceScreen({super.key, this.onHouseCreated, this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return AccountDeletionGate(
      key: ValueKey(FirebaseAuth.instance.currentUser?.uid),
      loadStatus: auth.getOwnAccountDeletionStatus,
      cancelRequest: auth.undoScheduledDeletion,
      signOut: () async {
        await auth.signOut();
        await onSignedOut?.call();
      },
      childBuilder: (_) => HouseOnboardingScreen(
        autoCreateOnly: true,
        initialHouseName: 'Chúng mình',
        onHouseCreated: onHouseCreated,
        onSignedOut: onSignedOut,
      ),
    );
  }
}
