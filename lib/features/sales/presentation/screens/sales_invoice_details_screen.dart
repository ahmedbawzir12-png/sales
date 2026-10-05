import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_payment_type.dart';
import '../../domain/repositories/sales_repository.dart';

/// شاشة تفاصيل فاتورة المبيعات وإلغائها
class SalesInvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;
  final SalesRepository repository;

  const SalesInvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.repository,
  });

  @override
  State<SalesInvoiceDetailsScreen> createState() => _SalesInvoiceDetailsScreenState();
}

class _SalesInvoiceDetailsScreenState extends State<SalesInvoiceDetailsScreen> {
  SalesInvoice? _invoice;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoice = await widget.repository.getInvoiceById(widget.invoiceId);
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelInvoice() async {
    if (_invoice == null || _invoice!.isCancelled) return;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد إلغاء الفاتورة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في إلغاء الفاتورة رقم (${_invoice!.invoiceNumber})؟\n\nسيتم إرجاع كميات جميع الأصناف المباعة إلى المخزون تلقائياً وإلغاء أي ذمم مالية مترتبة عليها.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        await widget.repository.cancelInvoice(
          _invoice!.id,
          reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الفاتورة وإعادة الكميات للمخزون بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadInvoice();
      } catch (e, s) {
        final failure = ErrorHandler.handle(e, s);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.userFriendlyMessage), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice?.invoiceNumber ?? 'تفاصيل فاتورة البيع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadInvoice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _invoice == null
                  ? const Center(child: Text('الفاتورة غير موجودة'))
                  : RefreshIndicator(
                      onRefresh: _loadInvoice,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. رأس الفاتورة والحالة
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _invoice!.invoiceNumber,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'التاريخ: ${AppFormatters.date(_invoice!.invoiceDate)}',
                                            style: const TextStyle(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      // شارة الحالة
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _invoice!.isCancelled
                                              ? AppColors.errorContainer
                                              : AppColors.successContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _invoice!.status.arabicLabel,
                                          style: TextStyle(
                                            color: _invoice!.isCancelled ? AppColors.error : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('العميل:', style: TextStyle(color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _invoice!.customerName ?? 'عميل نقدي (زبون عام)',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('نوع السداد:', style: TextStyle(color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _invoice!.paymentType.arabicLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: _invoice!.paymentType == SalesPaymentType.credit
                                                    ? AppColors.warning
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_invoice!.notes != null && _invoice!.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text('ملاحظات: ${_invoice!.notes!}', style: const TextStyle(color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. جدول أصناف ومبيعات الفاتورة
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الأصناف المباعة (${_invoice!.items.length})',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const Divider(),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('م')),
                                        DataColumn(label: Text('الصنف / المنتج')),
                                        DataColumn(label: Text('الكمية')),
                                        DataColumn(label: Text('سعر البيع')),
                                        DataColumn(label: Text('الخصم')),
                                        DataColumn(label: Text('الإجمالي')),
                                      ],
                                      rows: _invoice!.items.asMap().entries.map((entry) {
                                        final idx = entry.key + 1;
                                        final item = entry.value;

                                        return DataRow(
                                          cells: [
                                            DataCell(Text('$idx')),
                                            DataCell(Text(item.productName ?? 'منتج #${item.productId}')),
                                            DataCell(Text('${item.quantity} ${item.unitSymbol ?? ""}')),
                                            DataCell(Text(AppFormatters.currency(item.unitPrice))),
                                            DataCell(Text(AppFormatters.currency(item.discount))),
                                            DataCell(Text(
                                              AppFormatters.currency(item.total),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. ملخص المبالغ والمدفوعات
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildSummaryRow('المجموع الفرعي:', AppFormatters.currency(_invoice!.subtotal)),
                                  const SizedBox(height: 8),
                                  _buildSummaryRow('الخصم الإجمالي:', AppFormatters.currency(_invoice!.discount)),
                                  const Divider(height: 20),
                                  _buildSummaryRow(
                                    'الصافي النهائي:',
                                    AppFormatters.currency(_invoice!.totalAmount),
                                    isBold: true,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSummaryRow(
                                    'المبلغ المقبوض:',
                                    AppFormatters.currency(_invoice!.paidAmount),
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSummaryRow(
                                    'المتبقي (دين العميل):',
                                    AppFormatters.currency(_invoice!.remainingAmount),
                                    isBold: true,
                                    color: _invoice!.remainingAmount > 0 ? AppColors.error : AppColors.success,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 4. زر إلغاء الفاتورة (عندما تكون مكتملة)
                          if (!_invoice!.isCancelled) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isCancelling ? null : _cancelInvoice,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                ),
                                icon: _isCancelling
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                      )
                                    : const Icon(Icons.cancel_outlined),
                                label: const Text('إلغاء الفاتورة وإرجاع الكميات للمخزون'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 15 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
