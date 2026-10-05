import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../features/products/presentation/screens/categories_screen.dart';
import '../../features/products/presentation/screens/products_list_screen.dart';
import '../../features/products/presentation/screens/stock_inventory_screen.dart';
import '../../features/products/presentation/screens/units_screen.dart';
import '../../features/settings/presentation/screens/foundation_screen.dart';

/// الشاشة الهيكلية الرئيسية للتنقل بين أقسام النظام المتاحة في المرحلة الثانية
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    ProductsListScreen(),
    StockInventoryScreen(),
    CategoriesScreen(),
    UnitsScreen(),
    FoundationScreen(),
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
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune, color: AppColors.primary),
            label: 'الجرد والتسوية',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category, color: AppColors.primary),
            label: 'التصنيفات',
          ),
          NavigationDestination(
            icon: Icon(Icons.straighten_outlined),
            selectedIcon: Icon(Icons.straighten, color: AppColors.primary),
            label: 'الوحدات',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety, color: AppColors.primary),
            label: 'النظام',
          ),
        ],
      ),
    );
  }
}
