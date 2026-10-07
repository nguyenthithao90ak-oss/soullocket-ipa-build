import 'package:soullocket_app/utils/money_format.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/house_money_currency.dart';
import '../../utils/app_error_mapper.dart';
import '../../widgets/sl_toast.dart';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/service_locator.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/house_lists/house_list_controller.dart';
import '../../utils/services/house_lists/house_list_d1_client.dart';
import '../../utils/services/offline_cache_service.dart';

class WishlistScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const WishlistScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: context.tr('auth_guide_short'),
      icon: const Icon(
        Icons.info_outline_rounded,
        color: SLColors.primary,
        size: 22,
      ),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('util_danhschcng_153531')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('vault_features_label'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                context.tr(
                  'ui_utilities_save_gifts_or_places_you_want_to_5c0a33',
                ),
              ),
              SizedBox(height: 12),
              Text(
                context.tr('p3_help_how_to_label'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                context.tr(
                  'ui_utilities_click_add_wish_enter_gift_name_attach_dc8dc8',
                ),
              ),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Đã hiểu')),
          ),
        ],
      ),
    );
  }

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _currencySub;
  String _houseCurrency = '';
  int _houseGeneration = 0;
  bool _saving = false;
  // Mốc E: cờ server chọn nguồn RTDB hoặc D1; ghi D1 có revision + idempotency.
  HouseListController? _list;
  final Set<String> _busyKeys = {};

  bool get _isLoading => _list?.loading ?? true;

  /// `null` khi không tải được và chưa có bản nào để hiển thị.
  Map<String, Map<String, dynamic>>? get _data {
    final list = _list;
    if (list == null || (list.error != null && list.items.isEmpty)) {
      return null;
    }
    return list.items;
  }

  String _selectedScope = 'together'; // 'together', 'mine', 'partner'
  String _selectedCategory = 'gift';
  String _selectedPriority = 'normal';

  Map<String, String> get _categoryLabels => {
    'gift': L10nService().translate('ui_utilities_qu_t_ng_76b9a1'),
    'date': L10nService().translate('ui_utilities_h_n_h_4e1f88'),
    'home': L10nService().translate('wishlist_category_home'),
    'dream': L10nService().translate('ui_utilities_c_m_97b826'),
  };

  Map<String, String> get _priorityLabels => {
    'urgent': L10nService().translate('ui_utilities_u_ti_n_cao_830ad8'),
    'normal': L10nService().translate('home_va_74ffe0'),
    'someday': L10nService().translate('p5_later'),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final generation = ++_houseGeneration;
    final houseId = widget.houseId;
    _saving = false;
    _houseCurrency = '';
    _currencySub?.cancel();
    _currencySub = _dbRef
        .child(MoneyFormat.houseCurrencyPath(houseId))
        .onValue
        .listen((event) {
          if (!mounted || generation != _houseGeneration) return;
          setState(
            () => _houseCurrency = MoneyFormat.normalizeCode(
              event.snapshot.value,
            ),
          );
        }, onError: (_) {});
    _list?.dispose();
    _busyKeys.clear();
    // Giữ khóa cache cũ `wishlist_{houseId}` cho chế độ RTDB.
    _list = HouseListController(
      houseId: houseId,
      kind: 'wishlist',
      rtdbLimit: 200,
      rtdbCacheKey: 'wishlist_$houseId',
      client: locator<HouseListD1Client>(),
    )
      ..addListener(_onListChanged)
      ..start();
  }

  void _onListChanged() {
    if (mounted) setState(() {});
  }

  String _writeErrorMessage(Object error) {
    if (error is HouseListLimitException) {
      return context.tr(
        'ui_utilities_wish_list_has_reached_its_limit_maximum_f8e2ef',
      );
    }
    if (error is HouseListConflictException) {
      return context.tr('house_list_conflict_reloaded');
    }
    return AppErrorMapper.resolve(error).message;
  }

  @override
  void didUpdateWidget(covariant WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _loadData();
    }
  }

  Future<void> _addWish() async {
    if (_saving) return;
    final itemText = _itemController.text;
    final priceText = _priceController.text;
    final text = itemText.trim();
    if (text.isEmpty) return;
    if (_data != null && _data!.length >= 50) {
      SLToast.show(
        context,
        context.tr(
          'ui_utilities_wish_list_has_reached_its_limit_maximum_f8e2ef',
        ),
      );
      return;
    }
    final price = priceText.trim().isEmpty
        ? 0
        : MoneyFormat.parseWholeAmount(priceText);
    if (price == null) {
      SLToast.show(context, context.tr('util_nhpstinhpl_99919c'));
      return;
    }
    final generation = _houseGeneration;
    final houseId = widget.houseId;
    final author = widget.myName;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scope = _selectedScope;
    final category = _selectedCategory;
    final priority = _selectedPriority;
    bool isCurrent() =>
        mounted &&
        generation == _houseGeneration &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    _saving = true;
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (!isCurrent()) return;
      final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      final code = await HouseMoneyCurrency.ensure(
        root: _dbRef,
        houseId: houseId,
        isCurrent: isCurrent,
      );
      if (!isCurrent()) return;
      setState(() => _houseCurrency = code);
      final record = <String, Object?>{
        'a': author,
        'by': role,
        'scope': scope,
        'category': category,
        'priority': priority,
        'c': text,
        'est': price,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'done': false,
      };
      final list = _list;
      if (list != null && list.useD1) {
        await list.create(list.newItemId(), record);
      } else {
        await _dbRef.child('houses/$houseId/wishlist').push().set(record);
      }
      if (!mounted || !isCurrent()) return;
      if (_itemController.text == itemText) _itemController.clear();
      if (_priceController.text == priceText) _priceController.clear();
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (mounted && isCurrent()) {
        SLToast.show(context, _writeErrorMessage(error));
      }
    } finally {
      if (generation == _houseGeneration) _saving = false;
    }
  }

  void _toggleDone(String key, bool currentDone) {
    final list = _list;
    if (list != null && list.useD1) {
      unawaited(
        _writeD1(
          list,
          key,
          () => list.patch(key, {
            'done': !currentDone,
            'updatedTs': DateTime.now().millisecondsSinceEpoch,
          }),
        ),
      );
      return;
    }
    _dbRef.child('houses/${widget.houseId}/wishlist/$key').update({
      'done': !currentDone,
      'updatedTs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _writeD1(
    HouseListController list,
    String key,
    Future<Object?> Function() write,
  ) async {
    if (_busyKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));
    try {
      await write();
    } catch (error) {
      if (mounted && identical(list, _list)) {
        SLToast.show(context, _writeErrorMessage(error));
      }
    } finally {
      if (mounted && identical(list, _list)) {
        setState(() => _busyKeys.remove(key));
      }
    }
  }

  void _deleteWish(String key) {
    showDialog(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_delete_the_wish_7675cb')),
        content: Text(
          context.tr('ui_utilities_are_you_sure_you_want_to_delete_62ee99'),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Huỷ')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              Navigator.pop(ctx);
              final list = _list;
              if (list != null && list.useD1) {
                unawaited(_writeD1(list, key, () => list.remove(key)));
              } else {
                _dbRef.child('houses/${widget.houseId}/wishlist/$key').remove();
              }
            },

            child: Text(context.tr('ui_utilities_delete_82339c')),
          ),
        ],
      ),
    );
  }

  NumberFormat get _currencyFormat =>
      MoneyFormat.forCurrency(_houseCurrency.isEmpty ? 'VND' : _houseCurrency);

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
    _list?.dispose();
    _currencySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(
        context,
        context.tr('util_wishlisti_b2581f'),
        actions: [_buildInfoIcon(context)],
      ),
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
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
            title: context.tr('p5_notif_detail_category'),
            options: _categoryLabels,
            selectedValue: _selectedCategory,
            onSelected: (value) => setState(() => _selectedCategory = value),
          ),
          SLSpacing.h10,
          _buildWishOptionRow(
            title: context.tr('home_utin_52f79f'),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
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
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
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
            color: isSelected ? SLColors.primaryLight : SLColors.bgCard,
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
          children: options.entries
              .map((entry) {
                final selected = selectedValue == entry.key;
                final accent = colorFor?.call(entry.key) ?? SLColors.primary;
                return GestureDetector(
                  onTap: () => onSelected(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
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
              })
              .toList(growable: false),
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
        .map(
          (e) => {'key': e.key, ...Map<String, dynamic>.from(e.value as Map)},
        )
        .toList();
    var items = allItems
        .where(
          (item) => item['scope'] == _selectedScope || item['scope'] == null,
        )
        .toList();
    items.sort((a, b) {
      if (a['done'] == true && b['done'] != true) return 1;
      if (a['done'] != true && b['done'] == true) return -1;
      final priorityCompare = _priorityRank(
        b['priority']?.toString(),
      ).compareTo(_priorityRank(a['priority']?.toString()));
      if (priorityCompare != 0) return priorityCompare;
      return (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0);
    });

    final int totalCount = allItems.length;
    final int doneCount = allItems.where((item) => item['done'] == true).length;
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
                  border: Border.all(
                    color: SLColors.warning.withValues(alpha: 0.50),
                  ),
                ),
                child: const Icon(
                  Icons.local_mall_rounded,
                  color: SLColors.warning,
                  size: 28,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      L10nScope.of(context).format(
                        'ui_utilities_value1_wishes_in_the_list_e88ad5',
                        {'value1': totalCount},
                      ),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      L10nScope.of(context).format(
                        'ui_utilities_value1_items_completed_value2_7b816b',
                        {
                          'value1': doneCount,
                          'value2': _currencyFormat.format(totalPrice),
                        },
                      ),
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
              SLTheme.chip(
                L10nScope.of(
                  context,
                ).format('wishlist_completed_count', {'count': doneCount}),
                SLColors.success,
              ),
            ],
          ),
          SLSpacing.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: SLColors.warningLight,
              valueColor: const AlwaysStoppedAnimation<Color>(SLColors.success),
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr(
              'ui_utilities_high_priority_will_be_given_first_to_f4b6ce',
            ),
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
                color: isDone ? SLColors.success : SLColors.bgCard,
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
              border: Border.all(
                color: SLColors.warning.withValues(alpha: 0.42),
              ),
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
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SLColors.warningLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: SLColors.warning.withValues(alpha: 0.45),
                          ),
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
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: SLTheme.textLight,
              size: 21,
            ),
            onPressed: () => _deleteWish(item['key']),
          ),
        ],
      ),
    );
  }
}
