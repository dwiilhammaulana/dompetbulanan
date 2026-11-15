import 'package:flutter/foundation.dart';

import '../core/finance_period.dart';
import '../models/finance_models.dart';
import '../repositories/finance_repository.dart';

class MonthlyCashFlow {
  const MonthlyCashFlow({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

class FinanceController extends ChangeNotifier {
  FinanceController(this.repository);

  final FinanceRepository repository;

  FinanceData? _data;
  bool _loading = true;
  bool _mutating = false;
  String? _error;

  FinanceData? get data => _data;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  WalletSettings get wallet => _data!.wallet;
  List<FinanceCategory> get categories => _data!.categories;
  List<FinanceTransaction> get transactions => _data!.transactions;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await repository.load();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  FinancePeriod get currentPeriod =>
      FinancePeriod.cycleContaining(DateTime.now(), wallet.cycleStartDay);

  FinancePeriod get previousPeriod =>
      currentPeriod.previousCycle(wallet.cycleStartDay);

  FinanceSummary summaryFor(FinancePeriod period) =>
      FinanceSummary.fromTransactions(transactions, period);

  FinanceSummary get currentSummary => summaryFor(currentPeriod);
  FinanceSummary get previousSummary => summaryFor(previousPeriod);

  double get walletBalance {
    var result = wallet.initialBalance;
    for (final transaction in transactions) {
      result += transaction.kind == TransactionKind.income
          ? transaction.amount
          : -transaction.amount;
    }
    return result;
  }

  double get remainingBudget => wallet.monthlyBudget - currentSummary.expense;

  double get budgetProgress {
    if (wallet.monthlyBudget <= 0) return 0;
    return (currentSummary.expense / wallet.monthlyBudget).clamp(0, 1.0);
  }

  FinanceCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<FinanceCategory> categoriesFor(TransactionKind kind) => categories
      .where((category) => category.kind == kind)
      .toList(growable: false);

  List<FinanceTransaction> transactionsFor(
    FinancePeriod period, {
    TransactionKind? kind,
  }) =>
      transactions
          .where(
            (transaction) =>
                period.contains(transaction.date) &&
                (kind == null || transaction.kind == kind),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<MonthlyCashFlow> monthlyCashFlow({
    int count = 6,
    DateTime? endingMonth,
  }) {
    final end = endingMonth ?? DateTime.now();
    return List.generate(count, (index) {
      final month = DateTime(end.year, end.month - (count - 1 - index));
      final summary = summaryFor(FinancePeriod.calendarMonth(month));
      return MonthlyCashFlow(
        month: month,
        income: summary.income,
        expense: summary.expense,
      );
    });
  }

  Future<String?> addTransaction({
    required TransactionKind kind,
    required double amount,
    required DateTime date,
    required FinanceCategory category,
    required String note,
  }) => _mutate(
    () => repository.addTransaction(
      FinanceTransaction(
        id: '',
        walletId: wallet.id,
        categoryId: category.id,
        kind: kind,
        amount: amount,
        date: date,
        note: note,
      ),
    ),
  );

  Future<String?> deleteTransaction(String id) =>
      _mutate(() => repository.deleteTransaction(id));

  Future<String?> saveWallet(WalletSettings settings) =>
      _mutate(() => repository.saveWallet(settings));

  Future<String?> addCategory({
    required String name,
    required TransactionKind kind,
    required String iconKey,
    required String colorHex,
  }) => _mutate(
    () => repository.addCategory(
      FinanceCategory(
        id: '',
        name: name,
        kind: kind,
        iconKey: iconKey,
        colorHex: colorHex,
      ),
    ),
  );

  Future<String?> deleteCategory(String id) =>
      _mutate(() => repository.deleteCategory(id));

  Future<String?> _mutate(Future<void> Function() action) async {
    if (_mutating) return 'Tunggu proses sebelumnya selesai.';
    _mutating = true;
    notifyListeners();
    try {
      await action();
      _data = await repository.load();
      _error = null;
      return null;
    } catch (error) {
      return _friendlyError(error);
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('foreign key') || message.contains('23503')) {
      return 'Kategori masih dipakai oleh transaksi dan belum dapat dihapus.';
    }
    if (lowerMessage.contains('duplicate') ||
        lowerMessage.contains('unique constraint') ||
        message.contains('23505')) {
      return 'Nama kategori tersebut sudah ada.';
    }
    if (message.contains('SocketException') ||
        message.contains('Failed host')) {
      return 'Tidak dapat terhubung ke internet. Periksa koneksi lalu coba lagi.';
    }
    return message.replaceFirst('Bad state: ', '');
  }
}
