import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
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

/// شاشة نقطة البيع السريعة وسلة المشتريات (POS Screen)
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
          return matchName || matchCat;
        }).toList();
      }
    });
  }

  void _addToCart(Product product) {
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تنبيه: المنتج "${product.name}" نفد من المخزون تماماً.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final currentQty = _cart[index].quantity;
        if (currentQty + 1 > product.currentStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الكمية في السلة (${currentQty + 1}) تتجاوز الرصيد المتوفر (${product.currentStock})',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
        _cart[index].quantity += 1;
      } else {
        _cart.add(CartItem(product: product, quantity: 1.0, unitPrice: product.salePrice));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تنبيه: الكمية المطلوبة ($newQty) تتجاوز المخزون المتوفر (${item.product.currentStock})',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }

    setState(() {
      item.quantity = newQty;
      _recalculatePaidIfCash();
    });
  }

  void _updateCartItemPrice(int index, int newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _cart[index].unitPrice = newPrice;
      _recalculatePaidIfCash();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة أصناف إلى سلة البيع أولاً')),
      );
      return;
    }

    if (_paymentType == SalesPaymentType.credit && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('البيع الآجل يتطلب تحديد العميل، لا يمكن البيع الآجل لزبون عام'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // التحقق من المخزون لجميع الأصناف في السلة
    for (final item in _cart) {
      if (item.quantity > item.product.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن إتمام البيع: رصيد "${item.product.name}" المتوفر (${item.product.currentStock}) أقل من المطلوب (${item.quantity})',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_discount > _subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مبلغ الخصم لا يمكن أن يتجاوز المجموع الفرعي'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_paidAmount > _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المبلغ المدفوع لا يمكن أن يتجاوز الصافي النهائي للفاتورة'),
          backgroundColor: AppColors.error,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ واعتماد الفاتورة رقم ${savedInvoice.invoiceNumber} بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );

        _clearCart();
        await _loadInitialData(); // تحديث أرصدة المنتجات فورياً
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.point_of_sale, size: 24),
            const SizedBox(width: 8),
            const Text('نقطة البيع السريعة'),
            if (_generatedInvoiceNumber != null) ...[
              const SizedBox(width: 12),
              Chip(
                label: Text(_generatedInvoiceNumber!, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.primaryContainer,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث المنتجات والمخزون',
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
    );
  }

  Widget _buildProductsCatalog() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // شريط البحث في الأصناف
          TextField(
            controller: _searchProductController,
            decoration: InputDecoration(
              hintText: 'ابحث باسم المنتج أو التصنيف...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchProductController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchProductController.clear();
                        _filterProducts('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _filterProducts,
          ),
          const SizedBox(height: 10),

          // شبكة أو قائمة المنتجات
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('لا توجد منتجات مطابقة'))
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
                        elevation: 1,
                        color: isOutOfStock ? Colors.grey.shade100 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isOutOfStock ? Colors.grey.shade300 : AppColors.border,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isOutOfStock ? null : () => _addToCart(product),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
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
                                      'رصيد: ${product.currentStock} ${product.unitSymbol ?? ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                                        fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (isOutOfStock)
                                      const Text(
                                        'نفد',
                                        style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                  decoration: const InputDecoration(
                    labelText: 'العميل',
                    prefixIcon: Icon(Icons.person),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('السلة فارغة، اختر منتجات لإضافتها للبيع', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 10),
                    itemBuilder: (context, index) {
                      final item = _cart[index];

                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'المتاح: ${item.product.currentStock}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // تعديل السعر
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: '${item.unitPrice}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'السعر',
                                contentPadding: EdgeInsets.all(6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                final p = int.tryParse(val) ?? item.unitPrice;
                                _updateCartItemPrice(index, p);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          // أزرار الكمية
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _updateCartItemQuantity(index, item.quantity + 1),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // الإجمالي
                          Text(
                            AppFormatters.currency(item.calculatedTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeFromCart(index),
                          ),
                        ],
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
                  const Text('المجموع الفرعي:'),
                  Text(AppFormatters.currency(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('الصافي النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    AppFormatters.currency(_totalAmount),
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
                    const Text('المتبقي (دين على العميل):', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                    Text(
                      AppFormatters.currency(_remainingAmount),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                _isSaving ? 'جارٍ تسجيل العملية وتحديث المخزون...' : 'حفظ واعتماد الفاتورة',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
