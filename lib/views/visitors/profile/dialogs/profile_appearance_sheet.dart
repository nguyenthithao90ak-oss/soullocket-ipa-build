import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';
import '../sections/profile_section_models.dart';

Future<void> showVisitorProfileAppearanceSheet({
  required BuildContext context,
  required bool isUpdatingProfileAppearance,
  required String initialThemeKey,
  required bool hasCustomHeaderImage,
  required List<VisitorProfileHeaderThemeData> themes,
  required Future<void> Function() onPickHeaderImage,
  required Future<void> Function() onPickAvatar,
  required Future<void> Function() onRemoveHeaderImage,
  required Future<void> Function(String themeKey) onThemeSelected,
  required Future<void> Function() onOpenCommunitySettings,
  bool showThemeSelection = false,
}) async {
  var selectedThemeKey = initialThemeKey;
  var draftHasCustomHeaderImage = hasCustomHeaderImage;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, modalSetState) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: SLResponsive.scrollPhysicsForPlatform(),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5D9DF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  SLSpacing.h16,
                  Text(
                    context.tr('p5_profile_appearance_title'),
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    context.tr('p5_profile_appearance_description'),
                    style: SLTheme.quicksand(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w600,
                      color: SLColors.textSecond,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _VisitorProfileAppearanceAction(
                          icon: Icons.wallpaper_rounded,
                          label: context.tr('p5_profile_change_header'),
                          onTap: isUpdatingProfileAppearance
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await onPickHeaderImage();
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VisitorProfileAppearanceAction(
                          icon: Icons.account_circle_rounded,
                          label: context.tr('p5_profile_change_avatar'),
                          onTap: isUpdatingProfileAppearance
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await onPickAvatar();
                                },
                        ),
                      ),
                    ],
                  ),
                  if (draftHasCustomHeaderImage) ...[
                    const SizedBox(height: 10),
                    _VisitorProfileAppearanceAction(
                      icon: Icons.layers_clear_rounded,
                      label: context.tr('p5_profile_remove_header'),
                      onTap: isUpdatingProfileAppearance
                          ? null
                          : () async {
                              modalSetState(
                                () => draftHasCustomHeaderImage = false,
                              );
                              await onRemoveHeaderImage();
                            },
                    ),
                  ],
                  if (showThemeSelection) ...[
                    const SizedBox(height: 18),
                    Text(
                      context.tr('p5_profile_default_background'),
                      style: SLTheme.quicksand(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: themes.map((theme) {
                        final selected = selectedThemeKey == theme.key;
                        final themeLabel = context.tr(theme.labelKey);
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: themeLabel,
                          child: GestureDetector(
                            onTap: isUpdatingProfileAppearance
                                ? null
                                : () async {
                                    modalSetState(() {
                                      selectedThemeKey = theme.key;
                                      draftHasCustomHeaderImage = false;
                                    });
                                    await onThemeSelected(theme.key);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 92,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? SLColors.primary
                                      : SLColors.border,
                                  width: selected ? 1.6 : 1,
                                ),
                                color: Colors.white,
                                boxShadow: selected ? SLShadow.sm : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        colors: theme.colors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      theme.icon,
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  Text(
                                    themeLabel,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? SLColors.primary
                                          : SLColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _VisitorProfileAppearanceAction(
                    icon: Icons.settings_rounded,
                    label: context.tr('p5_profile_open_community_settings'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await onOpenCommunitySettings();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _VisitorProfileAppearanceAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _VisitorProfileAppearanceAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F1F5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: SLColors.primary, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: SLColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
