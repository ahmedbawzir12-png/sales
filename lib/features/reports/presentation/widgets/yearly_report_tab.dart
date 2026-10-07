import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/yearly_report_data.dart';

/// تبويب التقرير السنوي مع التفصيل والتحليل الشهري
class YearlyReportTab extends StatelessWidget {
  final YearlyReportData data;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;
  final bool isLoading;

  const YearlyReportTab({
    super.key,
    required this.data,
    required this.selectedYear,
    required this.onYearChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // شريط اختيار السنة
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border.withAlpha(120)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'التقرير المالي السنوي لسنة $selectedYear',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  underline: const SizedBox(),
                  items: [
                    for (int y = now.year - 4; y <= now.year + 1; y++)
                      DropdownMenuItem(
                        value: y,
                        child: Text('سنة $y', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                  onChanged: (y) {
                    if (y != null) onYearChanged(y);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // بطاقات إجماليات السنة
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'صافي أرباح السنة',
              value: Formatters.currency(data.totalNetProfit.round()),
              subtitle: 'بعد خصم التكلفة والمصروفات',
              icon: Icons.trending_up,
              color: data.totalNetProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              isProminent: true,
            ),
            _buildMetricCard(
              title: 'صافي مبيعات السنة',
              value: Formatters.currency(data.netSales),
              subtitle: 'بعد استبعاد المرتجعات',
              icon: Icons.point_of_sale,
              color: AppColors.primary,
            ),
            _buildMetricCard(
              title: 'تكلفة البضاعة السنوية',
              value: Formatters.currency(data.totalNetCogs.round()),
              subtitle: 'صافي تكلفة المبيعات',
              icon: Icons.inventory_2_outlined,
              color: Colors.blueGrey,
            ),
            _buildMetricCard(
              title: 'المصروفات السنوية',
              value: Formatters.currency(data.totalExpenses),
              subtitle: 'إجمالي مصاريف التشغيل',
              icon: Icons.receipt_long,
              color: Colors.red.shade700,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // جدول تفصيل الأشهر الـ 12
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حركة النشاط والأرباح شهراً بشهر لسنة $selectedYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Divider(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                  columns: const [
                    DataColumn(label: Text('الشهر', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('المبيعات', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('المرتجعات', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('صافي المبيعات', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('التكلفة', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الربح الإجمالي', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('المصروفات', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('صافي الربح', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.monthlyBreakdown.map((row) {
                    final isProf = row.netProfit >= 0;
                    return DataRow(
                      cells: [
                        DataCell(Text(row.monthName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(Formatters.currency(row.grossSales))),
                        DataCell(Text(Formatters.currency(row.salesReturns))),
                        DataCell(Text(
                          Formatters.currency(row.netSales),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        )),
                        DataCell(Text(Formatters.currency(row.netCogs.round()))),
                        DataCell(Text(Formatters.currency(row.grossProfit.round()))),
                        DataCell(Text(Formatters.currency(row.expenses))),
                        DataCell(Text(
                          Formatters.currency(row.netProfit.round()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isProf ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
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
        color: isProminent ? (color == Colors.red.shade700 ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B)) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProminent ? Colors.transparent : Colors.grey.shade200,
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
