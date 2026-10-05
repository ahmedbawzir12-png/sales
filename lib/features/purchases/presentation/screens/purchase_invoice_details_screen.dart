import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/repositories/purchases_repository.dart';

/// شاشة تفاصيل فاتورة الشراء مع إمكانية الإلغاء الآمن
class PurchaseInvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;
  final PurchasesRepository purchasesRepository;

  PurchaseInvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    PurchasesRepository? purchasesRepository,
  }) : purchasesRepository = purchasesRepository ?? PurchasesRepositoryImpl();

  @override
  State<PurchaseInvoiceDetailsScreen> createState() => _PurchaseInvoiceDetailsScreenState();
}

class _PurchaseInvoiceDetailsScreenState extends State<PurchaseInvoiceDetailsScreen> {
  PurchaseInvoice? _invoice;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoice = await widget.purchasesRepository.getInvoiceById(widget.invoiceId);
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل تفاصيل فاتورة الشراء';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmCancelInvoice() async {
    if (_invoice == null || _invoice!.isCancelled) return;

    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد إلغاء فاتورة الشراء'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من إلغاء الفاتورة رقم (${_invoice!.invoiceNumber})؟\n\n'
                'سيتم عكس أثر المخزون بالكامل وتسجيل حركة مرتجع، وتخفيض دين المورد إن وُجد.\n'
                'ملاحظة: يشترط توفر كميات كافية في المخزون لمنع النزول للسالب.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب الإلغاء *',
                  hintText: 'مثال: خطأ في البضاعة المستلمة...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'سبب الإلغاء مطلوب لتوثيق السجل';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.purchasesRepository.cancelPurchaseInvoice(
          _invoice!.id,
          reason: reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الفاتورة وعكس أثر المخزون والدين بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadInvoiceDetails();
        }
      } on AppException catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تعذر إلغاء الفاتورة'),
              content: Text(e.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء إلغاء الفاتورة: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'الفاتورة غير متوفرة'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadInvoiceDetails,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final invoice = _invoice!;

    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة شراء ${invoice.invoiceNumber}'),
        actions: [
          if (!invoice.isCancelled)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: 'إلغاء الفاتورة',
              onPressed: _confirmCancelInvoice,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. شريط تنبيه إن كانت الفاتورة ملغاة
            if (invoice.isCancelled)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذه الفاتورة ملغاة (تم عكس أثرها على المخزون وحساب المورد)',
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // 2. بطاقة بيانات الفاتورة والمورد
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'التاريخ: ${AppFormatters.dateTime(invoice.invoiceDate)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: invoice.isCancelled
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: invoice.isCancelled
                                      ? Colors.red.shade300
                                      : Colors.green.shade300,
                                ),
                              ),
                              child: Text(
                                invoice.status.arabicLabel,
                                style: TextStyle(
                                  color: invoice.isCancelled
                                      ? Colors.red.shade800
                                      : Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                invoice.paymentType.arabicLabel,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.business, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.supplierName ?? 'مورد غير معروف',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (invoice.supplierPhone != null)
                                Text(
                                  invoice.supplierPhone!,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. جدول بنود الفاتورة
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أصناف الفاتورة (${invoice.items.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2.5),
                        3: FlexColumnWidth(3),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('التكلفة', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('الإجمالي',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...invoice.items.map((item) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(item.productName ?? 'منتج #${item.productId}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('${item.quantity} ${item.unitSymbol ?? ""}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(AppFormatters.currency(item.unitCost)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  AppFormatters.currency(item.total),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. الملخص المالي
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow('المجموع الفرعي (Subtotal):', AppFormatters.currency(invoice.subtotal)),
                    if (invoice.discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'قيمة الخصم (Discount):',
                        '- ${AppFormatters.currency(invoice.discount)}',
                        valueColor: Colors.red,
                      ),
                    ],
                    const Divider(height: 20),
                    _buildSummaryRow(
                      'صافي الفاتورة (Total):',
                      AppFormatters.currency(invoice.total),
                      isBold: true,
                      fontSize: 17,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('المبلغ المدفوع (Paid):', AppFormatters.currency(invoice.paidAmount)),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'المتبقي (دين مستحق للمورد):',
                      invoice.isPaidInFull ? 'مسددة بالكامل ✓' : AppFormatters.currency(invoice.remainingAmount),
                      valueColor: invoice.isPaidInFull ? Colors.green : Colors.red.shade800,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),

            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notes, size: 18),
                          SizedBox(width: 6),
                          Text('ملاحظات الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(invoice.notes!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, double fontSize = 14, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
