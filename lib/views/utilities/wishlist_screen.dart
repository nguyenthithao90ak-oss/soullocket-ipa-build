import 'dart:async';

import 'package:flutter/material.dart';
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
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late Stream<DatabaseEvent> _wishlistStream;

  String _selectedScope = 'together'; // 'together', 'mine', 'partner'

  @override
  void initState() {
    super.initState();
    _wishlistStream = _dbRef.child('houses/${widget.houseId}/wishlist').onValue;
  }

  @override
  void didUpdateWidget(covariant WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _wishlistStream =
          _dbRef.child('houses/${widget.houseId}/wishlist').onValue;
    }
  }

  Future<void> _addWish() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    final priceText = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final price = int.tryParse(priceText) ?? 0;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final role = prefs.getString('il_role') ?? 'user1';

    final now = DateTime.now();
    await _dbRef.child('houses/${widget.houseId}/wishlist').push().set({
      'a': widget.myName,
      'by': role,
      'scope': _selectedScope,
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
    _dbRef.child('houses/${widget.houseId}/wishlist/$key').remove();
  }

  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'Wishlist đôi'),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFF8EC),
        accentColor: const Color(0xFFF59E0B),
        secondaryAccent: const Color(0xFFEC4899),
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
      borderColor: const Color(0xFFF6C16A).withValues(alpha: 0.50),
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
                    colors: <Color>[Color(0xFFF59E0B), Color(0xFFEC4899)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
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
                      'Điều ước mới',
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      'Lưu món đồ hoặc mục tiêu hai bạn muốn mua.',
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
              _buildScopeBtn('Cùng nhau', 'together'),
              SLSpacing.w8,
              _buildScopeBtn('Của tôi', 'mine'),
              SLSpacing.w8,
              _buildScopeBtn('Cho người ấy', 'partner'),
            ],
          ),
          SLSpacing.h16,
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _buildWishTextField(
                  controller: _itemController,
                  hintText: 'Tên món đồ...',
                ),
              ),
              SLSpacing.w8,
              Expanded(
                child: _buildWishTextField(
                  controller: _priceController,
                  hintText: 'Giá',
                  keyboardType: TextInputType.number,
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
                      colors: <Color>[Color(0xFFF59E0B), Color(0xFFEC4899)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.22),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF6C16A).withValues(alpha: 0.46)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: const Color(0xFFEC4899),
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
                isSelected ? const Color(0xFFFFEDF4) : const Color(0xFFFFFAF1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFEC4899).withValues(alpha: 0.42)
                  : const Color(0xFFF6C16A).withValues(alpha: 0.34),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: isSelected ? const Color(0xFFBE185D) : SLColors.textSecond,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWishList() {
    return StreamBuilder(
      stream: _wishlistStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SLColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: SLSpacing.all16,
            child: Center(
              child: SLTheme.emptyStatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Không tải được wishlist',
                subtitle: 'Không tải được danh sách lúc này. Hãy thử lại sau.',
                accentColor: SLColors.danger,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Padding(
            padding: SLSpacing.all16,
            child: Center(
              child: SLTheme.emptyStatePanel(
                icon: Icons.shopping_bag_rounded,
                title: 'Chưa có điều ước nào',
                subtitle: 'Thêm món đầu tiên để hai bạn cùng lên kế hoạch nhé.',
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
          );
        }

        final data =
            Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final allItems = data.entries
            .map((e) => {'key': e.key, ...Map<String, dynamic>.from(e.value)})
            .toList();
        var items = allItems
            .where((item) =>
                item['scope'] == _selectedScope || item['scope'] == null)
            .toList();
        items.sort(
            (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));

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
                title: 'Mục này đang trống',
                subtitle: 'Hãy đổi nhóm hoặc thêm điều ước mới vào nhóm này.',
                accentColor: const Color(0xFFEC4899),
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
      },
    );
  }

  Widget _buildWishlistSummary({
    required int totalCount,
    required int doneCount,
    required int totalPrice,
  }) {
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: const Color(0xFFF6C16A).withValues(alpha: 0.50),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFF59E0B).withValues(alpha: 0.24),
                  const Color(0xFFEC4899).withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: const Color(0xFFF6C16A).withValues(alpha: 0.50)),
            ),
            child: const Icon(Icons.local_mall_rounded,
                color: Color(0xFFB45309), size: 28),
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
          SLTheme.chip('$doneCount xong', const Color(0xFF16A34A)),
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
            ? const Color(0xFFF0FDF4).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFF6C16A).withValues(alpha: 0.30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C4A03).withValues(alpha: 0.07),
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
                    isDone ? const Color(0xFF16A34A) : const Color(0xFFFFFAF1),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF6C16A).withValues(alpha: 0.72),
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
              color: const Color(0xFFFFF4DB),
              border:
                  Border.all(color: const Color(0xFFF6C16A).withValues(alpha: 0.42)),
            ),
            child: Icon(
              isDone ? Icons.done_all_rounded : Icons.card_giftcard_rounded,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFB45309),
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
                    if (price > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4DB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFF6C16A).withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          _currencyFormat.format(price),
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            color: const Color(0xFFB45309),
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
