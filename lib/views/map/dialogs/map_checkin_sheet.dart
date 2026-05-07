part of '../map_screen.dart';

extension _MapCheckinSheetExt on _MapScreenState {
  Future<void> _showCheckinSheetDialog({ll.LatLng? selectedPoint}) async {
    final activePoint = selectedPoint ?? _myLiveLocation;
    if (activePoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Chưa có vị trí hiện tại, vui lòng bật vị trí rồi thử lại'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: const BoxDecoration(
            color: Color(0xFF242526),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: SLRadius.pillAll,
                  ),
                ),
              ),
              SLSpacing.h16,
              Text(
                'Check-in vị trí hiện tại',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _kMapPinkDeep,
                ),
              ),
              SLSpacing.h8,
              Text(
                'Toa do: ${_myLiveLocation!.latitude.toStringAsFixed(5)}, ${_myLiveLocation!.longitude.toStringAsFixed(5)}',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[400],
                ),
              ),
              SLSpacing.h16,
              _buildCheckinTextField(
                controller: nameCtrl,
                label: 'Tên địa điểm',
                hint: 'VD: Quán cafe, điểm hẹn, nhà sách...',
                icon: Icons.place_rounded,
              ),
              SLSpacing.h12,
              _buildCheckinTextField(
                controller: noteCtrl,
                label: 'Ghi chú',
                hint: 'Lưu lại kỷ niệm, cảm xúc, điều đặc biệt...',
                icon: Icons.note_alt_rounded,
                maxLines: 2,
              ),
              SLSpacing.h16,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final pinSnapshot =
                        await _mapPinLimitService.getSnapshot(widget.houseId);
                    final isCurrentPlaceAlreadyPinned =
                        pinSnapshot.containsLocation(
                      _myLiveLocation!.latitude,
                      _myLiveLocation!.longitude,
                    );
                    if (pinSnapshot.isFull && !isCurrentPlaceAlreadyPinned) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã đạt tối đa 30 vị trí ghim trên bản đồ. Hãy xoá bớt ghim cũ rồi thử lại.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
                    final name = nameCtrl.text.trim().isEmpty
                        ? 'Check-in của ${widget.myName}'
                        : nameCtrl.text.trim();
                    await _dbRef
                        .child('checkins/${widget.houseId}')
                        .push()
                        .set({
                      'lat': _myLiveLocation!.latitude,
                      'lng': _myLiveLocation!.longitude,
                      'name': name,
                      'note': noteCtrl.text.trim(),
                      'role': widget.myRole,
                      'uid': uid,
                      'author': widget.myName,
                      'ts': DateTime.now().millisecondsSinceEpoch,
                    });

                    DailyQuestService().recordProgress('map_checkin');

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kMapPinkDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text(
                    'Lưu check-in',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

  Widget _buildCheckinTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: SLTheme.quicksand(fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _kMapPinkDeep),
        filled: true,
        fillColor: const Color(0xFFFFF5F8),
        border: OutlineInputBorder(
          borderRadius: SLRadius.lgAll,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
