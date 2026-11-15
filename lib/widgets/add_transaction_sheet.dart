import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';
import 'common.dart';

Future<void> showAddTransactionSheet(
  BuildContext context,
  FinanceController controller,
) => Navigator.of(context).push<void>(
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 230),
    reverseTransitionDuration: const Duration(milliseconds: 190),
    pageBuilder: (context, animation, secondaryAnimation) =>
        AddTransactionSheet(controller: controller),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.055),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  ),
);

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _noteController = TextEditingController();
  TransactionKind _kind = TransactionKind.expense;
  FinanceCategory? _category;
  DateTime _date = DateTime.now();
  String _amountDigits = '';
  bool _saving = false;

  int get _amount => int.tryParse(_amountDigits) ?? 0;

  String get _amountLabel =>
      NumberFormat.decimalPattern('id_ID').format(_amount);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _changeKind(TransactionKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      _category = null;
    });
  }

  void _appendDigits(String digits) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      final next = '$_amountDigits$digits'.replaceFirst(RegExp(r'^0+'), '');
      _amountDigits = next.length > 12 ? next.substring(0, 12) : next;
    });
  }

  void _setAmount(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _amountDigits = value.clamp(0, 999999999999).toString();
      if (_amountDigits == '0') _amountDigits = '';
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal transaksi',
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickCategory() async {
    final categories = widget.controller.categoriesFor(_kind);
    if (categories.isEmpty) {
      showResultSnackBar(
        context,
        'Belum ada kategori ${_kind.label.toLowerCase()}. Tambahkan dari menu Akun.',
        '',
      );
      return;
    }
    final selected = await showModalBottomSheet<FinanceCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Pilih kategori ${_kind.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final active = category.id == _category?.id;
                    return InkWell(
                      onTap: () => Navigator.pop(context, category),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: active
                              ? category.color.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active ? category.color : AppColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryAvatar(category: category, size: 42),
                            const SizedBox(height: 7),
                            Text(
                              category.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _category = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_amount <= 0) {
      showResultSnackBar(context, 'Masukkan jumlah transaksi.', '');
      return;
    }
    if (_category == null) {
      showResultSnackBar(context, 'Pilih kategori transaksi.', '');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final error = await widget.controller.addTransaction(
      kind: _kind,
      amount: _amount.toDouble(),
      date: _date,
      category: _category!,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showResultSnackBar(context, error, '');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('${_kind.label} berhasil dicatat.')),
    );
  }

  Future<void> _editNote() async {
    final note = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            _TransactionNotePage(initialValue: _noteController.text),
      ),
    );
    if (note == null || !mounted) return;
    setState(() => _noteController.text = note);
  }

  @override
  Widget build(BuildContext context) {
    final kindColor = _kind == TransactionKind.expense
        ? AppColors.primary
        : AppColors.income;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keypadHeight = (screenHeight * 0.36).clamp(260.0, 310.0);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(8, 10, 18, 15),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 33),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tambah transaksi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      _KindTabs(
                        kind: _kind,
                        onChanged: _changeKind,
                        onDebtTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pencatatan hutang/pinjaman akan hadir di versi berikutnya.',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _InputRow(
                        icon: Icons.account_balance_wallet_outlined,
                        child: Text(
                          widget.controller.wallet.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'IDR',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              child: FittedBox(
                                key: ValueKey(_amountLabel),
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _amountLabel,
                                  style: TextStyle(
                                    color: kindColor,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w400,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 102),
                          Expanded(
                            child: Container(height: 2, color: kindColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 21),
                      _InputRow(
                        iconWidget: _category == null
                            ? const CircleAvatar(
                                radius: 21,
                                backgroundColor: Color(0xFFC9C9CC),
                              )
                            : CategoryAvatar(category: _category!, size: 44),
                        onTap: _pickCategory,
                        child: Text(
                          _category?.name ?? 'Pilih Kategori',
                          style: TextStyle(
                            color: _category == null
                                ? AppColors.muted
                                : AppColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InputRow(
                        icon: Icons.notes_rounded,
                        onTap: _editNote,
                        child: Text(
                          _noteController.text.trim().isEmpty
                              ? 'Tulis catatan'
                              : _noteController.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _noteController.text.trim().isEmpty
                                ? AppColors.muted
                                : AppColors.ink,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InputRow(
                        icon: Icons.calendar_month_outlined,
                        child: Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: () => setState(
                                () => _date = _date.subtract(
                                  const Duration(days: 1),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'EEEE, d/M/yyyy',
                                      'id_ID',
                                    ).format(_date),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _RoundIconButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: () => setState(
                                () =>
                                    _date = _date.add(const Duration(days: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              color: AppColors.canvas,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
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
                  _QuickAmounts(onSelect: _setAmount),
                  _AmountKeypad(
                    height: keypadHeight,
                    onDigits: _appendDigits,
                    onClear: () => _setAmount(0),
                    onHalf: () => _setAmount(_amount ~/ 2),
                    onDouble: () => _setAmount(_amount * 2),
                    onBackspace: () {
                      if (_amountDigits.isEmpty) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _amountDigits = _amountDigits.substring(
                          0,
                          _amountDigits.length - 1,
                        );
                      });
                    },
                    onSubtract: () => _setAmount(_amount - 10000),
                    onAdd: () => _setAmount(_amount + 10000),
                    onSave: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionNotePage extends StatefulWidget {
  const _TransactionNotePage({required this.initialValue});

  final String initialValue;

  @override
  State<_TransactionNotePage> createState() => _TransactionNotePageState();
}

class _TransactionNotePageState extends State<_TransactionNotePage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      toolbarHeight: 72,
      leading: IconButton(
        tooltip: 'Kembali',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 30),
      ),
      title: const Text('Catatan'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text(
            'SIMPAN',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        maxLength: 160,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 18, height: 1.45),
        decoration: const InputDecoration(
          hintText: 'Tulis catatan...',
          counterStyle: TextStyle(color: AppColors.muted),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ),
  );
}

class _KindTabs extends StatelessWidget {
  const _KindTabs({
    required this.kind,
    required this.onChanged,
    required this.onDebtTap,
  });

  final TransactionKind kind;
  final ValueChanged<TransactionKind> onChanged;
  final VoidCallback onDebtTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(25),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        _KindOption(
          label: 'Pengeluaran',
          selected: kind == TransactionKind.expense,
          onTap: () => onChanged(TransactionKind.expense),
        ),
        _KindOption(
          label: 'Pemasukan',
          selected: kind == TransactionKind.income,
          onTap: () => onChanged(TransactionKind.income),
        ),
        _KindOption(label: 'Hutang', selected: false, onTap: onDebtTap),
      ],
    ),
  );
}

class _KindOption extends StatelessWidget {
  const _KindOption({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : Colors.transparent,
          border: const Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: selected ? AppColors.ink : AppColors.muted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    this.icon,
    this.iconWidget,
    required this.child,
    this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerLeft,
              child: iconWidget ?? Icon(icon, size: 27, color: AppColors.ink),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    style: IconButton.styleFrom(backgroundColor: AppColors.surfaceAlt),
    icon: Icon(icon, color: AppColors.primary),
  );
}

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.onSelect});

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Row(
      children: [
        for (final value in const [10000, 20000, 25000, 50000, 100000]) ...[
          ActionChip(
            onPressed: () => onSelect(value),
            label: Text(NumberFormat.decimalPattern('id_ID').format(value)),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({
    required this.height,
    required this.onDigits,
    required this.onClear,
    required this.onHalf,
    required this.onDouble,
    required this.onBackspace,
    required this.onSubtract,
    required this.onAdd,
    required this.onSave,
  });

  final double height;
  final ValueChanged<String> onDigits;
  final VoidCallback onClear;
  final VoidCallback onHalf;
  final VoidCallback onDouble;
  final VoidCallback onBackspace;
  final VoidCallback onSubtract;
  final VoidCallback onAdd;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final keys = <(String, VoidCallback)>[
      ('C', onClear),
      ('½', onHalf),
      ('×2', onDouble),
      ('7', () => onDigits('7')),
      ('8', () => onDigits('8')),
      ('9', () => onDigits('9')),
      ('4', () => onDigits('4')),
      ('5', () => onDigits('5')),
      ('6', () => onDigits('6')),
      ('1', () => onDigits('1')),
      ('2', () => onDigits('2')),
      ('3', () => onDigits('3')),
      ('0', () => onDigits('0')),
      ('00', () => onDigits('00')),
      ('000', () => onDigits('000')),
    ];

    final actionHeight = (height - 21) * 0.18;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 14) / 3;
                final cellHeight = (height - 28) / 5;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, index) => _KeyButton(
                    label: keys[index].$1,
                    onTap: keys[index].$2,
                    accent: index < 3,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 78,
            child: Column(
              children: [
                SizedBox(
                  height: actionHeight,
                  child: _KeyButton(
                    icon: Icons.backspace_outlined,
                    onTap: onBackspace,
                    accent: true,
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: actionHeight,
                  child: _KeyButton(
                    label: '−10K',
                    onTap: onSubtract,
                    accent: true,
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: actionHeight,
                  child: _KeyButton(label: '+10K', onTap: onAdd, accent: true),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: _KeyButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    onTap: onSave,
                    save: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    required this.onTap,
    this.accent = false,
    this.save = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool accent;
  final bool save;

  @override
  Widget build(BuildContext context) => Material(
    color: save ? AppColors.income : AppColors.surfaceAlt,
    borderRadius: BorderRadius.circular(15),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                color: save
                    ? Colors.white
                    : accent
                    ? AppColors.primary
                    : AppColors.ink,
              )
            : Text(
                label!,
                style: TextStyle(
                  color: save
                      ? Colors.white
                      : accent
                      ? AppColors.primary
                      : AppColors.ink,
                  fontSize: accent ? 17 : 22,
                  fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
      ),
    ),
  );
}
