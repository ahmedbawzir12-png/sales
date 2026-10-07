import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/expenses_report_data.dart';

/// تبويب تقرير المصروفات التشغيلية
class ExpensesReportTab extends StatelessWidget {
  final ExpensesReportData data;
  final bool isLoading;

  const ExpensesReportTab({
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
        // بطاقة إجمالي المصروفات التشغيلية
        AppCard(
          backgroundColor: AppColors.primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي المصروفات التشغيلية للفترة',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.currency(data.totalExpenses),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.dateRange.label} • ${data.expenses.length} عملية صرف مسجلة',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.receipt_long, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // توزيع المصروفات حسب التصنيف
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'توزيع المصروفات حسب التصنيف',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Divider(height: 24),
              if (data.categoryBreakdown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('لا توجد مصروفات مسجلة في هذه الفترة')),
                )
              else
                Column(
                  children: data.categoryBreakdown.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${Formatters.currency(cat.amount)} (${cat.percentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: cat.percentage / 100,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary.withAlpha(200),
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // سجل عمليات الصرف المفصل
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل عمليات الصرف (${data.expenses.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Divider(height: 24),
              if (data.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('لا توجد عمليات صرف مسجلة')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.expenses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final exp = data.expenses[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: const Icon(Icons.arrow_upward, color: Colors.red, size: 18),
                      ),
                      title: Row(
                        children: [
                          Text(
                            exp.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exp.description,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        Formatters.formatDateTime(exp.expenseDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        Formatters.currency(exp.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red,
                        ),
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
}
