import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../../utils/app_error_mapper.dart';
import '../../core/sl_theme.dart';

// ============================================================
// PHASE 35: DATE SPOT MAP — GRA FULLSTACK
// Backend Service + UI Screen cùng 1 file
// ============================================================

class DateSpotMapService {
  static final DateSpotMapService _i = DateSpotMapService._();
  factory DateSpotMapService() => _i;
  DateSpotMapService._();

  final _db = FirebaseDatabase.instance;

  Future<void> pinDateSpot(
    String houseId, {
    required double lat,
    required double lng,
    required String name,
    required String note,
    String? photoUrl,
  }) async {
    await _db.ref('houses/$houseId/date_spots').push().set({
      'lat': lat,
      'lng': lng,
      'name': name,
      'note': note,
      'photoUrl': photoUrl,
      'ts': ServerValue.timestamp,
    });
  }

  Stream<List<Map<dynamic, dynamic>>> listenToDateSpots(String houseId) {
    return _db.ref('houses/$houseId/date_spots').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return [];
      final data = Map<dynamic, dynamic>.from(raw);
      return data.entries.map((entry) {
        if (entry.value is! Map) {
          return <dynamic, dynamic>{'id': entry.key};
        }
        final item = Map<dynamic, dynamic>.from(entry.value);
        item['id'] = entry.key;
        return item;
      }).toList();
    });
  }

  Stream<List<Map<dynamic, dynamic>>> listenToCheckins(String houseId) {
    return _db.ref('houses/$houseId/checkin').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return [];
      final data = Map<dynamic, dynamic>.from(raw);
      return data.entries.map((entry) {
        if (entry.value is! Map) {
          return <dynamic, dynamic>{'id': entry.key};
        }
        final item = Map<dynamic, dynamic>.from(entry.value);
        item['id'] = entry.key;
        return item;
      }).toList();
    });
  }

  Future<Map<String, double>?> fetchReferenceLocation(String houseId) async {
    final snapshot = await _db.ref('gps/$houseId').get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final points = <Map<String, double>>[];
    for (final value in data.values) {
      if (value is Map) {
        final item = Map<dynamic, dynamic>.from(value);
        final lat = (item['lt'] as num?)?.toDouble();
        final lng = (item['lg'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          points.add({'lat': lat, 'lng': lng});
        }
      }
    }

    if (points.isEmpty) return null;

    final avgLat = points.fold<double>(0, (sum, item) => sum + item['lat']!) /
        points.length;
    final avgLng = points.fold<double>(0, (sum, item) => sum + item['lng']!) /
        points.length;
    return {'lat': avgLat, 'lng': avgLng};
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class DateSpotScreen extends StatefulWidget {
  final String houseId;
  const DateSpotScreen({super.key, required this.houseId});

  @override
  State<DateSpotScreen> createState() => _DateSpotScreenState();
}

class _DateSpotScreenState extends State<DateSpotScreen> {
  final _svc = DateSpotMapService();
  late final Stream<List<_DateSpotEntry>> _spotsStream;

  @override
  void initState() {
    super.initState();
    _spotsStream = _buildSpotsStream();
  }

  Stream<List<_DateSpotEntry>> _buildSpotsStream() {
    return _dbCombineLatest(
      _svc.listenToDateSpots(widget.houseId),
      _svc.listenToCheckins(widget.houseId),
      (savedSpots, checkins) {
        final merged = <_DateSpotEntry>[
          ...savedSpots.map(_mapPinnedSpot),
          ...checkins.map(_mapCheckinSpot),
        ];
        merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return merged;
      },
    );
  }

  _DateSpotEntry _mapPinnedSpot(Map<dynamic, dynamic> raw) {
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    return _DateSpotEntry(
      id: raw['id']?.toString() ?? '',
      title: raw['name']?.toString() ?? 'Địa điểm hẹn hò',
      note: raw['note']?.toString() ?? '',
      emoji: '📍',
      sourceLabel: 'Đã ghim',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (raw['ts'] as num?)?.toInt() ?? 0,
      ),
      lat: lat,
      lng: lng,
    );
  }

  _DateSpotEntry _mapCheckinSpot(Map<dynamic, dynamic> raw) {
    return _DateSpotEntry(
      id: raw['id']?.toString() ?? '',
      title: raw['place']?.toString() ?? 'Check-in chung',
      note: raw['note']?.toString() ?? '',
      emoji: '💑',
      sourceLabel: 'Check-in',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (raw['ts'] as num?)?.toInt() ?? 0,
      ),
      subtitle: raw['a']?.toString(),
    );
  }

  void _showAddSpotDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final noteCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📍 Ghim Thánh Địa Mới',
                  style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
              SLSpacing.h20,
              TextField(
                controller: nameCtrl,
                cursorColor: const Color(0xFFD81B60),
                style: const TextStyle(color: Color(0xFF243041)),
                decoration: InputDecoration(
                  hintText: 'Tên địa điểm...',
                  hintStyle: const TextStyle(color: Color(0xFFB55A73)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.94),
                  border: OutlineInputBorder(
                      borderRadius: SLRadius.mdAll,
                      borderSide: BorderSide.none),
                ),
              ),
              SLSpacing.h12,
              TextField(
                controller: noteCtrl,
                cursorColor: const Color(0xFFD81B60),
                style: const TextStyle(color: Color(0xFF243041)),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Kỷ niệm gì ở đây...',
                  hintStyle: const TextStyle(color: Color(0xFFB55A73)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.94),
                  border: OutlineInputBorder(
                      borderRadius: SLRadius.mdAll,
                      borderSide: BorderSide.none),
                ),
              ),
              SLSpacing.h16,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final note = noteCtrl.text.trim();
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);
                    if (name.isEmpty) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                            content: Text('Nhập tên địa điểm trước nhé')),
                      );
                      return;
                    }

                    final location =
                        await _svc.fetchReferenceLocation(widget.houseId);
                    if (location == null) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Chưa có vị trí thật trong nhà chung. Hãy bật định vị hoặc dùng Điểm Danh trước.',
                          ),
                        ),
                      );
                      return;
                    }

                    await _svc.pinDateSpot(
                      widget.houseId,
                      lat: location['lat']!,
                      lng: location['lng']!,
                      name: name,
                      note: note,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            '📍 Đã ghim thánh địa tình yêu bằng vị trí hiện có'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:
                          RoundedRectangleBorder(borderRadius: SLRadius.mdAll)),
                  child: Text('GHIM VÀO BẢN ĐỒ',
                      style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF0f3460), Color(0xFF16213e), Color(0xFF1a1a2e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: StreamBuilder<List<_DateSpotEntry>>(
            stream: _spotsStream,
            builder: (context, snapshot) {
              final spots = snapshot.data ?? const <_DateSpotEntry>[];
              final totalDistance = _estimateTotalDistance(spots);
              return Column(
                children: [
                  Padding(
                    padding: SLSpacing.all20,
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white)),
                        Expanded(
                            child: Text('Bản Đồ Hẹn Hò 💑',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20))),
                        IconButton(
                            onPressed: _showAddSpotDialog,
                            icon: const Icon(Icons.add_location_alt,
                                color: Colors.pinkAccent, size: 28)),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: SLSpacing.all16,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE94057), Color(0xFF8A2387)]),
                      borderRadius: SLRadius.lgAll,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text('${spots.length}',
                              style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28)),
                          Text('Kỷ niệm',
                              style: SLTheme.quicksand(
                                  color: Colors.white70, fontSize: 12)),
                        ]),
                        Column(children: [
                          Text(
                              '${spots.where((e) => e.sourceLabel == 'Đã ghim').length}',
                              style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28)),
                          Text('Đã ghim',
                              style: SLTheme.quicksand(
                                  color: Colors.white70, fontSize: 12)),
                        ]),
                        Column(children: [
                          Text(totalDistance,
                              style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22)),
                          Text('Hành trình',
                              style: SLTheme.quicksand(
                                  color: Colors.white70, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                  SLSpacing.h16,
                  Expanded(
                    child: spots.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: spots.length,
                            itemBuilder: (ctx, i) => _buildSpotCard(spots[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white38, size: 64),
            SLSpacing.h16,
            Text(
              'Chưa có điểm hẹn nào được lưu. Hãy check-in hoặc ghim một nơi thật để bắt đầu bản đồ hẹn hò.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotCard(_DateSpotEntry spot) {
    final date = DateFormat('dd/MM/yyyy • HH:mm').format(spot.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.2),
              borderRadius: SLRadius.mdAll,
            ),
            child: Center(
                child: Text(spot.emoji, style: const TextStyle(fontSize: 24))),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.title,
                    style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                SLSpacing.h4,
                Text(
                  spot.note.isEmpty
                      ? 'Chưa có ghi chú cho địa điểm này.'
                      : spot.note,
                  style: SLTheme.quicksand(color: Colors.white60, fontSize: 12),
                ),
                SLSpacing.h8,
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildMetaChip(Icons.sell_outlined, spot.sourceLabel),
                    _buildMetaChip(Icons.calendar_today, date),
                    if (spot.subtitle != null && spot.subtitle!.isNotEmpty)
                      _buildMetaChip(Icons.favorite_border, spot.subtitle!),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white38),
        SLSpacing.w4,
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  String _estimateTotalDistance(List<_DateSpotEntry> spots) {
    final located = spots.where((e) => e.lat != null && e.lng != null).toList();
    if (located.length < 2) {
      return located.isEmpty ? '0 km' : '1 điểm';
    }
    double total = 0;
    for (var i = 0; i < located.length - 1; i++) {
      total += _svc.calculateDistance(
        located[i].lat!,
        located[i].lng!,
        located[i + 1].lat!,
        located[i + 1].lng!,
      );
    }
    if (total < 1) {
      return '${(total * 1000).round()} m';
    }
    return '${total.toStringAsFixed(1)} km';
  }
}

class _DateSpotEntry {
  final String id;
  final String title;
  final String note;
  final String emoji;
  final String sourceLabel;
  final DateTime timestamp;
  final String? subtitle;
  final double? lat;
  final double? lng;

  const _DateSpotEntry({
    required this.id,
    required this.title,
    required this.note,
    required this.emoji,
    required this.sourceLabel,
    required this.timestamp,
    this.subtitle,
    this.lat,
    this.lng,
  });
}

Stream<R> _dbCombineLatest<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A first, B second) combiner,
) async* {
  A? latestA;
  B? latestB;
  bool hasA = false;
  bool hasB = false;

  await for (final event in StreamGroup.merge([
    first.map((value) => (true, value)),
    second.map((value) => (false, value)),
  ])) {
    if (event.$1) {
      latestA = event.$2 as A;
      hasA = true;
    } else {
      latestB = event.$2 as B;
      hasB = true;
    }
    if (hasA && hasB) {
      yield combiner(latestA as A, latestB as B);
    }
  }
}

class StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>();
    var completed = 0;

    for (final stream in streams) {
      stream.listen(
        controller.add,
        onError: (Object error) {
          debugPrint(
            '[DateSpot] merged stream failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Không thể tải dữ liệu bản đồ hẹn hò.',
            ).message}',
          );
        },
        onDone: () {
          completed++;
          if (completed == streams.length) {
            controller.close();
          }
        },
      );
    }

    return controller.stream;
  }
}
