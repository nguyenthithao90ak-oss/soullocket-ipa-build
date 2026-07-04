import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/soul_event_service.dart';

class SoulEventEditorSheet extends StatefulWidget {
  final String houseId;
  final SoulEvent? initialEvent;

  const SoulEventEditorSheet(
      {super.key, required this.houseId, this.initialEvent});

  @override
  State<SoulEventEditorSheet> createState() => _SoulEventEditorSheetState();
}

class _SoulEventEditorSheetState extends State<SoulEventEditorSheet> {
  late TextEditingController _titleCtrl;
  DateTime _selectedDate = DateTime.now();
  String _selectedColor = '#FF4D94';
  bool _isLunar = false;

  final List<String> _colors = [
    '#FF4D94',
    '#FF8C42',
    '#FF3C38',
    '#A23E48',
    '#6A4C93',
    '#1982C4',
    '#8AC926',
    '#FFCA3A'
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialEvent?.title ?? '');
    if (widget.initialEvent != null) {
      _selectedDate =
          DateTime.fromMillisecondsSinceEpoch(widget.initialEvent!.dateMs);
      _selectedColor = widget.initialEvent!.colorHex;
      _isLunar = widget.initialEvent!.isLunar;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: SLColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;

    final newEvent = SoulEvent(
      id: widget.initialEvent?.id ?? '',
      title: _titleCtrl.text.trim(),
      dateMs: _selectedDate.millisecondsSinceEpoch,
      isLunar: _isLunar,
      category: 'all',
      colorHex: _selectedColor,
      createdAt: widget.initialEvent?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
    );

    await SoulEventService().saveEvent(widget.houseId, newEvent);
    if (mounted) Navigator.pop(context, newEvent);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.initialEvent == null ? 'Sự kiện mới' : 'Sửa sự kiện',
                  style: SLTypography.titleLarge),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: 'VD: Sinh nhật mẹ',
              filled: true,
              fillColor: SLColors.bgMain,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Text('MÀU SẮC',
              style: SLTypography.bodySmall
                  .copyWith(color: SLColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colors.map((hex) {
              final isSelected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 2)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('NGÀY',
              style: SLTypography.bodySmall
                  .copyWith(color: SLColors.textSecondary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: SLColors.bgMain,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: SLColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_selectedDate.toString().split(' ')[0],
                        style: SLTypography.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Hiển thị ngày âm lịch'),
            value: _isLunar,
            onChanged: (val) => setState(() => _isLunar = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: SLColors.primary,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SLColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: const Text('Lưu sự kiện',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
