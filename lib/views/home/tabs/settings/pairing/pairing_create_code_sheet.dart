import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_invite_qr_codec.dart';

class PairingCreateCodeSheet extends StatefulWidget {
  const PairingCreateCodeSheet({super.key, required this.myHouseId});

  final String myHouseId;

  @override
  State<PairingCreateCodeSheet> createState() => _PairingCreateCodeSheetState();
}

class _PairingCreateCodeSheetState extends State<PairingCreateCodeSheet> {
  bool _isLoading = false;
  String? _pairingCode;
  int _durationMinutes = 15;
  String? _errorMsg;
  Timer? _countdownTimer;
  String _timeLeftStr = '';

  String _t(String key) => context.tr(key);

  @override
  void initState() {
    super.initState();
    unawaited(_loadActiveCode());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveCode() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }
    try {
      final active = await PairingService.instance.getActivePairingCode(
        widget.myHouseId,
      );
      if (!mounted || active == null) {
        return;
      }

      final code = PairingInviteQrCodec.normalizeCode(
        active['code']?.toString(),
      );
      final expiresAt = active['expiresAt'] as int? ?? 0;
      if (code != null && expiresAt > DateTime.now().millisecondsSinceEpoch) {
        setState(() => _pairingCode = code);
        _startCountdown(expiresAt);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_create_error'),
          ).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final code = PairingInviteQrCodec.normalizeCode(
        await PairingService.instance.createPairingCode(_durationMinutes),
      );
      if (code == null) {
        throw StateError('invalid pairing invite');
      }
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch +
          (_durationMinutes * Duration.millisecondsPerMinute);
      if (!mounted) {
        return;
      }
      setState(() => _pairingCode = code);
      _startCountdown(expiresAt);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_create_error'),
          ).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCode() async {
    final code = _pairingCode;
    if (code == null || _isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await PairingService.instance.deleteCode(code);
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _pairingCode = null;
          _timeLeftStr = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_revoke_error'),
          ).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startCountdown(int expiresAt) {
    _countdownTimer?.cancel();
    _updateTimeLeft(expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft(expiresAt);
    });
  }

  void _updateTimeLeft(int expiresAt) {
    final diff = expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (diff <= 0) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _pairingCode = null;
          _timeLeftStr = '';
        });
      }
      return;
    }

    final seconds = (diff / 1000).ceil();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final secondsLabel = remainingSeconds.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _timeLeftStr = '$minutes:$secondsLabel';
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _pairingCode;
    if (code == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: PairingInviteQrCodec.formatCode(code)),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_t('pairing_ui_code_copied'))));
  }

  Future<void> _shareCode() async {
    final code = _pairingCode;
    if (code == null) {
      return;
    }
    final time = _timeLeftStr.isEmpty
        ? _durationLabel(_durationMinutes)
        : _timeLeftStr;
    final message = L10nScope.of(context).format('pairing_ui_share_message', {
      'code': PairingInviteQrCodec.formatCode(code),
      'time': time,
    });
    await SharePlus.instance.share(
      ShareParams(subject: _t('pairing_ui_share_subject'), text: message),
    );
  }

  String _durationLabel(int minutes) {
    switch (minutes) {
      case 5:
        return _t('pairing_ui_duration_5m');
      case 15:
        return _t('pairing_ui_duration_15m');
      case 60:
        return _t('pairing_ui_duration_60m');
      case 1440:
        return _t('pairing_ui_duration_1d');
      default:
        return '$minutes min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sheetHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SLColors.ink.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildCreatorNotice(),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _pairingCode == null
                          ? _buildGenerateState()
                          : _buildActiveInviteState(),
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      _ErrorNotice(message: _errorMsg!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEDF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_link_rounded,
                color: Color(0xFFB9516D),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('pairing_ui_create_title'),
                style: SLTheme.quicksand(
                  color: SLColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              tooltip: _t('pairing_ui_close'),
              icon: const Icon(
                Icons.close_rounded,
                color: SLColors.textSecond,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _t('pairing_ui_create_subtitle'),
          style: SLTheme.quicksand(
            color: SLColors.textSecond,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: SLColors.primary.withValues(alpha: 0.88),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t('pairing_ui_creator_notice'),
              style: SLTheme.quicksand(
                color: SLColors.textSecond,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateState() {
    return Column(
      key: const ValueKey<String>('generate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('pairing_ui_duration_label'),
          style: SLTheme.quicksand(
            color: SLColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <int>[5, 15, 60, 1440]
              .expand(
                (minutes) => [
                  Expanded(
                    child: _DurationChoice(
                      label: _durationLabel(minutes),
                      selected: _durationMinutes == minutes,
                      onTap: _isLoading
                          ? null
                          : () => setState(() => _durationMinutes = minutes),
                    ),
                  ),
                  if (minutes != 1440) const SizedBox(width: 8),
                ],
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isLoading ? null : _createCode,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFFB9516D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_link_rounded, size: 20),
                    const SizedBox(width: 9),
                    Text(
                      _t('pairing_ui_create_action'),
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildActiveInviteState() {
    final code = _pairingCode!;
    return Column(
      key: const ValueKey<String>('active'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEE5E4)),
          ),
          child: Column(
            children: [
              QrImageView(
                data: PairingInviteQrCodec.encode(code),
                version: QrVersions.auto,
                size: 184,
                padding: const EdgeInsets.all(12),
                semanticsLabel: _t('pairing_ui_invite_code_label'),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: SLColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: SLColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                PairingInviteQrCodec.formatCode(code),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: SLColors.textSecond,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _timeLeftStr.isEmpty
                          ? _t('pairing_ui_invite_expiring')
                          : L10nScope.of(context).format(
                              'pairing_ui_expires_in',
                              {'time': _timeLeftStr},
                            ),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: SLColors.textSecond,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackActions =
                constraints.maxWidth < 300 &&
                MediaQuery.textScalerOf(context).scale(14) > 17;
            final share = FilledButton.icon(
              onPressed: _isLoading ? null : _shareCode,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(
                _t('pairing_ui_share'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFFB9516D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            );
            final copy = OutlinedButton.icon(
              onPressed: _isLoading ? null : _copyCode,
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: Text(
                _t('pairing_ui_copy'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: SLColors.ink,
                side: const BorderSide(color: Color(0xFFE8DDDC)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            );
            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [share, const SizedBox(height: 10), copy],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 10),
                Expanded(child: share),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _isLoading ? null : _deleteCode,
          style: TextButton.styleFrom(
            foregroundColor: SLColors.textSecond,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_off_rounded, size: 16),
          label: Text(
            _t('pairing_ui_revoke'),
            style: SLTheme.quicksand(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? SLColors.primaryLight : SLColors.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? SLColors.primary : SLColors.border,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: selected ? SLColors.primaryActive : SLColors.textSecond,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SLColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SLColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: SLColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: SLTheme.quicksand(
                color: const Color(0xFF9A344C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
