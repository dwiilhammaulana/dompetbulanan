import 'package:flutter/material.dart';

import '../core/finance_period.dart';

enum TransactionKind {
  expense,
  income;

  String get databaseValue => name;

  String get label => this == expense ? 'Pengeluaran' : 'Pemasukan';

  static TransactionKind fromValue(String value) =>
      value == 'income' ? TransactionKind.income : TransactionKind.expense;
}

class WalletSettings {
  const WalletSettings({
    required this.id,
    required this.name,
    required this.currency,
    required this.initialBalance,
    required this.monthlyBudget,
    required this.cycleStartDay,
  });

  final String id;
  final String name;
  final String currency;
  final double initialBalance;
  final double monthlyBudget;
  final int cycleStartDay;

  WalletSettings copyWith({
    String? id,
    String? name,
    String? currency,
    double? initialBalance,
    double? monthlyBudget,
    int? cycleStartDay,
  }) => WalletSettings(
    id: id ?? this.id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    initialBalance: initialBalance ?? this.initialBalance,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    cycleStartDay: cycleStartDay ?? this.cycleStartDay,
  );

  factory WalletSettings.fromMap(Map<String, dynamic> map) => WalletSettings(
    id: map['id'] as String,
    name: map['name'] as String? ?? 'Dompet Utama',
    currency: map['currency'] as String? ?? 'IDR',
    initialBalance: _toDouble(map['initial_balance']),
    monthlyBudget: _toDouble(map['monthly_budget']),
    cycleStartDay: (map['cycle_start_day'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'name': name,
    'currency': currency,
    'initial_balance': initialBalance,
    'monthly_budget': monthlyBudget,
    'cycle_start_day': cycleStartDay,
  };
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.colorHex,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final TransactionKind kind;
  final String iconKey;
  final String colorHex;
  final bool isDefault;

  Color get color {
    final value = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  IconData get icon => categoryIcon(iconKey);

  factory FinanceCategory.fromMap(Map<String, dynamic> map) => FinanceCategory(
    id: map['id'] as String,
    name: map['name'] as String,
    kind: TransactionKind.fromValue(map['transaction_type'] as String),
    iconKey: map['icon_key'] as String? ?? 'other',
    colorHex: map['color_hex'] as String? ?? '#7A8B84',
    isDefault: map['is_default'] == true || map['is_default'] == 1,
  );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'name': name,
    'transaction_type': kind.databaseValue,
    'icon_key': iconKey,
    'color_hex': colorHex,
    'is_default': isDefault,
  };
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.kind,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final String walletId;
  final String categoryId;
  final TransactionKind kind;
  final double amount;
  final DateTime date;
  final String note;

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) =>
      FinanceTransaction(
        id: map['id'] as String,
        walletId: map['wallet_id'] as String,
        categoryId: map['category_id'] as String,
        kind: TransactionKind.fromValue(map['transaction_type'] as String),
        amount: _toDouble(map['amount']),
        date: DateTime.parse(map['transaction_date'] as String),
        note: map['note'] as String? ?? '',
      );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'wallet_id': walletId,
    'category_id': categoryId,
    'transaction_type': kind.databaseValue,
    'amount': amount,
    'transaction_date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'note': note,
  };
}

class FinanceData {
  const FinanceData({
    required this.wallet,
    required this.categories,
    required this.transactions,
  });

  final WalletSettings wallet;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
}

class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.dailyExpense,
  });

  final double income;
  final double expense;
  final Map<String, double> byCategory;
  final Map<DateTime, double> dailyExpense;

  double get net => income - expense;

  factory FinanceSummary.fromTransactions(
    Iterable<FinanceTransaction> transactions,
    FinancePeriod period,
  ) {
    var income = 0.0;
    var expense = 0.0;
    final byCategory = <String, double>{};
    final dailyExpense = <DateTime, double>{};

    for (final transaction in transactions) {
      if (!period.contains(transaction.date)) continue;
      if (transaction.kind == TransactionKind.income) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
        byCategory.update(
          transaction.categoryId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
        final day = FinancePeriod.dateOnly(transaction.date);
        dailyExpense.update(
          day,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    return FinanceSummary(
      income: income,
      expense: expense,
      byCategory: byCategory,
      dailyExpense: dailyExpense,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

IconData categoryIcon(String key) => switch (key) {
  'heart' => Icons.favorite_rounded,
  'food' => Icons.restaurant_rounded,
  'basket' => Icons.shopping_basket_rounded,
  'calculator' => Icons.calculate_rounded,
  'transport' => Icons.directions_car_filled_rounded,
  'shopping' => Icons.shopping_bag_rounded,
  'cart' => Icons.shopping_cart_rounded,
  'home' => Icons.home_rounded,
  'phone' => Icons.smartphone_rounded,
  'diamond' => Icons.diamond_rounded,
  'bank' => Icons.account_balance_rounded,
  'scooter' => Icons.two_wheeler_rounded,
  'medicine' => Icons.vaccines_rounded,
  'bill' => Icons.receipt_long_rounded,
  'health' => Icons.medical_services_rounded,
  'entertainment' => Icons.movie_rounded,
  'popcorn' => Icons.local_movies_rounded,
  'education' => Icons.school_rounded,
  'gift' => Icons.redeem_rounded,
  'salary' => Icons.account_balance_wallet_rounded,
  'bonus' => Icons.stars_rounded,
  'business' => Icons.work_rounded,
  'investment' => Icons.trending_up_rounded,
  'family' => Icons.family_restroom_rounded,
  'people' => Icons.group_rounded,
  'sport' => Icons.fitness_center_rounded,
  'travel' => Icons.flight_rounded,
  'coffee' => Icons.local_cafe_rounded,
  'analytics' => Icons.analytics_rounded,
  'building' => Icons.apartment_rounded,
  'computer' => Icons.desktop_windows_rounded,
  'tree' => Icons.park_rounded,
  'package' => Icons.inventory_2_rounded,
  'photo' => Icons.image_rounded,
  'camera' => Icons.photo_camera_rounded,
  'casino' => Icons.casino_rounded,
  'rocket' => Icons.rocket_launch_rounded,
  'game' => Icons.sports_esports_rounded,
  'book' => Icons.menu_book_rounded,
  'icecream' => Icons.icecream_rounded,
  'stroller' => Icons.child_friendly_rounded,
  'mail' => Icons.mail_rounded,
  'accessible' => Icons.accessible_rounded,
  'news' => Icons.newspaper_rounded,
  'cake' => Icons.cake_rounded,
  'fuel' => Icons.local_gas_station_rounded,
  'parking' => Icons.local_parking_rounded,
  'haircut' => Icons.content_cut_rounded,
  'pets' => Icons.pets_rounded,
  'wifi' => Icons.wifi_rounded,
  'music' => Icons.music_note_rounded,
  'savings' => Icons.savings_rounded,
  'charity' => Icons.volunteer_activism_rounded,
  _ => Icons.category_rounded,
};

const categoryIconOptions = <String>[
  'heart',
  'food',
  'basket',
  'calculator',
  'travel',
  'popcorn',
  'cart',
  'home',
  'phone',
  'diamond',
  'bank',
  'transport',
  'scooter',
  'medicine',
  'coffee',
  'analytics',
  'building',
  'people',
  'computer',
  'tree',
  'package',
  'photo',
  'camera',
  'casino',
  'rocket',
  'game',
  'book',
  'icecream',
  'stroller',
  'mail',
  'accessible',
  'news',
  'cake',
  'fuel',
  'parking',
  'haircut',
  'shopping',
  'bill',
  'health',
  'entertainment',
  'education',
  'gift',
  'salary',
  'bonus',
  'business',
  'investment',
  'family',
  'sport',
  'pets',
  'wifi',
  'music',
  'savings',
  'charity',
  'other',
];

const categoryColorOptions = <String>[
  '#F06464',
  '#F39A4A',
  '#E9BE42',
  '#58AD76',
  '#28A99E',
  '#4298E1',
  '#6C79D8',
  '#9867C5',
  '#D968A6',
  '#7A8B84',
];

List<FinanceCategory> defaultCategories() => const [
  FinanceCategory(
    id: 'expense-food',
    name: 'Makanan & Minuman',
    kind: TransactionKind.expense,
    iconKey: 'food',
    colorHex: '#F06464',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-transport',
    name: 'Transportasi',
    kind: TransactionKind.expense,
    iconKey: 'transport',
    colorHex: '#4298E1',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-shopping',
    name: 'Belanja',
    kind: TransactionKind.expense,
    iconKey: 'shopping',
    colorHex: '#D968A6',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-home',
    name: 'Rumah',
    kind: TransactionKind.expense,
    iconKey: 'home',
    colorHex: '#58AD76',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-bill',
    name: 'Tagihan',
    kind: TransactionKind.expense,
    iconKey: 'bill',
    colorHex: '#E9BE42',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-health',
    name: 'Kesehatan',
    kind: TransactionKind.expense,
    iconKey: 'health',
    colorHex: '#28A99E',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'expense-entertainment',
    name: 'Hiburan',
    kind: TransactionKind.expense,
    iconKey: 'entertainment',
    colorHex: '#9867C5',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'income-salary',
    name: 'Gaji',
    kind: TransactionKind.income,
    iconKey: 'salary',
    colorHex: '#168C62',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'income-bonus',
    name: 'Bonus',
    kind: TransactionKind.income,
    iconKey: 'bonus',
    colorHex: '#E9BE42',
    isDefault: true,
  ),
  FinanceCategory(
    id: 'income-business',
    name: 'Usaha',
    kind: TransactionKind.income,
    iconKey: 'business',
    colorHex: '#4298E1',
    isDefault: true,
  ),
];
