import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/finance_period.dart';
import '../core/formatters.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import '../widgets/common.dart';

enum _TransactionFilter { all, expense, income }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.controller,
    required this.onAddTransaction,
    required this.onSeeReports,
  });

  final FinanceController controller;
  final VoidCallback onAddTransaction;
  final VoidCallback onSeeReports;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  _TransactionFilter _filter = _TransactionFilter.all;
  bool _currentCycleOnly = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  List<FinanceTransaction> get _periodTransactions {
    final source = _currentCycleOnly
        ? widget.controller.transactionsFor(widget.controller.currentPeriod)
        : [...widget.controller.transactions];
    return source..sort((a, b) {
      final dateResult = b.date.compareTo(a.date);
      return dateResult != 0 ? dateResult : b.id.compareTo(a.id);
    });
  }

  List<FinanceTransaction> get _visibleTransactions {
    final query = _searchController.text.trim().toLowerCase();
    return _periodTransactions
        .where((transaction) {
          final filterMatch = switch (_filter) {
            _TransactionFilter.all => true,
            _TransactionFilter.expense =>
              transaction.kind == TransactionKind.expense,
            _TransactionFilter.income =>
              transaction.kind == TransactionKind.income,
          };
          if (!filterMatch) return false;
          if (query.isEmpty) return true;
          final category = widget.controller.categoryById(
            transaction.categoryId,
          );
          return transaction.note.toLowerCase().contains(query) ||
              (category?.name.toLowerCase().contains(query) ?? false) ||
              transaction.amount.toStringAsFixed(0).contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final periodTransactions = _periodTransactions;
    final transactions = _visibleTransactions;
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final transaction in transactions) {
      final day = FinancePeriod.dateOnly(transaction.date);
      grouped.putIfAbsent(day, () => []).add(transaction);
    }
    final totalExpense = periodTransactions
        .where((item) => item.kind == TransactionKind.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final totalIncome = periodTransactions
        .where((item) => item.kind == TransactionKind.income)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: CustomScrollView(
          key: const PageStorageKey('transactions-scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HistoryHeader(
                controller: widget.controller,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                currentCycleOnly: _currentCycleOnly,
                searching: _searching,
                searchController: _searchController,
                filter: _filter,
                onToggleSearch: () {
                  setState(() {
                    _searching = !_searching;
                    if (!_searching) _searchController.clear();
                  });
                },
                onFilterChanged: (value) => setState(() => _filter = value),
                onScopeChanged: (value) =>
                    setState(() => _currentCycleOnly = value),
                onSeeReports: widget.onSeeReports,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            if (grouped.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: EmptyState(
                      icon: _searchController.text.isEmpty
                          ? Icons.receipt_long_rounded
                          : Icons.search_off_rounded,
                      title: _searchController.text.isEmpty
                          ? 'Belum ada transaksi'
                          : 'Transaksi tidak ditemukan',
                      message: _searchController.text.isEmpty
                          ? (_currentCycleOnly
                                ? 'Belum ada transaksi pada periode keuangan ini.'
                                : 'Mulai catat pemasukan dan pengeluaran Anda.')
                          : 'Coba gunakan kata kunci atau filter yang berbeda.',
                      action: _searchController.text.isEmpty
                          ? FilledButton.icon(
                              onPressed: widget.onAddTransaction,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tambah transaksi'),
                            )
                          : null,
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _DayGroup(
                      date: entry.key,
                      transactions: entry.value,
                      controller: widget.controller,
                      onDelete: _delete,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 106)),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(FinanceTransaction transaction) async {
    final confirmed = await confirmAction(
      context,
      title: 'Hapus transaksi?',
      message:
          'Transaksi ${formatRupiah(transaction.amount)} akan dihapus permanen.',
    );
    if (!confirmed || !mounted) return;
    final error = await widget.controller.deleteTransaction(transaction.id);
    if (mounted) {
      showResultSnackBar(context, error, 'Transaksi berhasil dihapus.');
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.controller,
    required this.totalIncome,
    required this.totalExpense,
    required this.currentCycleOnly,
    required this.searching,
    required this.searchController,
    required this.filter,
    required this.onToggleSearch,
    required this.onFilterChanged,
    required this.onScopeChanged,
    required this.onSeeReports,
  });

  final FinanceController controller;
  final double totalIncome;
  final double totalExpense;
  final bool currentCycleOnly;
  final bool searching;
  final TextEditingController searchController;
  final _TransactionFilter filter;
  final VoidCallback onToggleSearch;
  final ValueChanged<_TransactionFilter> onFilterChanged;
  final ValueChanged<bool> onScopeChanged;
  final VoidCallback onSeeReports;

  @override
  Widget build(BuildContext context) {
    final period = controller.currentPeriod;
    final net = totalIncome - totalExpense;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.help_outline_rounded, size: 27),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD8762B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 92),
                        child: Text(
                          controller.wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.unfold_more_rounded, size: 18),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: searching
                            ? 'Tutup pencarian'
                            : 'Cari transaksi',
                        onPressed: onToggleSearch,
                        icon: Icon(
                          searching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          size: 27,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Filter riwayat',
                        icon: const Icon(Icons.more_vert_rounded, size: 27),
                        onSelected: (value) {
                          switch (value) {
                            case 'cycle':
                              onScopeChanged(true);
                            case 'all-time':
                              onScopeChanged(false);
                            case 'filter-all':
                              onFilterChanged(_TransactionFilter.all);
                            case 'filter-expense':
                              onFilterChanged(_TransactionFilter.expense);
                            case 'filter-income':
                              onFilterChanged(_TransactionFilter.income);
                          }
                        },
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'cycle',
                            checked: currentCycleOnly,
                            child: const Text('Periode aktif'),
                          ),
                          CheckedPopupMenuItem(
                            value: 'all-time',
                            checked: !currentCycleOnly,
                            child: const Text('Semua waktu'),
                          ),
                          const PopupMenuDivider(),
                          CheckedPopupMenuItem(
                            value: 'filter-all',
                            checked: filter == _TransactionFilter.all,
                            child: const Text('Semua transaksi'),
                          ),
                          CheckedPopupMenuItem(
                            value: 'filter-expense',
                            checked: filter == _TransactionFilter.expense,
                            child: const Text('Pengeluaran saja'),
                          ),
                          CheckedPopupMenuItem(
                            value: 'filter-income',
                            checked: filter == _TransactionFilter.income,
                            child: const Text('Pemasukan saja'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: searching
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Cari kategori, catatan, atau nominal',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 19),
          const Text('Saldo', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(
            formatRupiah(controller.walletBalance),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              currentCycleOnly
                  ? '${DateFormat('dd/MM').format(period.start)} - ${DateFormat('dd/MM').format(period.end)}'
                  : 'Semua transaksi',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 17),
          _SummaryLine(
            label: 'Pemasukan',
            value: totalIncome,
            color: AppColors.income,
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Pengeluaran',
            value: totalExpense,
            color: AppColors.expense,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 205, top: 8),
            child: Divider(height: 1),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              Text(
                '${net < 0 ? '-' : ''}${formatRupiah(net.abs())}',
                style: TextStyle(
                  color: net < 0 ? AppColors.expense : AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          FilledButton(
            onPressed: onSeeReports,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Lihat laporan untuk periode ini'),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 16),
        ),
      ),
      Text(
        formatRupiah(value),
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.date,
    required this.transactions,
    required this.controller,
    required this.onDelete,
  });

  final DateTime date;
  final List<FinanceTransaction> transactions;
  final FinanceController controller;
  final ValueChanged<FinanceTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final expense = transactions
        .where((item) => item.kind == TransactionKind.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final income = transactions
        .where((item) => item.kind == TransactionKind.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final net = income - expense;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 15, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 57,
                child: Text(
                  date.day.toString(),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 38,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _relativeDay(date),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(date),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${net < 0
                    ? '-'
                    : net > 0
                    ? '+'
                    : ''}${formatRupiah(net.abs())}',
                style: TextStyle(
                  color: net < 0
                      ? AppColors.expense
                      : net > 0
                      ? AppColors.income
                      : AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const Divider(height: 16),
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionTile(
              transaction: transactions[index],
              category: controller.categoryById(transactions[index].categoryId),
              onDelete: () => onDelete(transactions[index]),
            ),
            if (index < transactions.length - 1)
              const Divider(height: 1, indent: 62),
          ],
        ],
      ),
    );
  }

  String _relativeDay(DateTime value) {
    final today = FinancePeriod.dateOnly(DateTime.now());
    final target = FinancePeriod.dateOnly(value);
    if (target == today) return 'Hari ini';
    if (target == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return DateFormat('EEEE', 'id_ID').format(value);
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final FinanceCategory? category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final safeCategory =
        category ??
        FinanceCategory(
          id: 'unknown',
          name: 'Kategori terhapus',
          kind: transaction.kind,
          iconKey: 'other',
          colorHex: '#7A8B84',
        );
    return InkWell(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CategoryAvatar(category: safeCategory, size: 46),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeCategory.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.note.isEmpty
                        ? 'Tanpa catatan'
                        : transaction.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatRupiah(transaction.amount),
              style: TextStyle(
                color: transaction.kind == TransactionKind.income
                    ? AppColors.income
                    : AppColors.expense,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Pilihan transaksi',
              iconSize: 19,
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.expense,
                      ),
                      SizedBox(width: 9),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
