import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';

class UpdateDialogHelper {
  static void show(
    BuildContext context,
    String storeUrl,
    String latestVersion,
    bool forceUpdate,
  ) {
    final l10n = L10nService();
    showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        canPop: !forceUpdate,
        child: SLAlertDialog(
          title: SLDialogHeading(
            title: l10n.translate('dialog_update_title'),
            icon: Icons.system_update_rounded,
          ),
          content: Text(
            l10n.format(
              forceUpdate
                  ? 'dialog_update_required'
                  : 'dialog_update_available',
              {'version': latestVersion},
            ),
          ),
          actions: [
            if (!forceUpdate)
              SLDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.translate('dialog_later')),
              ),
            SLDialogAction(
              primary: true,
              onPressed: () async {
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(l10n.translate('dialog_update_action')),
            ),
          ],
        ),
      ),
    );
  }
}
