import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/finance_models.dart';
import 'finance_repository.dart';

class SqliteFinanceRepository implements FinanceRepository {
  SqliteFinanceRepository(this._factory, {String? databasePath})
    : _databasePathOverride = databasePath;

  factory SqliteFinanceRepository.forCurrentPlatform() =>
      SqliteFinanceRepository(databaseFactorySqflitePlugin);

  static const _databaseName = 'dompet_bulanan.db';
  static const _databaseVersion = 1;
  static const _walletId = 'wallet-local';

  final DatabaseFactory _factory;
  final String? _databasePathOverride;
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final databasePath =
        _databasePathOverride ??
        path.join(await _factory.getDatabasesPath(), _databaseName);
    _database = await _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      ),
    );
    return _database!;
  }

  Future<void> _createSchema(Database database, int version) async {
    final batch = database.batch();
    batch.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'IDR',
        initial_balance REAL NOT NULL DEFAULT 0,
        monthly_budget REAL NOT NULL DEFAULT 0 CHECK (monthly_budget >= 0),
        cycle_start_day INTEGER NOT NULL DEFAULT 1
          CHECK (cycle_start_day BETWEEN 1 AND 31),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE,
        transaction_type TEXT NOT NULL
          CHECK (transaction_type IN ('income', 'expense')),
        icon_key TEXT NOT NULL DEFAULT 'other',
        color_hex TEXT NOT NULL DEFAULT '#7A8B84',
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        UNIQUE (name, transaction_type)
      )
    ''');
    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        wallet_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        transaction_type TEXT NOT NULL
          CHECK (transaction_type IN ('income', 'expense')),
        amount REAL NOT NULL CHECK (amount > 0),
        transaction_date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute('''
      CREATE INDEX transactions_date_idx
      ON transactions (transaction_date DESC, created_at DESC)
    ''');
    batch.execute('''
      CREATE INDEX transactions_category_idx
      ON transactions (category_id)
    ''');
    await batch.commit(noResult: true);
    await _seedDefaults(database);
  }

  Future<void> _seedDefaults(DatabaseExecutor database) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.insert('wallets', {
      'id': _walletId,
      'name': 'Dompet Utama',
      'currency': 'IDR',
      'initial_balance': 0,
      'monthly_budget': 0,
      'cycle_start_day': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    for (final category in defaultCategories()) {
      await database.insert('categories', {
        ...category.toLocalMap(),
        'is_default': category.isDefault ? 1 : 0,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  @override
  Future<FinanceData> load() async {
    final database = await _db;

    final walletRows = await database.query('wallets', limit: 1);
    final categoryRows = await database.query(
      'categories',
      orderBy: 'rowid ASC',
    );
    final transactionRows = await database.query(
      'transactions',
      orderBy: 'transaction_date DESC, created_at DESC',
    );

    if (walletRows.isEmpty) {
      throw StateError('Dompet lokal tidak ditemukan.');
    }

    return FinanceData(
      wallet: WalletSettings.fromMap(walletRows.first),
      categories: categoryRows.map(FinanceCategory.fromMap).toList(),
      transactions: transactionRows.map(FinanceTransaction.fromMap).toList(),
    );
  }

  @override
  Future<void> saveWallet(WalletSettings wallet) async {
    final database = await _db;
    await database.update(
      'wallets',
      {
        'name': wallet.name,
        'currency': wallet.currency,
        'initial_balance': wallet.initialBalance,
        'monthly_budget': wallet.monthlyBudget,
        'cycle_start_day': wallet.cycleStartDay,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [wallet.id],
    );
  }

  @override
  Future<void> addTransaction(FinanceTransaction transaction) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.insert('transactions', {
      'id': transaction.id.isEmpty ? _newId('transaction') : transaction.id,
      'wallet_id': transaction.walletId,
      'category_id': transaction.categoryId,
      'transaction_type': transaction.kind.databaseValue,
      'amount': transaction.amount,
      'transaction_date': _dateString(transaction.date),
      'note': transaction.note.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final database = await _db;
    await database.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  @override
  Future<void> addCategory(FinanceCategory category) async {
    final database = await _db;
    await database.insert('categories', {
      'id': category.id.isEmpty ? _newId('category') : category.id,
      'name': category.name.trim(),
      'transaction_type': category.kind.databaseValue,
      'icon_key': category.iconKey,
      'color_hex': category.colorHex,
      'is_default': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final database = await _db;
    await database.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<void> close() async {
    final database = _database;
    if (database != null && database.isOpen) await database.close();
    _database = null;
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
