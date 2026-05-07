import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/sl_theme.dart';
import '../../services/l10n_service.dart';

/// Finance Screen - Visual parity 100% với Web gốc hhaaluutru5h49
/// Card trắng glass, màu #d81b60, gradient hồng, list-item CSS
class FinanceScreen extends StatefulWidget {
  final String houseId;
  final String myName;
  const FinanceScreen({super.key, required this.houseId, required this.myName});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _goalAmountController = TextEditingController();
  final TextEditingController _goalDaysController = TextEditingController();
  final TextEditingController _savingsGoalNameController =
      TextEditingController();
  final TextEditingController _savingsGoalAmountController =
      TextEditingController();
  final TextEditingController _splitAmountController = TextEditingController();
  final TextEditingController _splitPeopleController =
      TextEditingController(text: '2');

  String _transactionType = 'out';
  String _category = '🍜 Ăn uống';
  int _totalBalance = 0, _totalIn = 0, _totalOut = 0;

  Map<String, dynamic>? _budgetPlan;
  Map<String, dynamic>? _savingsGoal;
  List<Map<String, dynamic>> _allTransactions = [];
  String _transactionSignature = '';
  late final Stream<DatabaseEvent> _budgetStream;
  StreamSubscription<DatabaseEvent>? _budgetPlanSub;
  StreamSubscription<DatabaseEvent>? _savingsGoalSub;

  final List<String> _categories = [
    '🍜 Ăn uống',
    '🎬 Giải trí',
    '🎁 Quà cáp',
    '💒 Hẹn hò',
    '🏠 Sinh hoạt',
    '✈️ Du lịch',
    '💊 Thuốc men',
    '📦 Khác'
  ];
  final _fmt =
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _budgetStream = _dbRef.child('houses/${widget.houseId}/budget').onValue;
    _loadBudgetPlan();
    _loadSavingsGoal();
  }

  void _loadBudgetPlan() {
    _budgetPlanSub?.cancel();
    _budgetPlanSub = _dbRef
        .child('houses/${widget.houseId}/finance_plan')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (event.snapshot.exists && raw is Map && mounted) {
        setState(() {
          _budgetPlan = Map<String, dynamic>.from(raw);
        });
      } else if (mounted) {
        setState(() {
          _budgetPlan = null;
        });
      }
    });
  }

  void _loadSavingsGoal() {
    _savingsGoalSub?.cancel();
    _savingsGoalSub = _dbRef
        .child('houses/${widget.houseId}/savings_goal')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (event.snapshot.exists && raw is Map && mounted) {
        setState(() {
          _savingsGoal = Map<String, dynamic>.from(raw);
        });
      } else if (mounted) {
        setState(() {
          _savingsGoal = null;
        });
      }
    });
  }

  void _saveBudgetPlan() {
    final amount = int.tryParse(
        _goalAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final days = int.tryParse(_goalDaysController.text);
    if (amount == null || days == null || days <= 0) return;

    final now = DateTime.now();
    _dbRef.child('houses/${widget.houseId}/finance_plan').set({
      'targetAmount': amount,
      'targetDays': days,
      'createdAt': now.millisecondsSinceEpoch,
      'startDate': DateFormat('yyyy-MM-dd').format(now),
    });
    _goalAmountController.clear();
    _goalDaysController.clear();
    Navigator.pop(context);
  }

  void _saveSavingsGoal() {
    final amount = int.tryParse(
        _savingsGoalAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final name = _savingsGoalNameController.text.trim();
    if (amount == null || amount <= 0 || name.isEmpty) return;

    final now = DateTime.now();
    _dbRef.child('houses/${widget.houseId}/savings_goal').set({
      'name': name,
      'targetAmount': amount,
      'createdAt': now.millisecondsSinceEpoch,
    });
    _savingsGoalAmountController.clear();
    _savingsGoalNameController.clear();
    Navigator.pop(context);
  }

  void _resetSavingsGoal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa Quỹ? 🧨',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: Text('Bạn có chắc chắn muốn xóa mục tiêu quỹ chung này?',
            style: SLTheme.quicksand(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              _dbRef.child('houses/${widget.houseId}/savings_goal').remove();
              Navigator.pop(ctx);
            },
            child: Text(L10nService().translate('Xóa'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _resetBudgetPlan() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa kế hoạch? 🧨',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: Text('Bạn có chắc chắn muốn xóa kế hoạch chi tiêu hiện tại?',
            style: SLTheme.quicksand(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              _dbRef.child('houses/${widget.houseId}/finance_plan').remove();
              Navigator.pop(ctx);
            },
            child: Text(L10nService().translate('Xóa'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addTransaction() {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nhập số tiền hợp lệ!',
            style: SLTheme.quicksand(fontWeight: FontWeight.w700)),
        backgroundColor: SLTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final now = DateTime.now();
    _dbRef.child('houses/${widget.houseId}/budget').push().set({
      'from': widget.myName,
      'amount': amount,
      'type': _transactionType,
      'category': _category,
      'note': _noteController.text.trim(),
      'ts': now.millisecondsSinceEpoch,
      'time': DateFormat('dd/MM, HH:mm').format(now),
    });
    _amountController.clear();
    _noteController.clear();
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
  }

  void _deleteTransaction(String key) =>
      _dbRef.child('houses/${widget.houseId}/budget/$key').remove();

  void _showSplitBillDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final mediaQuery = MediaQuery.of(dialogContext);
            final availableHeight =
                mediaQuery.size.height - mediaQuery.viewInsets.bottom;
            final amount = int.tryParse(_splitAmountController.text
                    .replaceAll(RegExp(r'[^0-9]'), '')) ??
                0;
            final people = int.tryParse(_splitPeopleController.text) ?? 2;
            final splitResult = people > 0 ? amount / people : 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              scrollable: true,
              title: Text('Chia Tiền (Split Bill) 🍕',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight:
                      (availableHeight * 0.45).clamp(180.0, 320.0).toDouble(),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _splitAmountController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Tổng số tiền (VND)'),
                        scrollPadding: const EdgeInsets.only(bottom: 24),
                        onChanged: (_) => setDialogState(() {}),
                        onSubmitted: (_) =>
                            FocusScope.of(dialogContext).nextFocus(),
                      ),
                      SLSpacing.h8,
                      TextField(
                        controller: _splitPeopleController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration:
                            const InputDecoration(labelText: 'Số người chia'),
                        scrollPadding: const EdgeInsets.only(bottom: 24),
                        onChanged: (_) => setDialogState(() {}),
                        onSubmitted: (_) =>
                            FocusScope.of(dialogContext).unfocus(),
                      ),
                      SLSpacing.h16,
                      if (amount > 0 && people > 0)
                        Container(
                          width: double.infinity,
                          padding: SLSpacing.all12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F7),
                            borderRadius: SLRadius.mdAll,
                          ),
                          child: Text(
                            'Mỗi người trả:\n${_fmt.format(splitResult)}',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: SLTheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _budgetPlanSub?.cancel();
    _savingsGoalSub?.cancel();
    _amountController.dispose();
    _noteController.dispose();
    _goalAmountController.dispose();
    _goalDaysController.dispose();
    _savingsGoalNameController.dispose();
    _savingsGoalAmountController.dispose();
    _splitAmountController.dispose();
    _splitPeopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr('finance_title'),
            style: SLTheme.quicksand(
                color: SLTheme.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: SLTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: SLTheme.textMain),
            onPressed: _showSplitBillDialog,
            tooltip: 'Chia Tiền',
          ),
        ],
      ),
      body: SLTheme.background(
        child: SafeArea(
            child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _buildBalanceCard()),
          SliverToBoxAdapter(child: _buildBudgetPlanSection()),
          SliverToBoxAdapter(child: _buildSavingsGoalSection()),
          SliverToBoxAdapter(child: _buildChartSection()),
          SliverToBoxAdapter(child: _buildInputArea()),
          _buildTransactionList(),
        ])),
      ),
    );
  }

  Widget _buildBudgetPlanSection() {
    if (_budgetPlan == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: SLTheme.primaryButton(
          label: '➕ Lập kế hoạch chi tiêu',
          onPressed: _showPlanDialog,
        ),
      );
    }

    final target = _budgetPlan!['targetAmount'] as int? ?? 0;
    final days = _budgetPlan!['targetDays'] as int? ?? 1;
    final createdAt = _budgetPlan!['createdAt'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final startTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final endTime = startTime.add(Duration(days: days));
    final now = DateTime.now();

    // Tính số ngày đã qua và còn lại
    final passedDays = now.difference(startTime).inDays;
    final remainingDays = days - passedDays;
    final isExpired = now.isAfter(endTime);

    // Tính tiến độ chi tiêu
    final double percent =
        target > 0 ? (_totalOut / target).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = _totalOut > target;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: isOverBudget ? const Color(0xFFFFF0F0) : const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: isOverBudget
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.green.withValues(alpha: 0.3),
            width: 2),
        boxShadow: [
          BoxShadow(
              color:
                  (isOverBudget ? Colors.red : Colors.green).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(isOverBudget ? '⚠️' : '🎯',
                      style: const TextStyle(fontSize: 20)),
                  SLSpacing.w8,
                  Text(
                    isOverBudget ? 'VƯỢT NGÂN SÁCH!' : 'KẾ HOẠCH CHI TIÊU',
                    style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isOverBudget ? Colors.red : Colors.green[800],
                        letterSpacing: 1.1),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: _showPlanDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  SLSpacing.w12,
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 18, color: Colors.red),
                    onPressed: _resetBudgetPlan,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã dùng: ${_fmt.format(_totalOut)}',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SLTheme.textMain),
              ),
              Text(
                'Mục tiêu: ${_fmt.format(target)}',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: SLTheme.textMuted),
              ),
            ],
          ),
          SLSpacing.h8,
          ClipRRect(
            borderRadius: SLRadius.smAll,
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? Colors.red : Colors.green),
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 14, color: Colors.blueGrey),
              SLSpacing.w8,
              Text(
                isExpired
                    ? 'Đã kết thúc kế hoạch'
                    : 'Còn lại $remainingDays/$days ngày',
                style: SLTheme.quicksand(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
              const Spacer(),
              if (!isExpired && !isOverBudget)
                Text(
                  'Có thể tiêu thêm: ${_fmt.format(((target - _totalOut) / (remainingDays > 0 ? remainingDays : 1)).floor())}/ngày',
                  style: SLTheme.quicksand(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalSection() {
    if (_savingsGoal == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: SLTheme.primaryButton(
          label: '🎯 Tạo Quỹ Cưới / Quỹ Du Lịch',
          onPressed: _showSavingsGoalDialog,
        ),
      );
    }

    final target = _savingsGoal!['targetAmount'] as int? ?? 0;
    final name = _savingsGoal!['name'] as String? ?? 'Quỹ Chung';

    // Tính số tiền đã tiết kiệm được
    // Trong trường hợp này, ta có thể tính từ số tiền thu nhập (in) trừ đi một số khoản,
    // hoặc có thể tính đơn giản bằng tổng số tiền thu nhập (in) hoặc tạo danh mục 'Tiết kiệm'.
    // Ở đây ta dùng _totalBalance làm số tiền hiện có trong quỹ, nếu quỹ chung là tài khoản chính.
    // Hoặc ta tính tổng thu (hoặc chi cho danh mục Tiết kiệm).
    // Để đơn giản, ta dùng _totalBalance để so sánh với mục tiêu quỹ.
    final currentSaved = _totalBalance > 0 ? _totalBalance : 0;

    final double percent =
        target > 0 ? (currentSaved / target).clamp(0.0, 1.0) : 0.0;
    final isReached = currentSaved >= target;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('💍', style: TextStyle(fontSize: 20)),
                  SLSpacing.w8,
                  Text(
                    name.toUpperCase(),
                    style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.amber[800],
                        letterSpacing: 1.1),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: _showSavingsGoalDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  SLSpacing.w12,
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 18, color: Colors.red),
                    onPressed: _resetSavingsGoal,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã có: ${_fmt.format(currentSaved)}',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SLTheme.textMain),
              ),
              Text(
                'Mục tiêu: ${_fmt.format(target)}',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: SLTheme.textMuted),
              ),
            ],
          ),
          SLSpacing.h8,
          ClipRRect(
            borderRadius: SLRadius.smAll,
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(
                  isReached ? Colors.green : Colors.amber),
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
              SLSpacing.w8,
              Text(
                isReached
                    ? '🎉 Đã đạt mục tiêu!'
                    : 'Đạt ${(percent * 100).toStringAsFixed(1)}%',
                style: SLTheme.quicksand(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSavingsGoalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text('Tạo Quỹ Mới 💍',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _savingsGoalNameController,
            decoration: const InputDecoration(
                labelText: 'Tên Quỹ (vd: Quỹ Cưới, Du Lịch)'),
          ),
          SLSpacing.h8,
          TextField(
            controller: _savingsGoalAmountController,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Số tiền mục tiêu (VND)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: _saveSavingsGoal,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll)),
            child: const Text('Lưu Quỹ',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (_allTransactions.isEmpty) return const SizedBox.shrink();

    // Lọc các giao dịch chi tiêu (out) để vẽ biểu đồ
    final outTransactions =
        _allTransactions.where((t) => t['type'] == 'out').toList();
    if (outTransactions.isEmpty) return const SizedBox.shrink();

    // Tính tổng theo danh mục
    final Map<String, double> categoryTotals = {};
    double totalOut = 0;
    for (var t in outTransactions) {
      final cat = t['category']?.toString() ?? 'Khác';
      final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
      totalOut += amt;
    }

    if (totalOut <= 0) return const SizedBox.shrink();

    final List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    final colors = [
      SLTheme.primary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.redAccent,
      Colors.brown,
    ];

    categoryTotals.forEach((cat, amt) {
      final percent = (amt / totalOut * 100);
      if (percent > 0) {
        pieSections.add(PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: percent,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
        colorIndex++;
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phân tích chi tiêu 📊',
              style: SLTheme.quicksand(
                  color: SLTheme.textMain,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          SLSpacing.h16,
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: categoryTotals.entries.map((e) {
                      final idx = categoryTotals.keys.toList().indexOf(e.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[idx % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            SLSpacing.w8,
                            Expanded(
                              child: Text(
                                e.key,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text('Lập Kế Hoạch 🗓️',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _goalAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Tổng ngân sách dự kiến (VND)'),
          ),
          SLSpacing.h8,
          TextField(
            controller: _goalDaysController,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Số ngày áp dụng (vd: 30)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: _saveBudgetPlan,
            style: ElevatedButton.styleFrom(
                backgroundColor: SLTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll)),
            child: const Text('Lưu Kế Hoạch',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(children: [
        Text(context.tr('total_balance'),
            style: SLTheme.quicksand(
                color: SLTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        SLSpacing.h8,
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: _totalBalance >= 0
                ? const [Color(0xFFD81B60), Color(0xFF9C27B0)]
                : const [Colors.red, Colors.deepOrange],
          ).createShader(b),
          child: Text(_fmt.format(_totalBalance),
              style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900)),
        ),
        SLSpacing.h16,
        // Thu/Chi thanh bar đôi
        Row(children: [
          _balanceMiniBar('💚 ${context.tr('income')}', _totalIn, Colors.green,
              const Color(0xFF2E7D32)),
          SLSpacing.w12,
          _balanceMiniBar('❤️ ${context.tr('expense')}', _totalOut,
              const Color(0xFFD81B60), Colors.red),
        ]),
      ]),
    );
  }

  Widget _balanceMiniBar(
      String label, int amount, Color barColor, Color textColor) {
    final ratio =
        _totalIn + _totalOut == 0 ? 0.0 : amount / (_totalIn + _totalOut);
    return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: SLTheme.quicksand(
              color: textColor, fontWeight: FontWeight.w800, fontSize: 11)),
      SLSpacing.h4,
      ClipRRect(
          borderRadius: SLRadius.smAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFE8D5DF),
            valueColor: AlwaysStoppedAnimation(barColor),
          )),
      SLSpacing.h4,
      Text(_fmt.format(amount),
          style: TextStyle(
              color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
    ]));
  }

  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all16,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Thu/Chi toggle - clone .mood-wrap
        Row(children: [
          _typeBtn('💚 ${context.tr('income')}', 'in', Colors.green),
          SLSpacing.w8,
          _typeBtn('❤️ ${context.tr('expense')}', 'out', SLTheme.primary),
        ]),
        SLSpacing.h12,
        // Category chips
        Text('${context.tr('category')}:',
            style: SLTheme.quicksand(
                color: SLTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        SLSpacing.h8,
        SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: SLTheme.btnGradient)
                          : null,
                      color: isSelected ? null : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : const Color(0xFFE8D5DF),
                          width: 1.5),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                isSelected ? Colors.white : SLTheme.textMuted,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600)),
                  ),
                );
              },
            )),
        SLSpacing.h12,
        // Amount input
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16),
          decoration: InputDecoration(
            hintText: '${context.tr('amount')} (VND)...',
            hintStyle: SLTheme.quicksand(color: SLTheme.textLight),
            prefixIcon: Icon(Icons.attach_money,
                color: SLTheme.primary.withValues(alpha: 0.6), size: 20),
            filled: true,
            fillColor: const Color(0xFFFFF5F7),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Color(0xFFE8D5DF), width: 2.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Color(0xFFD81B60), width: 2.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        SLSpacing.h8,
        TextField(
          controller: _noteController,
          style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16),
          decoration: InputDecoration(
            hintText: '${context.tr('note')} (tùy chọn)...',
            hintStyle: SLTheme.quicksand(color: SLTheme.textLight),
            prefixIcon: Icon(Icons.notes,
                color: SLTheme.primary.withValues(alpha: 0.6), size: 20),
            filled: true,
            fillColor: const Color(0xFFFFF5F7),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Color(0xFFE8D5DF), width: 2.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Color(0xFFD81B60), width: 2.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        SLSpacing.h12,
        SLTheme.primaryButton(
          label:
              '${context.tr('save')} ${_transactionType == 'in' ? context.tr('income') : context.tr('expense')} • $_category',
          onPressed: _addTransaction,
        ),
      ]),
    );
  }

  Widget _typeBtn(String label, String type, Color color) {
    final isSelected = _transactionType == type;
    return Expanded(
        child: GestureDetector(
      onTap: () => setState(() => _transactionType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF5F5F5),
          borderRadius: SLRadius.lgAll,
          border: Border.all(
              color: isSelected ? color : const Color(0xFFE8D5DF), width: 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: SLTheme.quicksand(
                color: isSelected ? Colors.white : SLTheme.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ),
    ));
  }

  void _syncTransactionSummary({
    required List<Map<String, dynamic>> items,
    required int totalIn,
    required int totalOut,
  }) {
    final signature = items
        .map((item) =>
            '${item['key']}:${item['type']}:${item['amount']}:${item['ts']}:${item['category']}:${item['note']}')
        .join('|');
    final balance = totalIn - totalOut;

    if (_totalIn == totalIn &&
        _totalOut == totalOut &&
        _totalBalance == balance &&
        _transactionSignature == signature) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_totalIn == totalIn &&
          _totalOut == totalOut &&
          _totalBalance == balance &&
          _transactionSignature == signature) {
        return;
      }
      setState(() {
        _totalIn = totalIn;
        _totalOut = totalOut;
        _totalBalance = balance;
        _allTransactions = items;
        _transactionSignature = signature;
      });
    });
  }

  Widget _buildTransactionList() {
    return StreamBuilder(
      stream: _budgetStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60))));
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Lỗi tải giao dịch: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                    color: SLTheme.textMain, fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          _syncTransactionSummary(
            items: const <Map<String, dynamic>>[],
            totalIn: 0,
            totalOut: 0,
          );
          return SliverToBoxAdapter(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                const Text('💸',
                    style: TextStyle(fontSize: 50),
                    textScaler: TextScaler.linear(1.0)),
                SLSpacing.h8,
                Text('Chưa có giao dịch nào.\nHãy thêm thu/chi đầu tiên!',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                        color: SLTheme.textMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ])));
        }
        final data =
            Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final items = data.entries
            .map((e) => {'key': e.key, ...Map<String, dynamic>.from(e.value)})
            .toList();
        items.sort(
            (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));

        int tempIn = 0, tempOut = 0;
        for (var item in items) {
          final amt = item['amount'] as int? ?? 0;
          if (item['type'] == 'in') {
            tempIn += amt;
          } else {
            tempOut += amt;
          }
        }
        _syncTransactionSummary(
          items: items,
          totalIn: tempIn,
          totalOut: tempOut,
        );

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final item = items[i];
                final isIncome = item['type'] == 'in';
                final catEmoji =
                    item['category']?.toString().split(' ').first ??
                        (isIncome ? '💚' : '❤️');

                // Clone .list-item từ Web gốc
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: SLSpacing.all16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: SLRadius.xlAll,
                    border: Border(
                        left: BorderSide(
                            color: isIncome ? Colors.green : SLTheme.primary,
                            width: 5)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(children: [
                    // Category icon circle
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: isIncome
                                ? [
                                    const Color(0xFFE8F5E9),
                                    const Color(0xFFC8E6C9)
                                  ]
                                : [
                                    const Color(0xFFFFE4EB),
                                    const Color(0xFFFFB3D9)
                                  ]),
                        borderRadius: SLRadius.mdAll,
                      ),
                      child: Center(
                          child: Text(catEmoji,
                              style: const TextStyle(fontSize: 22))),
                    ),
                    SLSpacing.w12,
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              item['category'] ??
                                  (isIncome ? 'Thu nhập' : 'Chi tiêu'),
                              style: SLTheme.quicksand(
                                  color: SLTheme.textMain,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          if ((item['note'] ?? '').toString().isNotEmpty)
                            Text(item['note'],
                                style: SLTheme.quicksand(
                                    color: SLTheme.textMuted, fontSize: 12)),
                          Row(children: [
                            SLTheme.authorTag(item['from'] ?? ''),
                            SLSpacing.w8,
                            Text(item['time'] ?? '',
                                style: SLTheme.quicksand(
                                    color: SLTheme.textLight, fontSize: 10)),
                          ]),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${isIncome ? '+' : '-'}${_fmt.format(item['amount'] ?? 0)}',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isIncome
                                    ? const Color(0xFF2E7D32)
                                    : SLTheme.primary,
                              )),
                          SLSpacing.h4,
                          GestureDetector(
                            onTap: () => _deleteTransaction(item['key']),
                            child: const Icon(Icons.delete_outline,
                                color: SLTheme.textLight, size: 18),
                          ),
                        ]),
                  ]),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}
