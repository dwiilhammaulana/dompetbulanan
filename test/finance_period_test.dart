import 'package:dompet_bulanan/core/finance_period.dart';
import 'package:dompet_bulanan/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancePeriod', () {
    test('membuat siklus gajian tanggal 25 secara otomatis', () {
      final period = FinancePeriod.cycleContaining(DateTime(2026, 11, 14), 25);

      expect(period.start, DateTime(2026, 10, 25));
      expect(period.end, DateTime(2026, 11, 24));
      expect(period.dayCount, 31);
    });

    test('menjepit tanggal 31 pada bulan yang lebih pendek', () {
      final february = FinancePeriod.cycleContaining(DateTime(2027, 2, 28), 31);

      expect(february.start, DateTime(2027, 2, 28));
      expect(february.end, DateTime(2027, 3, 30));
    });

    test('periode sebelumnya berakhir sebelum periode aktif', () {
      final current = FinancePeriod.cycleContaining(DateTime(2026, 11, 14), 25);
      final previous = current.previousCycle(25);

      expect(previous.start, DateTime(2026, 9, 25));
      expect(previous.end, DateTime(2026, 10, 24));
    });
  });

  test('FinanceSummary memisahkan pemasukan dan pengeluaran', () {
    final transactions = [
      FinanceTransaction(
        id: '1',
        walletId: 'wallet',
        categoryId: 'salary',
        kind: TransactionKind.income,
        amount: 7000000,
        date: DateTime(2026, 11, 1),
      ),
      FinanceTransaction(
        id: '2',
        walletId: 'wallet',
        categoryId: 'food',
        kind: TransactionKind.expense,
        amount: 100000,
        date: DateTime(2026, 11, 2),
      ),
      FinanceTransaction(
        id: '3',
        walletId: 'wallet',
        categoryId: 'food',
        kind: TransactionKind.expense,
        amount: 50000,
        date: DateTime(2026, 11, 2),
      ),
    ];

    final summary = FinanceSummary.fromTransactions(
      transactions,
      FinancePeriod.calendarMonth(DateTime(2026, 11)),
    );

    expect(summary.income, 7000000);
    expect(summary.expense, 150000);
    expect(summary.net, 6850000);
    expect(summary.byCategory['food'], 150000);
    expect(summary.dailyExpense[DateTime(2026, 11, 2)], 150000);
  });
}
