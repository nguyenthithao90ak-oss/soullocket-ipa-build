import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_cute_kit.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_invite_qr_codec.dart';

class PairingCreateCodeSheet extends StatefulWidget {
  const PairingCreateCodeSheet({super.key, required this.myHouseId});

  final String myHouseId;

  @override
  State<PairingCreateCodeSheet> createState() => _PairingCreateCodeSheetState();
}

class _PairingCreateCodeSheetState extends State<PairingCreateCodeSheet> {
  static const _requestTimeout = Duration(seconds: 15);
  bool _isLoading = false;
  String? _pairingCode;
  int _durationMinutes = 15;
  String? _errorMsg;
  Timer? _countdownTimer;
  Timer? _copiedTimer;
  bool _copied = false;
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
    _copiedTimer?.cancel();
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
      final active = await PairingService.instance
          .getActivePairingCode(widget.myHouseId)
          .timeout(_requestTimeout);
      if (!mounted || active == null) {
        return;
      }

      final code = PairingInviteQrCodec.normalizeCode(
        active['code']?.toString(),
      );
      final expiresAt = (active['expiresAt'] as num?)?.toInt() ?? 0;
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
      final invite = await PairingService.instance
          .createPairingCode(_durationMinutes)
          .timeout(_requestTimeout);
      final code = PairingInviteQrCodec.normalizeCode(invite.code);
      if (code == null) {
        throw StateError('invalid pairing invite');
      }
      if (!mounted) {
        return;
      }
      setState(() => _pairingCode = code);
      _startCountdown(invite.expiresAt);
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
      await PairingService.instance.deleteCode(code).timeout(_requestTimeout);
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
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secondsLabel = (seconds % 60).toString().padLeft(2, '0');
    // Mã sống tới 1 ngày: hiện giờ:phút:giây thay vì "87:14".
    final label = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$secondsLabel'
        : '$minutes:$secondsLabel';
    if (mounted) {
      setState(() {
        _timeLeftStr = label;
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
    // Báo ngay trong hộp: SnackBar của màn dưới bị lớp nền mờ che.
    _copiedTimer?.cancel();
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
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
    return PairingCuteDialogFrame(
      cardKey: const ValueKey<String>('pairing-create-card'),
      canPop: !_isLoading,
      closeTooltip: _t('pairing_ui_close'),
      onClose: _isLoading ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PairingCuteHeader(
            badge: const PairingCoupleHeartBadge(
              size: 58,
              centerIcon: Icons.add_link_rounded,
            ),
            title: _t('pairing_ui_create_title'),
            subtitle: _t('pairing_ui_create_subtitle'),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _pairingCode == null
                ? _buildGenerateState()
                : _buildActiveInviteState(),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            SLSettingsNotice(tone: SLSettingsTone.danger, message: _errorMsg!),
          ],
          const SizedBox(height: 16),
          PairingCuteNote(
            icon: Icons.privacy_tip_outlined,
            message: _t('pairing_ui_creator_notice'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateState() {
    Widget choice(int minutes) => Expanded(
      child: PairingCuteChoicePill(
        label: _durationLabel(minutes),
        selected: _durationMinutes == minutes,
        onTap: _isLoading
            ? null
            : () => setState(() => _durationMinutes = minutes),
      ),
    );
    return Column(
      key: const ValueKey<String>('generate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PairingCuteTicket(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PairingCuteTag(
                  icon: Icons.timer_outlined,
                  label: _t('pairing_ui_duration_label'),
                ),
              ),
              const SizedBox(height: 12),
              // Lưới 2×2 để nhãn dài (vd. "15 Minuten") không bị cắt.
              Row(
                children: [choice(5), const SizedBox(width: 8), choice(15)],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  choice(60),
                  const SizedBox(width: 8),
                  choice(1440),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PairingCutePillButton(
          label: _t('pairing_ui_create_action'),
          icon: Icons.add_link_rounded,
          height: 54,
          loading: _isLoading,
          onPressed: _isLoading ? null : _createCode,
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
        PairingCuteTicket(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PairingCuteTag(
                  icon: Icons.auto_awesome_rounded,
                  label: _t('pairing_quick_my_code'),
                ),
              ),
              const SizedBox(height: 12),
              PairingCuteQr(
                data: PairingInviteQrCodec.encode(code),
                semanticsLabel: _t('pairing_ui_invite_code_label'),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  PairingInviteQrCodec.formatCode(code),
                  maxLines: 1,
                  style: SLTheme.quicksand(
                    color: PairingCutePalette.plum,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PairingCuteTimerPill(
                icon: Icons.timer_outlined,
                text: _timeLeftStr.isEmpty
                    ? _t('pairing_ui_invite_expiring')
                    : L10nScope.of(context).format('pairing_ui_expires_in', {
                        'time': _timeLeftStr,
                      }),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackActions =
                      constraints.maxWidth < 300 &&
                      MediaQuery.textScalerOf(context).scale(14) > 17;
                  final copy = PairingCutePillButton(
                    label: _t('pairing_ui_copy'),
                    icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                    filled: false,
                    onPressed: _isLoading ? null : _copyCode,
                  );
                  final share = PairingCutePillButton(
                    label: _t('pairing_ui_share'),
                    icon: Icons.send_rounded,
                    onPressed: _isLoading ? null : _shareCode,
                  );
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [share, const SizedBox(height: 8), copy],
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
              if (_copied) ...[
                const SizedBox(height: 6),
                Text(
                  _t('pairing_ui_code_copied'),
                  textAlign: TextAlign.center,
                  style: SLSettingsText.caption(SLSettingsColors.success),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _isLoading ? null : _deleteCode,
          style: TextButton.styleFrom(
            foregroundColor: PairingCutePalette.plumSoft,
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PairingCutePalette.rose,
                  ),
                )
              : const Icon(Icons.link_off_rounded, size: 17),
          label: Text(
            _t('pairing_ui_revoke'),
            style: SLTheme.quicksand(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
