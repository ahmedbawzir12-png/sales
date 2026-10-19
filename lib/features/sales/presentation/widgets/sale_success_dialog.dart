import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_payment_type.dart';
import '../screens/sales_invoice_details_screen.dart';
import '../../domain/repositories/sales_repository.dart';
import 'printable_invoice_dialog.dart';

/// مربع حوار إتمام البيع بنجاح (Sale Success Dialog)
/// يقدم إجراءات فورية وسلسة (عرض، طباعة، بيع جديد)
class SaleSuccessDialog extends StatelessWidget {
  final SalesInvoice invoice;
  final SalesRepository repository;
  final VoidCallback onNewSale;

  const SaleSuccessDialog({
    super.key,
    required this.invoice,
    required this.repository,
    required this.onNewSale,
  });

  static Future<void> show(
    BuildContext context, {
    required SalesInvoice invoice,
    required SalesRepository repository,
    required VoidCallback onNewSale,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SaleSuccessDialog(
        invoice: invoice,
        repository: repository,
        onNewSale: onNewSale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = invoice.paymentType == SalesPaymentType.credit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. شارة النجاح
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 46,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'تمت عملية البيع بنجاح',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تم اعتماد الفاتورة وتحديث المخزون وقيد الحسابات فورياً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // 2. بطاقة ملخص الفاتورة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('رقم الفاتورة:', invoice.invoiceNumber, isPrimary: true),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'العميل:',
                      invoice.customerName ?? 'عميل نقدي (زبون عام)',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'طريقة الدفع:',
                      invoice.paymentType.arabicLabel,
                      color: isCredit ? AppColors.warning : AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'إجمالي الفاتورة:',
                      AppFormatters.currency(invoice.totalAmount),
                      isBold: true,
                    ),
                    if (isCredit && invoice.remainingAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'المبلغ المتبقي (دين):',
                        AppFormatters.currency(invoice.remainingAmount),
                        color: AppColors.error,
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. أزرار الإجراءات الفورية
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SalesInvoiceDetailsScreen(
                                  invoiceId: invoice.id,
                                  repository: repository,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('عرض الفاتورة'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            PrintableInvoiceDialog.show(context, invoice: invoice);
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('طباعة الفاتورة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNewSale();
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('عملية بيع جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isPrimary = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: isPrimary ? 16 : (isBold ? 14 : 13),
            fontWeight: isBold || isPrimary ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isPrimary ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
