import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/purchases_report_data.dart';

/// تبويب تقرير المشتريات المفصل
class PurchasesReportTab extends StatelessWidget {
  final PurchasesReportData data;
  final bool isLoading;

  const PurchasesReportTab({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // بطاقات المؤشرات الإجمالية
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'صافي المشتريات',
              value: Formatters.currency(data.netPurchases),
              subtitle: 'بعد خصم المرتجعات',
              icon: Icons.shopping_cart_outlined,
              color: AppColors.primary,
              isProminent: true,
            ),
            _buildMetricCard(
              title: 'إجمالي المشتريات',
              value: Formatters.currency(data.grossPurchases),
              subtitle: 'قبل المرتجعات (${data.invoiceCount} فاتورة)',
              icon: Icons.inventory_2_outlined,
              color: Colors.blueGrey,
            ),
            _buildMetricCard(
              title: 'مرتجعات المشتريات',
              value: Formatters.currency(data.returnsTotal),
              subtitle: 'مردودات إلى الموردين',
              icon: Icons.reply_outlined,
              color: Colors.orange.shade800,
            ),
            _buildMetricCard(
              title: 'المسدد للموردين نقداً',
              value: Formatters.currency(data.cashPaidTotal),
              subtitle: 'مدفوعات نقدية فورية',
              icon: Icons.payments_outlined,
              color: Colors.green.shade700,
            ),
            _buildMetricCard(
              title: 'المشتريات الآجلة (ديون علينا)',
              value: Formatters.currency(data.remainingDebtTotal),
              subtitle: 'ذمم دائنة مستحقة للموردين',
              icon: Icons.request_quote_outlined,
              color: Colors.red.shade700,
            ),
            _buildMetricCard(
              title: 'متوسط فاتورة الشراء',
              value: Formatters.currency(data.averageInvoiceValue.round()),
              subtitle: 'معدل أمر التوريد',
              icon: Icons.analytics_outlined,
              color: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // جدول / قائمة فواتير الشراء
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'فواتير مشتريات الفترة (${data.invoices.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    data.dateRange.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (data.invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'لا توجد فواتير مشتريات مسجلة في هذه الفترة',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.invoices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final inv = data.invoices[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: inv.isCredit
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        child: Icon(
                          inv.isCredit ? Icons.credit_card : Icons.check_circle_outline,
                          color: inv.isCredit ? Colors.red : Colors.green,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            inv.invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            inv.supplierName ?? 'مورد عام',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${Formatters.formatDate(inv.invoiceDate)} • ${inv.isCredit ? "آجل" : "نقدي"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency(inv.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          if (inv.remainingAmount > 0)
                            Text(
                              'متبقي: ${Formatters.currency(inv.remainingAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const Text(
                              'مسددة بالكامل',
                              style: TextStyle(fontSize: 11, color: Colors.green),
                            ),
                        ],
                      ),
                    );
                  },
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
      width: 200,
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
