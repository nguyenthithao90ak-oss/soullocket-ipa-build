import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';
import '../../services/activity_history_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

class LocationDiaryScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const LocationDiaryScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<LocationDiaryScreen> createState() => _LocationDiaryScreenState();
}

class _LocationDiaryScreenState extends State<LocationDiaryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _checkins = [];
  StreamSubscription<DatabaseEvent>? _checkinSubscription;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  void _loadCheckins() {
    _checkinSubscription = _dbRef
        .child('houses/${widget.houseId}/checkin')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final data = Map<dynamic, dynamic>.from(raw);
        final List<Map<String, dynamic>> loaded = [];
        data.forEach((key, value) {
          if (value is! Map) return;
          final item = Map<String, dynamic>.from(value);
          item['id'] = key;
          loaded.add(item);
        });
        loaded.sort(
            (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
        if (mounted) setState(() => _checkins = loaded);
      } else {
        if (mounted) setState(() => _checkins = []);
      }
    });
  }

  @override
  void dispose() {
    _checkinSubscription?.cancel();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addCheckin() async {
    final place = _placeController.text.trim();
    final note = _noteController.text.trim();
    if (place.isEmpty) return;

    try {
      await _dbRef.child('houses/${widget.houseId}/checkin').push().set({
        'a': widget.myName,
        'place': place,
        'note': note,
        'ts': ServerValue.timestamp,
        'time': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      });
      if (!mounted) return;

      _placeController.clear();
      _noteController.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã Check-in thành công! 📍')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm check-in: $e')),
        );
      }
    }
  }

  Future<void> _deleteCheckin(String id) async {
    try {
      final ref = _dbRef.child('houses/${widget.houseId}/checkin/$id');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        await ActivityHistoryService.instance.add(
          'đã xóa một check-in',
          houseId: widget.houseId,
          title: 'Đã xóa check-in',
          subtitle: data['place']?.toString() ?? '',
          action: 'delete',
          module: 'location_diary',
          entityType: 'checkin',
          entityId: id,
          sourceLabel: 'Nhật ký địa điểm',
          restorePath: 'houses/${widget.houseId}/checkin/$id',
          restorePayload: data,
        );
      }
      await ref.remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa check-in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'NHẬT KÝ ĐỊA ĐIỂM',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildInputArea(),
              Expanded(child: _buildCheckinList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all20,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Lưu lại những nơi hai bạn đã cùng nhau đi qua. 👣',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          SLSpacing.h20,
          _buildTextField(_placeController, 'Tên địa điểm (VD: Hồ Gươm)...',
              Icons.location_on),
          SLSpacing.h8,
          _buildTextField(
              _noteController, 'Ghi chú kỷ niệm (tuỳ chọn)...', Icons.notes,
              maxLines: 2),
          SLSpacing.h16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                elevation: 0,
              ),
              onPressed: _addCheckin,
              child: Text(
                'CHECK-IN NGAY',
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF11998e),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: SLRadius.lgAll,
        border: Border.all(
          color: const Color(0xFFFF8AA0).withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: const Color(0xFFD81B60),
        style: SLTheme.quicksand(
          color: const Color(0xFF243041),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(color: const Color(0xFFB55A73)),
          prefixIcon: Icon(icon, color: const Color(0xFFD81B60)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCheckinList() {
    return _checkins.isEmpty
        ? Center(
            child: Text('Chưa có địa điểm check-in nào.',
                style: SLTheme.quicksand(
                    color: Colors.white70, fontWeight: FontWeight.w600)))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _checkins.length,
            itemBuilder: (context, index) {
              final item = _checkins[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FastBackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: SLSpacing.all16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.map_outlined,
                                color: Colors.white),
                          ),
                          SLSpacing.w16,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['place'] ?? '',
                                  style: SLTheme.quicksand(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16),
                                ),
                                if ((item['note'] ?? '').isNotEmpty)
                                  Text(
                                    item['note'],
                                    style: SLTheme.quicksand(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                SLSpacing.h4,
                                Text(
                                  '👣 ${item['a']} • ${item['time']}',
                                  style: SLTheme.quicksand(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white30, size: 20),
                            onPressed: () => _deleteCheckin(item['id']),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }
}
