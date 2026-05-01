import 'package:flutter/material.dart';

import '../../forgot_password_screen.dart';

class ForgotPasswordLauncher {
  const ForgotPasswordLauncher._();

  static Future<void> launch(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }
}
