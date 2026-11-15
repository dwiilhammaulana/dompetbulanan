import '../models/finance_models.dart';

abstract class FinanceRepository {
  Future<FinanceData> load();

  Future<void> saveWallet(WalletSettings wallet);

  Future<void> addTransaction(FinanceTransaction transaction);

  Future<void> deleteTransaction(String transactionId);

  Future<void> addCategory(FinanceCategory category);

  Future<void> deleteCategory(String categoryId);
}
