import 'package:soullocket_app/utils/money_format.dart';
import 'package:soullocket_app/utils/locale_date_format.dart';
import 'widgets/finance_dialog.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/house_money_currency.dart';
import '../../utils/finance_category.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/sl_theme.dart';
import '../../widgets/skeleton_container.dart';
import '../../utils/initial_event_timeout.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/app_error_mapper.dart';
import 'package:soullocket_app/widgets/sl_toast.dart';
import 'widgets/finance_design.dart';

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
  final TextEditingController _splitPeopleController = TextEditingController(
    text: '2',
  );

  String _transactionType = 'out';
  String _category = 'food';
  bool _saving = false;
  int _houseGeneration = 0;
  int _totalBalance = 0, _totalIn = 0, _totalOut = 0;

  Map<String, dynamic>? _budgetPlan;
  Map<String, dynamic>? _savingsGoal;
  List<Map<String, dynamic>> _allTransactions = [];
  String _transactionSignature = '';
  late Stream<DatabaseEvent> _budgetStream;
  StreamSubscription<DatabaseEvent>? _budgetPlanSub;
  StreamSubscription<DatabaseEvent>? _savingsGoalSub;

  List<String> get _categories => FinanceCategory.labelKeys.keys.toList();
  // Loại tiền chung của nhà (VND, USD, EUR...), mặc định theo khu vực.
  String _houseCurrency = '';
  StreamSubscription<DatabaseEvent>? _currencySub;
  NumberFormat get _fmt =>
      MoneyFormat.forCurrency(_houseCurrency.isEmpty ? 'VND' : _houseCurrency);

  @override
  void initState() {
    super.initState();
    _bindHouse();
  }

  @override
  void didUpdateWidget(covariant FinanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) _bindHouse();
  }

  void _bindHouse() {
    final generation = ++_houseGeneration;
    final houseId = widget.houseId;
    _saving = false;
    _houseCurrency = '';
    _allTransactions = [];
    _transactionSignature = '';
    _totalBalance = _totalIn = _totalOut = 0;
    _budgetPlan = null;
    _savingsGoal = null;
    _budgetStream = _watchBudget();
    _loadBudgetPlan();
    _loadSavingsGoal();
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
  }

  Future<String> _ensureHouseCurrency(int generation, String? uid) async {
    final code = await HouseMoneyCurrency.ensure(
      root: _dbRef,
      houseId: widget.houseId,
      isCurrent: () =>
          mounted &&
          generation == _houseGeneration &&
          FirebaseAuth.instance.currentUser?.uid == uid,
    );
    if (mounted && generation == _houseGeneration) {
      setState(() => _houseCurrency = code);
    }
    return code;
  }

  Stream<DatabaseEvent> _watchBudget() => withInitialEventTimeout(
    _dbRef.child('houses/${widget.houseId}/budget').limitToLast(200).onValue,
  );

  bool _isCurrentWrite(int generation, String? uid) =>
      mounted &&
      generation == _houseGeneration &&
      FirebaseAuth.instance.currentUser?.uid == uid;

  void _showWriteError(Object error) {
    SLToast.show(context, AppErrorMapper.resolve(error).message);
  }

  Color _financeFilterSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? SLColors.darkBgElevated
        : SLColors.bgSubtle;
  }

  Color _financeFilterBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? SLColors.darkBorder
        : SLColors.border;
  }

  Color _financeFilterText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? SLColors.darkTextPrimary
        : SLColors.textPrimary;
  }

  void _loadBudgetPlan() {
    final generation = _houseGeneration;
    _budgetPlanSub?.cancel();
    _budgetPlanSub = _dbRef
        .child('houses/${widget.houseId}/finance_plan')
        .onValue
        .listen((event) {
          if (!mounted || generation != _houseGeneration) return;
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
    final generation = _houseGeneration;
    _savingsGoalSub?.cancel();
    _savingsGoalSub = _dbRef
        .child('houses/${widget.houseId}/savings_goal')
        .onValue
        .listen((event) {
          if (!mounted || generation != _houseGeneration) return;
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

  Future<void> _saveBudgetPlan() async {
    if (_saving) return;
    final amountText = _goalAmountController.text;
    final daysText = _goalDaysController.text;
    final amount = MoneyFormat.parseWholeAmount(amountText);
    final days = int.tryParse(daysText);
    if (amount == null || amount <= 0 || days == null || days <= 0) return;
    final generation = _houseGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = widget.houseId;
    _saving = true;
    try {
      await _ensureHouseCurrency(generation, uid);
      if (!_isCurrentWrite(generation, uid)) return;
      final now = DateTime.now();
      await _dbRef.child('houses/$houseId/finance_plan').set({
        'targetAmount': amount,
        'targetDays': days,
        'createdAt': now.millisecondsSinceEpoch,
        'startDate': DateFormat('yyyy-MM-dd').format(now),
      });
      if (!_isCurrentWrite(generation, uid)) return;
      if (_goalAmountController.text == amountText &&
          _goalDaysController.text == daysText) {
        _goalAmountController.clear();
        _goalDaysController.clear();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (error) {
      if (_isCurrentWrite(generation, uid)) _showWriteError(error);
    } finally {
      if (generation == _houseGeneration) _saving = false;
    }
  }

  Future<void> _saveSavingsGoal() async {
    if (_saving) return;
    final amountText = _savingsGoalAmountController.text;
    final nameText = _savingsGoalNameController.text;
    final amount = MoneyFormat.parseWholeAmount(amountText);
    final name = nameText.trim();
    if (amount == null || amount <= 0 || name.isEmpty) return;
    final generation = _houseGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = widget.houseId;
    _saving = true;
    try {
      await _ensureHouseCurrency(generation, uid);
      if (!_isCurrentWrite(generation, uid)) return;
      await _dbRef.child('houses/$houseId/savings_goal').set({
        'name': name,
        'targetAmount': amount,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (!_isCurrentWrite(generation, uid)) return;
      if (_savingsGoalAmountController.text == amountText &&
          _savingsGoalNameController.text == nameText) {
        _savingsGoalAmountController.clear();
        _savingsGoalNameController.clear();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (error) {
      if (_isCurrentWrite(generation, uid)) _showWriteError(error);
    } finally {
      if (generation == _houseGeneration) _saving = false;
    }
  }

  void _resetSavingsGoal() {
    showDialog(
      context: context,
      builder: (ctx) => FinanceDialog(
        title: Text(context.tr('util_xaqu_086ff0')),
        content: Text(context.tr('util_bncchcchnm_fd1095')),
        actions: [
          FinanceDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          FinanceDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              _dbRef.child('houses/${widget.houseId}/savings_goal').remove();
              Navigator.pop(ctx);
            },
            child: Text(L10nService().translate(context.tr('util_xa_4ed187'))),
          ),
        ],
      ),
    );
  }

  void _resetBudgetPlan() {
    showDialog(
      context: context,
      builder: (ctx) => FinanceDialog(
        title: Text(context.tr('util_xakhoch_ba0a75')),
        content: Text(context.tr('util_bncchcchnm_ed97cc')),
        actions: [
          FinanceDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          FinanceDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              _dbRef.child('houses/${widget.houseId}/finance_plan').remove();
              Navigator.pop(ctx);
            },
            child: Text(L10nService().translate(context.tr('util_xa_4ed187'))),
          ),
        ],
      ),
    );
  }

  Future<void> _addTransaction() async {
    if (_saving) return;
    final amountText = _amountController.text;
    final noteText = _noteController.text;
    final amount = MoneyFormat.parseWholeAmount(amountText);
    if (amount == null || amount <= 0) {
      SLToast.show(context, context.tr('util_nhpstinhpl_99919c'));
      return;
    }
    final generation = _houseGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = widget.houseId;
    final author = widget.myName;
    final type = _transactionType;
    final category = _category;
    _saving = true;
    try {
      final currentSnap = await _dbRef
          .child('houses/$houseId/budget')
          .limitToFirst(101)
          .get();
      if (!_isCurrentWrite(generation, uid)) return;
      if (currentSnap.value is Map &&
          (currentSnap.value as Map).length >= 100) {
        if (!mounted) return;
        SLToast.show(context, context.tr('p8_finance_transaction_limit'));
        return;
      }
      await _ensureHouseCurrency(generation, uid);
      if (!_isCurrentWrite(generation, uid)) return;
      final now = DateTime.now();
      await _dbRef.child('houses/$houseId/budget').push().set({
        'from': author,
        'amount': amount,
        'type': type,
        'category': category,
        'note': noteText.trim(),
        'ts': now.millisecondsSinceEpoch,
        'time': LocaleDateFormat.dayMonthTime(now),
      });
      if (!_isCurrentWrite(generation, uid)) return;
      if (_amountController.text == amountText) _amountController.clear();
      if (_noteController.text == noteText) _noteController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      HapticFeedback.mediumImpact();
    } catch (error) {
      if (_isCurrentWrite(generation, uid)) _showWriteError(error);
    } finally {
      if (generation == _houseGeneration) _saving = false;
    }
  }

  void _deleteTransaction(String key) {
    showDialog(
      context: context,
      builder: (ctx) => FinanceDialog(
        title: Text(context.tr('p8_finance_delete_transaction_title')),
        content: Text(context.tr('p8_finance_delete_transaction_body')),
        actions: [
          FinanceDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('p8_finance_cancel')),
          ),
          FinanceDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              Navigator.pop(ctx);
              _dbRef.child('houses/${widget.houseId}/budget/$key').remove();
            },

            child: Text(context.tr('p8_finance_delete')),
          ),
        ],
      ),
    );
  }

  void _showSplitBillDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final amount =
                MoneyFormat.parseWholeAmount(_splitAmountController.text) ?? 0;
            final people = int.tryParse(_splitPeopleController.text) ?? 2;
            final splitResult = people > 0 ? amount / people : 0;

            return FinanceDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              scrollable: true,
              title: Text(context.tr('util_chiatinspl_820857')),
              content: FinanceSplitBillForm(
                amountController: _splitAmountController,
                peopleController: _splitPeopleController,
                onChanged: () => setDialogState(() {}),
                resultText: amount > 0 && people > 0
                    ? L10nService().format('util_finance_each_pays', {
                        'amount': _fmt.format(splitResult),
                      })
                    : null,
              ),
              actions: [
                FinanceDialogAction(
                  primary: true,

                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.tr('util_ng_f63d1e')),
                ),
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
    _currencySub?.cancel();
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

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => FinanceDialog(
        title: Text(context.tr('p8_finance_info_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('p8_finance_info_features_title'),
                style: FinancePalette.text(context, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p8_finance_info_features_body'),
                style: FinancePalette.text(
                  context,
                  color: FinancePalette.muted(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('p8_finance_info_how_to_title'),
                style: FinancePalette.text(context, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p8_finance_info_how_to_body'),
                style: FinancePalette.text(
                  context,
                  color: FinancePalette.muted(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FinanceDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('p8_finance_info_dismiss')),
          ),
        ],
      ),
    );
  }

  String get _currencyCode => _houseCurrency.isEmpty ? 'VND' : _houseCurrency;

  Widget _buildModernActions() {
    final actions = [
      FinanceActionCard(
        title: context.tr('util_lpkhochchi_bc03dd'),
        subtitle: context.tr('p8_finance_info_how_to_body'),
        icon: Icons.track_changes_rounded,
        color: FinancePalette.rose,
        onTap: _showPlanDialog,
      ),
      FinanceActionCard(
        title: context.tr('util_toquciqudu_2385ab'),
        subtitle: context.tr('util_titkim_595e8b'),
        icon: Icons.savings_outlined,
        color: FinancePalette.gold,
        onTap: _showSavingsGoalDialog,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 355 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            children: [actions[0], const SizedBox(height: 10), actions[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: actions[0]),
            const SizedBox(width: 10),
            Expanded(child: actions[1]),
          ],
        );
      },
    );
  }

  Widget _buildModernBudgetPlan() {
    final plan = _budgetPlan;
    if (plan == null) return const SizedBox.shrink();

    final target = (plan['targetAmount'] as num?)?.toInt() ?? 0;
    final days = (plan['targetDays'] as num?)?.toInt() ?? 1;
    final createdAt =
        (plan['createdAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final startTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final passedDays = DateTime.now().difference(startTime).inDays;
    final remainingDays = math.max(0, days - passedDays);
    final expired = DateTime.now().isAfter(startTime.add(Duration(days: days)));
    final percent = target > 0 ? (_totalOut / target).clamp(0.0, 1.0) : 0.0;
    final over = _totalOut > target;
    final status = expired
        ? context.tr('util_ktthckhoch_635af9')
        : over
        ? context.tr('util_vtngnsch_937fb7')
        : L10nService().format('util_finance_days_left', {
            'remaining': remainingDays,
            'days': days,
          });
    final hint = !expired && !over
        ? L10nService().format('util_finance_can_spend_more_daily', {
            'amount': _fmt.format(
              ((target - _totalOut) / (remainingDays > 0 ? remainingDays : 1))
                  .floor(),
            ),
          })
        : null;

    return FinanceGoalCard(
      title: context.tr('util_khochchiti_f81032'),
      eyebrow: context.tr('util_lpkhochchi_bc03dd'),
      currentText: L10nService().format('util_finance_used_amount', {
        'amount': _fmt.format(_totalOut),
      }),
      targetText: L10nService().format('util_finance_target_amount', {
        'amount': _fmt.format(target),
      }),
      progress: percent,
      status: status,
      hint: hint,
      color: over ? FinancePalette.rose : FinancePalette.sage,
      icon: over ? Icons.warning_amber_rounded : Icons.track_changes_rounded,
      onEdit: _showPlanDialog,
      onDelete: _resetBudgetPlan,
      editLabel: context.tr('p8_finance_edit_budget_plan'),
      deleteLabel: context.tr('p8_finance_delete_budget_plan'),
    );
  }

  Widget _buildModernSavingsGoal() {
    final goal = _savingsGoal;
    if (goal == null) return const SizedBox.shrink();

    final target = (goal['targetAmount'] as num?)?.toInt() ?? 0;
    final title = goal['name']?.toString().trim().isNotEmpty == true
        ? goal['name'].toString()
        : context.tr('util_quchung_1cd93f');
    final saved = math.max(0, _totalBalance);
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final reached = target > 0 && saved >= target;

    return FinanceGoalCard(
      title: title,
      eyebrow: context.tr('util_toqumi_e38258'),
      currentText: L10nService().format('util_finance_saved_amount', {
        'amount': _fmt.format(saved),
      }),
      targetText: L10nService().format('util_finance_target_amount', {
        'amount': _fmt.format(target),
      }),
      progress: progress,
      status: reached
          ? context.tr('util_tmctiu_d4d469')
          : L10nService().format('util_finance_goal_percent', {
              'percent': (progress * 100).toStringAsFixed(1),
            }),
      color: FinancePalette.gold,
      icon: Icons.savings_outlined,
      onEdit: _showSavingsGoalDialog,
      onDelete: _resetSavingsGoal,
      editLabel: context.tr('p8_finance_edit_savings_goal'),
      deleteLabel: context.tr('p8_finance_delete_savings_goal'),
    );
  }

  Widget _buildModernChart() {
    final totals = <String, int>{};
    for (final transaction in _allTransactions.where(
      (item) => item['type'] == 'out',
    )) {
      final category =
          FinanceCategory.codeOf(transaction['category']) ??
          transaction['category']?.toString() ??
          'other';
      totals[category] =
          (totals[category] ?? 0) +
          ((transaction['amount'] as num?)?.toInt() ?? 0);
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final ordered = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = ordered.first.value;
    final colors = [
      FinancePalette.rose,
      FinancePalette.sage,
      FinancePalette.lavender,
      FinancePalette.gold,
      const Color(0xFF5E8795),
    ];

    return FinanceCard(
      tint: FinancePalette.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('util_phntchchit_1737cd'),
                  style: FinancePalette.text(
                    context,
                    size: 16,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.auto_graph_rounded,
                color: FinancePalette.accent(context, FinancePalette.lavender),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...ordered.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
            final color = FinancePalette.accent(
              context,
              colors[index % colors.length],
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == ordered.length - 1 ? 0 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          FinanceCategory.label(item.key, context.tr),
                          style: FinancePalette.text(
                            context,
                            size: 12,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt.format(item.value),
                        style: FinancePalette.text(
                          context,
                          size: 12,
                          weight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: FinancePalette.motion(context),
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(7),
                      backgroundColor: color.withValues(alpha: 0.12),
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModernTransactionList() {
    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('finance-modern-${widget.houseId}'),
      stream: _budgetStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: SkeletonContainer.rounded(
                width: double.infinity,
                height: 92,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: FinanceCard(
              child: Column(
                children: [
                  Text(
                    L10nService().format('util_finance_load_tx_error', {
                      'error': AppErrorMapper.resolve(snapshot.error).message,
                    }),
                    textAlign: TextAlign.center,
                    style: FinancePalette.text(context, size: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _budgetStream = _watchBudget()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final raw = snapshot.data?.snapshot.value;
        if (raw == null || raw is! Map) {
          _syncTransactionSummary(
            items: const <Map<String, dynamic>>[],
            totalIn: 0,
            totalOut: 0,
          );
          return const SliverToBoxAdapter(
            child: FinanceCard(child: FinanceEmptyState()),
          );
        }

        final items = raw.entries
            .where((entry) => entry.value is Map)
            .map(
              (entry) => {
                'key': entry.key,
                ...Map<String, dynamic>.from(entry.value as Map),
              },
            )
            .toList();
        items.sort(
          (a, b) => ((b['ts'] as num?)?.toInt() ?? 0).compareTo(
            (a['ts'] as num?)?.toInt() ?? 0,
          ),
        );
        var totalIn = 0;
        var totalOut = 0;
        for (final item in items) {
          final amount = (item['amount'] as num?)?.toInt() ?? 0;
          if (item['type'] == 'in') {
            totalIn += amount;
          } else {
            totalOut += amount;
          }
        }
        _syncTransactionSummary(
          items: items,
          totalIn: totalIn,
          totalOut: totalOut,
        );

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];
            final income = item['type'] == 'in';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FinanceTransactionTile(
                key: ValueKey('finance-transaction-${item['key']}'),
                category: item['category']?.toString() ?? 'other',
                amount:
                    '${income ? '+' : '-'}${_fmt.format((item['amount'] as num?)?.toInt() ?? 0)}',
                author: item['from']?.toString() ?? '',
                time: item['time']?.toString() ?? '',
                note: item['note']?.toString() ?? '',
                income: income,
                onDelete: () => _deleteTransaction(item['key']),
              ),
            );
          }, childCount: items.length),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: FinancePalette.canvas(context),
        elevation: 0,
        centerTitle: true,
        foregroundColor: FinancePalette.ink(context),
        title: Text(
          context.tr('finance_title'),
          style: SLTheme.quicksand(
            color: FinancePalette.ink(context),
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: context.tr('p8_finance_back_tooltip'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            onPressed: () => _showInfoDialog(context),
            tooltip: context.tr('p8_finance_info_tooltip'),
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: _showSplitBillDialog,
            tooltip: context.tr('util_chiatin_4685f5'),
          ),
        ],
      ),
      body: ColoredBox(
        color: FinancePalette.canvas(context),
        child: SafeArea(
          child: CustomScrollView(
            physics: SLResponsive.scrollPhysicsForPlatform(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FinanceBalanceCard(
                      balance: _fmt.format(_totalBalance),
                      income: _fmt.format(_totalIn),
                      expense: _fmt.format(_totalOut),
                      currency: _currencyCode,
                      negative: _totalBalance < 0,
                    ),
                    _buildModernActions(),
                    _buildModernBudgetPlan(),
                    _buildModernSavingsGoal(),
                    _buildModernChart(),
                    FinanceSectionTitle(
                      label: context.tr('finance_add_transaction_title'),
                    ),
                    FinanceComposer(
                      type: _transactionType,
                      category: _category,
                      currency: _currencyCode,
                      amountController: _amountController,
                      noteController: _noteController,
                      saving: _saving,
                      onType: (type) => setState(() => _transactionType = type),
                      onCategory: (category) =>
                          setState(() => _category = category),
                      onSave: _addTransaction,
                    ),
                    FinanceSectionTitle(
                      label: context.tr('finance_recent_transactions_title'),
                      count: _allTransactions.isEmpty
                          ? null
                          : _allTransactions.length.toString(),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: _buildModernTransactionList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 20, color: color),
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildBudgetPlanSection() {
    if (_budgetPlan == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: SLTheme.primaryButton(
          label: context.tr('util_lpkhochchi_bc03dd'),
          onPressed: _showPlanDialog,
        ),
      );
    }

    final target = _budgetPlan!['targetAmount'] as int? ?? 0;
    final days = _budgetPlan!['targetDays'] as int? ?? 1;
    final createdAt =
        _budgetPlan!['createdAt'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final startTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final endTime = startTime.add(Duration(days: days));
    final now = DateTime.now();
    final passedDays = now.difference(startTime).inDays;
    final remainingDays = days - passedDays;
    final isExpired = now.isAfter(endTime);
    final double percent = target > 0
        ? (_totalOut / target).clamp(0.0, 1.0)
        : 0.0;
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
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOverBudget ? Colors.red : Colors.green).withValues(
              alpha: 0.05,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      isOverBudget ? '⚠️' : '🎯',
                      style: const TextStyle(fontSize: 20),
                    ),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        isOverBudget
                            ? context.tr('util_vtngnsch_937fb7')
                            : context.tr('util_khochchiti_f81032'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: isOverBudget ? Colors.red : Colors.green[800],
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cardIconButton(
                icon: Icons.edit_outlined,
                tooltip: context.tr('p8_finance_edit_budget_plan'),
                onPressed: _showPlanDialog,
              ),
              const SizedBox(width: 4),
              _cardIconButton(
                icon: Icons.delete_sweep_outlined,
                color: Colors.red,
                tooltip: context.tr('p8_finance_delete_budget_plan'),
                onPressed: _resetBudgetPlan,
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(
                child: Text(
                  L10nService().format('util_finance_used_amount', {
                    'amount': _fmt.format(_totalOut),
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SLTheme.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  L10nService().format('util_finance_target_amount', {
                    'amount': _fmt.format(target),
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: SLTheme.textMuted,
                  ),
                ),
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
                isOverBudget ? Colors.red : Colors.green,
              ),
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: Colors.blueGrey,
              ),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  isExpired
                      ? context.tr('util_ktthckhoch_635af9')
                      : L10nService().format('util_finance_days_left', {
                          'remaining': remainingDays,
                          'days': days,
                        }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (!isExpired && !isOverBudget) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                L10nService().format('util_finance_can_spend_more_daily', {
                  'amount': _fmt.format(
                    ((target - _totalOut) /
                            (remainingDays > 0 ? remainingDays : 1))
                        .floor(),
                  ),
                }),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildSavingsGoalSection() {
    if (_savingsGoal == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: SLTheme.primaryButton(
          label: context.tr('util_toquciqudu_2385ab'),
          onPressed: _showSavingsGoalDialog,
        ),
      );
    }

    final target = _savingsGoal!['targetAmount'] as int? ?? 0;
    final name =
        _savingsGoal!['name'] as String? ?? context.tr('util_quchung_1cd93f');

    // Tính số tiền đã tiết kiệm được
    // Trong trường hợp này, ta có thể tính từ số tiền thu nhập (in) trừ đi một số khoản,
    // hoặc có thể tính đơn giản bằng tổng số tiền thu nhập (in) hoặc tạo danh mục context.tr('util_titkim_595e8b').
    // Ở đây ta dùng _totalBalance làm số tiền hiện có trong quỹ, nếu quỹ chung là tài khoản chính.
    // Hoặc ta tính tổng thu (hoặc chi cho danh mục Tiết kiệm).
    // Để đơn giản, ta dùng _totalBalance để so sánh với mục tiêu quỹ.
    final currentSaved = _totalBalance > 0 ? _totalBalance : 0;

    final double percent = target > 0
        ? (currentSaved / target).clamp(0.0, 1.0)
        : 0.0;
    final isReached = currentSaved >= target;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('💍', style: TextStyle(fontSize: 20)),
                    SLSpacing.w8,
                    Expanded(
                      child: Text(
                        name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.amber[800],
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cardIconButton(
                icon: Icons.edit_outlined,
                tooltip: context.tr('p8_finance_edit_savings_goal'),
                onPressed: _showSavingsGoalDialog,
              ),
              const SizedBox(width: 4),
              _cardIconButton(
                icon: Icons.delete_sweep_outlined,
                color: Colors.red,
                tooltip: context.tr('p8_finance_delete_savings_goal'),
                onPressed: _resetSavingsGoal,
              ),
            ],
          ),
          SLSpacing.h12,
          Row(
            children: [
              Expanded(
                child: Text(
                  L10nService().format('util_finance_saved_amount', {
                    'amount': _fmt.format(currentSaved),
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SLTheme.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  L10nService().format('util_finance_target_amount', {
                    'amount': _fmt.format(target),
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: SLTheme.textMuted,
                  ),
                ),
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
                isReached ? Colors.green : Colors.amber,
              ),
            ),
          ),
          SLSpacing.h12,
          Row(
            children: [
              const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
              SLSpacing.w8,
              Text(
                isReached
                    ? context.tr('util_tmctiu_d4d469')
                    : L10nService().format('util_finance_goal_percent', {
                        'percent': (percent * 100).toStringAsFixed(1),
                      }),
                style: SLTheme.quicksand(
                  color: Colors.amber[800],
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
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
      builder: (ctx) => FinanceDialog(
        title: Text(context.tr('util_toqumi_e38258')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _savingsGoalNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: context.tr('util_tnquvdquci_811553'),
                counterText: '',
              ),
            ),
            SLSpacing.h8,
            TextField(
              controller: _savingsGoalAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 12,
              decoration: InputDecoration(
                labelText: context.tr('util_stinmctiuv_e1bc2d'),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          FinanceDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          FinanceDialogAction(
            primary: true,

            onPressed: _saveSavingsGoal,

            child: Text(context.tr('util_luqu_163328')),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildChartSection() {
    if (_allTransactions.isEmpty) return const SizedBox.shrink();

    // Lọc các giao dịch chi tiêu (out) để vẽ biểu đồ
    final outTransactions = _allTransactions
        .where((t) => t['type'] == 'out')
        .toList();
    if (outTransactions.isEmpty) return const SizedBox.shrink();

    // Tính tổng theo danh mục
    final Map<String, double> categoryTotals = {};
    double totalOut = 0;
    for (var t in outTransactions) {
      final cat =
          FinanceCategory.codeOf(t['category']) ??
          t['category']?.toString() ??
          'other';
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
        pieSections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: percent,
            title: '${percent.toStringAsFixed(1)}%',
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('util_phntchchit_1737cd'),
            style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SLSpacing.h16,
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 430;
              final chart = Semantics(
                label: context.tr('p8_finance_expense_chart_semantics'),
                child: PieChart(
                  PieChartData(
                    sections: pieSections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              );
              final legend = ListView(
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
                            FinanceCategory.label(e.key, context.tr),
                            maxLines: 2,
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
              );

              if (isCompact) {
                return Column(
                  children: [
                    SizedBox(height: 150, child: chart),
                    const SizedBox(height: 12),
                    SizedBox(height: 112, child: legend),
                  ],
                );
              }

              return SizedBox(
                height: 150,
                child: Row(
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 12),
                    Expanded(child: legend),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FinanceDialog(
        title: Text(context.tr('util_lpkhoch_eb08e6')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _goalAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 12,
              decoration: InputDecoration(
                labelText: context.tr('util_tngngnschd_7447b3'),
                counterText: '',
              ),
            ),
            SLSpacing.h8,
            TextField(
              controller: _goalDaysController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 5,
              decoration: InputDecoration(
                labelText: context.tr('util_sngypdngvd_78fb41'),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          FinanceDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          FinanceDialogAction(
            primary: true,

            onPressed: _saveBudgetPlan,

            child: Text(context.tr('util_lukhoch_f05771')),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            context.tr('total_balance'),
            style: SLTheme.quicksand(
              color: SLTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SLSpacing.h8,
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: _totalBalance >= 0
                  ? const [Color(0xFFD81B60), Color(0xFF9C27B0)]
                  : const [Colors.red, Colors.deepOrange],
            ).createShader(b),
            child: Text(
              _fmt.format(_totalBalance),
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SLSpacing.h16,
          Row(
            children: [
              _balanceMiniBar(
                '💚 ${context.tr('income')}',
                _totalIn,
                Colors.green,
                const Color(0xFF2E7D32),
              ),
              SLSpacing.w12,
              _balanceMiniBar(
                '❤️ ${context.tr('expense')}',
                _totalOut,
                const Color(0xFFD81B60),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceMiniBar(
    String label,
    int amount,
    Color barColor,
    Color textColor,
  ) {
    final ratio = _totalIn + _totalOut == 0
        ? 0.0
        : amount / (_totalIn + _totalOut);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTheme.quicksand(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          SLSpacing.h4,
          ClipRRect(
            borderRadius: SLRadius.smAll,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8D5DF),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          SLSpacing.h4,
          Text(
            _fmt.format(amount),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all16,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: SLTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thu/Chi toggle - clone .mood-wrap
          Row(
            children: [
              _typeBtn('💚 ${context.tr('income')}', 'in', SLColors.success),
              SLSpacing.w8,
              _typeBtn('❤️ ${context.tr('expense')}', 'out', SLColors.primary),
            ],
          ),
          SLSpacing.h12,
          // Category chips
          Text(
            '${context.tr('category')}:',
            style: SLTheme.quicksand(
              color: SLTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          SLSpacing.h8,
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _category == cat;
                final label = FinanceCategory.label(cat, context.tr);
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: label,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _category = cat),
                        borderRadius: SLRadius.pillAll,
                        child: AnimatedContainer(
                          duration: SLDurations.fast,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: SLTheme.btnGradient,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : _financeFilterSurface(context),
                            borderRadius: SLRadius.pillAll,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : _financeFilterBorder(context),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                height: 1.2,
                                color: isSelected
                                    ? Colors.white
                                    : _financeFilterText(context),
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SLSpacing.h12,
          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            maxLength: 12,
            decoration: InputDecoration(
              hintText: context.tr('p8_finance_amount_hint'),
              hintStyle: SLTheme.quicksand(color: SLTheme.textLight),
              prefixIcon: Icon(
                Icons.attach_money,
                color: SLTheme.primary.withValues(alpha: 0.6),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFFFF5F7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFE8D5DF),
                  width: 2.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFD81B60),
                  width: 2.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: '',
            ),
          ),
          SLSpacing.h8,
          TextField(
            controller: _noteController,
            style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            maxLength: 100,
            decoration: InputDecoration(
              hintText: context.tr('util_tychn_9aa32e'),
              hintStyle: SLTheme.quicksand(color: SLTheme.textLight),
              prefixIcon: Icon(
                Icons.notes,
                color: SLTheme.primary.withValues(alpha: 0.6),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFFFF5F7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFE8D5DF),
                  width: 2.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFD81B60),
                  width: 2.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: '',
            ),
          ),
          SLSpacing.h12,
          SLTheme.primaryButton(
            label:
                '${context.tr('save')} ${_transactionType == 'in' ? context.tr('income') : context.tr('expense')} • ${FinanceCategory.label(_category, context.tr)}',
            onPressed: _addTransaction,
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, String type, Color color) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _transactionType = type),
            borderRadius: SLRadius.lgAll,
            child: AnimatedContainer(
              duration: SLDurations.normal,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color : _financeFilterSurface(context),
                borderRadius: SLRadius.lgAll,
                border: Border.all(
                  color: isSelected ? color : _financeFilterBorder(context),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: isSelected
                      ? Colors.white
                      : _financeFilterText(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _syncTransactionSummary({
    required List<Map<String, dynamic>> items,
    required int totalIn,
    required int totalOut,
  }) {
    final signature = items
        .map(
          (item) =>
              '${item['key']}:${item['type']}:${item['amount']}:${item['ts']}:${item['category']}:${item['note']}',
        )
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

  // ignore: unused_element, kept as a compatibility implementation for staged rollback.
  Widget _buildTransactionList() {
    return StreamBuilder(
      key: ValueKey(widget.houseId),
      stream: _budgetStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SkeletonContainer.rounded(
                  width: double.infinity,
                  height: 75,
                ),
              );
            }, childCount: 5),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    L10nService().format('util_finance_load_tx_error', {
                      'error': AppErrorMapper.resolve(snapshot.error).message,
                    }),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: SLTheme.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _budgetStream = _watchBudget()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('retry')),
                  ),
                ],
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
                  const Text(
                    '💸',
                    style: TextStyle(fontSize: 50),
                    textScaler: TextScaler.linear(1.0),
                  ),
                  SLSpacing.h8,
                  Text(
                    context.tr('util_finance_empty_transactions'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: SLTheme.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final data = Map<dynamic, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );
        final items = data.entries
            .map((e) => {'key': e.key, ...Map<String, dynamic>.from(e.value)})
            .toList();
        items.sort(
          (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0),
        );

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
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final item = items[i];
              final isIncome = item['type'] == 'in';
              final catEmoji = FinanceCategory.emoji(item['category']);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.xlAll,
                  border: Border(
                    left: BorderSide(
                      color: isIncome ? Colors.green : SLTheme.primary,
                      width: 5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isIncome
                              ? [
                                  const Color(0xFFE8F5E9),
                                  const Color(0xFFC8E6C9),
                                ]
                              : [
                                  const Color(0xFFFFE4EB),
                                  const Color(0xFFFFB3D9),
                                ],
                        ),
                        borderRadius: SLRadius.mdAll,
                      ),
                      child: Center(
                        child: Text(
                          catEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FinanceCategory.label(item['category'], context.tr),
                            style: SLTheme.quicksand(
                              color: SLTheme.textMain,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if ((item['note'] ?? '').toString().isNotEmpty)
                            Text(
                              item['note'],
                              style: SLTheme.quicksand(
                                color: SLTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          Row(
                            children: [
                              SLTheme.authorTag(item['from'] ?? ''),
                              SLSpacing.w8,
                              Text(
                                item['time'] ?? '',
                                style: SLTheme.quicksand(
                                  color: SLTheme.textLight,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          ),
                        ),
                        SLSpacing.h4,
                        GestureDetector(
                          onTap: () => _deleteTransaction(item['key']),
                          child: const Icon(
                            Icons.delete_outline,
                            color: SLTheme.textLight,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }
}
