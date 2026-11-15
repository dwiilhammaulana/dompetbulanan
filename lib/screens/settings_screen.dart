import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final wallet = controller.wallet;
    final period = controller.currentPeriod;
    final expenseCategories = controller.categoriesFor(TransactionKind.expense);
    final incomeCategories = controller.categoriesFor(TransactionKind.income);

    return PageFrame(
      child: ListView(
        key: const PageStorageKey('settings-scroll'),
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          Text('Akun', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            'Sesuaikan dompet, siklus gajian, dan kategori',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Dompet bulanan',
            subtitle: 'Dasar perhitungan saldo dan sisa batas pengeluaran',
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Nama dompet',
                    value: wallet.name,
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.payments_rounded,
                    label: 'Saldo awal',
                    value: formatRupiah(wallet.initialBalance),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.savings_rounded,
                    label: 'Batas pengeluaran / siklus',
                    value: wallet.monthlyBudget <= 0
                        ? 'Belum diatur'
                        : formatRupiah(wallet.monthlyBudget),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.autorenew_rounded,
                    label: 'Siklus berulang otomatis',
                    value:
                        'Tanggal ${wallet.cycleStartDay} sampai ${period.end.day}',
                    caption:
                        '${formatDate(period.start)} – ${formatDate(period.end)}',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _editWallet(context),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Ubah pengaturan dompet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cukup tentukan tanggal awal gajian satu kali. Tanggal akhir selalu dihitung sehari sebelum siklus berikutnya, termasuk untuk bulan yang lebih pendek.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Kategori',
            subtitle: 'Ikon dibuat dengan gaya orisinal yang mudah dikenali',
            trailing: FilledButton.icon(
              onPressed: () => _openCategories(context),
              icon: const Icon(Icons.category_outlined, size: 18),
              label: const Text('Kelola'),
            ),
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Pengeluaran',
            color: AppColors.expense,
            categories: expenseCategories,
            onDelete: (category) => _deleteCategory(context, category),
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Pemasukan',
            color: AppColors.income,
            categories: incomeCategories,
            onDelete: (category) => _deleteCategory(context, category),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Penyimpanan data'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storage_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SQLite lokal',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Semua data tersimpan di perangkat tanpa akun dan tanpa internet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Menghapus aplikasi juga akan menghapus database lokal. Fitur ekspor dan pemulihan cadangan dapat ditambahkan pada tahap berikutnya.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'Dompet Bulanan · data keuangan Anda tetap milik Anda',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editWallet(BuildContext context) async {
    final settings = await showDialog<WalletSettings>(
      context: context,
      builder: (_) => _WalletDialog(wallet: controller.wallet),
    );
    if (settings == null || !context.mounted) return;
    final error = await controller.saveWallet(settings);
    if (context.mounted) {
      showResultSnackBar(
        context,
        error,
        'Pengaturan dompet berhasil disimpan.',
      );
    }
  }

  Future<void> _openCategories(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(controller: controller),
      ),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    FinanceCategory category,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Hapus kategori?',
      message:
          'Kategori “${category.name}” hanya dapat dihapus jika belum dipakai transaksi.',
    );
    if (!confirmed || !context.mounted) return;
    final error = await controller.deleteCategory(category.id);
    if (context.mounted) {
      showResultSnackBar(context, error, 'Kategori berhasil dihapus.');
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary, size: 21),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    ],
  );
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.color,
    required this.categories,
    required this.onDelete,
  });

  final String title;
  final Color color;
  final List<FinanceCategory> categories;
  final ValueChanged<FinanceCategory> onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${categories.length} kategori',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            const Text('Belum ada kategori.')
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: categories
                  .map(
                    (category) => InputChip(
                      avatar: Icon(
                        category.icon,
                        size: 18,
                        color: category.color,
                      ),
                      label: Text(category.name),
                      onDeleted: () => onDelete(category),
                      deleteIcon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    ),
  );
}

class _WalletDialog extends StatefulWidget {
  const _WalletDialog({required this.wallet});

  final WalletSettings wallet;

  @override
  State<_WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<_WalletDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _budget;
  late int _startDay;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.wallet.name);
    _balance = TextEditingController(
      text: widget.wallet.initialBalance.toStringAsFixed(0),
    );
    _budget = TextEditingController(
      text: widget.wallet.monthlyBudget.toStringAsFixed(0),
    );
    _startDay = widget.wallet.cycleStartDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pengaturan dompet'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama dompet'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Nama dompet wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Saldo awal',
                  prefixText: 'Rp ',
                  helperText: 'Saldo saat pertama mulai memakai aplikasi',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Batas pengeluaran normal',
                  prefixText: 'Rp ',
                  helperText: 'Dipakai untuk menghitung sisa atau kelebihan',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _startDay,
                decoration: const InputDecoration(
                  labelText: 'Tanggal awal siklus / gajian',
                  helperText: 'Berulang otomatis setiap bulan',
                ),
                items: List.generate(
                  31,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('Tanggal ${index + 1}'),
                  ),
                ),
                onChanged: (value) => setState(() => _startDay = value ?? 1),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            widget.wallet.copyWith(
              name: _name.text.trim(),
              initialBalance: parseMoney(_balance.text),
              monthlyBudget: parseMoney(_budget.text),
              cycleStartDay: _startDay,
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}
