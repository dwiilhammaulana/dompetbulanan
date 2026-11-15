import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/finance_period.dart';
import '../core/formatters.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import '../widgets/common.dart';
import '../widgets/finance_charts.dart';

enum _ReportPreset { cycle, month, year, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPreset _preset = _ReportPreset.cycle;
  DateTime _cursor = DateTime.now();
  FinancePeriod? _customPeriod;

  FinancePeriod get _period => switch (_preset) {
    _ReportPreset.cycle => FinancePeriod.cycleContaining(
      _cursor,
      widget.controller.wallet.cycleStartDay,
    ),
    _ReportPreset.month => FinancePeriod.calendarMonth(_cursor),
    _ReportPreset.year => FinancePeriod.calendarYear(_cursor.year),
    _ReportPreset.custom => _customPeriod ?? widget.controller.currentPeriod,
  };

  String get _periodLabel => switch (_preset) {
    _ReportPreset.month => formatMonth(_cursor),
    _ReportPreset.year => _cursor.year.toString(),
    _ => '${formatDate(_period.start)} – ${formatDate(_period.end)}',
  };

  FinancePeriod get _previousComparablePeriod {
    final current = _period;
    return switch (_preset) {
      _ReportPreset.cycle => current.previousCycle(
        widget.controller.wallet.cycleStartDay,
      ),
      _ReportPreset.month => FinancePeriod.calendarMonth(
        DateTime(_cursor.year, _cursor.month - 1),
      ),
      _ReportPreset.year => FinancePeriod.calendarYear(_cursor.year - 1),
      _ReportPreset.custom => FinancePeriod(
        start: current.start.subtract(Duration(days: current.dayCount)),
        end: current.start.subtract(const Duration(days: 1)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final summary = widget.controller.summaryFor(period);
    final previousPeriod = _previousComparablePeriod;
    final previousSummary = widget.controller.summaryFor(previousPeriod);
    final expenseCategories = widget.controller.categoriesFor(
      TransactionKind.expense,
    );
    final categoryMap = {for (final item in expenseCategories) item.id: item};
    final categoryEntries = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cashFlow = _preset == _ReportPreset.year
        ? widget.controller.monthlyCashFlow(
            count: 12,
            endingMonth: DateTime(_cursor.year, 12),
          )
        : widget.controller.monthlyCashFlow(count: 6, endingMonth: period.end);

    return PageFrame(
      child: ListView(
        key: const PageStorageKey('reports-scroll'),
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          _ReportWalletHeader(controller: widget.controller),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(
                  label: 'Siklus gajian',
                  selected: _preset == _ReportPreset.cycle,
                  onSelected: () => _selectPreset(_ReportPreset.cycle),
                ),
                _PresetChip(
                  label: 'Bulanan',
                  selected: _preset == _ReportPreset.month,
                  onSelected: () => _selectPreset(_ReportPreset.month),
                ),
                _PresetChip(
                  label: 'Tahunan',
                  selected: _preset == _ReportPreset.year,
                  onSelected: () => _selectPreset(_ReportPreset.year),
                ),
                _PresetChip(
                  label: 'Tanggal khusus',
                  selected: _preset == _ReportPreset.custom,
                  onSelected: _pickCustomPeriod,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PeriodNavigator(
            label: _periodLabel,
            caption: _presetLabel(_preset),
            custom: _preset == _ReportPreset.custom,
            onPrevious: () => _movePeriod(-1),
            onNext: () => _movePeriod(1),
            onPick: _pickCustomPeriod,
          ),
          const SizedBox(height: 16),
          _NetFlowCard(summary: summary),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan kategori',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryMetric(
                          label: 'Pemasukan',
                          value: summary.income,
                          color: AppColors.income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryMetric(
                          label: 'Pengeluaran',
                          value: summary.expense,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    child: CategoryDonutChart(
                      summary: summary,
                      categories: expenseCategories,
                    ),
                  ),
                  if (categoryEntries.isNotEmpty) ...[
                    const Divider(height: 20),
                    for (final entry in categoryEntries)
                      _CategoryReportRow(
                        category: categoryMap[entry.key],
                        amount: entry.value,
                        total: summary.expense,
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _BudgetReport(summary: summary, budgetLimit: _budgetLimit(period)),
          if (period.dayCount <= 93) ...[
            const SizedBox(height: 26),
            const SectionHeader(
              title: 'Tren pengeluaran',
              subtitle: 'Pergerakan kumulatif dibanding periode sebelumnya',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
                child: RepaintBoundary(
                  child: SpendingComparisonChart(
                    current: summary,
                    previous: previousSummary,
                    currentPeriod: period,
                    previousPeriod: previousPeriod,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Pemasukan & pengeluaran',
            subtitle: _preset == _ReportPreset.year
                ? 'Perbandingan 12 bulan pada ${_cursor.year}'
                : 'Perbandingan 6 bulan terakhir',
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
              child: RepaintBoundary(
                child: MonthlyCashFlowChart(data: cashFlow),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectPreset(_ReportPreset preset) {
    setState(() {
      _preset = preset;
      _cursor = DateTime.now();
    });
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_preset) {
        case _ReportPreset.cycle:
          final current = _period;
          _cursor = direction < 0
              ? current.start.subtract(const Duration(days: 1))
              : current.end.add(const Duration(days: 1));
        case _ReportPreset.month:
          _cursor = DateTime(_cursor.year, _cursor.month + direction);
        case _ReportPreset.year:
          _cursor = DateTime(_cursor.year + direction);
        case _ReportPreset.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomPeriod() async {
    final initial = _customPeriod ?? widget.controller.currentPeriod;
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initial.start, end: initial.end),
      helpText: 'Pilih periode laporan',
      saveText: 'Gunakan',
    );
    if (result != null && mounted) {
      setState(() {
        _customPeriod = FinancePeriod(start: result.start, end: result.end);
        _preset = _ReportPreset.custom;
      });
    }
  }

  String _presetLabel(_ReportPreset preset) => switch (preset) {
    _ReportPreset.cycle => 'Siklus keuangan',
    _ReportPreset.month => 'Laporan bulanan',
    _ReportPreset.year => 'Laporan tahunan',
    _ReportPreset.custom => 'Periode pilihan Anda',
  };

  double _budgetLimit(FinancePeriod period) {
    final monthlyBudget = widget.controller.wallet.monthlyBudget;
    return switch (_preset) {
      _ReportPreset.year => monthlyBudget * 12,
      _ReportPreset.custom => monthlyBudget * (period.dayCount / 30.4375),
      _ => monthlyBudget,
    };
  }
}

class _ReportWalletHeader extends StatelessWidget {
  const _ReportWalletHeader({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text('Laporan', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD8762B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        controller.wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text('Saldo', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 3),
      Text(
        formatRupiah(controller.walletBalance),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ],
  );
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.caption,
    required this.custom,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String label;
  final String caption;
  final bool custom;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: Row(
        children: [
          IconButton(
            onPressed: custom ? onPick : onPrevious,
            icon: Icon(
              custom
                  ? Icons.calendar_month_outlined
                  : Icons.chevron_left_rounded,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: custom ? onPick : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      caption,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 170),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: custom ? onPick : onNext,
            icon: Icon(
              custom
                  ? Icons.edit_calendar_outlined
                  : Icons.chevron_right_rounded,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NetFlowCard extends StatelessWidget {
  const _NetFlowCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final positive = summary.net >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Pemasukan Bersih',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.help_rounded,
                        color: AppColors.muted,
                        size: 19,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  positive ? 'Surplus' : 'Defisit',
                  style: TextStyle(
                    color: positive ? AppColors.primary : AppColors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${positive ? '+' : '-'} ${formatRupiah(summary.net.abs())}',
              style: TextStyle(
                color: positive ? AppColors.primary : AppColors.expense,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 21),
            _FlowBar(
              label: 'Pemasukan',
              value: summary.income,
              maxValue: math.max(summary.income, summary.expense),
              color: AppColors.income,
            ),
            const SizedBox(height: 17),
            _FlowBar(
              label: 'Pengeluaran',
              value: summary.expense,
              maxValue: math.max(summary.income, summary.expense),
              color: AppColors.expense,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = maxValue <= 0 ? 0.0 : value / maxValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatRupiah(value),
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * progress,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: progress > 0.22
                    ? Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryMetric extends StatelessWidget {
  const _CategoryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatRupiah(value),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}

class _BudgetReport extends StatelessWidget {
  const _BudgetReport({required this.summary, required this.budgetLimit});

  final FinanceSummary summary;
  final double budgetLimit;

  @override
  Widget build(BuildContext context) {
    if (budgetLimit <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(17),
          child: Row(
            children: [
              Icon(Icons.savings_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Batas pengeluaran normal belum diatur. Atur dari menu Akun.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final remaining = budgetLimit - summary.expense;
    final over = remaining < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    over ? 'Kelebihan pengeluaran' : 'Sisa pengeluaran normal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRupiah(remaining.abs()),
                      style: TextStyle(
                        color: over ? AppColors.expense : AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (summary.expense / budgetLimit).clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppColors.expense : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(),
    ),
  );
}

class _CategoryReportRow extends StatelessWidget {
  const _CategoryReportRow({
    required this.category,
    required this.amount,
    required this.total,
  });

  final FinanceCategory? category;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final safeCategory =
        category ??
        const FinanceCategory(
          id: 'unknown',
          name: 'Kategori lain',
          kind: TransactionKind.expense,
          iconKey: 'other',
          colorHex: '#7A8B84',
        );
    final percentage = total <= 0 ? 0 : amount / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryAvatar(category: safeCategory, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        safeCategory.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatRupiah(amount),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percentage.toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(safeCategory.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}% dari pengeluaran',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
