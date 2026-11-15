import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchController = TextEditingController();
  TransactionKind _kind = TransactionKind.expense;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final query = _searchController.text.trim().toLowerCase();
      final categories = widget.controller
          .categoriesFor(_kind)
          .where(
            (category) =>
                query.isEmpty || category.name.toLowerCase().contains(query),
          )
          .toList(growable: false);

      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          toolbarHeight: 72,
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 30),
          ),
          title: const Text('Kategori'),
          actions: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFD8762B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            IconButton(
              tooltip: _searching ? 'Tutup pencarian' : 'Cari kategori',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _searchController.clear();
              }),
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                size: 29,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _searching
                  ? Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Cari nama kategori',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _CategoryTabs(
              kind: _kind,
              onChanged: (kind) {
                HapticFeedback.selectionClick();
                setState(() => _kind = kind);
              },
              onDebtTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Kategori hutang/pinjaman akan hadir di versi berikutnya.',
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                key: ValueKey(_kind),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 1, bottom: 28),
                itemCount: categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _NewCategoryRow(
                      onTap: () => _openNewCategory(context),
                    );
                  }
                  final category = categories[index - 1];
                  return _CategoryRow(
                    category: category,
                    onTap: () => _showCategoryActions(context, category),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _openNewCategory(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewCategoryScreen(
          controller: widget.controller,
          initialKind: _kind,
        ),
      ),
    );
  }

  Future<void> _showCategoryActions(
    BuildContext context,
    FinanceCategory category,
  ) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CategoryAvatar(category: category, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.kind.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus kategori'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete != true || !context.mounted) return;
    final confirmed = await confirmAction(
      context,
      title: 'Hapus kategori?',
      message:
          'Kategori “${category.name}” hanya dapat dihapus jika belum dipakai transaksi.',
    );
    if (!confirmed || !context.mounted) return;
    final error = await widget.controller.deleteCategory(category.id);
    if (context.mounted) {
      showResultSnackBar(context, error, 'Kategori berhasil dihapus.');
    }
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.kind,
    required this.onChanged,
    required this.onDebtTap,
  });

  final TransactionKind kind;
  final ValueChanged<TransactionKind> onChanged;
  final VoidCallback onDebtTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 82,
    color: AppColors.surface,
    child: Row(
      children: [
        _TabItem(
          label: 'PENGELUARAN',
          selected: kind == TransactionKind.expense,
          onTap: () => onChanged(TransactionKind.expense),
        ),
        _TabItem(
          label: 'PEMASUKAN',
          selected: kind == TransactionKind.income,
          onTap: () => onChanged(TransactionKind.income),
        ),
        _TabItem(label: 'HUTANG/\nPINJAMAN', selected: false, onTap: onDebtTap),
      ],
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
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
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.ink : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewCategoryRow extends StatelessWidget {
  const _NewCategoryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 25),
            ),
            SizedBox(width: 24),
            Text(
              'KATEGORI BARU',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final FinanceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
            CategoryAvatar(category: category, size: 48),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class NewCategoryScreen extends StatefulWidget {
  const NewCategoryScreen({
    super.key,
    required this.controller,
    required this.initialKind,
  });

  final FinanceController controller;
  final TransactionKind initialKind;

  @override
  State<NewCategoryScreen> createState() => _NewCategoryScreenState();
}

class _NewCategoryScreenState extends State<NewCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late TransactionKind _kind;
  String _iconKey = 'heart';
  String _colorHex = categoryColorOptions.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final preview = FinanceCategory(
      id: 'preview',
      name: '',
      kind: _kind,
      iconKey: _iconKey,
      colorHex: _colorHex,
    );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        toolbarHeight: 72,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
        ),
        title: const Text('Kategori baru'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickIcon,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CategoryAvatar(category: preview, size: 58),
                              Positioned(
                                right: -3,
                                bottom: -3,
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(fontSize: 21),
                            decoration: const InputDecoration(
                              hintText: 'Nama Kategori',
                              filled: false,
                              border: UnderlineInputBorder(),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Nama kategori wajib diisi.'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        const SizedBox(
                          width: 70,
                          child: Icon(Icons.exposure_rounded, size: 31),
                        ),
                        Expanded(
                          child: _KindChoice(
                            label: 'Pengeluaran',
                            selected: _kind == TransactionKind.expense,
                            onTap: () =>
                                setState(() => _kind = TransactionKind.expense),
                          ),
                        ),
                        Expanded(
                          child: _KindChoice(
                            label: 'Pemasukan',
                            selected: _kind == TransactionKind.income,
                            onTap: () =>
                                setState(() => _kind = TransactionKind.income),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Warna ikon',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: categoryColorOptions.map((hex) {
                        final color = _colorFromHex(hex);
                        final selected = hex == _colorHex;
                        return InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _colorHex = hex),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.ink
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving || _nameController.text.trim().isEmpty
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickIcon() async {
    final value = await Navigator.of(context).push<_IconSelection>(
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(selectedIconKey: _iconKey),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _iconKey = value.iconKey;
      _colorHex = value.colorHex;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final error = await widget.controller.addCategory(
      name: _nameController.text.trim(),
      kind: _kind,
      iconKey: _iconKey,
      colorHex: _colorHex,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showResultSnackBar(context, error, '');
      return;
    }
    Navigator.pop(context, true);
  }
}

class _KindChoice extends StatelessWidget {
  const _KindChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.muted,
                width: 2,
              ),
            ),
            child: selected
                ? const Center(
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class IconPickerScreen extends StatefulWidget {
  const IconPickerScreen({super.key, required this.selectedIconKey});

  final String selectedIconKey;

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {
  bool _basic = true;

  @override
  Widget build(BuildContext context) {
    final split = (categoryIconOptions.length * 0.66).round();
    final icons = _basic
        ? categoryIconOptions.take(split).toList(growable: false)
        : categoryIconOptions.skip(split).toList(growable: false);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        toolbarHeight: 72,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
        ),
        title: const Text('Ikon'),
      ),
      body: Column(
        children: [
          Container(
            height: 68,
            color: AppColors.surface,
            child: Row(
              children: [
                _IconTab(
                  label: 'DASAR',
                  selected: _basic,
                  onTap: () => setState(() => _basic = true),
                ),
                _IconTab(
                  label: 'TAMBAHAN',
                  selected: !_basic,
                  onTap: () => setState(() => _basic = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              key: ValueKey(_basic),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                final key = icons[index];
                final globalIndex = categoryIconOptions.indexOf(key);
                final colorHex =
                    categoryColorOptions[globalIndex %
                        categoryColorOptions.length];
                final color = _colorFromHex(colorHex);
                final selected = key == widget.selectedIconKey;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(
                    context,
                    _IconSelection(iconKey: key, colorHex: colorHex),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.ink
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          categoryIcon(key),
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          right: 1,
                          bottom: 1,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: AppColors.primary,
                            child: Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTab extends StatelessWidget {
  const _IconTab({
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
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.ink : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            height: 4,
            width: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IconSelection {
  const _IconSelection({required this.iconKey, required this.colorHex});

  final String iconKey;
  final String colorHex;
}

Color _colorFromHex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
