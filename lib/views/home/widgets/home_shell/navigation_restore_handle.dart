import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../utils/services/l10n_service.dart';

/// Hướng dẫn thao tác giao diện chung trên máy, không chứa dữ liệu tài khoản.
class NavigationRestoreHandle extends StatefulWidget {
  const NavigationRestoreHandle({
    super.key,
    required this.onRestore,
    required this.accent,
  });

  static const learnedKey = 'il_nav_restore_learned_v1';
  final VoidCallback onRestore;
  final Color accent;

  @override
  State<NavigationRestoreHandle> createState() =>
      _NavigationRestoreHandleState();
}

class _NavigationRestoreHandleState extends State<NavigationRestoreHandle> {
  bool _showHint = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    var learned = false;
    try {
      learned =
          (await SharedPreferences.getInstance()).getBool(
            NavigationRestoreHandle.learnedKey,
          ) ??
          false;
    } catch (_) {
      // Không để lỗi bộ nhớ cục bộ chặn nút hiện lại thanh điều hướng.
    }
    if (mounted && !_restoring) setState(() => _showHint = !learned);
  }

  Future<void> _remember() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(
        NavigationRestoreHandle.learnedKey,
        true,
      );
    } catch (_) {
      // Có thể hướng dẫn lại lần sau nếu không lưu được; vẫn mở thanh ngay.
    }
  }

  void _restore() {
    if (_restoring) return;
    _restoring = true;
    // Chỉ ghi nhận sau thao tác thật, không tính lúc mới hiển thị lời nhắc.
    unawaited(_remember());
    widget.onRestore();
  }

  @override
  Widget build(BuildContext context) {
    final label = context.tr('nav_restore_action');
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showHint)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6C9D2)),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .32,
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          context.tr('nav_restore_hint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF51434B),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < 0) _restore();
                },
                child: Tooltip(
                  message: label,
                  child: Material(
                    color: const Color(0xFFFFFCF8),
                    shape: const StadiumBorder(
                      side: BorderSide(color: Color(0xFFE6C9D2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _restore,
                      child: Semantics(
                        button: true,
                        label: label,
                        excludeSemantics: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 64,
                            minHeight: 48,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: widget.accent,
                                ),
                                if (_showHint &&
                                    MediaQuery.sizeOf(context).height >= 420)
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF51434B),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
