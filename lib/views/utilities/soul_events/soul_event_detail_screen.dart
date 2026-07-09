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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: color),
        actions: [
          IconButton(icon: Icon(Icons.edit, color: color), onPressed: _editEvent),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteEvent),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.featured_play_list_rounded, color: color, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              _event.title,
              style: SLTypography.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              DateTime.fromMillisecondsSinceEpoch(_event.dateMs).toString().split(' ')[0],
              style: SLTypography.bodyMedium.copyWith(color: SLColors.textSecondary),
            ),
            const SizedBox(height: 48),
            Text(
              '$displayDays',
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
                letterSpacing: -4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPast ? 'Ngày đã trôi qua' : 'Ngày nữa',
              style: SLTypography.titleLarge.copyWith(color: color.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}
