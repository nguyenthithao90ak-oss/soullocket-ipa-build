import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/flexible_date_input.dart';

@immutable
class AnniversaryItemData {
  final String id;
  final String title;
  final String dateLabel;
  final String badge;
  final bool isDeleting;
  final bool canDelete;

  const AnniversaryItemData({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.badge,
    this.isDeleting = false,
    this.canDelete = true,
  });
}

class AnniversaryPanel extends StatelessWidget {
  const AnniversaryPanel({
    super.key,
    required this.nameController,
    required this.dateController,
    required this.items,
    this.title = 'Kỷ niệm',
    this.subtitle =
        'Tách form nhập ngày và danh sách sự kiện để shell chỉ cần nối draft + callback.',
    this.onDateChanged,
    this.onPickDate,
    this.onAdd,
    this.onDelete,
    this.addLabel = 'Thêm',
    this.emptyLabel = 'Chưa có mốc nào trong danh sách.',
  });

  final TextEditingController nameController;
  final TextEditingController dateController;
  final List<AnniversaryItemData> items;
  final String title;
  final String subtitle;
  final ValueChanged<String>? onDateChanged;
  final VoidCallback? onPickDate;
  final VoidCallback? onAdd;
  final ValueChanged<AnniversaryItemData>? onDelete;
  final String addLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5D4E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7D6C79),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InputBox(
                  controller: nameController,
                  hintText: 'Tên sự kiện',
                  icon: Icons.favorite_border_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InputBox(
                  controller: dateController,
                  hintText: 'ngày/tháng/năm',
                  helperText: 'Đang nhập ngày/tháng/năm',
                  icon: Icons.calendar_month_rounded,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: const [FlexibleDateInputFormatter()],
                  onChanged: onDateChanged,
                  trailing: IconButton(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.event_rounded),
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 56,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    addLabel,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8D7A86),
              ),
            )
          else
            Column(
              children: items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBFD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3DDE7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Color(0xFFD81B60),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: SLTheme.quicksand(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF41333C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.dateLabel} • ${item.badge}',
                              style: SLTheme.quicksand(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8A5B76),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.canDelete) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: item.isDeleting || onDelete == null
                              ? null
                              : () => onDelete!(item),
                          icon: item.isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                          color: const Color(0xFFD81B60),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        helperText: helperText,
        prefixIcon: Icon(icon, color: const Color(0xFFD81B60)),
        suffixIcon: trailing,
        filled: true,
        fillColor: const Color(0xFFFFFBFD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF3DDE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF3DDE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD81B60)),
        ),
      ),
      style: SLTheme.quicksand(
        fontSize: 13.2,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF4D3B46),
      ),
    );
  }
}
