import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class SingleMatchSecretCodeDialog extends StatefulWidget {
  final String houseId;

  const SingleMatchSecretCodeDialog({super.key, required this.houseId});

  @override
  State<SingleMatchSecretCodeDialog> createState() =>
      _SingleMatchSecretCodeDialogState();
}

class _SingleMatchSecretCodeDialogState
    extends State<SingleMatchSecretCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isWaiting = false;
  StreamSubscription<String?>? _matchSub;

  @override
  void dispose() {
    _codeController.dispose();
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final roomId = await SingleMatchService.instance.pairWithSecretCode(
        secretCode: code,
        myHouseId: widget.houseId,
      );

      if (roomId != null) {
        if (!mounted) return;
        Navigator.of(context).pop(roomId);
        return;
      }

      setState(() {
        _isWaiting = true;
        _isLoading = false;
      });

      _matchSub = SingleMatchService.instance.watchSecretCodeMatch(code).listen(
        (matchedRoomId) {
          if (matchedRoomId != null && mounted) {
            Navigator.of(context).pop(matchedRoomId);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorMapper.resolve(e).message),
          backgroundColor: SLColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? colorScheme.surface : SLColors.bgMain;
    final inputColor = isDark
        ? colorScheme.surfaceContainerHighest
        : SLColors.bgCard;
    final primaryText = isDark ? colorScheme.onSurface : SLColors.textPrimary;
    final secondaryText = isDark
        ? colorScheme.onSurfaceVariant
        : SLColors.textSecondary;

    return Semantics(
      namesRoute: true,
      label: context.tr('p9_match_secret_title'),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  size: 48,
                  color: SLColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('p9_match_secret_title'),
                  style: SLTypography.titleMedium.copyWith(color: primaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('p9_match_secret_description'),
                  style: SLTypography.bodyMedium.copyWith(color: secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_isWaiting)
                  Semantics(
                    liveRegion: true,
                    label: context.tr('p9_match_secret_waiting'),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: SLColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('p9_match_secret_waiting'),
                          style: SLTypography.bodyMedium.copyWith(
                            color: isDark
                                ? colorScheme.onSurfaceVariant
                                : SLColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  TextField(
                    controller: _codeController,
                    style: SLTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isLoading) _submitCode();
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('p9_match_secret_input_label'),
                      hintText: context.tr('p9_match_secret_hint'),
                      filled: true,
                      fillColor: inputColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.tr('p9_match_secret_cancel'),
                          style: SLTypography.labelLarge.copyWith(
                            color: isDark
                                ? colorScheme.onSurfaceVariant
                                : SLColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    if (!_isWaiting) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submitCode,
                          style: FilledButton.styleFrom(
                            backgroundColor: SLColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? Semantics(
                                  liveRegion: true,
                                  label: context.tr(
                                    'p9_match_secret_submitting',
                                  ),
                                  child: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  context.tr('p9_match_secret_submit'),
                                  style: SLTypography.labelLarge,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
