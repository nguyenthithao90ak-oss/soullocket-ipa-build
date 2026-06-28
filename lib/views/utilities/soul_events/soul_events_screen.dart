import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';

import 'soul_event_detail_screen.dart';
import 'soul_event_editor_sheet.dart';

class SoulEventsScreen extends StatefulWidget {
  const SoulEventsScreen({super.key});

  @override
  State<SoulEventsScreen> createState() => _SoulEventsScreenState();
}

class _SoulEventsScreenState extends State<SoulEventsScreen> {
  String? _houseId;

  @override
  void initState() {
    super.initState();
    _loadHouseId();
  }

  Future<void> _loadHouseId() async {
    final houseId = await HouseService().getCurrentHouseId();
    if (mounted) {
      setState(() {
        _houseId = houseId;
      });
    }
  }

  int _calculateDaysDiff(int dateMs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return eventDay.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (_houseId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: SLColors.bgMain,
      appBar: AppBar(
        title: Text('Sự Kiện & Kỷ Niệm', style: SLTypography.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: SLColors.primary, size: 28),
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      body: StreamBuilder<List<SoulEvent>>(
        stream: SoulEventService().streamEvents(_houseId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          if (events.isEmpty) {
            return Center(child: Text('Chưa có sự kiện nào', style: SLTypography.bodyMedium));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final diff = _calculateDaysDiff(event.dateMs);
              final isPast = diff < 0;
              final displayDays = diff.abs();
              
              final color = Color(int.tryParse(event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFFFF4D94);

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SoulEventDetailScreen(houseId: _houseId!, event: event))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.event_note_rounded, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: SLTypography.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              DateTime.fromMillisecondsSinceEpoch(event.dateMs).toString().split(' ')[0], 
                              style: SLTypography.bodySmall.copyWith(color: SLColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$displayDays', style: SLTypography.displayLarge.copyWith(color: color, height: 1.0)),
                          Text(isPast ? 'Ngày trước' : 'Ngày nữa', style: SLTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(SoulEvent? event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoulEventEditorSheet(houseId: _houseId!, initialEvent: event),
    );
  }
}
