import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/home_shared_note_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Lời nhắn chung mới do người ấy viết mà mình chưa mở đọc.
@immutable
class HomePartnerLetter {
  const HomePartnerLetter({required this.text, required this.updatedAt});

  final String text;
  final int updatedAt;
}

typedef HomePartnerLetterWidgetBuilder =
    Widget Function(
      BuildContext context,
      HomePartnerLetter? letter,
      VoidCallback openLetter,
    );

/// Theo dõi `houses/{houseId}/homeNote`: khi người ấy sửa lời nhắn, bé thỏ
/// cầm phong thư cho tới khi mình mở đọc (mốc đã đọc lưu theo máy + UID).
class HomePartnerLetterHost extends StatefulWidget {
  const HomePartnerLetterHost({
    super.key,
    required this.houseId,
    required this.uid,
    required this.partnerName,
    required this.builder,
    this.service,
    this.now,
  });

  final String? houseId;
  final String? uid;
  final String partnerName;
  final HomePartnerLetterWidgetBuilder builder;
  final HomeSharedNoteService? service;

  /// Cho test cố định thời gian.
  final DateTime Function()? now;

  /// Thư quá cũ thì thôi không nhắc nữa.
  static const Duration maxAge = Duration(hours: 24);

  static String seenKey(String uid, String houseId) =>
      'home_note_seen_at_${uid}_$houseId';

  @override
  State<HomePartnerLetterHost> createState() => _HomePartnerLetterHostState();
}

class _HomePartnerLetterHostState extends State<HomePartnerLetterHost> {
  StreamSubscription<HomeSharedNote?>? _sub;
  Timer? _retry;
  HomeSharedNote? _note;
  int _seenAt = 0;
  String? _scope;

  HomeSharedNoteService get _service =>
      widget.service ?? HomeSharedNoteService();

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant HomePartnerLetterHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId || oldWidget.uid != widget.uid) {
      _bind();
    }
  }

  void _bind() {
    _sub?.cancel();
    _retry?.cancel();
    _note = null;
    _seenAt = 0;
    final houseId = widget.houseId?.trim() ?? '';
    final uid = widget.uid?.trim() ?? '';
    if (houseId.isEmpty || uid.isEmpty) {
      _scope = null;
      return;
    }
    final scope = '$uid/$houseId';
    _scope = scope;
    unawaited(_loadSeen(uid, houseId, scope));
    _sub = _service
        .watch(houseId)
        .listen(
          (note) {
            if (!mounted || _scope != scope) return;
            setState(() => _note = note);
          },
          onError: (Object error) {
            debugPrint('[HomePartnerLetterHost] listen failed: $error');
            _retry = Timer(const Duration(seconds: 10), () {
              if (mounted && _scope == scope) _bind();
            });
          },
        );
  }

  Future<void> _loadSeen(String uid, String houseId, String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getInt(HomePartnerLetterHost.seenKey(uid, houseId)) ?? 0;
      if (mounted && _scope == scope && seen > _seenAt) {
        setState(() => _seenAt = seen);
      }
    } catch (error) {
      debugPrint('[HomePartnerLetterHost] load seen failed: $error');
    }
  }

  HomePartnerLetter? get _letter {
    final note = _note;
    final uid = widget.uid?.trim() ?? '';
    if (note == null || uid.isEmpty) return null;
    if (note.updatedBy.isEmpty || note.updatedBy == uid) return null;
    if (note.text.trim().isEmpty || note.updatedAt <= _seenAt) return null;
    final now = (widget.now ?? DateTime.now)().millisecondsSinceEpoch;
    if (now - note.updatedAt > HomePartnerLetterHost.maxAge.inMilliseconds) {
      return null;
    }
    return HomePartnerLetter(text: note.text.trim(), updatedAt: note.updatedAt);
  }

  Future<void> _markSeen(int updatedAt) async {
    final houseId = widget.houseId?.trim() ?? '';
    final uid = widget.uid?.trim() ?? '';
    if (houseId.isEmpty || uid.isEmpty) return;
    if (mounted) setState(() => _seenAt = updatedAt);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        HomePartnerLetterHost.seenKey(uid, houseId),
        updatedAt,
      );
    } catch (error) {
      debugPrint('[HomePartnerLetterHost] save seen failed: $error');
    }
  }

  Future<void> _open() async {
    final letter = _letter;
    if (letter == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PartnerLetterSheet(letter: letter, partnerName: widget.partnerName),
    );
    await _markSeen(letter.updatedAt);
  }

  @override
  void dispose() {
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _letter, () => unawaited(_open()));
}

class _PartnerLetterSheet extends StatelessWidget {
  const _PartnerLetterSheet({required this.letter, required this.partnerName});

  final HomePartnerLetter letter;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: SLColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
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
            const SizedBox(height: 18),
            const Center(child: Text('💌', style: TextStyle(fontSize: 40))),
            const SizedBox(height: 8),
            Text(
              l10n.format('companion_letter_title', {
                'name': partnerName.trim(),
              }),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecond,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SLColors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                letter.text,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                backgroundColor: SLColors.primary,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.translate('companion_letter_close')),
            ),
          ],
        ),
      ),
    );
  }
}
