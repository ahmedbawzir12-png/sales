import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import 'package:sales/core/presentation/widgets/primary_hero_card.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// الشاشة الرئيسية للوحة التحكم والرقابة المالية لمعرض المفروشات (Read-Only)
class DashboardScreen extends StatefulWidget {
  final DashboardRepository? repository;

  const DashboardScreen({super.key, this.repository});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repo;
  DashboardSummary _summary = DashboardSummary.empty();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DashboardRepositoryImpl();
    AppDataNotifier.instance.addListener(_onDataChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _repo.getDashboardSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل بيانات لوحة التحكم: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToReports(int tabIndex, {int debtsSubTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsScreen(
          initialTabIndex: tabIndex,
          initialDebtsSubTab: debtsSubTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم والرقابة الإدارية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'فتح شاشة التقارير',
            onPressed: () => _navigateToReports(0),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  // 1. الحاوية الكحلية الإحصائية الموحدة (PrimaryHeroCard)
                  _buildPrimaryHeroDashboard(),

                  const SizedBox(height: 20),

                  // 2. بطاقة تنبيهات المخزون المنخفض
                  _buildLowStockSection(),

                  const SizedBox(height: 20),

                  // 3. اختصارات التقارير السريعة
                  _buildReportsShortcutsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPrimaryHeroDashboard() {
    final s = _summary;
    final todayProfitPositive = s.todayNetProfit >= 0;
    final monthProfitPositive = s.monthNetProfit >= 0;

    return PrimaryHeroCard(
      title: 'مؤشرات الأداء المالي والمخزني',
      badge: 'البيانات الحية',
      icon: Icons.dashboard_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رصيد الصندوق الفعلي الآن
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(35)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(40),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'رصيد الصندوق النقدي الفعلي الآن',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(s.cashBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // الصف الأول: مبيعات اليوم وصافي أرباح اليوم
          Row(
            children: [
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'صافي مبيعات اليوم',
                  value: Formatters.currency(s.todayNetSales),
                  subtitle: 'إجمالي: ${Formatters.currency(s.todayGrossSales)}',
                  icon: Icons.point_of_sale,
                  onTap: () => _navigateToReports(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'صافي أرباح اليوم',
                  value: Formatters.currency(s.todayNetProfit.round()),
                  subtitle: 'مصروفات اليوم: ${Formatters.currency(s.todayExpenses)}',
                  valueColor: todayProfitPositive
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  icon: Icons.trending_up,
                  onTap: () => _navigateToReports(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الصف الثاني: مبيعات الشهر وصافي أرباح الشهر
          Row(
            children: [
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'صافي مبيعات الشهر',
                  value: Formatters.currency(s.monthNetSales),
                  subtitle: 'إجمالي: ${Formatters.currency(s.monthGrossSales)}',
                  icon: Icons.calendar_today,
                  onTap: () => _navigateToReports(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'صافي أرباح الشهر',
                  value: Formatters.currency(s.monthNetProfit.round()),
                  subtitle: 'مصروفات الشهر: ${Formatters.currency(s.monthExpenses)}',
                  valueColor: monthProfitPositive
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  icon: Icons.auto_graph,
                  onTap: () => _navigateToReports(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الصف الثالث: ديون العملاء وديون الموردين (تفاعلي مع شاشة الديون)
          Row(
            children: [
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'ديون العملاء (لنا)',
                  value: Formatters.currency(s.customerDebtTotal),
                  subtitle: 'اضغط لعرض العملاء المدينين',
                  icon: Icons.people_alt,
                  onTap: () => _navigateToReports(3, debtsSubTab: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryHeroMetricItem(
                  label: 'ديون الموردين (علينا)',
                  value: Formatters.currency(s.supplierDebtTotal),
                  subtitle: 'اضغط لعرض كشف الموردين',
                  icon: Icons.business,
                  onTap: () => _navigateToReports(3, debtsSubTab: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الصف الرابع: قيمة المخزون بالتكلفة وإجمالي الأصناف
          PrimaryHeroMetricItem(
            label: 'قيمة المخزون المستودعي بالتكلفة',
            value: Formatters.currency(s.inventoryCostValue.round()),
            subtitle:
                'إجمالي الأصناف: ${s.inventoryTotalItems} صنف • ${s.lowStockCount} بحاجة طلب',
            icon: Icons.inventory_2_outlined,
            onTap: () => _navigateToReports(2),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection() {
    final items = _summary.lowStockProducts;

    if (items.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.check_circle, color: Colors.green.shade700),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المخزون متوازن وسليم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'لا توجد منتجات وصلت أو هبطت دون حد الطلب الأدنى حالياً.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيهات نواقص المخزون (${items.length} صنف)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'أصناف وصلت أو نزلت عن الحد الأدنى المحدد لإعادة الطلب',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _navigateToReports(2),
                child: const Text('تقرير المخزون'),
              ),
            ],
          ),
          const Divider(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.take(5).length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final it = items[idx];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${it.categoryName} • المتوفر: ${it.currentStock} ${it.unitSymbol} (الحد الأدنى: ${it.minimumStock})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'عجز: -${it.difference.toStringAsFixed(1)} ${it.unitSymbol}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
          if (items.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _navigateToReports(2),
                child: Text('عرض باقي النواقص (${items.length - 5} صنف إضافي)...'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportsShortcutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختصارات التقارير المالية والتحليلية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildReportShortcutTile(
              title: 'تقرير المبيعات',
              subtitle: 'الفواتير، المقبوض نقداً، والمبيعات الآجلة',
              icon: Icons.point_of_sale,
              color: Colors.blue.shade800,
              onTap: () => _navigateToReports(0),
            ),
            _buildReportShortcutTile(
              title: 'تقرير المشتريات',
              subtitle: 'فواتير الموردين، المدفوع، والآجل',
              icon: Icons.shopping_cart,
              color: Colors.indigo.shade800,
              onTap: () => _navigateToReports(1),
            ),
            _buildReportShortcutTile(
              title: 'المخزون وحركة الأصناف',
              subtitle: 'تكلفة المخزون، النواقص، وسجل الحركات',
              icon: Icons.inventory_2,
              color: Colors.teal.shade800,
              onTap: () => _navigateToReports(2),
            ),
            _buildReportShortcutTile(
              title: 'تقرير الديون والذمم',
              subtitle: 'كشف حساب ديون العملاء والموردين',
              icon: Icons.people_alt,
              color: Colors.purple.shade800,
              onTap: () => _navigateToReports(3),
            ),
            _buildReportShortcutTile(
              title: 'المصروفات التشغيلية',
              subtitle: 'توزيع المصروفات حسب التصنيفات',
              icon: Icons.receipt_long,
              color: Colors.deepOrange.shade800,
              onTap: () => _navigateToReports(4),
            ),
            _buildReportShortcutTile(
              title: 'الأرباح والخسائر (P&L)',
              subtitle: 'صافي المبيعات، التكلفة، والأرباح الحقيقية',
              icon: Icons.account_balance,
              color: Colors.green.shade800,
              onTap: () => _navigateToReports(5),
            ),
            _buildReportShortcutTile(
              title: 'التقرير المالي السنوي',
              subtitle: 'تحليل الأشهر الـ 12 ومقارنة الأداء',
              icon: Icons.calendar_month,
              color: Colors.brown.shade800,
              onTap: () => _navigateToReports(6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportShortcutTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
