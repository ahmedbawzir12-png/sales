import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/cash_flow_direction.dart';
import '../../domain/entities/cash_transaction.dart';

/// نافذة تفاصيل ومصدر حركة الصندوق
class CashTransactionDetailsDialog extends StatelessWidget {
  final CashTransaction transaction;

  const CashTransactionDetailsDialog({
    super.key,
    required this.transaction,
  });

  static void show(BuildContext context, CashTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => CashTransactionDetailsDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.direction == CashFlowDirection.cashIn;
    final color = isIncome ? AppColors.success : AppColors.error;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تفاصيل حركة الصندوق',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, minWidth: 280),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة المبلغ والنوع
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      transaction.type.arabicLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isIncome ? "+" : "-"}${Formatters.formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (transaction.runningBalance != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'الرصيد بعد الحركة: ${Formatters.formatCurrency(transaction.runningBalance!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // جدول تفاصيل العملية
              _buildDetailRow(
                icon: Icons.description_outlined,
                title: 'البيان / الوصف:',
                value: transaction.description,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                title: 'تاريخ وتوقيت الحركة:',
                value: Formatters.formatDateTime(transaction.transactionDate),
              ),
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.swap_horiz,
                title: 'اتجاه التدفق:',
                value: transaction.direction.arabicLabel,
              ),
              if (transaction.referenceType != null) ...[
                const Divider(height: 16),
                _buildDetailRow(
                  icon: Icons.tag,
                  title: 'المرجع المرتبط:',
                  value: '${transaction.referenceType} #${transaction.referenceId ?? ""}',
                ),
              ],
              if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                const Divider(height: 16),
                _buildDetailRow(
                  icon: Icons.notes,
                  title: 'ملاحظات إضافية:',
                  value: transaction.notes!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
