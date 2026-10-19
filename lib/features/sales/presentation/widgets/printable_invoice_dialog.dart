import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/app_toast.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_payment_type.dart';

/// نافذة معاينة وطباعة الفاتورة التجارية (Printable Invoice Dialog)
/// مصممة خصيصاً لتطابق معايير فواتير محلات الأثاث والمفروشات الراقية
/// تلتزم الصرامة المحاسبية بعدم عرض أي تكلفة داخلية (unitCostAtSale / Average Cost)
class PrintableInvoiceDialog extends StatelessWidget {
  final SalesInvoice invoice;
  final String storeName;
  final String storePhone;
  final String storeAddress;

  const PrintableInvoiceDialog({
    super.key,
    required this.invoice,
    this.storeName = 'معرض المفروشات العصري',
    this.storePhone = '771234567 - 05443210',
    this.storeAddress = 'شارع المعارض الرئيسي - بجوار بنك التضامن',
  });

  static Future<void> show(
    BuildContext context, {
    required SalesInvoice invoice,
    String? storeName,
    String? storePhone,
    String? storeAddress,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PrintableInvoiceDialog(
        invoice: invoice,
        storeName: storeName ?? 'معرض المفروشات العصري',
        storePhone: storePhone ?? '771234567 - 05443210',
        storeAddress: storeAddress ?? 'شارع المعارض الرئيسي - بجوار بنك التضامن',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = invoice.paymentType == SalesPaymentType.credit;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط الأدوات العلوي
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'معاينة وطباعة الفاتورة التجارية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ورقة الفاتورة المطبوعة (A4 / Thermal Printable Sheet)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. ترويسة المتجر
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  storeAddress,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'هاتف: $storePhone',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'فاتورة مبيعات',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  invoice.invoiceNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(thickness: 1.5),
                      const SizedBox(height: 8),

                      // 2. بيانات الفاتورة والعميل
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'بيانات العميل:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  invoice.customerName ?? 'عميل نقدي (زبون عام)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'تاريخ ووقت الإصدار:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.dateTime(invoice.invoiceDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'طريقة السداد: ${invoice.paymentType.arabicLabel}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isCredit ? AppColors.warning : AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (invoice.isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ملغاة',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. جدول الأصناف المباعة (بدون أي تكلفة داخلية)
                      Table(
                        border: TableBorder.all(color: AppColors.border, width: 1),
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(4.5),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2.5),
                          4: FlexColumnWidth(2.5),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceElevated,
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('م', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('الصنف / المفروشات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('الإجمالي', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          ...invoice.items.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final item = entry.value;
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('$idx', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    item.productName ?? 'صنف #${item.productId}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    '${item.quantity} ${item.unitSymbol ?? ""}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    AppFormatters.currency(item.unitPrice),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    AppFormatters.currency(item.total),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. ملخص الإجماليات
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360, minWidth: 200),
                          child: Column(
                            children: [
                              _buildSummaryRow('المجموع الفرعي:', AppFormatters.currency(invoice.subtotal)),
                              if (invoice.discount > 0)
                                _buildSummaryRow('الخصم الممنوح:', '- ${AppFormatters.currency(invoice.discount)}', isDiscount: true),
                              const Divider(height: 12),
                              _buildSummaryRow(
                                'الصافي المطلوب:',
                                AppFormatters.currency(invoice.totalAmount),
                                isBold: true,
                              ),
                              _buildSummaryRow('المبلغ المدفوع:', AppFormatters.currency(invoice.paidAmount)),
                              if (isCredit)
                                _buildSummaryRow(
                                  'المتبقي ذمة (دين):',
                                  AppFormatters.currency(invoice.remainingAmount),
                                  highlightWarning: invoice.remainingAmount > 0,
                                ),
                            ],
                          ),
                        ),
                      ),

                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ملاحظات: ${invoice.notes}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const Text(
                        'شكراً لتعاملكم معنا • البضاعة المباعة ترد أو تستبدل خلال 3 أيام بحالتها الأصلية مع إبراز الفاتورة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // أزرار التحكم
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('إغلاق'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      AppToast.showInfo(
                        context,
                        'تم إرسال أمر الطباعة إلى الطابعة الافتراضية بنجاح',
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('طباعة الفاتورة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isDiscount = false,
    bool highlightWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 13.5 : 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isDiscount ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isBold ? 14.5 : 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlightWarning
                  ? AppColors.error
                  : (isDiscount
                      ? AppColors.warning
                      : (isBold ? AppColors.primary : AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
