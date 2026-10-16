import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:flutter/material.dart';

import 'package:soullocket_app/views/auth/house_onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/services/auth_service.dart';
import '../app_entry/widgets/loading_scaffold.dart';
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
      // Cùng màn tải với HouseOnboardingScreen tự tạo nhà, nên bước kiểm tra
      // tài khoản và bước tạo nhà trông như một màn chờ liền mạch.
      loadingBuilder: (_) => const LoadingScaffold(),
      childBuilder: (_) => HouseOnboardingScreen(
        autoCreateOnly: true,
        initialHouseName: UiCopy.text('copy_30f2bdf55443'),
        onHouseCreated: onHouseCreated,
        onSignedOut: onSignedOut,
      ),
    );
  }
}
