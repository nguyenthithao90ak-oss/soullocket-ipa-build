import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
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
        SLSnackBar(
          content: Text(AppErrorMapper.resolve(e).message),
          backgroundColor: SLColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label: context.tr('p9_match_secret_title'),
      child: SLAlertDialog(
        title: SLDialogHeading(
          title: context.tr('p9_match_secret_title'),
          icon: Icons.vpn_key_outlined,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('p9_match_secret_description')),
            const SizedBox(height: 20),
            if (_isWaiting)
              Semantics(
                liveRegion: true,
                label: context.tr('p9_match_secret_waiting'),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: SLDialogStyle.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(context.tr('p9_match_secret_waiting')),
                  ],
                ),
              )
            else
              TextField(
                controller: _codeController,
                style: SLTypography.bodyMedium.copyWith(
                  color: SLColors.ink,
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
                ),
                textCapitalization: TextCapitalization.characters,
              ),
          ],
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('p9_match_secret_cancel')),
          ),
          if (!_isWaiting)
            SLDialogAction(
              primary: true,
              onPressed: _isLoading ? null : _submitCode,
              child: _isLoading
                  ? Semantics(
                      liveRegion: true,
                      label: context.tr('p9_match_secret_submitting'),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SLDialogStyle.primary,
                        ),
                      ),
                    )
                  : Text(context.tr('p9_match_secret_submit')),
            ),
        ],
      ),
    );
  }
}
