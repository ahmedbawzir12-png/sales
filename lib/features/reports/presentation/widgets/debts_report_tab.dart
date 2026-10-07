import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/debts_report_data.dart';

/// تبويب تقرير الديون والذمم الشامل (العملاء والموردين)
class DebtsReportTab extends StatefulWidget {
  final DebtsReportData data;
  final bool isLoading;
  final int initialSubTab; // 0 for customers, 1 for suppliers

  const DebtsReportTab({
    super.key,
    required this.data,
    this.isLoading = false,
    this.initialSubTab = 0,
  });

  @override
  State<DebtsReportTab> createState() => _DebtsReportTabState();
}

class _DebtsReportTabState extends State<DebtsReportTab> {
  late int _selectedTab;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSubTab;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final d = widget.data;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // بطاقات إجماليات الديون
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'إجمالي ديون العملاء (لنا)',
              value: Formatters.currency(d.totalCustomerDebt),
              subtitle: '${d.customerDebts.length} عميل عليهم مستحقات',
              icon: Icons.people_alt_outlined,
              color: Colors.blue.shade800,
              isProminent: true,
            ),
            _buildMetricCard(
              title: 'إجمالي ديون الموردين (علينا)',
              value: Formatters.currency(d.totalSupplierDebt),
              subtitle: '${d.supplierDebts.length} مورد لهم مستحقات',
              icon: Icons.business_outlined,
              color: Colors.orange.shade800,
            ),
            _buildMetricCard(
              title: 'صافي المركز الائتماني',
              value: Formatters.currency(d.netDebt),
              subtitle: d.netDebt >= 0 ? 'فائض لصالح المحل' : 'التزامات للموردين تفوق العملاء',
              icon: Icons.account_balance_outlined,
              color: d.netDebt >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // أزرار التبديل بين العملاء والموردين
        Row(
          children: [
            ChoiceChip(
              label: Text('ديون العملاء (${d.customerDebts.length})'),
              selected: _selectedTab == 0,
              onSelected: (val) => setState(() => _selectedTab = 0),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _selectedTab == 0 ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('ديون الموردين (${d.supplierDebts.length})'),
              selected: _selectedTab == 1,
              onSelected: (val) => setState(() => _selectedTab = 1),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _selectedTab == 1 ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // شريط البحث اللحظي
        TextField(
          decoration: InputDecoration(
            hintText: _selectedTab == 0
                ? 'بحث فوري باسم العميل أو رقم الهاتف...'
                : 'بحث فوري باسم المورد أو رقم الهاتف...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),

        if (_selectedTab == 0) _buildCustomerDebtsList() else _buildSupplierDebtsList(),
      ],
    );
  }

  Widget _buildCustomerDebtsList() {
    final filtered = widget.data.customerDebts.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery) ||
          (c.phone != null && c.phone!.contains(_searchQuery));
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'كشف العملاء المدينين (${filtered.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'مرتب حسب أعلى رصيد مستحق',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('لا توجد ديون مستحقة على العملاء'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final cust = filtered[idx];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        cust.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (cust.phone != null && cust.phone!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          cust.phone!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'آجل: ${Formatters.currency(cust.creditSalesTotal)} • مسدد: ${Formatters.currency(cust.paidTotal)} • مردود: ${Formatters.currency(cust.returnsTotal)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(cust.remainingBalance),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                      if (cust.lastActivityDate != null)
                        Text(
                          'آخر حركة: ${Formatters.formatDate(cust.lastActivityDate!)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSupplierDebtsList() {
    final filtered = widget.data.supplierDebts.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery) ||
          (s.phone != null && s.phone!.contains(_searchQuery));
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'كشف ديون الموردين (${filtered.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'مرتب حسب أعلى رصيد مستحق',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('لا توجد مستحقات قائمة للموردين'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final supp = filtered[idx];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        supp.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (supp.phone != null && supp.phone!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          supp.phone!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'آجل: ${Formatters.currency(supp.creditPurchasesTotal)} • مسدد: ${Formatters.currency(supp.paidTotal)} • مردود: ${Formatters.currency(supp.returnsTotal)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(supp.remainingBalance),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.deepOrange,
                        ),
                      ),
                      if (supp.lastActivityDate != null)
                        Text(
                          'آخر حركة: ${Formatters.formatDate(supp.lastActivityDate!)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isProminent = false,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isProminent ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProminent ? AppColors.primary : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isProminent ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: isProminent ? Colors.white70 : color,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isProminent ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isProminent ? Colors.white60 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
