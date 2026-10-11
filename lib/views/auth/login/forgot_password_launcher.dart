import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_route.dart';

import '../forgot_password_screen.dart';

class ForgotPasswordLauncher {
  const ForgotPasswordLauncher._();

  static Future<void> launch(BuildContext context) {
    return slPush<void>(context, const ForgotPasswordScreen());
  }
}
