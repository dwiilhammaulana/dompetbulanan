import 'package:dompet_bulanan/app.dart';
import 'package:dompet_bulanan/models/finance_models.dart';
import 'package:dompet_bulanan/repositories/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('langsung membuka beranda tanpa login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      DompetBulananApp(repository: _FakeFinanceRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dompet Utama'), findsOneWidget);
    expect(find.text('Ringkasan'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
    expect(find.textContaining('Supabase'), findsNothing);

    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat laporan untuk periode ini'), findsOneWidget);

    await tester.tap(find.text('Anggaran'));
    await tester.pumpAndSettle();
    expect(find.text('Pemasukan Bersih'), findsOneWidget);

    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Dompet bulanan'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah transaksi'), findsOneWidget);
    expect(find.text('Pilih Kategori'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeFinanceRepository implements FinanceRepository {
  @override
  Future<FinanceData> load() async => FinanceData(
    wallet: const WalletSettings(
      id: 'wallet-local',
      name: 'Dompet Utama',
      currency: 'IDR',
      initialBalance: 0,
      monthlyBudget: 0,
      cycleStartDay: 1,
    ),
    categories: defaultCategories(),
    transactions: const [],
  );

  @override
  Future<void> addCategory(FinanceCategory category) async {}

  @override
  Future<void> addTransaction(FinanceTransaction transaction) async {}

  @override
  Future<void> deleteCategory(String categoryId) async {}

  @override
  Future<void> deleteTransaction(String transactionId) async {}

  @override
  Future<void> saveWallet(WalletSettings wallet) async {}
}
