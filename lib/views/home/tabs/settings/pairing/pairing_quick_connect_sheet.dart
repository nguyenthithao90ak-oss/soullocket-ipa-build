import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';

import 'pairing_cute_kit.dart';
import 'pairing_invite_qr_codec.dart';
import 'pairing_qr_scanner_screen.dart';

/// Kết quả khi bảng ghép nhanh ghép thành công.
enum PairingQuickConnectResult {
  /// Mình nhập mã người ấy và đã chuyển sang không gian của người ấy.
  joinedPartnerHouse,

  /// Người ấy nhập mã của mình và đã vào không gian của mình.
  partnerJoinedMyHouse,
}

/// Các lời gọi server/RTDB của bảng ghép nhanh, tách riêng để test bằng dữ liệu giả.
abstract class PairingQuickConnectGateway {
  Future<PairingInviteCode?> loadActiveCode(String houseId);
  Future<PairingInviteCode> createCode();

  /// Trả 'accepted' khi server tự chấp nhận, 'pending' với server cũ.
  Future<String> submitCode(String code);
  Future<void> finalizeJoin();

  /// Trạng thái mã của mình trong [houseId]; null khi không còn mã.
  Stream<String?> watchMyInviteStatus(String houseId);
  Stream<int> watchMemberCount(String houseId);
  Stream<String> watchMyRequestStatus();
}

class FirebasePairingQuickConnectGateway implements PairingQuickConnectGateway {
  const FirebasePairingQuickConnectGateway();

  /// Mã ở bảng ghép nhanh luôn sống 5 phút rồi tự đổi mã mới.
  static const int codeMinutes = 5;

  @override
  Future<PairingInviteCode?> loadActiveCode(String houseId) async {
    final active = await PairingService.instance.getActivePairingCode(houseId);
    final code = PairingInviteQrCodec.normalizeCode(
      active?['code']?.toString(),
    );
    final expiresAt = (active?['expiresAt'] as num?)?.toInt() ?? 0;
    if (code == null || expiresAt <= 0) return null;
    return PairingInviteCode(code: code, expiresAt: expiresAt);
  }

  @override
  Future<PairingInviteCode> createCode() =>
      PairingService.instance.createPairingCode(codeMinutes);

  @override
  Future<String> submitCode(String code) =>
      PairingService.instance.sendPairingRequest(code);

  @override
  Future<void> finalizeJoin() => PairingService.instance.finalizeMerge();

  @override
  Stream<String?> watchMyInviteStatus(String houseId) {
    return PairingService.instance.watchMyInvite().map((view) {
      if (view == null || view['houseId']?.toString() != houseId) return null;
      return view['status']?.toString();
    });
  }

  @override
  Stream<int> watchMemberCount(String houseId) {
    return FirebaseDatabase.instance.ref('houses/$houseId/members').onValue.map(
      (event) {
        final value = event.snapshot.value;
        return value is Map ? value.length : 0;
      },
    );
  }

  @override
  Stream<String> watchMyRequestStatus() =>
      PairingService.instance.listenToMyRequestStatus();
}

/// Mở hộp ghép nhanh nổi giữa màn hình (bo góc, nền tối mờ) thay cho bảng
/// trượt từ đáy. Chạm ra ngoài hoặc nút Quay lại để đóng, trừ khi đang kết nối.
Future<PairingQuickConnectResult?> showPairingQuickConnectDialog(
  BuildContext context, {
  required PairingQuickConnectSheet sheet,
}) {
  return showPairingCuteDialog<PairingQuickConnectResult>(
    context,
    builder: (_) => sheet,
  );
}

/// Bảng ghép nhanh: mã của mình (tự đổi mỗi 5 phút) và ô nhập mã người ấy.
/// Nhập đúng mã là kết nối ngay, không cần ai bấm chấp nhận.
class PairingQuickConnectSheet extends StatefulWidget {
  const PairingQuickConnectSheet({
    super.key,
    required this.houseId,
    this.gateway = const FirebasePairingQuickConnectGateway(),
    this.clock,
    this.onPaired,
  });

  final String houseId;
  final PairingQuickConnectGateway gateway;
  final DateTime Function()? clock;

  /// Mặc định phát âm thanh ghép nối; test truyền hàm rỗng.
  final Future<void> Function()? onPaired;

  /// Mở bảng; ghép xong thì nạp lại app để mọi màn dùng đúng không gian chung.
  static Future<PairingQuickConnectResult?> show(
    BuildContext context, {
    required String houseId,
  }) async {
    final result = await showPairingQuickConnectDialog(
      context,
      sheet: PairingQuickConnectSheet(houseId: houseId),
    );
    if (result != null && context.mounted) {
      unawaited(
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppEntry()),
          (route) => false,
        ),
      );
    }
    return result;
  }

  @override
  State<PairingQuickConnectSheet> createState() =>
      _PairingQuickConnectSheetState();
}

class _PairingQuickConnectSheetState extends State<PairingQuickConnectSheet>
    with WidgetsBindingObserver {
  static const _requestTimeout = Duration(seconds: 15);
  static const _reuseMargin = Duration(seconds: 45);
  static const _partnerJoinTimeout = Duration(seconds: 60);
  static const _successHold = Duration(milliseconds: 1800);
  static const _codeLifetime = Duration(
    minutes: FirebasePairingQuickConnectGateway.codeMinutes,
  );

  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  StreamSubscription<String?>? _inviteSub;
  StreamSubscription<int>? _membersSub;
  StreamSubscription<String>? _requestSub;
  Timer? _ticker;
  Timer? _refreshTimer;
  Timer? _partnerJoinTimer;
  Timer? _copiedTimer;
  Timer? _closeTimer;

  PairingInviteCode? _myCode;
  Duration _remaining = Duration.zero;
  bool _codeLoading = false;
  String? _codeError;
  bool _showQr = false;
  bool _copied = false;
  String? _inviteStatus;
  bool _partnerJoining = false;
  int? _lastMemberCount;
  bool _submitting = false;
  bool _joining = false;
  bool _waitingApproval = false;
  String? _entryError;
  PairingQuickConnectResult? _result;
  bool _foreground = true;
  bool _refreshWhenForeground = false;

  bool get _isDone => _result != null;
  bool get _entryBusy => _submitting || _joining;

  String _t(String key) => context.tr(key);
  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inviteSub = widget.gateway
        .watchMyInviteStatus(widget.houseId)
        .listen(_onInviteStatus, onError: (Object _) {});
    _membersSub = widget.gateway
        .watchMemberCount(widget.houseId)
        .listen(_onMemberCount, onError: (Object _) {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_ensureCode());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inviteSub?.cancel();
    _membersSub?.cancel();
    _requestSub?.cancel();
    _ticker?.cancel();
    _refreshTimer?.cancel();
    _partnerJoinTimer?.cancel();
    _copiedTimer?.cancel();
    _closeTimer?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _refreshWhenForeground) {
      _refreshWhenForeground = false;
      unawaited(_ensureCode());
    }
  }

  Duration _timeLeft(PairingInviteCode code) => Duration(
    milliseconds: code.expiresAt - _now().millisecondsSinceEpoch,
  );

  void _tick() {
    final code = _myCode;
    if (!mounted || code == null || _isDone) return;
    final left = _timeLeft(code);
    if (left > Duration.zero) {
      setState(() => _remaining = left);
      return;
    }
    setState(() {
      _myCode = null;
      _remaining = Duration.zero;
    });
    unawaited(_ensureCode(forceNew: true));
  }

  /// Dùng lại mã còn hạn; hết hạn thì xin server mã mới 5 phút.
  Future<void> _ensureCode({bool forceNew = false}) async {
    if (_codeLoading || _isDone || _partnerJoining || _joining) return;
    if (!_foreground) {
      // Không xin mã khi app đang ở nền; mở lại thì làm mới.
      _refreshWhenForeground = true;
      return;
    }
    setState(() {
      _codeLoading = true;
      _codeError = null;
    });
    try {
      PairingInviteCode? code;
      if (!forceNew) {
        code = await widget.gateway
            .loadActiveCode(widget.houseId)
            .timeout(_requestTimeout);
        // Chỉ dùng lại mã 5 phút còn đủ giờ. Mã dài hạn tạo ở màn "Tạo mã" cũ
        // (tới 1 ngày) được thay bằng mã 5 phút cho đúng bảng tự đổi mã này.
        if (code != null) {
          final left = _timeLeft(code);
          if (left < _reuseMargin || left > _codeLifetime + _reuseMargin) {
            code = null;
          }
        }
      }
      code ??= await widget.gateway.createCode().timeout(_requestTimeout);
      if (!mounted || _isDone) return;
      setState(() {
        _myCode = code;
        _remaining = _timeLeft(code!);
      });
    } catch (error) {
      // Người ấy đang dùng mã cũ thì server không cấp mã mới; không báo lỗi.
      if (!mounted || _isDone || _partnerJoining) return;
      setState(() {
        _codeError = AppErrorMapper.resolve(
          error,
          fallbackMessage: _t('pairing_ui_create_error'),
        ).message;
      });
    } finally {
      if (mounted) setState(() => _codeLoading = false);
    }
  }

  void _onInviteStatus(String? status) {
    if (!mounted || _isDone) return;
    final previous = _inviteStatus;
    _inviteStatus = status;
    final joining = status == 'accepted' || status == 'pending';
    if (joining != _partnerJoining) {
      setState(() => _partnerJoining = joining);
      _partnerJoinTimer?.cancel();
      if (joining) {
        // Người ấy bỏ dở giữa chừng thì sau một lúc trở lại màn bình thường.
        _partnerJoinTimer = Timer(_partnerJoinTimeout, () {
          if (mounted && !_isDone) setState(() => _partnerJoining = false);
        });
      }
    }
    if (status == null && previous != null) {
      // Mã bị dùng/thu hồi ở nơi khác: chờ danh sách thành viên rồi mới tạo mã mới.
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _isDone) return;
        setState(() => _myCode = null);
        unawaited(_ensureCode(forceNew: true));
      });
    }
  }

  void _onMemberCount(int count) {
    if (!mounted || _isDone) return;
    final previous = _lastMemberCount;
    _lastMemberCount = count;
    // Khi mình đang chuyển sang nhà người ấy, số thành viên nhà cũ không còn ý nghĩa.
    if (count < 2 || _joining) return;
    if (previous == null) {
      // Đã đủ hai người ngay khi mở bảng: không còn gì để ghép.
      Navigator.of(context).maybePop();
      return;
    }
    _celebrate(PairingQuickConnectResult.partnerJoinedMyHouse);
  }

  Future<void> _submit() async {
    if (_entryBusy || _isDone) return;
    final code = PairingInviteQrCodec.normalizeCode(_codeCtrl.text);
    if (code == null) {
      setState(() => _entryError = _t('pairing_ui_code_invalid'));
      _codeFocus.requestFocus();
      return;
    }
    if (code == _myCode?.code) {
      setState(() => _entryError = _t('pairing_quick_own_code'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _entryError = null;
    });
    try {
      final status = await widget.gateway
          .submitCode(code)
          .timeout(_requestTimeout);
      if (!mounted || _isDone) return;
      if (status == 'pending') {
        setState(() => _waitingApproval = true);
        _listenForLegacyApproval();
        return;
      }
      await _finalizeJoin();
    } catch (error) {
      if (!mounted || _isDone) return;
      setState(() {
        _entryError = AppErrorMapper.resolve(
          error,
          fallbackMessage: _t('pairing_ui_request_error'),
        ).message;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Server chưa cập nhật thì vẫn chờ chủ nhà duyệt như cũ.
  void _listenForLegacyApproval() {
    _requestSub?.cancel();
    _requestSub = widget.gateway.watchMyRequestStatus().listen((status) {
      if (!mounted || _isDone) return;
      if (status == 'accepted') {
        unawaited(_finalizeJoin());
      } else if (status == 'rejected') {
        setState(() {
          _waitingApproval = false;
          _entryError = _t('pairing_ui_rejected_body');
        });
      }
    }, onError: (Object _) {});
  }

  Future<void> _finalizeJoin() async {
    if (_joining || _isDone) return;
    setState(() {
      _joining = true;
      _waitingApproval = false;
      _entryError = null;
    });
    try {
      await widget.gateway.finalizeJoin().timeout(_requestTimeout);
      if (!mounted) return;
      _celebrate(PairingQuickConnectResult.joinedPartnerHouse);
    } catch (error) {
      if (!mounted || _isDone) return;
      setState(() {
        _entryError = AppErrorMapper.resolve(
          error,
          fallbackMessage: _t('pairing_ui_finalize_error'),
        ).message;
      });
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _celebrate(PairingQuickConnectResult result) {
    if (_isDone) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _requestSub?.cancel();
    setState(() => _result = result);
    unawaited(
      (widget.onPaired ?? SoundService().playPaired)().catchError((
        Object error,
      ) {
        debugPrint('[PairingQuickConnect] Cannot play sound: $error');
      }),
    );
    _closeTimer = Timer(_successHold, () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  void _setCode(String code) {
    final formatted = PairingInviteQrCodec.formatCode(code);
    _codeCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _entryError = null);
  }

  void _onCodeChanged(String value) {
    if (_entryError != null) setState(() => _entryError = null);
    // Đủ 12 số là gửi luôn, không cần bấm thêm.
    if (PairingInviteQrCodec.normalizeCode(value) != null) unawaited(_submit());
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final code = extractPairingCode(data?.text);
    if (code == null) {
      setState(() => _entryError = _t('pairing_ui_clipboard_invalid'));
      return;
    }
    _setCode(code);
    unawaited(_submit());
  }

  Future<void> _scanCode() async {
    final code = await slPush<String>(
      context,
      const PairingQrScannerScreen(),
      fullscreenDialog: true,
    );
    if (!mounted || code == null) return;
    _setCode(code);
    unawaited(_submit());
  }

  Future<void> _copyCode() async {
    final code = _myCode;
    if (code == null) return;
    await Clipboard.setData(
      ClipboardData(text: PairingInviteQrCodec.formatCode(code.code)),
    );
    if (!mounted) return;
    _copiedTimer?.cancel();
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareCode() async {
    final code = _myCode;
    if (code == null) return;
    final message = L10nScope.of(context).format('pairing_ui_share_message', {
      'code': PairingInviteQrCodec.formatCode(code.code),
      'time': _formatDuration(_remaining),
    });
    await SharePlus.instance.share(
      ShareParams(subject: _t('pairing_ui_share_subject'), text: message),
    );
  }

  static String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PairingCuteDialogFrame(
      cardKey: const ValueKey<String>('pairing-quick-card'),
      canPop: !_entryBusy,
      showClose: !_isDone,
      closeTooltip: _t('pairing_ui_close'),
      onClose: _entryBusy ? null : () => Navigator.of(context).pop(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _isDone ? _buildSuccess() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      key: const ValueKey<String>('pairing-quick-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PairingCuteHeader(
          badge: const PairingCoupleHeartBadge(size: 58),
          title: _t('pairing_ui_dashboard_title'),
          subtitle: _t('pairing_quick_subtitle'),
        ),
        const SizedBox(height: 18),
        _buildMyCodeCard(),
        const SizedBox(height: 16),
        _buildOrDivider(),
        const SizedBox(height: 14),
        _buildEntrySection(),
        const SizedBox(height: 16),
        PairingCuteNote(message: _t('pairing_quick_join_notice')),
      ],
    );
  }

  /// Thẻ "vé" chứa mã của mình.
  Widget _buildMyCodeCard() {
    final code = _myCode;
    return PairingCuteTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: PairingCuteTag(
                  icon: Icons.auto_awesome_rounded,
                  label: _t('pairing_quick_my_code'),
                ),
              ),
              const Spacer(),
              if (code != null && !_partnerJoining)
                IconButton(
                  key: const ValueKey<String>('pairing-quick-qr-toggle'),
                  tooltip: _t(
                    _showQr ? 'pairing_quick_hide_qr' : 'pairing_quick_show_qr',
                  ),
                  onPressed: () => setState(() => _showQr = !_showQr),
                  style: IconButton.styleFrom(
                    backgroundColor: _showQr
                        ? PairingCutePalette.petal
                        : PairingCutePalette.blush,
                  ),
                  icon: Icon(
                    _showQr ? Icons.qr_code_2_rounded : Icons.qr_code_rounded,
                    color: PairingCutePalette.roseDeep,
                    size: 21,
                  ),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: _buildMyCodeBody(code),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCodeBody(PairingInviteCode? code) {
    if (_partnerJoining) {
      return Container(
        key: const ValueKey<String>('pairing-quick-partner-joining'),
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PairingCutePalette.mint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: PairingCutePalette.mintDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('pairing_quick_partner_joining'),
                style: SLTheme.quicksand(
                  color: PairingCutePalette.mintDeep,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (code != null) return _buildActiveCode(code);
    if (_codeError != null && !_codeLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _codeError!,
              textAlign: TextAlign.center,
              style: SLSettingsText.caption(SLSettingsColors.danger),
            ),
            const SizedBox(height: 10),
            PairingCutePillButton(
              label: _t('pairing_ui_state_retry'),
              icon: Icons.refresh_rounded,
              filled: false,
              onPressed: () => _ensureCode(forceNew: true),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 92,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: PairingCutePalette.rose,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _t('pairing_quick_code_creating'),
                style: SLTheme.quicksand(
                  color: PairingCutePalette.plumSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCode(PairingInviteCode code) {
    final formatted = PairingInviteQrCodec.formatCode(code.code);
    final progress = (_remaining.inMilliseconds / _codeLifetime.inMilliseconds)
        .clamp(0.0, 1.0);
    return Column(
      key: const ValueKey<String>('pairing-quick-active-code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Semantics(
          label: '${_t('pairing_quick_my_code')}: $formatted',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatted,
              maxLines: 1,
              style: SLTheme.quicksand(
                color: PairingCutePalette.plum,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        PairingCuteTimerPill(
          text: L10nScope.of(context).format('pairing_quick_new_code_in', {
            'time': _formatDuration(_remaining),
          }),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: PairingCutePalette.rose,
            backgroundColor: PairingCutePalette.petal,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 300 &&
                MediaQuery.textScalerOf(context).scale(14) > 17;
            final copy = PairingCutePillButton(
              label: _t('pairing_ui_copy'),
              icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
              filled: false,
              onPressed: _copyCode,
            );
            final share = PairingCutePillButton(
              label: _t('pairing_ui_share'),
              icon: Icons.send_rounded,
              onPressed: _shareCode,
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 8), share],
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
        if (_showQr) ...[
          const SizedBox(height: 14),
          PairingCuteQr(
            data: PairingInviteQrCodec.encode(code.code),
            semanticsLabel: _t('pairing_ui_invite_code_label'),
          ),
        ],
      ],
    );
  }

  Widget _buildOrDivider() {
    Widget line() => Expanded(
      child: Container(
        height: 1.4,
        decoration: BoxDecoration(
          color: PairingCutePalette.line,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 11,
                color: PairingCutePalette.heart,
              ),
              const SizedBox(width: 6),
              Text(
                _t('pairing_quick_or'),
                style: SLTheme.quicksand(
                  color: PairingCutePalette.plumSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.favorite_rounded,
                size: 11,
                color: PairingCutePalette.heart,
              ),
            ],
          ),
        ),
        line(),
      ],
    );
  }

  Widget _buildEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PairingCuteTag(
            icon: Icons.favorite_border_rounded,
            label: _t('pairing_quick_partner_code'),
          ),
        ),
        const SizedBox(height: 10),
        PairingCuteCodeField(
          fieldKey: const ValueKey<String>('pairing-quick-code-field'),
          controller: _codeCtrl,
          focusNode: _codeFocus,
          readOnly: _entryBusy,
          hintText: _t('pairing_ui_code_hint'),
          inputFormatters: const <TextInputFormatter>[
            PairingCodeInputFormatter(),
          ],
          onSubmitted: (_) => _submit(),
          onChanged: _onCodeChanged,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            PairingCuteChip(
              icon: Icons.content_paste_rounded,
              label: _t('pairing_ui_paste'),
              onPressed: _entryBusy ? null : _pasteCode,
            ),
            PairingCuteChip(
              icon: Icons.qr_code_scanner_rounded,
              label: _t('pairing_ui_scan_action'),
              onPressed: _entryBusy ? null : _scanCode,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_waitingApproval) ...[
          SLSettingsNotice(
            tone: SLSettingsTone.info,
            icon: Icons.mark_email_read_outlined,
            title: _t('pairing_ui_wait_title'),
            message: _t('pairing_ui_wait_body'),
          ),
          const SizedBox(height: 10),
        ],
        PairingCutePillButton(
          key: const ValueKey<String>('pairing-quick-connect-button'),
          label: _t(
            _entryBusy ? 'pairing_quick_connecting' : 'pairing_quick_connect_action',
          ),
          icon: Icons.favorite_rounded,
          height: 54,
          loading: _entryBusy,
          onPressed: _entryBusy || _waitingApproval ? null : _submit,
        ),
        if (_entryError != null) ...[
          const SizedBox(height: 10),
          SLSettingsNotice(
            tone: SLSettingsTone.danger,
            message: _entryError!,
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess() {
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('pairing-quick-success'),
      tween: Tween<double>(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: PairingCuteStatusPanel(
        icon: Icons.favorite_rounded,
        badge: const PairingCoupleHeartBadge(size: 80, together: true),
        title: _t('pairing_ui_success_title'),
        body: _t('pairing_ui_success_body'),
        footer: const SizedBox(height: 8),
      ),
    );
  }
}

/// Lấy mã 12 số từ nội dung dán: mã trần, payload QR hoặc nguyên tin nhắn chia sẻ.
String? extractPairingCode(String? text) {
  final raw = text?.trim() ?? '';
  if (raw.isEmpty || raw.length > 600) return null;
  final direct = PairingInviteQrCodec.decode(raw);
  if (direct != null) return direct;
  final match = RegExp(
    r'(?<!\d)(\d{4})[\s-]?(\d{4})[\s-]?(\d{4})(?!\d)',
  ).firstMatch(raw);
  if (match == null) return null;
  return '${match.group(1)}${match.group(2)}${match.group(3)}';
}

/// Định dạng mã 12 số thành 0000-0000-0000 trong lúc gõ.
class PairingCodeInputFormatter extends TextInputFormatter {
  const PairingCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > PairingInviteQrCodec.codeLength
        ? digits.substring(0, PairingInviteQrCodec.codeLength)
        : digits;
    final grouped = StringBuffer();
    for (var index = 0; index < limited.length; index++) {
      if (index > 0 && index % 4 == 0) grouped.write('-');
      grouped.write(limited[index]);
    }
    final text = grouped.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
