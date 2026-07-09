part of '../map_screen.dart';

extension _MapCheckinSheetExt on _MapScreenState {
  Future<void> _showCheckinSheetDialog({ll.LatLng? selectedPoint}) async {
    final activePoint = selectedPoint ?? _myLiveLocation;
    if (activePoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('map_chacvtrhin_ccf9e7')),
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
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final bottomPadding = mediaQuery.viewInsets.bottom +
            (mediaQuery.viewPadding.bottom > 0
                ? mediaQuery.viewPadding.bottom + 12
                : 12);
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
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
                  context.tr('map_checkinvtr_07f54d'),
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _kMapPinkDeep,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  'Toạ độ: ${activePoint.latitude.toStringAsFixed(5)}, ${activePoint.longitude.toStringAsFixed(5)}',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                  ),
                ),
                SLSpacing.h16,
                _buildCheckinTextField(
                  controller: nameCtrl,
                  label: context.tr('map_tnaim_ae1e33'),
                  hint: context.tr('map_vdquncafei_701fce'),
                  icon: Icons.place_rounded,
                ),
                SLSpacing.h12,
                _buildCheckinTextField(
                  controller: noteCtrl,
                  label: context.tr('map_ghich_f481f9'),
                  hint: context.tr('map_luliknimcm_f10773'),
                  icon: Icons.note_alt_rounded,
                  maxLines: 2,
                ),
                SLSpacing.h16,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final msgLimitFull = context.tr('map_ttia30vtrg_8875b5');
                      final pinSnapshot =
                          await _mapPinLimitService.getSnapshot(widget.houseId);
                      final isCurrentPlaceAlreadyPinned =
                          pinSnapshot.containsLocation(
                        activePoint.latitude,
                        activePoint.longitude,
                      );
                      if (pinSnapshot.isFull && !isCurrentPlaceAlreadyPinned) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              msgLimitFull,
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
                      final checkinRef =
                          _dbRef.child('checkins/${widget.houseId}').push();
                      await checkinRef.set({
                        'lat': activePoint.latitude,
                        'lng': activePoint.longitude,
                        'name': name,
                        'note': noteCtrl.text.trim(),
                        'role': widget.myRole,
                        'uid': uid,
                        'author': widget.myName,
                        'ts': DateTime.now().millisecondsSinceEpoch,
                      });

                      _listenCheckins();
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
                      context.tr('map_lucheckin_e0a374'),
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
        );
      },
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
