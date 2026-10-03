import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/collage_limit_service.dart';

class CollageLimitUiHelper {
  static Future<bool> checkLimitAndAskAd(BuildContext context) {
    return CollageLimitService().checkLimitAndAskAd(
      onAskUserToWatchAd: (currentLimit, dailyLimit) async {
        if (!context.mounted) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => SLAlertDialog(
                title: Text(L10nService().translate('ui_utilities_image_creation_limit_reached_11f7b6')),
                content: Text(
                  L10nService().format('ui_utilities_you_have_run_out_of_attempts_to_20b825', {'value1': currentLimit, 'value2': dailyLimit}),
                ),
                actions: [
                  SLDialogAction(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(L10nService().translate('core_cancel')),
                  ),
                  SLDialogAction.icon(
                    primary: true,
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.play_circle_fill),
                    label: Text(L10nService().format('ui_utilities_get_value1_turns_009697', {'value1': dailyLimit})),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onShowMessage: (message, {bool isError = false}) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(message,
                ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? null : const Color(0xFFD81B60),
          ),
        );
      },
    );
  }
}
