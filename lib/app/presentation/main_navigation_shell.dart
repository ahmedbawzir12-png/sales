import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../features/cash/presentation/screens/cashbox_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/products/presentation/screens/products_list_screen.dart';
import '../../features/products/presentation/screens/stock_inventory_screen.dart';
import '../../features/purchases/presentation/screens/purchases_list_screen.dart';
import '../../features/sales/presentation/screens/sales_list_screen.dart';
import '../../features/settings/presentation/screens/foundation_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_list_screen.dart';

/// الشاشة الهيكلية الرئيسية للتنقل بين أقسام النظام المتاحة
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  late final List<Widget> _screens = [
    const ProductsListScreen(),
    const SalesListScreen(),
    PurchasesListScreen(),
    const CustomersListScreen(),
    SuppliersListScreen(),
    const CashboxScreen(),
    const ExpensesScreen(),
    const StockInventoryScreen(),
    const FoundationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          AppDataNotifier.instance.notifyTabSelected(idx);
        },
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary),
            label: 'المبيعات',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.primary),
            label: 'المشتريات',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people, color: AppColors.primary),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business, color: AppColors.primary),
            label: 'الموردون',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary),
            label: 'الصندوق',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
            label: 'المصروفات',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune, color: AppColors.primary),
            label: 'الجرد والتسوية',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'النظام',
          ),
        ],
      ),
    );
  }
}
