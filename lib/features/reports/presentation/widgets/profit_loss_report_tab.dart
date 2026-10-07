import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/profit_loss_report_data.dart';

/// تبويب تقرير الأرباح والخسائر المالي (Profit & Loss Statement)
class ProfitLossReportTab extends StatelessWidget {
  final ProfitLossReportData data;
  final bool isLoading;

  const ProfitLossReportTab({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isProfit = data.netProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // بطاقة ملخص صافي الربح النهائي
        AppCard(
          backgroundColor: isProfit ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isProfit ? 'صافي أرباح الفترة (فائض)' : 'صافي خسائر الفترة (عجز)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'هامش الربح: ${data.profitMargin.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Formatters.currency(data.netProfit.round()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.dateRange.label} • الربح الإجمالي: ${Formatters.currency(data.grossProfit.round())}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // قائمة الدخل التقديرية التفصيلية (Financial P&L Breakdown)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'قائمة الدخل والأرباح (P&L Breakdown)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تعتمد على التكلفة التاريخية الفعلية للبضاعة المباعة وقت البيع والمردودات',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),

              // 1. بند الإيرادات والمبيعات
              _buildSectionHeader('1. الإيرادات وصافي المبيعات'),
              _buildRow('إجمالي فواتير المبيعات', data.grossSales.toDouble(), isAddition: true),
              _buildRow('(-) مرتجعات المبيعات', data.salesReturns.toDouble(), isDeduction: true),
              _buildSubtotalRow('صافي المبيعات (Net Sales)', data.netSales.toDouble()),
              const Divider(height: 20),

              // 2. تكلفة البضاعة المباعة
              _buildSectionHeader('2. تكلفة البضاعة المباعة (COGS)'),
              _buildRow('تكلفة البضاعة المباعة التاريخية', data.grossCogs, isDeduction: true),
              _buildRow('(-) استعادة تكلفة المرتجعات', data.returnedCogs, isAddition: true),
              _buildSubtotalRow('صافي تكلفة البضاعة المباعة', data.netCogs),
              const Divider(height: 20),

              // 3. مجمل الربح
              _buildSubtotalRow(
                'الربح الإجمالي (Gross Profit)',
                data.grossProfit,
                highlightColor: Colors.blue.shade900,
                fontSize: 15,
              ),
              const Divider(height: 20),

              // 4. المصروفات التشغيلية
              _buildSectionHeader('3. المصروفات التشغيلية (Operating Expenses)'),
              _buildRow('(-) المصروفات التشغيلية', data.operatingExpenses.toDouble(), isDeduction: true),
              const Divider(height: 20),

              // 5. صافي الربح النهائي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: profitColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: profitColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'صافي الربح النهائي (Net Profit):',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: profitColor,
                      ),
                    ),
                    Text(
                      Formatters.currency(data.netProfit.round()),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: profitColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // تنبيهات وقواعد المحاسبة المطبقة في النظام
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المحددات والضوابط المحاسبية المطبقة:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• سحوبات المالك الشخصية تخفض رصيد الصندوق فقط ولا تخصم من الأرباح التشغيلية.\n'
                      '• سندات قبض العميل وصرف المورد هي تسويات ذمم نقدية وليست إيرادات أو مصروفات.\n'
                      '• تكلفة البضاعة ثابتة تاريخياً وفق متوسط تكلفة المخزون وقت تنفيذ الفاتورة.',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    bool isAddition = false,
    bool isDeduction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            Formatters.currency(amount.round()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDeduction
                  ? Colors.red.shade700
                  : (isAddition ? Colors.green.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalRow(
    String label,
    double amount, {
    Color? highlightColor,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? Colors.black87,
            ),
          ),
          Text(
            Formatters.currency(amount.round()),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
