import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/utils/app_toast.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../customers/data/repositories/customers_repository_impl.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/repositories/customers_repository.dart';
import '../../../customers/presentation/screens/add_edit_customer_dialog.dart';
import '../../../products/data/repositories/products_repository_impl.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/products_repository.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_invoice_item.dart';
import '../../domain/entities/sales_payment_type.dart';
import '../../domain/repositories/sales_repository.dart';
import '../widgets/sale_success_dialog.dart';

/// شاشة نقطة البيع السريعة وسلة المبيعات (POS Screen)
/// محسنة للمرحلة التاسعة: تركيز فوري للبحث، سلة مرنة، منع البيع الزائد،
/// إتمام سريع وموثوق، واختصارات لوحة المفاتيح
class PosScreen extends StatefulWidget {
  final SalesRepository? salesRepository;
  final ProductsRepository? productsRepository;
  final CustomersRepository? customersRepository;

  const PosScreen({
    super.key,
    this.salesRepository,
    this.productsRepository,
    this.customersRepository,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late final SalesRepository _salesRepo;
  late final ProductsRepository _productsRepo;
  late final CustomersRepository _customersRepo;

  // قائمة المنتجات والعملاء
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Customer> _customers = [];

  // سلة البيع النشطة
  final List<CartItem> _cart = [];

  // إعدادات وبيانات الفاتورة
  Customer? _selectedCustomer;
  SalesPaymentType _paymentType = SalesPaymentType.cash;
  final TextEditingController _searchProductController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _generatedInvoiceNumber;

  @override
  void initState() {
    super.initState();
    _salesRepo = widget.salesRepository ?? SalesRepositoryImpl();
    _productsRepo = widget.productsRepository ?? ProductsRepositoryImpl();
    _customersRepo = widget.customersRepository ?? CustomersRepositoryImpl();

    _loadInitialData();
  }

  @override
  void dispose() {
    _searchProductController.dispose();
    _searchFocusNode.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _productsRepo.getProducts(onlyActive: true);
      final customers = await _customersRepo.getCustomers(onlyActive: true);
      final nextNumber = await _salesRepo.generateNextInvoiceNumber();

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _customers = customers;
          _generatedInvoiceNumber = nextNumber;
          _isLoading = false;
        });

        // توجيه مؤشر الكتابة تلقائياً لحقل البحث لتنفيذ البيع بسرعة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
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

  void _filterProducts(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      if (term.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final matchName = p.name.toLowerCase().contains(term);
          final matchCat = p.categoryName?.toLowerCase().contains(term) ?? false;
          final matchId = p.id.toString() == term || '#${p.id}' == term;
          return matchName || matchCat || matchId;
        }).toList();
      }
    });
  }

  void _addToCart(Product product) {
    if (product.currentStock <= 0) {
      AppToast.showError(
        context,
        'تنبيه: المنتج "${product.name}" نفد من المخزون تماماً.',
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final currentQty = _cart[index].quantity;
        if (currentQty + 1 > product.currentStock) {
          AppToast.showWarning(
            context,
            'لا توجد كمية كافية في المخزون. المتاح حالياً: ${product.currentStock}',
          );
          return;
        }
        _cart[index].quantity += 1;
      } else {
        _cart.add(CartItem(
          product: product,
          quantity: 1.0,
          unitPrice: product.salePrice,
        ));
      }
      _recalculatePaidIfCash();
    });
  }

  void _updateCartItemQuantity(int index, double newQty) {
    if (newQty <= 0) {
      _removeFromCart(index);
      return;
    }

    final item = _cart[index];
    if (newQty > item.product.currentStock) {
      AppToast.showWarning(
        context,
        'لا توجد كمية كافية في المخزون. المتاح حالياً: ${item.product.currentStock}',
      );
      return; // منع البيع الزائد قطعياً
    }

    setState(() {
      item.quantity = newQty;
      _recalculatePaidIfCash();
    });
  }

  void _showQuantityEditDialog(int index) {
    final item = _cart[index];
    final qtyController = TextEditingController(text: '${item.quantity}');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل كمية "${item.product.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الرصيد المتاح: ${item.product.currentStock} ${item.product.unitSymbol ?? ""}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'الكمية المطلوبة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(qtyController.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop();
                _updateCartItemQuantity(index, parsed);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
      _recalculatePaidIfCash();
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _discountController.text = '0';
      _paidAmountController.text = '0';
      _notesController.clear();
      _selectedCustomer = null;
      _paymentType = SalesPaymentType.cash;
    });
  }

  int get _subtotal => _cart.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice).round());

  int get _discount => int.tryParse(_discountController.text.trim()) ?? 0;

  int get _totalAmount {
    final sub = _subtotal;
    final disc = _discount;
    final total = sub - disc;
    return total > 0 ? total : 0;
  }

  int get _paidAmount => int.tryParse(_paidAmountController.text.trim()) ?? 0;

  int get _remainingAmount {
    if (_paymentType == SalesPaymentType.cash) return 0;
    final rem = _totalAmount - _paidAmount;
    return rem > 0 ? rem : 0;
  }

  void _recalculatePaidIfCash() {
    if (_paymentType == SalesPaymentType.cash) {
      _paidAmountController.text = _totalAmount.toString();
    }
  }

  Future<void> _quickAddCustomer() async {
    final created = await AddEditCustomerDialog.show(context, repository: _customersRepo);
    if (created != null) {
      final updatedList = await _customersRepo.getCustomers(onlyActive: true);
      setState(() {
        _customers = updatedList;
        _selectedCustomer = updatedList.firstWhere(
          (c) => c.id == created.id,
          orElse: () => created,
        );
      });
    }
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      AppToast.showWarning(
        context,
        'يرجى إضافة أصناف إلى سلة البيع أولاً',
      );
      return;
    }

    if (_paymentType == SalesPaymentType.credit && _selectedCustomer == null) {
      AppToast.showError(
        context,
        '❌ يجب اختيار العميل للبيع الآجل.',
      );
      return;
    }

    // التحقق من المخزون لجميع الأصناف في السلة
    for (final item in _cart) {
      if (item.quantity > item.product.currentStock) {
        AppToast.showError(
          context,
          'لا يمكن إتمام البيع: رصيد "${item.product.name}" المتوفر (${item.product.currentStock}) أقل من المطلوب (${item.quantity})',
        );
        return;
      }
    }

    if (_discount > _subtotal) {
      AppToast.showError(
        context,
        'مبلغ الخصم لا يمكن أن يتجاوز المجموع الفرعي',
      );
      return;
    }

    if (_paidAmount > _totalAmount) {
      AppToast.showError(
        context,
        'المبلغ المدفوع لا يمكن أن يتجاوز الصافي النهائي للفاتورة',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final invoiceNumber = _generatedInvoiceNumber ?? await _salesRepo.generateNextInvoiceNumber();

      final items = _cart.map((draft) {
        return SalesInvoiceItem(
          id: 0,
          salesInvoiceId: 0,
          productId: draft.product.id,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          unitCostAtSale: draft.product.averageCost,
          discount: draft.discount,
          total: draft.calculatedTotal,
          costTotal: draft.estimatedCostTotal,
        );
      }).toList();

      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: invoiceNumber,
        customerId: _selectedCustomer?.id,
        invoiceDate: DateTime.now(),
        subtotal: _subtotal,
        discount: _discount,
        totalAmount: _totalAmount,
        paidAmount: _paymentType == SalesPaymentType.cash ? _totalAmount : _paidAmount,
        remainingAmount: _remainingAmount,
        paymentType: _paymentType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final savedInvoice = await _salesRepo.createInvoice(invoice);

      if (mounted) {
        // فتح شاشة نجاح العملية متضمنة الطباعة والعرض والبيع الجديد
        await SaleSuccessDialog.show(
          context,
          invoice: savedInvoice,
          repository: _salesRepo,
          onNewSale: () {
            _clearCart();
            _searchProductController.clear();
            _filterProducts('');
            _searchFocusNode.requestFocus();
            _loadInitialData();
          },
        );
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_isSaving && _cart.isNotEmpty) {
            _completeSale();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.point_of_sale, size: 24),
                const SizedBox(width: 8),
                const Text('نقطة البيع السريعة'),
                if (_generatedInvoiceNumber != null) ...[
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(
                      _generatedInvoiceNumber!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    backgroundColor: AppColors.primaryContainer,
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'تحديث بيانات المنتجات والأسعار',
                icon: const Icon(Icons.refresh),
                onPressed: _loadInitialData,
              ),
            ],
          ),
          body: _isLoading
              ? const LoadingState(message: 'جارٍ تجهيز الأصناف والأسعار...')
              : _errorMessage != null && _allProducts.isEmpty
                  ? ErrorState(message: _errorMessage!, onRetry: _loadInitialData)
                  : isWide
                      ? Row(
                          children: [
                            // القسم الأيمن: كتالوج واختيار المنتجات
                            Expanded(flex: 5, child: _buildProductsCatalog()),
                            const VerticalDivider(width: 1),
                            // القسم الأيسر: سلة البيع والحسابات
                            Expanded(flex: 4, child: _buildCartPanel()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 5, child: _buildProductsCatalog()),
                            const Divider(height: 1),
                            Expanded(flex: 6, child: _buildCartPanel()),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildProductsCatalog() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // شريط البحث الموحد والسريع
          AppSearchField(
            controller: _searchProductController,
            focusNode: _searchFocusNode,
            hint: 'ابحث باسم المنتج أو التصنيف أو الرمز (Ctrl+F)...',
            onChanged: _filterProducts,
            onClear: () => _filterProducts(''),
          ),
          const SizedBox(height: 10),

          // شبكة أو قائمة المنتجات
          Expanded(
            child: _filteredProducts.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد منتجات مطابقة',
                    description: 'جرّب البحث باسم آخر أو تأكد من تفعيل الصنف',
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 1.25,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final isOutOfStock = product.currentStock <= 0;

                      return Card(
                        elevation: 0,
                        color: isOutOfStock ? Colors.grey.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isOutOfStock ? Colors.grey.shade300 : AppColors.border,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isOutOfStock ? null : () => _addToCart(product),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isOutOfStock ? Colors.grey : AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                      color: isOutOfStock ? Colors.grey : AppColors.primary,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  AppFormatters.currency(product.salePrice),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOutOfStock ? Colors.grey : AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'المتاح: ${product.currentStock} ${product.unitSymbol ?? ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                                        fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    if (isOutOfStock)
                                      const Text(
                                        'نفد',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. اختيار العميل ونوع الدفع
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('pos_customer_${_selectedCustomer?.id}'),
                  initialValue: _customers.any((c) => c.id == _selectedCustomer?.id)
                      ? _selectedCustomer?.id
                      : null,
                  decoration: InputDecoration(
                    labelText: 'العميل',
                    prefixIcon: const Icon(Icons.person),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                    errorText: _paymentType == SalesPaymentType.credit && _selectedCustomer == null
                        ? 'مطلوب للبيع الآجل'
                        : null,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('زبون عام (نقدي)'),
                    ),
                    ..._customers.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(
                          '${c.name} ${c.currentBalance > 0 ? "(${AppFormatters.currency(c.currentBalance)})" : ""}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (id) {
                    setState(() {
                      if (id == null) {
                        _selectedCustomer = null;
                      } else {
                        _selectedCustomer = _customers.firstWhere((c) => c.id == id);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'إضافة عميل سريع',
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: _quickAddCustomer,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // نوع الدفع
          Row(
            children: [
              Expanded(
                child: SegmentedButton<SalesPaymentType>(
                  segments: const [
                    ButtonSegment(
                      value: SalesPaymentType.cash,
                      label: Text('نقدي'),
                      icon: Icon(Icons.money),
                    ),
                    ButtonSegment(
                      value: SalesPaymentType.credit,
                      label: Text('آجل'),
                      icon: Icon(Icons.access_time),
                    ),
                  ],
                  selected: {_paymentType},
                  onSelectionChanged: (val) {
                    setState(() {
                      _paymentType = val.first;
                      _recalculatePaidIfCash();
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: 'تفريغ السلة',
                icon: const Icon(Icons.delete_sweep, color: AppColors.error),
                onPressed: _cart.isEmpty ? null : _clearCart,
              ),
            ],
          ),
          const Divider(height: 18),

          // 2. قائمة أصناف السلة
          Expanded(
            child: _cart.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'السلة فارغة',
                    description: 'انقر على أي منتج من القائمة لإضافته للبيع',
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 10),
                    itemBuilder: (context, index) {
                      final item = _cart[index];

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border.withAlpha(80)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // السطر الأول: اسم المنتج وسعر الوحدة وزر الحذف
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppFormatters.currency(item.unitPrice),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'حذف الصنف من السلة',
                                  onPressed: () => _removeFromCart(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // السطر الثاني: التحكم بالكمية والإجمالي للبند
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'إنقاص الكمية',
                                  onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
                                ),
                                InkWell(
                                  onTap: () => _showQuantityEditDialog(index),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'زيادة الكمية',
                                  onPressed: () => _updateCartItemQuantity(index, item.quantity + 1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppFormatters.currency(item.calculatedTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 18),

          // 3. لوحة الحسابات والخصم والدفع
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('المجموع الفرعي:')),
                  Text(
                    AppFormatters.currency(_subtotal),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(child: Text('الخصم:')),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _recalculatePaidIfCash()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('الصافي النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  Text(
                    AppFormatters.currency(_totalAmount),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
              if (_paymentType == SalesPaymentType.credit) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(child: Text('المبلغ المدفوع مقدماً:')),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _paidAmountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('المتبقي (دين على العميل):', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                    ),
                    Text(
                      AppFormatters.currency(_remainingAmount),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // زر حفظ واعتماد البيع
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _completeSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'جارٍ تسجيل العملية وتحديث المخزون...' : 'إتمام البيع (Ctrl+Enter)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
