import 'dart:io';

import 'package:dompet_bulanan/models/finance_models.dart';
import 'package:dompet_bulanan/repositories/sqlite_finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late SqliteFinanceRepository repository;

  setUp(() {
    repository = SqliteFinanceRepository(
      databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() => repository.close());

  test('membuat dompet dan kategori bawaan tanpa transaksi contoh', () async {
    final data = await repository.load();

    expect(data.wallet.name, 'Dompet Utama');
    expect(data.wallet.initialBalance, 0);
    expect(data.categories, isNotEmpty);
    expect(
      data.categories.any((item) => item.name == 'Makanan & Minuman'),
      isTrue,
    );
    expect(data.categories.any((item) => item.name == 'Gaji'), isTrue);
    expect(data.transactions, isEmpty);
  });

  test('menyimpan pengaturan dan transaksi secara lokal', () async {
    final initial = await repository.load();
    final food = initial.categories.firstWhere(
      (item) => item.kind == TransactionKind.expense,
    );

    await repository.saveWallet(
      initial.wallet.copyWith(
        initialBalance: 3000000,
        monthlyBudget: 4500000,
        cycleStartDay: 25,
      ),
    );
    await repository.addTransaction(
      FinanceTransaction(
        id: '',
        walletId: initial.wallet.id,
        categoryId: food.id,
        kind: TransactionKind.expense,
        amount: 75000,
        date: DateTime(2026, 11, 15),
        note: 'Makan siang',
      ),
    );

    final saved = await repository.load();
    expect(saved.wallet.initialBalance, 3000000);
    expect(saved.wallet.monthlyBudget, 4500000);
    expect(saved.wallet.cycleStartDay, 25);
    expect(saved.transactions, hasLength(1));
    expect(saved.transactions.single.amount, 75000);
    expect(saved.transactions.single.note, 'Makan siang');
  });

  test('kategori yang sudah dipakai tidak dapat dihapus', () async {
    final initial = await repository.load();
    final food = initial.categories.firstWhere(
      (item) => item.kind == TransactionKind.expense,
    );
    await repository.addTransaction(
      FinanceTransaction(
        id: '',
        walletId: initial.wallet.id,
        categoryId: food.id,
        kind: TransactionKind.expense,
        amount: 10000,
        date: DateTime(2026, 11, 15),
      ),
    );

    expect(
      () => repository.deleteCategory(food.id),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('kategori kustom dapat ditambah dan dihapus', () async {
    await repository.addCategory(
      const FinanceCategory(
        id: '',
        name: 'Hobi',
        kind: TransactionKind.expense,
        iconKey: 'sport',
        colorHex: '#9867C5',
      ),
    );
    final withCategory = await repository.load();
    final custom = withCategory.categories.firstWhere(
      (item) => item.name == 'Hobi',
    );

    await repository.deleteCategory(custom.id);
    final afterDelete = await repository.load();
    expect(afterDelete.categories.any((item) => item.name == 'Hobi'), isFalse);
  });

  test('data tetap ada setelah database ditutup dan dibuka kembali', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'dompet-bulanan-sqlite-',
    );
    final databasePath = path.join(temporaryDirectory.path, 'finance.db');
    final firstRepository = SqliteFinanceRepository(
      databaseFactoryFfi,
      databasePath: databasePath,
    );

    try {
      final firstData = await firstRepository.load();
      await firstRepository.saveWallet(
        firstData.wallet.copyWith(name: 'Dompet Persisten'),
      );
      await firstRepository.close();

      final reopenedRepository = SqliteFinanceRepository(
        databaseFactoryFfi,
        databasePath: databasePath,
      );
      final reopenedData = await reopenedRepository.load();
      expect(reopenedData.wallet.name, 'Dompet Persisten');
      await reopenedRepository.close();
    } finally {
      await firstRepository.close();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });
}
