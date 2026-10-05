import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';
import '../../domain/repositories/purchase_returns_repository.dart';

/// نافذة إنشاء مرتجع مشتريات وتحديد الأصناف والكميات المراد إرجاعها للمورد
class CreatePurchaseReturnDialog extends StatefulWidget {
  final int purchaseInvoiceId;
  final String invoiceNumber;
  final int supplierId;
  final PurchaseReturnsRepository returnsRepository;

  const CreatePurchaseReturnDialog({
    super.key,
    required this.purchaseInvoiceId,
    required this.invoiceNumber,
    required this.supplierId,
    required this.returnsRepository,
  });

  static Future<PurchaseReturn?> show(
    BuildContext context, {
    required int purchaseInvoiceId,
    required String invoiceNumber,
    required int supplierId,
    required PurchaseReturnsRepository returnsRepository,
  }) {
    return showDialog<PurchaseReturn>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreatePurchaseReturnDialog(
        purchaseInvoiceId: purchaseInvoiceId,
        invoiceNumber: invoiceNumber,
        supplierId: supplierId,
        returnsRepository: returnsRepository,
      ),
    );
  }

  @override
  State<CreatePurchaseReturnDialog> createState() =>
      _CreatePurchaseReturnDialogState();
}

class _CreatePurchaseReturnDialogState
    extends State<CreatePurchaseReturnDialog> {
  List<PurchaseReturnAvailableItem>? _availableItems;
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
          .getAvailableReturnItems(widget.purchaseInvoiceId);
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
          _errorMessage = 'فشل استرجاع بنود فاتورة الشراء المتاحة للإرجاع';
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
        total += (qty * item.unitCost).round();
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

    final returnItems = <PurchaseReturnItem>[];
    for (final item in _availableItems!) {
      final ctrl = _controllers[item.productId];
      final qty = double.tryParse(ctrl?.text.trim() ?? '0') ?? 0.0;
      if (qty <= 0) continue;

      if (qty > item.availableQuantity) {
        setState(() {
          _errorMessage =
              'الكمية المدخلة للصنف "${item.productName}" ($qty) تتجاوز المتاح من الفاتورة (${item.availableQuantity})';
        });
        return;
      }

      if (qty > item.currentWarehouseStock) {
        setState(() {
          _errorMessage =
              'لا يمكن إرجاع ($qty) من "${item.productName}" لأن الرصيد المتوفر في المستودع هو (${item.currentWarehouseStock}) فقط';
        });
        return;
      }

      returnItems.add(
        PurchaseReturnItem(
          id: 0,
          purchaseReturnId: 0,
          productId: item.productId,
          productName: item.productName,
          quantity: qty,
          unitCost: item.unitCost,
          total: (qty * item.unitCost).round(),
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
      final returnDoc = PurchaseReturn(
        id: 0,
        returnNumber: '',
        purchaseInvoiceId: widget.purchaseInvoiceId,
        supplierId: widget.supplierId,
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
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.keyboard_return_outlined,
                color: AppColors.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'مرتجع مشتريات لفاتورة: ${widget.invoiceNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
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
                            child: Text(
                                'لا توجد أصناف قابلة للإرجاع في فاتورة الشراء هذه'),
                          )
                        : ListView.separated(
                            itemCount: _availableItems!.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _availableItems![index];
                              final ctrl = _controllers[item.productId]!;
                              final entered = double.tryParse(ctrl.text) ?? 0;
                              final isExceeded = entered > item.availableQuantity ||
                                  entered > item.currentWarehouseStock;

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
                                            'سعر الشراء: ${Formatters.formatCurrency(item.unitCost)}',
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
                                            'المشترى: ${item.originalQuantity}',
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'المتاح: ${item.availableQuantity}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'المخزون الحالي: ${item.currentWarehouseStock}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: item.currentWarehouseStock <= 0
                                                  ? AppColors.error
                                                  : Colors.grey.shade700,
                                              fontWeight:
                                                  item.currentWarehouseStock <= 0
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 110,
                                      child: TextField(
                                        controller: ctrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        enabled: item.availableQuantity > 0 &&
                                            item.currentWarehouseStock > 0,
                                        decoration: InputDecoration(
                                          labelText: 'كمية الإرجاع',
                                          isDense: true,
                                          errorText: isExceeded ? 'خطأ' : null,
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
                      hintText: 'سبب رد البضاعة للمورد...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // شريط الإجمالي
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي الكميات المرتجعة: ${_totalReturnItemsCount.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إجمالي قيمة المرتجع: ${Formatters.formatCurrency(_calculatedReturnTotal)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
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
          label: const Text('اعتماد المرتجع وخصم المخزون'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
