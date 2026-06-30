import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/offline_cache_service.dart';

class WishlistScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const WishlistScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: 'Hướng dẫn',
      icon: const Icon(Icons.info_outline_rounded, color: SLColors.primary, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Danh sách Ước nguyện',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Lưu lại những món quà hoặc những nơi bạn muốn đi để người ấy biết.\n- Tạo bất ngờ bằng cách âm thầm đánh dấu "Đã mua tặng".'),
              SizedBox(height: 12),
              Text('Cách sử dụng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('- Bấm Thêm điều ước, nhập tên món quà, đính kèm hình ảnh và link mua hàng.\n- Nửa kia có thể vào xem và bấm nút Thực hiện điều ước để tặng bạn một sự bất ngờ.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _sub;
  Map<dynamic, dynamic>? _data;
  bool _isLoading = true;

  String _selectedScope = 'together'; // 'together', 'mine', 'partner'
  String _selectedCategory = 'gift';
  String _selectedPriority = 'normal';

  final Map<String, String> _categoryLabels = const {
    'gift': 'Quà tặng',
    'date': 'Hẹn hò',
    'home': 'Nhà chung',
    'dream': 'Ước mơ',
  };

  final Map<String, String> _priorityLabels = const {
    'urgent': 'Ưu tiên cao',
    'normal': 'Vừa',
    'someday': 'Để sau',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final cacheKey = 'wishlist_${widget.houseId}';
    final cached = OfflineCacheService.loadCacheSync(cacheKey);
    if (cached != null && cached is Map) {
      _data = Map<dynamic, dynamic>.from(cached);
      _isLoading = false;
    }

    _sub?.cancel();
    _sub = _dbRef.child('houses/${widget.houseId}/wishlist').onValue.listen((event) {
      if (!mounted) return;
      final val = event.snapshot.value;
      if (val is Map) {
        OfflineCacheService.saveCache(cacheKey, val);
        setState(() {
          _data = Map<dynamic, dynamic>.from(val);
          _isLoading = false;
        });
      } else {
        setState(() {
          _data = {};
          _isLoading = false;
        });
      }
    }, onError: (_) {
      if (mounted && _data == null) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _loadData();
    }
  }

  Future<void> _addWish() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    if (_data != null && _data!.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Danh sách điều ước đã đạt giới hạn (tối đa 50 mục). Vui lòng xoá bớt trước khi thêm mới.'),
        backgroundColor: SLColors.danger,
      ));
      return;
    }

    final priceText = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final price = int.tryParse(priceText) ?? 0;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';

    final now = DateTime.now();
    await _dbRef.child('houses/${widget.houseId}/wishlist').push().set({
      'a': widget.myName,
      'by': role,
      'scope': _selectedScope,
      'category': _selectedCategory,
      'priority': _selectedPriority,
      'c': text,
      'est': price,
      'ts': now.millisecondsSinceEpoch,
      'done': false,
    });

    _itemController.clear();
    _priceController.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  void _toggleDone(String key, bool currentDone) {
    _dbRef.child('houses/${widget.houseId}/wishlist/$key').update({
      'done': !currentDone,
      'updatedTs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _deleteWish(String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá điều ước'),
        content: const Text('Bạn có chắc chắn muốn xoá điều ước này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dbRef.child('houses/${widget.houseId}/wishlist/$key').remove();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: L10nService().translate('util_txt_b5407d'));

  int _priorityRank(String? value) {
    switch (value) {
      case 'urgent':
        return 3;
      case 'normal':
        return 2;
      case 'someday':
        return 1;
      default:
        return 2;
    }
  }

  Color _priorityColor(String value) {
    switch (value) {
      case 'urgent':
        return SLColors.danger;
      case 'someday':
        return SLColors.textSecond;
      default:
        return SLColors.primary;
    }
  }

  String _categoryLabel(String? value) {
    return _categoryLabels[value] ?? _categoryLabels['gift']!;
  }

  String _priorityLabel(String? value) {
    return _priorityLabels[value] ?? _priorityLabels['normal']!;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, context.tr('util_wishlisti_b2581f'), actions: [_buildInfoIcon(context)]),
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.bgMain,
        accentColor: SLColors.warning,
        secondaryAccent: SLColors.primary,
        motif: SLCanvasBackdropMotif.sparkles,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildInputArea(),
              Expanded(child: _buildWishList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SLTheme.softPanel(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      borderColor: SLColors.warning.withValues(alpha: 0.50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: <Color>[SLColors.warning, SLColors.primary],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: SLColors.warning.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_bag_rounded,
                    color: Colors.white, size: 22),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr('util_iucmi_46ac75'),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      context.tr('util_lumnhocmct_1fb788'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            children: <Widget>[
              _buildScopeBtn(context.tr('util_cngnhau_592254'), 'together'),
              SLSpacing.w8,
              _buildScopeBtn(context.tr('util_cati_13fe32'), 'mine'),
              SLSpacing.w8,
              _buildScopeBtn(context.tr('util_chongiy_aa30ac'), 'partner'),
            ],
          ),
          SLSpacing.h12,
          _buildWishOptionRow(
            title: 'Nhóm',
            options: _categoryLabels,
            selectedValue: _selectedCategory,
            onSelected: (value) => setState(() => _selectedCategory = value),
          ),
          SLSpacing.h10,
          _buildWishOptionRow(
            title: 'Ưu tiên',
            options: _priorityLabels,
            selectedValue: _selectedPriority,
            onSelected: (value) => setState(() => _selectedPriority = value),
            colorFor: _priorityColor,
          ),
          SLSpacing.h16,
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _buildWishTextField(
                  controller: _itemController,
                  hintText: context.tr('util_tnmn_945dda'),
                  maxLength: 80,
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildWishTextField(
                  controller: _priceController,
                  hintText: context.tr('util_gi_072c1a'),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                ),
              ),
              SLSpacing.w8,
              GestureDetector(
                onTap: _addWish,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[SLColors.warning, SLColors.primary],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: SLColors.primary.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWishTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SLColors.bgMain,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SLColors.warning.withValues(alpha: 0.46)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        cursorColor: SLColors.primary,
        style: SLTheme.quicksand(
          color: SLColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: SLTheme.quicksand(
            color: SLTheme.textMuted,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
          counterText: "",
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildScopeBtn(String label, String value) {
    final isSelected = _selectedScope == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedScope = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected ? SLColors.primaryLight : SLColors.bgCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? SLColors.primary.withValues(alpha: 0.42)
                  : SLColors.warning.withValues(alpha: 0.34),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: isSelected ? SLColors.primaryActive : SLColors.textSecond,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWishOptionRow({
    required String title,
    required Map<String, String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    Color Function(String value)? colorFor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: SLColors.textSecond,
          ),
        ),
        SLSpacing.h6,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final selected = selectedValue == entry.key;
            final accent = colorFor?.call(entry.key) ?? SLColors.primary;
            return GestureDetector(
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.13)
                      : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.58)
                        : SLColors.warning.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? accent : SLColors.textSecond,
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildWishList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SLColors.primary),
      );
    }

    if (_data == null) {
      return Padding(
        padding: SLSpacing.all16,
        child: Center(
          child: SLTheme.emptyStatePanel(
            icon: Icons.error_outline_rounded,
            title: context.tr('util_khngticwis_659dd6'),
            subtitle: context.tr('util_khngticdan_0d77c8'),
            accentColor: SLColors.danger,
          ),
        ),
      );
    }

    if (_data!.isEmpty) {
      return Padding(
        padding: SLSpacing.all16,
        child: Center(
          child: SLTheme.emptyStatePanel(
            icon: Icons.shopping_bag_rounded,
            title: context.tr('util_chaciucno_1000c1'),
            subtitle: context.tr('util_thmmnutinh_30b48b'),
            accentColor: SLColors.warning,
          ),
        ),
      );
    }

    final data = _data!;
    final allItems = data.entries
        .map((e) => {'key': e.key, ...Map<String, dynamic>.from(e.value as Map)})
        .toList();
    var items = allItems
        .where((item) =>
            item['scope'] == _selectedScope || item['scope'] == null)
        .toList();
    items.sort((a, b) {
      if (a['done'] == true && b['done'] != true) return 1;
      if (a['done'] != true && b['done'] == true) return -1;
      final priorityCompare =
          _priorityRank(b['priority']?.toString()).compareTo(
        _priorityRank(a['priority']?.toString()),
      );
      if (priorityCompare != 0) return priorityCompare;
      return (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0);
    });

    final int totalCount = allItems.length;
    final int doneCount =
        allItems.where((item) => item['done'] == true).length;
    final int totalPrice = allItems.fold<int>(
      0,
      (sum, item) => sum + (item['est'] as int? ?? 0),
    );

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: <Widget>[
          _buildWishlistSummary(
            totalCount: totalCount,
            doneCount: doneCount,
            totalPrice: totalPrice,
          ),
          SLSpacing.h12,
          SLTheme.emptyStatePanel(
            icon: Icons.filter_alt_off_rounded,
            title: context.tr('util_mcnyangtrn_18c888'),
            subtitle: context.tr('util_hyinhmhoct_956ce0'),
            accentColor: SLColors.primary,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: items.length + 1,
      separatorBuilder: (_, __) => SLSpacing.h12,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildWishlistSummary(
            totalCount: totalCount,
            doneCount: doneCount,
            totalPrice: totalPrice,
          );
        }

        final item = items[index - 1];
        final isDone = item['done'] == true;
        final price = item['est'] as int? ?? 0;
        return _buildWishCard(item: item, isDone: isDone, price: price);
      },
    );
  }

  Widget _buildWishlistSummary({
    required int totalCount,
    required int doneCount,
    required int totalPrice,
  }) {
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: SLColors.warning.withValues(alpha: 0.50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SLColors.warning.withValues(alpha: 0.24),
                      SLColors.primary.withValues(alpha: 0.14),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border:
                      Border.all(color: SLColors.warning.withValues(alpha: 0.50)),
                ),
                child: const Icon(Icons.local_mall_rounded,
                    color: SLColors.warning, size: 28),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Wishlist đang có $totalCount món',
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      'Hoàn thành $doneCount món • ${_currencyFormat.format(totalPrice)}',
                      style: SLTheme.quicksand(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.w12,
              SLTheme.chip('$doneCount xong', SLColors.success),
            ],
          ),
          SLSpacing.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: SLColors.warningLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(SLColors.success),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Ưu tiên cao sẽ được đưa lên trước để dễ quyết định mua/làm trước.',
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: SLColors.textSecond,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishMetaChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildWishCard({
    required Map<String, dynamic> item,
    required bool isDone,
    required int price,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        color: isDone
            ? SLColors.successLight.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone
              ? SLColors.successLight
              : SLColors.warning.withValues(alpha: 0.30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SLColors.warning.withValues(alpha: 0.07),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => _toggleDone(item['key'], isDone),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isDone ? SLColors.success : SLColors.bgCard,
                border: Border.all(
                  color: isDone
                      ? SLColors.success
                      : SLColors.warning.withValues(alpha: 0.72),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 18,
                color: isDone ? Colors.white : Colors.transparent,
              ),
            ),
          ),
          SLSpacing.w12,
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: SLColors.warningLight,
              border:
                  Border.all(color: SLColors.warning.withValues(alpha: 0.42)),
            ),
            child: Icon(
              isDone ? Icons.done_all_rounded : Icons.card_giftcard_rounded,
              color: isDone ? SLColors.success : SLColors.warning,
              size: 21,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item['c'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? SLTheme.textLight : SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h6,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      item['a'] ?? '',
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        color: SLColors.textSecond,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _buildWishMetaChip(
                      label: _categoryLabel(item['category']?.toString()),
                      icon: Icons.category_rounded,
                      color: SLColors.primary,
                    ),
                    _buildWishMetaChip(
                      label: _priorityLabel(item['priority']?.toString()),
                      icon: Icons.flag_rounded,
                      color: _priorityColor(
                        item['priority']?.toString() ?? 'normal',
                      ),
                    ),
                    if (price > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SLColors.warningLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: SLColors.warning.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          _currencyFormat.format(price),
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            color: SLColors.warning,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: SLTheme.textLight, size: 21),
            onPressed: () => _deleteWish(item['key']),
          ),
        ],
      ),
    );
  }
}
