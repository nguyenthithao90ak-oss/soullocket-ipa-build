import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import 'utilities_hub_tile.dart';

enum UtilitiesAppAction { open, togglePin }

/// Bảng hiện khi nhấn giữ một tiện ích: mở hoặc ghim lên trang Nhà.
Future<UtilitiesAppAction?> showUtilitiesAppActionSheet(
  BuildContext context, {
  required UtilityApp app,
  required bool isPinned,
}) {
  return showModalBottomSheet<UtilitiesAppAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: SLColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) =>
        _UtilitiesAppActionSheet(app: app, isPinned: isPinned),
  );
}

class _UtilitiesAppActionSheet extends StatelessWidget {
  const _UtilitiesAppActionSheet({required this.app, required this.isPinned});

  final UtilityApp app;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UtilityHubSticker(app: app, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.localizedTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SheetAction(
            icon: Icons.arrow_outward_rounded,
            label: context.tr('utilities_action_open'),
            onTap: () => Navigator.of(context).pop(UtilitiesAppAction.open),
          ),
          const SizedBox(height: 8),
          _SheetAction(
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            label: context.tr(
              isPinned ? 'utilities_action_unpin' : 'utilities_action_pin',
            ),
            onTap: () =>
                Navigator.of(context).pop(UtilitiesAppAction.togglePin),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: SLColors.bgSubtle,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: SLColors.primaryActive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
