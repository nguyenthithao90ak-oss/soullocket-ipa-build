import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/activity_history_service.dart';
import '../../utils/app_error_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bucket List Screen - Visual parity với Web gốc hhaaluutru5h49
/// Màu: gradient hồng #FF9A9E→#FAD0C4→#A18CD1, card trắng glass, btn #d81b60
class BucketListScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const BucketListScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen>
    with TickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();

  List<_ConfettiPiece> _confetti = [];
  late Stream<DatabaseEvent> _bucketStream;
  late AnimationController _confettiCtrl;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _bucketStream = _dbRef.child('houses/${widget.houseId}/bucket').onValue;
    _confettiCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed && mounted) {
              setState(() => _showConfetti = false);
            }
          });
  }

  @override
  void didUpdateWidget(covariant BucketListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _bucketStream = _dbRef.child('houses/${widget.houseId}/bucket').onValue;
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _itemController.dispose();
    super.dispose();
  }

  void _triggerCelebration() {
    final rng = Random();
    setState(() {
      _confetti = List.generate(
          45,
          (_) => _ConfettiPiece(
                x: rng.nextDouble(),
                color: [
                  Colors.pink,
                  Colors.yellow,
                  Colors.cyan,
                  Colors.green,
                  Colors.orange,
                  Colors.purple
                ][rng.nextInt(6)],
                size: 6 + rng.nextDouble() * 8,
                speed: 0.3 + rng.nextDouble() * 0.7,
              ));
      _showConfetti = true;
    });
    _confettiCtrl.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 200), () => HapticFeedback.mediumImpact());
  }

  Future<void> _addItem() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final labelAction = context.tr('util_thm1mcvobu_fc5d40');
    await _dbRef.child('houses/${widget.houseId}/bucket').push().set({
      'a': widget.myName,
      'c': text,
      'ts': now.millisecondsSinceEpoch,
      'time': DateFormat('dd/MM/yyyy').format(now),
      'done': false,
    });

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    ActivityHistoryService.instance.add(
      labelAction,
      houseId: widget.houseId,
      role: role,
    );

    _itemController.clear();
    HapticFeedback.lightImpact();
  }

  void _toggleItem(String key, bool currentDone) {
    _dbRef
        .child('houses/${widget.houseId}/bucket/$key')
        .update({'done': !currentDone});
    if (!currentDone) _triggerCelebration();
  }

  void _deleteItem(String key) {
    final labelAction = context.tr('util_xamtmcbuck_d18916');
    final labelTitle = context.tr('util_xabucketli_47d0b4');
    final existing = _dbRef.child('houses/${widget.houseId}/bucket/$key');
    existing.get().then((snapshot) async {
      if (!snapshot.exists || snapshot.value is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      await ActivityHistoryService.instance.add(
        labelAction,
        houseId: widget.houseId,
        title: labelTitle,
        subtitle: data['c']?.toString() ?? '',
        action: 'delete',
        module: 'bucket_list',
        entityType: 'bucket_item',
        entityId: key,
        sourceLabel: 'Bucket List',
        restorePath: 'houses/${widget.houseId}/bucket/$key',
        restorePayload: data,
      );
      await existing.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, context.tr('util_danhschcng_153531')),
      body: Stack(
        children: <Widget>[
          SLTheme.softCanvasBackdrop(
            baseColor: const Color(0xFFFFF7F7),
            accentColor: const Color(0xFFEC4899),
            secondaryAccent: const Color(0xFF8B5CF6),
            motif: SLCanvasBackdropMotif.sparkles,
            child: SafeArea(
              child: StreamBuilder(
                stream: _bucketStream,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: SLColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: SLSpacing.all16,
                      child: Center(
                        child: SLTheme.emptyStatePanel(
                          icon: Icons.error_outline_rounded,
                          title: context.tr('util_khngticbuc_cb9126'),
                          subtitle:
                              AppErrorMapper.resolve(snapshot.error).message,
                          accentColor: SLColors.danger,
                        ),
                      ),
                    );
                  }

                  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
                  if (snapshot.hasData &&
                      snapshot.data?.snapshot.value != null) {
                    final raw = snapshot.data!.snapshot.value;
                    if (raw is Map) {
                      final data = Map<dynamic, dynamic>.from(raw);
                      items = data.entries
                          .where((e) => e.value is Map)
                          .map((e) => {
                                'key': e.key,
                                ...Map<String, dynamic>.from(e.value as Map)
                              })
                          .toList();
                    }
                    items.sort((a, b) => (a['done'] == true ? 1 : 0)
                        .compareTo(b['done'] == true ? 1 : 0));
                  }

                  final doneCount =
                      items.where((i) => i['done'] == true).length;
                  final total = items.length;
                  final progress = total == 0 ? 0.0 : doneCount / total;

                  return Column(
                    children: <Widget>[
                      _buildProgressCard(
                        doneCount: doneCount,
                        total: total,
                        progress: progress,
                      ),
                      _buildComposer(),
                      Expanded(
                        child: items.isEmpty
                            ? Padding(
                                padding: SLSpacing.all16,
                                child: Center(
                                  child: SLTheme.emptyStatePanel(
                                    icon: Icons.flag_rounded,
                                    title: context.tr('util_chaccnguyn_5c63b7'),
                                    subtitle:
                                        context.tr('util_hythmmtiuc_67a421'),
                                    accentColor: const Color(0xFFEC4899),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => SLSpacing.h12,
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  final isDone = item['done'] == true;
                                  return _buildListItem(item, isDone);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_showConfetti)
            IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (ctx, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        pieces: _confetti,
                        progress: _confettiCtrl.value,
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required int doneCount,
    required int total,
    required double progress,
  }) {
    return SLTheme.softPanel(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: const Color(0xFFF3B1CC).withValues(alpha: 0.48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr('util_hnhtrnhcah_b1ffed'),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      L10nService().format('util_bucket_done_count', {'done': doneCount, 'total': total}),
                      style: SLTheme.quicksand(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.w12,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount / $total',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFF4DCE5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFEC4899),
              ),
            ),
          ),
          if (total > 0 && doneCount == total) ...<Widget>[
            SLSpacing.h8,
            Center(
              child: Text(
                context.tr('util_honthnhttc_75a566'),
                style: SLTheme.quicksand(
                  color: const Color(0xFFBE185D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SLTheme.softPanel(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      borderColor: const Color(0xFFF3B1CC).withValues(alpha: 0.42),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _itemController,
              style: SLTheme.quicksand(
                color: SLTheme.textMain,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: context.tr('util_iumunlmcng_a70228'),
                hintStyle: SLTheme.quicksand(color: SLTheme.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _addItem(),
            ),
          ),
          GestureDetector(
            onTap: _addItem,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: SLTheme.btnGradient),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item, bool isDone) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFFF0FDF4).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFF3B1CC).withValues(alpha: 0.34),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF6A3254).withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => _toggleItem(item['key'], isDone),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDone
                    ? const LinearGradient(
                        colors: <Color>[Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      )
                    : null,
                color: isDone ? null : const Color(0xFFFFF6FA),
                border: isDone
                    ? null
                    : Border.all(color: SLTheme.primary, width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: isDone ? Colors.white : Colors.transparent,
                ),
              ),
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item['c'] ?? '',
                  style: SLTheme.quicksand(
                    color: isDone ? SLTheme.textMuted : SLTheme.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: SLTheme.textMuted,
                    height: 1.35,
                  ),
                ),
                SLSpacing.h6,
                Row(
                  children: <Widget>[
                    SLTheme.authorTag(item['a'] ?? ''),
                    SLSpacing.w8,
                    Text(
                      item['time'] ?? '',
                      style: SLTheme.quicksand(
                        color: SLTheme.textLight,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isDone)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.celebration_rounded,
                  color: Color(0xFF16A34A), size: 18),
            ),
          GestureDetector(
            onTap: () => _deleteItem(item['key']),
            child: const Icon(Icons.delete_outline_rounded,
                color: SLTheme.textLight, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final Color color;
  final double size;
  final double speed;
  _ConfettiPiece(
      {required this.x,
      required this.color,
      required this.size,
      required this.speed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  _ConfettiPainter({required this.pieces, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    for (var p in pieces) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      final y = p.speed * progress * size.height * 1.5;
      final x = p.x * size.width + sin(progress * pi * 4 + p.x * 10) * 20;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x, y), width: p.size, height: p.size * 0.5),
              const Radius.circular(2)),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
