import 'package:flutter/material.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../features/cash/presentation/screens/cashbox_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/products/presentation/screens/products_list_screen.dart';
import '../../features/products/presentation/screens/stock_inventory_screen.dart';
import '../../features/purchases/presentation/screens/purchases_list_screen.dart';
import '../../features/sales/presentation/screens/sales_list_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/foundation_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_list_screen.dart';

/// عنصر تعريف التبويب في القائمة الجانبية
class _SidebarDestination {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? sectionTitle;

  const _SidebarDestination({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.sectionTitle,
  });
}

/// الشاشة الهيكلية الرئيسية بنظام القائمة الجانبية (Sidebar) المخصص لبيئة سطح المكتب
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  bool _isExpanded = true;

  static const List<_SidebarDestination> _destinations = [
    // 1. العمليات التجارية
    _SidebarDestination(
      index: 0,
      label: 'المنتجات',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      sectionTitle: 'العمليات التجارية والمخزون',
    ),
    _SidebarDestination(
      index: 1,
      label: 'المبيعات',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
    ),
    _SidebarDestination(
      index: 2,
      label: 'المشتريات',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
    ),

    // 2. الحسابات والشركاء
    _SidebarDestination(
      index: 3,
      label: 'العملاء',
      icon: Icons.people_outlined,
      selectedIcon: Icons.people,
      sectionTitle: 'الشركاء والمالية',
    ),
    _SidebarDestination(
      index: 4,
      label: 'الموردون',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
    ),
    _SidebarDestination(
      index: 5,
      label: 'الصندوق',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    _SidebarDestination(
      index: 6,
      label: 'المصروفات',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),

    // 3. المستودع والرقابة والإدارة
    _SidebarDestination(
      index: 7,
      label: 'الجرد والتسوية',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      sectionTitle: 'الرقابة وإدارة النظام',
    ),
    _SidebarDestination(
      index: 8,
      label: 'لوحة التحكم',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _SidebarDestination(
      index: 9,
      label: 'التقارير',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
    ),
    _SidebarDestination(
      index: 10,
      label: 'النظام',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  late final List<Widget> _screens = [
    const ProductsListScreen(),
    const SalesListScreen(),
    PurchasesListScreen(),
    const CustomersListScreen(),
    SuppliersListScreen(),
    const CashboxScreen(),
    const ExpensesScreen(),
    const StockInventoryScreen(),
    const DashboardScreen(),
    const ReportsScreen(),
    const FoundationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onSelectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    AppDataNotifier.instance.notifyTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // شريط التنقل الجانبي لسطح المكتب
          _buildSidebar(),

          // الفاصل الرأسي المدمج بلون متناسق مع السايد بار الداكن
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),

          // منطقة المحتوى التفاعلي الرئيسي
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _isExpanded ? 255 : 74,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ترويسة الشريط الجانبي (الهوية والشعار وزر الطي/التوسيع)
            _buildSidebarHeader(),

            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),

            // قائمة وجهات وأقسام النظام
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in _destinations) ...[
                      if (item.sectionTitle != null)
                        _buildSectionHeader(item.sectionTitle!),
                      _buildSidebarItem(item),
                    ],
                  ],
                ),
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),

            // تذييل الشريط الجانبي (حالة النظام ورقم الإصدار)
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 14 : 10,
      ),
      child: Row(
        mainAxisAlignment:
            _isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
        children: [
          if (_isExpanded) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chair_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'تطبيق سطح المكتب',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_open_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              hoverColor: Colors.white.withValues(alpha: 0.12),
              tooltip: 'طي القائمة الجانبية',
              onPressed: () => setState(() => _isExpanded = false),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                size: 22,
                color: Colors.white,
              ),
              hoverColor: Colors.white.withValues(alpha: 0.12),
              tooltip: 'توسيع القائمة الجانبية',
              onPressed: () => setState(() => _isExpanded = true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    if (!_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8), // Sky Blue accent
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(_SidebarDestination item) {
    final isSelected = _currentIndex == item.index;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 10 : 8,
        vertical: 2.5,
      ),
      child: Tooltip(
        message: item.label,
        waitDuration: _isExpanded
            ? const Duration(seconds: 1)
            : const Duration(milliseconds: 200),
        child: Material(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: isSelected
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.08),
            onTap: () => _onSelectTab(item.index),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.2,
                      )
                    : null,
              ),
              child: _isExpanded
                  ? Row(
                      children: [
                        // مؤشر التحديد الرأسي بلون سماوي متوهج
                        Container(
                          width: 4,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.75),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.88),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.75),
                            size: 22,
                          ),
                          if (isSelected)
                            Positioned(
                              right: 2,
                              child: Container(
                                width: 3,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.7),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    if (!_isExpanded) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        child: Tooltip(
          message: 'متصل محلياً (SQLite) • v${AppConstants.appVersion}',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'متصل محلياً',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
