import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/home_shared_note_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';

/// Lời nhắn chung trên đầu Home, đồng bộ cho cả hai người.
/// - Chưa ai viết: hiện gợi ý "Viết gì đó cho {tên người kia}".
/// - Đã xóa trắng: ẩn chữ nhưng vẫn giữ vùng chạm để viết lại.
class HomeSharedNoteHeader extends StatefulWidget {
  const HomeSharedNoteHeader({
    super.key,
    required this.houseId,
    required this.partnerName,
    this.service,
    this.uid,
  });

  final String houseId;
  final String partnerName;
  final HomeSharedNoteService? service;

  /// Mặc định lấy UID đang đăng nhập; test truyền sẵn.
  final String? uid;

  @override
  State<HomeSharedNoteHeader> createState() => _HomeSharedNoteHeaderState();
}

class _HomeSharedNoteHeaderState extends State<HomeSharedNoteHeader> {
  late HomeSharedNoteService _service;
  StreamSubscription<HomeSharedNote?>? _sub;
  Timer? _retryTimer;
  HomeSharedNote? _note;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HomeSharedNoteService();
    _listen();
  }

  @override
  void didUpdateWidget(covariant HomeSharedNoteHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _note = null;
      _loaded = false;
      _listen();
    }
  }

  void _listen() {
    _retryTimer?.cancel();
    _sub?.cancel();
    final houseId = widget.houseId;
    _sub = _service
        .watch(houseId)
        .listen(
          (note) {
            if (!mounted || houseId != widget.houseId) return;
            setState(() {
              _note = note;
              _loaded = true;
            });
          },
          onError: (Object error) {
            debugPrint('[HomeSharedNoteHeader] listen failed: $error');
            if (!mounted) return;
            setState(() => _loaded = true);
            // Lỗi mạng/quyền tạm thời: nghe lại sau ít giây.
            _retryTimer?.cancel();
            _retryTimer = Timer(const Duration(seconds: 10), () {
              if (mounted && houseId == widget.houseId) _listen();
            });
          },
        );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openEditor() async {
    final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final houseId = widget.houseId;
    final result = await showModalBottomSheet<HomeSharedNoteSaveResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HomeSharedNoteEditor(
        service: _service,
        houseId: houseId,
        uid: uid,
        initialText: _note?.text ?? '',
        partnerName: widget.partnerName,
      ),
    );
    if (!mounted || result == null) return;
    final l10n = L10nScope.of(context);
    switch (result.status) {
      case HomeSharedNoteSaveStatus.saved:
        SLNotice.showSuccess(context, l10n.translate('home_note_saved'));
      case HomeSharedNoteSaveStatus.rateLimited:
        SLNotice.showInfo(
          context,
          l10n.format('home_note_rate_limited', {
            'minutes': _minutesUntil(result.retryAt),
          }),
        );
      case HomeSharedNoteSaveStatus.failed:
        SLNotice.showError(context, l10n.translate('home_note_save_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final text = note?.text.trim() ?? '';
    final l10n = L10nScope.of(context);
    final partner = widget.partnerName.trim();

    return Semantics(
      button: true,
      label: text.isEmpty ? l10n.translate('home_note_tap_to_write') : text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _loaded ? _openEditor : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 48,
            minWidth: double.infinity,
          ),
          child: !_loaded
              ? const SizedBox(height: 48)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;

                    if (note == null) {
                      // Câu ngắn giữ đúng bề rộng tự nhiên để cả cụm nằm giữa;
                      // câu dài được phép co lại và tự xuống dòng trong vùng an toàn.
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  l10n.format('home_note_placeholder', {
                                    'name': partner,
                                  }),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    color: SLColors.textSecond,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: SLColors.textSecond.withValues(
                                  alpha: .8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (text.isEmpty) {
                      // Lời nhắn đã bị xóa: không hiện gì nhưng chạm đúng chỗ vẫn sửa được.
                      return const SizedBox(height: 48);
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textPrimary,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

int _minutesUntil(int? epochMs) {
  if (epochMs == null) return 60;
  final diff = epochMs - DateTime.now().millisecondsSinceEpoch;
  return (diff / 60000).ceil().clamp(1, 60);
}

class _HomeSharedNoteEditor extends StatefulWidget {
  const _HomeSharedNoteEditor({
    required this.service,
    required this.houseId,
    required this.uid,
    required this.initialText,
    required this.partnerName,
  });

  final HomeSharedNoteService service;
  final String houseId;
  final String uid;
  final String initialText;
  final String partnerName;

  @override
  State<_HomeSharedNoteEditor> createState() => _HomeSharedNoteEditorState();
}

class _HomeSharedNoteEditorState extends State<_HomeSharedNoteEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  HomeSharedNoteQuota? _quota;
  bool _quotaLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.service
        .readQuota(widget.houseId, widget.uid)
        .then((quota) {
          if (mounted) {
            setState(() {
              _quota = quota;
              _quotaLoaded = true;
            });
          }
        })
        .catchError((Object error) {
          debugPrint('[HomeSharedNoteEditor] quota: $error');
          if (mounted) setState(() => _quotaLoaded = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _remaining {
    final quota = _quota;
    if (quota == null) return HomeSharedNoteService.maxEditsPerWindow;
    return quota.remainingAt(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.service.save(
      houseId: widget.houseId,
      uid: widget.uid,
      text: _controller.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final remaining = _remaining;
    final exhausted = _quotaLoaded && remaining <= 0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: SLColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SLColors.textSecond.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('home_note_edit_title'),
                style: SLTheme.quicksand(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.translate('home_note_edit_rule'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SLColors.textSecond,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: !exhausted,
                enabled: !exhausted && !_saving,
                maxLength: HomeSharedNoteService.maxLength,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SLColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.format('home_note_placeholder', {
                    'name': widget.partnerName.trim(),
                  }),
                  filled: true,
                  fillColor: SLColors.primary.withValues(alpha: .06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    tooltip: l10n.translate('home_note_clear'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: exhausted || _saving
                        ? null
                        : () => _controller.clear(),
                  ),
                ),
              ),
              if (_quotaLoaded)
                Text(
                  exhausted
                      ? l10n.format('home_note_rate_limited', {
                          'minutes': _minutesUntil(_quota?.resetsAt),
                        })
                      : l10n.format('home_note_remaining', {
                          'count': remaining,
                        }),
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: exhausted ? SLColors.primary : SLColors.textSecond,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.translate('home_note_cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                        backgroundColor: SLColors.primary,
                      ),
                      onPressed: exhausted || _saving || !_quotaLoaded
                          ? null
                          : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.translate('home_note_save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
