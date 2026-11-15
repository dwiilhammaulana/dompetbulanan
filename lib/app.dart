import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'repositories/finance_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transactions_screen.dart';
import 'state/finance_controller.dart';
import 'widgets/add_transaction_sheet.dart';

class DompetBulananApp extends StatelessWidget {
  const DompetBulananApp({super.key, required this.repository});

  final FinanceRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Dompet Bulanan',
    theme: buildAppTheme(),
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: FinanceShell(repository: repository),
  );
}

class FinanceShell extends StatefulWidget {
  const FinanceShell({super.key, required this.repository});

  final FinanceRepository repository;

  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  late final FinanceController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = FinanceController(widget.repository)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAddTransaction() =>
      showAddTransactionSheet(context, _controller);

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.loading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        );
      }
      if (_controller.error != null || _controller.data == null) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storage_rounded,
                        size: 54,
                        color: AppColors.expense,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Data belum dapat dimuat',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _controller.error ??
                            'Terjadi kesalahan yang tidak diketahui.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _controller.load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final pages = [
        DashboardScreen(
          key: const PageStorageKey('ringkasan'),
          controller: _controller,
          onAddTransaction: _openAddTransaction,
          onSeeTransactions: () => _selectPage(1),
          onSeeReports: () => _selectPage(2),
          onOpenSettings: () => _selectPage(3),
        ),
        TransactionsScreen(
          key: const PageStorageKey('transaksi'),
          controller: _controller,
          onAddTransaction: _openAddTransaction,
          onSeeReports: () => _selectPage(2),
        ),
        ReportsScreen(
          key: const PageStorageKey('anggaran'),
          controller: _controller,
        ),
        SettingsScreen(
          key: const PageStorageKey('akun'),
          controller: _controller,
        ),
      ];

      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        floatingActionButton: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            onPressed: _openAddTransaction,
            tooltip: 'Tambah transaksi',
            child: const Icon(Icons.add_rounded, size: 36),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _FinanceBottomBar(
          selectedIndex: _selectedIndex,
          onSelected: _selectPage,
        ),
      );
    },
  );
}

class _FinanceBottomBar extends StatelessWidget {
  const _FinanceBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => BottomAppBar(
    height: 80,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    color: AppColors.nav,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    child: Row(
      children: [
        Expanded(
          child: _BottomItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Ringkasan',
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
        ),
        Expanded(
          child: _BottomItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Transaksi',
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
        ),
        const SizedBox(width: 70),
        Expanded(
          child: _BottomItem(
            icon: Icons.stacked_bar_chart_outlined,
            selectedIcon: Icons.stacked_bar_chart_rounded,
            label: 'Anggaran',
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ),
        Expanded(
          child: _BottomItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Akun',
            selected: selectedIndex == 3,
            onTap: () => onSelected(3),
          ),
        ),
      ],
    ),
  );
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 30,
      containedInkWell: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: 0.86, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              key: ValueKey(selected),
              size: 25,
              color: selected ? AppColors.ink : AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? AppColors.ink : AppColors.muted,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
