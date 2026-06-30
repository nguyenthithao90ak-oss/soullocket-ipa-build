import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';

import 'soul_event_editor_sheet.dart';

class SoulEventDetailScreen extends StatefulWidget {
  final String houseId;
  final SoulEvent event;

  const SoulEventDetailScreen({super.key, required this.houseId, required this.event});

  @override
  State<SoulEventDetailScreen> createState() => _SoulEventDetailScreenState();
}

class _SoulEventDetailScreenState extends State<SoulEventDetailScreen> {
  late SoulEvent _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  int _calculateDaysDiff(int dateMs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return eventDay.difference(today).inDays;
  }

  void _editEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoulEventEditorSheet(
        houseId: widget.houseId,
        initialEvent: _event,
      ),
    ).then((updated) {
      if (updated is SoulEvent && mounted) {
        setState(() {
          _event = updated;
        });
      }
    });
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: const Text('Sự kiện này sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SoulEventService().deleteEvent(widget.houseId, _event.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = _calculateDaysDiff(_event.dateMs);
    final isPast = diff < 0;
    final displayDays = diff.abs();
    final color = Color(int.tryParse(_event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFFFF4D94);
    final date = DateTime.fromMillisecondsSinceEpoch(_event.dateMs);
    final dateStr = "${date.day} thg ${date.month}, ${date.year}";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: Icon(Icons.edit, color: color), onPressed: _editEvent),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteEvent),
        ],
      ),
      body: SLTheme.background(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _event.title.toLowerCase().contains('sinh nhật') 
                          ? Icons.cake_rounded 
                          : _event.title.toLowerCase().contains('kỷ niệm') 
                              ? Icons.favorite_rounded 
                              : Icons.event_note_rounded, 
                      color: color, 
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _event.title,
                    style: SLTypography.headlineLarge.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dateStr,
                        style: SLTypography.bodyMedium.copyWith(color: SLColors.textSecondary),
                      ),
                      if (_event.isLunar) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Âm lịch', 
                            style: SLTypography.labelSmall.copyWith(
                              color: Colors.amber[800], 
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    '$displayDays',
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      diff == 0
                          ? 'HÔM NAY'
                          : isPast 
                              ? 'NGÀY ĐÃ TRÔI QUA' 
                              : 'NGÀY NỮA',
                      style: SLTypography.titleSmall.copyWith(
                        color: color, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
