import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../services/house_service.dart';
import '../../services/travel_planner_service.dart';

class TravelPlannerScreen extends StatefulWidget {
  const TravelPlannerScreen({super.key});

  @override
  State<TravelPlannerScreen> createState() => _TravelPlannerScreenState();
}

class _TravelPlannerScreenState extends State<TravelPlannerScreen> {
  final _houseService = HouseService();
  final _travelService = TravelPlannerService();

  String? _houseId;
  Stream<List<TravelPin>>? _travelPinsStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (!mounted) return;
    setState(() {
      _houseId = houseId;
      _travelPinsStream =
          houseId == null ? null : _travelService.streamTravelPins(houseId);
      _isLoading = false;
    });
  }

  Future<void> _showPinSheet({TravelPin? pin}) async {
    final cityCtrl = TextEditingController(text: pin?.city ?? '');
    final countryCtrl = TextEditingController(text: pin?.country ?? '');
    final noteCtrl = TextEditingController(text: pin?.note ?? '');
    final latCtrl = TextEditingController(
      text: pin == null ? '' : pin.lat.toStringAsFixed(5),
    );
    final lngCtrl = TextEditingController(
      text: pin == null ? '' : pin.lng.toStringAsFixed(5),
    );
    var visited = pin?.visited ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                decoration: const BoxDecoration(
                  color: SLColors.bgCard,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(SLRadius.xl)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: SLColors.border,
                            borderRadius: SLRadius.pillAll,
                          ),
                        ),
                      ),
                      SLSpacing.h16,
                      Text(
                        pin == null
                            ? 'Thêm điểm đến mới'
                            : 'Cập nhật kỷ niệm chuyến đi',
                        style: SLTheme.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                      SLSpacing.h16,
                      _TravelTextField(
                        controller: cityCtrl,
                        label: 'Thành phố',
                        hintText: 'Ví dụ: Đà Lạt',
                      ),
                      SLSpacing.h12,
                      _TravelTextField(
                        controller: countryCtrl,
                        label: 'Quốc gia',
                        hintText: 'Ví dụ: Việt Nam',
                      ),
                      SLSpacing.h12,
                      Row(
                        children: [
                          Expanded(
                            child: _TravelTextField(
                              controller: latCtrl,
                              label: 'Vĩ độ',
                              hintText: '11.9404',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                          SLSpacing.w12,
                          Expanded(
                            child: _TravelTextField(
                              controller: lngCtrl,
                              label: 'Kinh độ',
                              hintText: '108.4583',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SLSpacing.h12,
                      _TravelTextField(
                        controller: noteCtrl,
                        label: 'Ghi chú',
                        hintText: 'Kỷ niệm đẹp ở nơi này...',
                        maxLines: 4,
                      ),
                      SLSpacing.h12,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SLColors.primaryLight,
                          borderRadius: SLRadius.lgAll,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đã ghé thăm địa điểm này',
                                style: SLTheme.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textPrimary,
                                ),
                              ),
                            ),
                            Switch(
                              value: visited,
                              activeThumbColor: SLColors.primaryActive,
                              onChanged: (value) {
                                setModalState(() => visited = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      SLSpacing.h16,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final city = cityCtrl.text.trim();
                            final country = countryCtrl.text.trim();
                            final note = noteCtrl.text.trim();
                            final lat = double.tryParse(latCtrl.text.trim());
                            final lng = double.tryParse(lngCtrl.text.trim());

                            if (_houseId == null ||
                                city.isEmpty ||
                                lat == null ||
                                lng == null) {
                              return;
                            }

                            if (pin == null) {
                              await _travelService.addTravelPin(
                                houseId: _houseId!,
                                lat: lat,
                                lng: lng,
                                city: city,
                                country: country,
                                note: note,
                                visited: visited,
                              );
                            } else {
                              await _travelService.updatePinMemory(
                                houseId: _houseId!,
                                pinId: pin.id,
                                note: note,
                              );
                              await _travelService.toggleVisited(
                                _houseId!,
                                pin.id,
                                visited,
                              );
                            }

                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SLColors.primaryActive,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.lgAll,
                            ),
                          ),
                          child: Text(
                            pin == null ? 'Lưu điểm đến' : 'Cập nhật chuyến đi',
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleVisited(TravelPin pin) async {
    if (_houseId == null) return;
    await _travelService.toggleVisited(_houseId!, pin.id, !pin.visited);
  }

  Future<void> _deletePin(TravelPin pin) async {
    if (_houseId == null) return;
    await _travelService.removeTravelPin(_houseId!, pin.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'Bản đồ hành trình ✈️'),
      floatingActionButton: _houseId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showPinSheet,
              backgroundColor: SLColors.primaryActive,
              foregroundColor: Colors.white,
              label: Text(
                'Thêm điểm đến',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.add_location_alt_rounded),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: SLTheme.defaultGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SLColors.primaryActive,
                  ),
                )
              : _houseId == null
                  ? const _TravelEmptyState(
                      title: 'Chưa tìm thấy tổ ấm',
                      subtitle:
                          'Hãy đăng nhập lại để bắt đầu lưu các chuyến đi chung.',
                      icon: Icons.travel_explore_rounded,
                    )
                  : StreamBuilder<List<TravelPin>>(
                      stream: _travelPinsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !(snapshot.hasData &&
                                (snapshot.data?.isNotEmpty ?? false))) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: SLColors.primaryActive,
                            ),
                          );
                        }

                        final pins = snapshot.data ?? [];
                        final stats = _TravelOverview.fromPins(pins);

                        final showTopLoading =
                            snapshot.connectionState == ConnectionState.waiting;

                        return Stack(
                          children: [
                            Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: _TravelHeroCard(stats: stats),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: _TravelInsightCard(stats: stats),
                                ),
                                Expanded(
                                  child: pins.isEmpty
                                      ? const _TravelEmptyState(
                                          title: 'Chưa có điểm đến nào',
                                          subtitle:
                                              'Thêm thành phố đầu tiên để bắt đầu bản đồ hành trình của hai bạn.',
                                          icon: Icons.map_outlined,
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            100,
                                          ),
                                          itemBuilder: (context, index) {
                                            final pin = pins[index];
                                            return _TravelPinCard(
                                              pin: pin,
                                              onToggleVisited: () =>
                                                  _toggleVisited(pin),
                                              onEdit: () =>
                                                  _showPinSheet(pin: pin),
                                              onDelete: () => _deletePin(pin),
                                            );
                                          },
                                          separatorBuilder: (_, __) =>
                                              SLSpacing.h12,
                                          itemCount: pins.length,
                                        ),
                                ),
                              ],
                            ),
                            if (showTopLoading)
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _TravelHeroCard extends StatelessWidget {
  final _TravelOverview stats;

  const _TravelHeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 2),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bản đồ yêu thương',
                  style: SLTheme.quicksand(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: SLColors.primaryLight,
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  '${stats.visitedPins}/${stats.totalPins} đã ghé',
                  style: SLTheme.quicksand(
                    color: SLColors.primaryActive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h8,
          Text(
            'Lưu những nơi hai bạn đã đi qua, dự định ghé thăm và những kỷ niệm nhỏ ở mỗi điểm dừng.',
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SLColors.textSecondary,
              height: 1.45,
            ),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: _TravelStatPill(
                  label: 'Điểm đến',
                  value: '${stats.totalPins}',
                  color: SLColors.primaryActive,
                  background: SLColors.primaryLight,
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _TravelStatPill(
                  label: 'Quốc gia',
                  value: '${stats.uniqueCountries}',
                  color: SLColors.info,
                  background: SLColors.infoLight,
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _TravelStatPill(
                  label: 'Thành phố',
                  value: '${stats.uniqueCities}',
                  color: SLColors.success,
                  background: SLColors.successLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelInsightCard extends StatelessWidget {
  final _TravelOverview stats;

  const _TravelInsightCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final completion =
        stats.totalPins == 0 ? 0.0 : stats.visitedPins / stats.totalPins;

    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhịp du lịch của hai bạn',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h8,
          LinearProgressIndicator(
            value: completion,
            minHeight: 8,
            borderRadius: SLRadius.pillAll,
            backgroundColor: SLColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(SLColors.primaryActive),
          ),
          SLSpacing.h8,
          Text(
            stats.totalPins == 0
                ? 'Chưa có lịch trình nào được thêm.'
                : stats.visitedPins == stats.totalPins
                    ? 'Tất cả điểm đến hiện tại đã được đánh dấu hoàn thành.'
                    : 'Còn ${stats.totalPins - stats.visitedPins} điểm đến đang chờ hai bạn ghé thăm.',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SLColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelPinCard extends StatelessWidget {
  final TravelPin pin;
  final VoidCallback onToggleVisited;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TravelPinCard({
    required this.pin,
    required this.onToggleVisited,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = pin.ts == 0
        ? 'Vừa thêm'
        : DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(pin.ts),
          );

    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: SLRadius.xlAll,
        border: Border.all(
          color: pin.visited
              ? SLColors.success.withValues(alpha: 0.18)
              : SLColors.primary.withValues(alpha: 0.14),
        ),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pin.visited
                      ? SLColors.successLight
                      : SLColors.primaryLight,
                  borderRadius: SLRadius.lgAll,
                ),
                child: Icon(
                  pin.visited
                      ? Icons.verified_rounded
                      : Icons.location_on_rounded,
                  color:
                      pin.visited ? SLColors.success : SLColors.primaryActive,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.country.isEmpty
                          ? pin.city
                          : '${pin.city}, ${pin.country}',
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      'Lưu ngày $dateText',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pin.visited
                      ? SLColors.successLight
                      : SLColors.warningLight,
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  pin.visited ? 'Đã ghé' : 'Dự định',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: pin.visited ? SLColors.success : SLColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Container(
            width: double.infinity,
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: SLColors.bgSubtle,
              borderRadius: SLRadius.lgAll,
            ),
            child: Text(
              pin.note.isEmpty
                  ? 'Chưa có ghi chú, hãy thêm một kỷ niệm nhỏ cho chuyến đi này.'
                  : pin.note,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SLColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          SLSpacing.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TravelTag(
                label: 'Lat ${pin.lat.toStringAsFixed(3)}',
                icon: Icons.map_outlined,
              ),
              _TravelTag(
                label: 'Lng ${pin.lng.toStringAsFixed(3)}',
                icon: Icons.explore_outlined,
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleVisited,
                  icon: Icon(
                    pin.visited
                        ? Icons.undo_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(pin.visited ? 'Chưa ghé' : 'Đánh dấu đã ghé'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SLColors.primaryActive,
                    side: const BorderSide(color: SLColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
                  ),
                ),
              ),
              SLSpacing.w8,
              IconButton(
                onPressed: onEdit,
                style: IconButton.styleFrom(
                  backgroundColor: SLColors.infoLight,
                  foregroundColor: SLColors.info,
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
              SLSpacing.w8,
              IconButton(
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: SLColors.dangerLight,
                  foregroundColor: SLColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _TravelStatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: SLRadius.lgAll,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          SLSpacing.gapH(2),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TravelTag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SLColors.bgSubtle,
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: SLColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SLColors.textSecondary),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SLColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _TravelTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SLColors.textPrimary,
          ),
        ),
        SLSpacing.h8,
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w700,
            color: SLColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: SLTheme.quicksand(color: SLColors.textTertiary),
            filled: true,
            fillColor: SLColors.bgSubtle,
            border: OutlineInputBorder(
              borderRadius: SLRadius.lgAll,
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _TravelEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TravelEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, size: 44, color: SLColors.primaryActive),
            ),
            SLSpacing.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
            ),
            SLSpacing.h8,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SLColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelOverview {
  final int totalPins;
  final int visitedPins;
  final int uniqueCountries;
  final int uniqueCities;

  const _TravelOverview({
    required this.totalPins,
    required this.visitedPins,
    required this.uniqueCountries,
    required this.uniqueCities,
  });

  factory _TravelOverview.fromPins(List<TravelPin> pins) {
    final visited = pins.where((pin) => pin.visited).toList();
    final countries = visited
        .map((pin) => pin.country.trim())
        .where((country) => country.isNotEmpty)
        .toSet();
    final cities = visited
        .map((pin) => pin.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet();

    return _TravelOverview(
      totalPins: pins.length,
      visitedPins: visited.length,
      uniqueCountries: countries.length,
      uniqueCities: cities.length,
    );
  }
}
