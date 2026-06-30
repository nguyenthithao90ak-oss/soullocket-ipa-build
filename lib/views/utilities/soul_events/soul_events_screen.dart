import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';

import 'package:soullocket_app/utils/services/widget_service.dart';

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
    if (houseId != null) {
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

  IconData _getEventIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('sinh nhật') || t.contains('sn') || t.contains('birthday')) {
      return Icons.cake_rounded;
    }
    if (t.contains('kỷ niệm') || t.contains('yêu') || t.contains('love') || t.contains('anniversary')) {
      return Icons.favorite_rounded;
    }
    if (t.contains('du lịch') || t.contains('đi chơi') || t.contains('trip') || t.contains('flight')) {
      return Icons.flight_takeoff_rounded;
    }
    if (t.contains('cưới') || t.contains('wedding') || t.contains('marry')) {
      return Icons.favorite_rounded;
    }
    if (t.contains('học') || t.contains('thi') || t.contains('exam') || t.contains('study')) {
      return Icons.school_rounded;
    }
    return Icons.event_note_rounded;
  }

  Widget _buildDDayBadge(int diff, Color color) {
    final isPast = diff < 0;
    final displayDays = diff.abs();
    
    String dDayText;
    Color badgeBgColor;
    Color textColor = Colors.white;
    
    if (diff == 0) {
      dDayText = 'HÔM NAY';
      badgeBgColor = color;
    } else if (isPast) {
      dDayText = 'D+ $displayDays';
      badgeBgColor = SLColors.textSecond.withOpacity(0.15);
      textColor = SLColors.textPrimary;
    } else {
      dDayText = 'D- $displayDays';
      badgeBgColor = color;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: diff >= 0 ? [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Text(
        dDayText,
        style: SLTypography.titleSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_houseId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Sự Kiện & Kỷ Niệm', style: SLTypography.titleLarge.copyWith(color: SLColors.primary, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: SLColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_home_screen_rounded, color: SLColors.secondary, size: 24),
            tooltip: 'Thêm tiện ích ra màn hình',
            onPressed: () async {
              try {
                await WidgetService.requestPinSoulEventWidget();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi yêu cầu ghim Tiện ích Sự kiện & Kỷ niệm!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: SLColors.primary, size: 28),
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      body: SLTheme.background(
        child: StreamBuilder<List<SoulEvent>>(
          stream: SoulEventService().streamEvents(_houseId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final events = snapshot.data!;
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available_rounded, color: SLColors.textSecond.withOpacity(0.3), size: 64),
                    const SizedBox(height: 16),
                    Text('Chưa có sự kiện nào', style: SLTypography.bodyMedium),
                  ],
                ),
              );
            }
            
            // Sort events: pinned first, then by days diff (upcoming first, then past)
            final sortedEvents = List<SoulEvent>.from(events)..sort((a, b) {
              if (a.isPinned != b.isPinned) {
                return a.isPinned ? -1 : 1;
              }
              final diffA = _calculateDaysDiff(a.dateMs);
              final diffB = _calculateDaysDiff(b.dateMs);
              if (diffA >= 0 && diffB >= 0) {
                return diffA.compareTo(diffB);
              } else if (diffA < 0 && diffB < 0) {
                return diffB.compareTo(diffA);
              } else {
                return diffA >= 0 ? -1 : 1;
              }
            });

            return ListView.builder(
              physics: SLResponsive.scrollPhysicsForPlatform(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: sortedEvents.length,
              itemBuilder: (context, index) {
                final event = sortedEvents[index];
                final diff = _calculateDaysDiff(event.dateMs);
                final color = Color(int.tryParse(event.colorHex.replaceFirst('#', '0xFF')) ?? 0xFFFF4D94);
                final date = DateTime.fromMillisecondsSinceEpoch(event.dateMs);
                final dateStr = "${date.day} thg ${date.month}, ${date.year}";

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => SoulEventDetailScreen(houseId: _houseId!, event: event),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: event.isPinned
                          ? Border.all(color: SLColors.warningGold.withOpacity(0.5), width: 1.5)
                          : Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                      boxShadow: event.isPinned 
                          ? [
                              BoxShadow(
                                color: SLColors.warningGold.withOpacity(0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: color.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_getEventIcon(event.title), color: color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: SLTypography.titleMedium.copyWith(
                                        color: SLColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (event.isPinned)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4, right: 8),
                                      child: Icon(Icons.push_pin_rounded, color: SLColors.warningGold, size: 14),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    dateStr, 
                                    style: SLTypography.bodySmall.copyWith(color: SLColors.textSecondary),
                                  ),
                                  if (event.isLunar) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.dark_mode_rounded, color: Colors.amber, size: 9),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Âm lịch', 
                                            style: SLTypography.labelSmall.copyWith(
                                              color: Colors.amber[800], 
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildDDayBadge(diff, color),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
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
