import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/finance_period.dart';
import '../core/formatters.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onAddTransaction,
    required this.onSeeTransactions,
    required this.onSeeReports,
    required this.onOpenSettings,
  });

  final FinanceController controller;
  final VoidCallback onAddTransaction;
  final VoidCallback onSeeTransactions;
  final VoidCallback onSeeReports;
  final VoidCallback onOpenSettings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showBalance = true;
  bool _monthlyReport = true;

  @override
  Widget build(BuildContext context) {
    final ranges = _reportRanges();
    final current = widget.controller.summaryFor(ranges.$1);
    final previous = widget.controller.summaryFor(ranges.$2);
    final difference = current.expense - previous.expense;
    final percent = previous.expense <= 0
        ? null
        : difference.abs() / previous.expense * 100;
    final recent = [...widget.controller.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return PageFrame(
      child: ListView(
        key: const PageStorageKey('dashboard-scroll'),
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          _TopBalance(
            balance: widget.controller.walletBalance,
            showBalance: _showBalance,
            onToggleBalance: () => setState(() => _showBalance = !_showBalance),
            onSearch: widget.onSeeTransactions,
            onNotifications: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tidak ada pengingat baru.')),
            ),
          ),
          const SizedBox(height: 24),
          _WalletCard(
            walletName: widget.controller.wallet.name,
            balance: widget.controller.walletBalance,
            showBalance: _showBalance,
            onTap: widget.onOpenSettings,
          ),
          const SizedBox(height: 26),
          _SectionLink(
            title: _monthlyReport
                ? 'Laporan periode ini'
                : 'Laporan minggu ini',
            action: 'Lihat semua laporan',
            onTap: widget.onSeeReports,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReportToggle(
                    monthly: _monthlyReport,
                    onChanged: (value) =>
                        setState(() => _monthlyReport = value),
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Column(
                      key: ValueKey(_monthlyReport),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatRupiah(current.expense),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _monthlyReport
                                    ? 'Total pembelanjaan periode ini'
                                    : 'Total pembelanjaan 7 hari terakhir',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            _TrendBadge(
                              difference: difference,
                              percent: percent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  RepaintBoundary(
                    child: _ComparisonBars(
                      previous: previous.expense,
                      current: current.expense,
                      previousLabel: _monthlyReport
                          ? 'Periode lalu'
                          : '7 hari lalu',
                      currentLabel: _monthlyReport
                          ? 'Periode ini'
                          : '7 hari ini',
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Divider(height: 1),
                  InkWell(
                    onTap: widget.onSeeReports,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.primary,
                          ),
                          Expanded(
                            child: Text(
                              'Laporan pengeluaran',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _BudgetCard(
            controller: widget.controller,
            onTap: widget.controller.wallet.monthlyBudget > 0
                ? widget.onSeeReports
                : widget.onOpenSettings,
          ),
          const SizedBox(height: 26),
          _SectionLink(
            title: 'Transaksi terbaru',
            action: 'Lihat semua',
            onTap: widget.onSeeTransactions,
          ),
          const SizedBox(height: 10),
          Card(
            child: recent.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Belum ada transaksi',
                    message: 'Catat pemasukan atau pengeluaran pertama Anda.',
                    action: FilledButton.icon(
                      onPressed: widget.onAddTransaction,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah transaksi'),
                    ),
                  )
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < math.min(recent.length, 4);
                        index++
                      ) ...[
                        _RecentTransaction(
                          transaction: recent[index],
                          category: widget.controller.categoryById(
                            recent[index].categoryId,
                          ),
                        ),
                        if (index < math.min(recent.length, 4) - 1)
                          const Divider(height: 1, indent: 72),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  (FinancePeriod, FinancePeriod) _reportRanges() {
    if (_monthlyReport) {
      return (
        widget.controller.currentPeriod,
        widget.controller.previousPeriod,
      );
    }
    final today = FinancePeriod.dateOnly(DateTime.now());
    final current = FinancePeriod(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    final previous = FinancePeriod(
      start: current.start.subtract(const Duration(days: 7)),
      end: current.start.subtract(const Duration(days: 1)),
    );
    return (current, previous);
  }
}

class _TopBalance extends StatelessWidget {
  const _TopBalance({
    required this.balance,
    required this.showBalance,
    required this.onToggleBalance,
    required this.onSearch,
    required this.onNotifications,
  });

  final double balance;
  final bool showBalance;
  final VoidCallback onToggleBalance;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      showBalance ? formatRupiah(balance) : 'Rp ••••••',
                      key: ValueKey(showBalance),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: showBalance
                      ? 'Sembunyikan saldo'
                      : 'Tampilkan saldo',
                  onPressed: onToggleBalance,
                  icon: Icon(
                    showBalance
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 23,
                  ),
                ),
              ],
            ),
            const Text(
              'Jumlah saldo',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cari transaksi',
        onPressed: onSearch,
        icon: const Icon(Icons.search_rounded, size: 29),
      ),
      IconButton(
        tooltip: 'Pengingat',
        onPressed: onNotifications,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 28),
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.expense,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.walletName,
    required this.balance,
    required this.showBalance,
    required this.onTap,
  });

  final String walletName;
  final double balance;
  final bool showBalance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 19),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Dompet Saya',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                const Text(
                  'Kelola',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(height: 1),
            const SizedBox(height: 17),
            Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8762B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    walletName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  showBalance ? formatRupiah(balance) : 'Rp ••••••',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _ReportToggle extends StatelessWidget {
  const _ReportToggle({required this.monthly, required this.onChanged});

  final bool monthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        _ToggleOption(
          label: 'Minggu',
          selected: !monthly,
          onTap: () => onChanged(false),
        ),
        _ToggleOption(
          label: 'Bulan',
          selected: monthly,
          onTap: () => onChanged(true),
        ),
      ],
    ),
  );
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3A3B3E) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.ink : AppColors.muted,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.difference, required this.percent});

  final double difference;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    if (difference == 0) {
      return const Text('Tetap', style: TextStyle(color: AppColors.muted));
    }
    final improved = difference < 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          improved ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          size: 17,
          color: improved ? AppColors.primary : AppColors.expense,
        ),
        const SizedBox(width: 3),
        Text(
          percent == null ? 'Baru' : '${percent!.toStringAsFixed(0)}%',
          style: TextStyle(
            color: improved ? AppColors.primary : AppColors.expense,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ComparisonBars extends StatelessWidget {
  const _ComparisonBars({
    required this.previous,
    required this.current,
    required this.previousLabel,
    required this.currentLabel,
  });

  final double previous;
  final double current;
  final String previousLabel;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(previous, current);
    double ratio(double value) => maxValue <= 0 ? 0.03 : value / maxValue;

    return SizedBox(
      height: 205,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Bar(
              ratio: ratio(previous),
              value: previous,
              label: previousLabel,
              color: const Color(0xFFFFA2A4),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _Bar(
              ratio: ratio(current),
              value: current,
              label: currentLabel,
              color: AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.ratio,
    required this.value,
    required this.label,
    required this.color,
  });

  final double ratio;
  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.bottomCenter,
            child: Tooltip(
              message: formatRupiah(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 78,
                height: math.max(4, constraints.maxHeight * ratio),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.controller, required this.onTap});

  final FinanceController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBudget = controller.wallet.monthlyBudget > 0;
    final remaining = controller.remainingBudget;
    final overBudget = hasBudget && remaining < 0;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          (overBudget ? AppColors.expense : AppColors.primary)
                              .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.savings_outlined,
                      color: overBudget ? AppColors.expense : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasBudget
                              ? (overBudget
                                    ? 'Melebihi pengeluaran normal'
                                    : 'Sisa pengeluaran normal')
                              : 'Atur pengeluaran normal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasBudget
                              ? '${formatRupiah(controller.currentSummary.expense)} dari ${formatRupiah(controller.wallet.monthlyBudget)}'
                              : 'Tentukan batas bulanan dari pengaturan dompet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (hasBudget)
                    Text(
                      formatRupiah(remaining.abs()),
                      style: TextStyle(
                        color: overBudget
                            ? AppColors.expense
                            : AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: controller.budgetProgress,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(
                      overBudget ? AppColors.expense : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransaction extends StatelessWidget {
  const _RecentTransaction({required this.transaction, required this.category});

  final FinanceTransaction transaction;
  final FinanceCategory? category;

  @override
  Widget build(BuildContext context) {
    final safeCategory =
        category ??
        FinanceCategory(
          id: 'unknown',
          name: 'Kategori lain',
          kind: transaction.kind,
          iconKey: 'other',
          colorHex: '#7A8B84',
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CategoryAvatar(category: safeCategory, size: 43),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeCategory.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note.isEmpty
                      ? formatDate(transaction.date)
                      : transaction.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          AmountText(amount: transaction.amount, kind: transaction.kind),
        ],
      ),
    );
  }
}
