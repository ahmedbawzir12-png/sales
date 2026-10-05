import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/sales_return.dart';
import '../../domain/entities/sales_return_item.dart';
import '../../domain/repositories/sales_returns_repository.dart';

/// نافذة إنشاء مرتجع مبيعات وتحديد الأصناف والكميات المراد إرجاعها
class CreateSalesReturnDialog extends StatefulWidget {
  final int salesInvoiceId;
  final String invoiceNumber;
  final SalesReturnsRepository returnsRepository;

  const CreateSalesReturnDialog({
    super.key,
    required this.salesInvoiceId,
    required this.invoiceNumber,
    required this.returnsRepository,
  });

  static Future<SalesReturn?> show(
    BuildContext context, {
    required int salesInvoiceId,
    required String invoiceNumber,
    required SalesReturnsRepository returnsRepository,
  }) {
    return showDialog<SalesReturn>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateSalesReturnDialog(
        salesInvoiceId: salesInvoiceId,
        invoiceNumber: invoiceNumber,
        returnsRepository: returnsRepository,
      ),
    );
  }

  @override
  State<CreateSalesReturnDialog> createState() =>
      _CreateSalesReturnDialogState();
}

class _CreateSalesReturnDialogState extends State<CreateSalesReturnDialog> {
  List<SalesReturnAvailableItem>? _availableItems;
  final Map<int, TextEditingController> _controllers = {};
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
  }

  Future<void> _loadAvailableItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.returnsRepository
          .getAvailableReturnItems(widget.salesInvoiceId);
      for (final item in items) {
        _controllers[item.productId] = TextEditingController(text: '0');
      }

      if (mounted) {
        setState(() {
          _availableItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل استرجاع بنود الفاتورة المتاحة للإرجاع';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  int get _calculatedReturnTotal {
    if (_availableItems == null) return 0;
    int total = 0;
    for (final item in _availableItems!) {
      final ctrl = _controllers[item.productId];
      final qty = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
      if (qty > 0) {
        total += (qty * item.unitPrice).round();
      }
    }
    return total;
  }

  double get _totalReturnItemsCount {
    if (_availableItems == null) return 0.0;
    double count = 0;
    for (final item in _availableItems!) {
      final ctrl = _controllers[item.productId];
      final qty = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
      count += qty;
    }
    return count;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _availableItems == null) return;

    final returnItems = <SalesReturnItem>[];
    for (final item in _availableItems!) {
      final ctrl = _controllers[item.productId];
      final qty = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
      if (qty <= 0) continue;

      if (qty > item.availableQuantity) {
        setState(() {
          _errorMessage =
              'الكمية المدخلة للصنف "${item.productName}" ($qty) تتجاوز المتاح (${item.availableQuantity})';
        });
        return;
      }

      returnItems.add(
        SalesReturnItem(
          id: 0,
          salesReturnId: 0,
          productId: item.productId,
          productName: item.productName,
          quantity: qty,
          unitPrice: item.unitPrice,
          unitCostAtSale: item.unitCostAtSale,
          total: (qty * item.unitPrice).round(),
        ),
      );
    }

    if (returnItems.isEmpty) {
      setState(() => _errorMessage = 'يرجى تحديد كمية إرجاع لصنف واحد على الأقل');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final returnDoc = SalesReturn(
        id: 0,
        returnNumber: '',
        salesInvoiceId: widget.salesInvoiceId,
        returnDate: DateTime.now(),
        total: _calculatedReturnTotal,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        items: returnItems,
      );

      final saved = await widget.returnsRepository.createReturn(returnDoc);

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_return_outlined,
                color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'مرتجع مبيعات لفاتورة: ${widget.invoiceNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 520,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),

                  // جدول الأصناف
                  Expanded(
                    child: _availableItems == null || _availableItems!.isEmpty
                        ? const Center(
                            child: Text('لا توجد أصناف قابلة للإرجاع في هذه الفاتورة'),
                          )
                        : ListView.separated(
                            itemCount: _availableItems!.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _availableItems![index];
                              final ctrl = _controllers[item.productId]!;
                              final isExceeded = (double.tryParse(ctrl.text) ?? 0) >
                                  item.availableQuantity;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                          Text(
                                            'سعر البيع: ${Formatters.formatCurrency(item.unitPrice)}',
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'المباع: ${item.originalQuantity}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            'المرتجع: ${item.alreadyReturnedQuantity}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.availableQuantity > 0
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'المتاح: ${item.availableQuantity}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: item.availableQuantity > 0
                                                ? Colors.blue.shade800
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 110,
                                      child: TextField(
                                        controller: ctrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        enabled: item.availableQuantity > 0,
                                        decoration: InputDecoration(
                                          labelText: 'كمية الإرجاع',
                                          isDense: true,
                                          errorText: isExceeded ? 'تجاوز' : null,
                                          border: const OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),

                  // حقل ملاحظات المرتجع
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'سبب / ملاحظات المرتجع (اختياري)',
                      hintText: 'مثال: وجود عيب مصنعي، استبدال، رغبة الزبون...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // شريط الإجمالي
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي الكميات: ${_totalReturnItemsCount.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إجمالي قيمة المرتجع: ${Formatters.formatCurrency(_calculatedReturnTotal)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting || _calculatedReturnTotal <= 0
              ? null
              : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: const Text('اعتماد المرتجع وإرجاع المخزون'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
