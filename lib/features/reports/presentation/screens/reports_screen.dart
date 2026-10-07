import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/date_range.dart';
import '../../domain/entities/debts_report_data.dart';
import '../../domain/entities/expenses_report_data.dart';
import '../../domain/entities/inventory_report_data.dart';
import '../../domain/entities/profit_loss_report_data.dart';
import '../../domain/entities/purchases_report_data.dart';
import '../../domain/entities/sales_report_data.dart';
import '../../domain/entities/stock_movement_report_row.dart';
import '../../domain/entities/yearly_report_data.dart';
import '../../domain/repositories/reports_repository.dart';
import '../widgets/date_range_selector_widget.dart';
import '../widgets/debts_report_tab.dart';
import '../widgets/expenses_report_tab.dart';
import '../widgets/inventory_report_tab.dart';
import '../widgets/profit_loss_report_tab.dart';
import '../widgets/purchases_report_tab.dart';
import '../widgets/sales_report_tab.dart';
import '../widgets/yearly_report_tab.dart';

/// الشاشة الشاملة لتقارير النظام والتحليل المالي والمخزني (Read-Only)
class ReportsScreen extends StatefulWidget {
  final ReportsRepository? repository;
  final int initialTabIndex;
  final DateRange? initialRange;
  final int initialDebtsSubTab;

  const ReportsScreen({
    super.key,
    this.repository,
    this.initialTabIndex = 0,
    this.initialRange,
    this.initialDebtsSubTab = 0,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final ReportsRepository _repo;
  late final TabController _tabController;
  late DateRange _selectedRange;
  late int _selectedYear;

  bool _isLoading = true;
  String? _errorMessage;

  // البيانات المحملة
  SalesReportData? _salesData;
  PurchasesReportData? _purchasesData;
  InventoryReportData? _inventoryData;
  List<StockMovementReportRow> _stockMovements = [];
  DebtsReportData? _debtsData;
  ExpensesReportData? _expensesData;
  ProfitLossReportData? _profitLossData;
  YearlyReportData? _yearlyData;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ReportsRepositoryImpl();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );
    _selectedRange = widget.initialRange ?? DateRange.currentMonth();
    _selectedYear = DateTime.now().year;

    _tabController.addListener(_onTabChanged);
    AppDataNotifier.instance.addListener(_onDataChanged);

    _loadCurrentTabData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    AppDataNotifier.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadCurrentTabData();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadCurrentTabData();
  }

  Future<void> _loadCurrentTabData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tab = _tabController.index;
      switch (tab) {
        case 0:
          _salesData = await _repo.getSalesReport(_selectedRange);
          break;
        case 1:
          _purchasesData = await _repo.getPurchasesReport(_selectedRange);
          break;
        case 2:
          _inventoryData = await _repo.getInventoryReport();
          _stockMovements = await _repo.getStockMovementsReport();
          break;
        case 3:
          _debtsData = await _repo.getDebtsReport();
          break;
        case 4:
          _expensesData = await _repo.getExpensesReport(_selectedRange);
          break;
        case 5:
          _profitLossData = await _repo.getProfitLossReport(_selectedRange);
          break;
        case 6:
          _yearlyData = await _repo.getYearlyReport(_selectedYear);
          break;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل بيانات التقرير: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onRangeChanged(DateRange newRange) {
    setState(() => _selectedRange = newRange);
    _loadCurrentTabData();
  }

  void _onYearChanged(int newYear) {
    setState(() => _selectedYear = newYear);
    _loadCurrentTabData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التقارير والتحليل المالي'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث التقرير',
            onPressed: _loadCurrentTabData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'المبيعات'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'المشتريات'),
            Tab(icon: Icon(Icons.inventory_2), text: 'المخزون والحركة'),
            Tab(icon: Icon(Icons.people_alt), text: 'الديون والذمم'),
            Tab(icon: Icon(Icons.receipt_long), text: 'المصروفات'),
            Tab(icon: Icon(Icons.account_balance), text: 'الأرباح والخسائر'),
            Tab(icon: Icon(Icons.calendar_month), text: 'التقرير السنوي'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // محدد الفترة (يظهر في جميع التبويبات عدا التقرير السنوي لأن له محدد سنة خاص به)
            if (_tabController.index != 6)
              DateRangeSelectorWidget(
                selectedRange: _selectedRange,
                onRangeChanged: _onRangeChanged,
              ),

            // رسالة الخطأ إن وجدت
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // محتوى التبويبات
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 0: المبيعات
                  SalesReportTab(
                    data: _salesData ?? SalesReportData.empty(_selectedRange),
                    isLoading: _isLoading && _salesData == null,
                  ),

                  // 1: المشتريات
                  PurchasesReportTab(
                    data: _purchasesData ?? PurchasesReportData.empty(_selectedRange),
                    isLoading: _isLoading && _purchasesData == null,
                  ),

                  // 2: المخزون وحركته
                  InventoryReportTab(
                    inventoryData: _inventoryData ?? InventoryReportData.empty(),
                    movements: _stockMovements,
                    isLoading: _isLoading && _inventoryData == null,
                  ),

                  // 3: الديون والذمم
                  DebtsReportTab(
                    data: _debtsData ?? DebtsReportData.empty(),
                    isLoading: _isLoading && _debtsData == null,
                    initialSubTab: widget.initialDebtsSubTab,
                  ),

                  // 4: المصروفات
                  ExpensesReportTab(
                    data: _expensesData ?? ExpensesReportData.empty(_selectedRange),
                    isLoading: _isLoading && _expensesData == null,
                  ),

                  // 5: الأرباح والخسائر
                  ProfitLossReportTab(
                    data: _profitLossData ?? ProfitLossReportData.empty(_selectedRange),
                    isLoading: _isLoading && _profitLossData == null,
                  ),

                  // 6: التقرير السنوي
                  YearlyReportTab(
                    data: _yearlyData ?? YearlyReportData.empty(_selectedYear),
                    selectedYear: _selectedYear,
                    onYearChanged: _onYearChanged,
                    isLoading: _isLoading && _yearlyData == null,
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
