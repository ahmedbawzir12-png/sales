import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/features/products/data/repositories/categories_repository_impl.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/data/repositories/units_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/repositories/categories_repository.dart';
import 'package:sales/features/products/domain/repositories/products_repository.dart';
import 'package:sales/features/products/domain/repositories/units_repository.dart';
import 'package:sales/features/products/presentation/screens/quick_add_product_dialog.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/purchases/domain/repositories/purchases_repository.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
import 'package:sales/features/suppliers/domain/repositories/suppliers_repository.dart';
import 'package:sales/features/suppliers/presentation/screens/add_edit_supplier_dialog.dart';

/// خيارات البحث والإكمال التلقائي للمنتجات
sealed class _ProductSearchOption {
  const _ProductSearchOption();
}

class _ExistingProductOption extends _ProductSearchOption {
  final Product product;
  const _ExistingProductOption(this.product);
}

class _AddNewProductOption extends _ProductSearchOption {
  final String query;
  const _AddNewProductOption(this.query);
}

/// سطر مسودة صنف في واجهة فاتورة الشراء
class _InvoiceItemDraft {
  Product? product;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;

  _InvoiceItemDraft({
    this.product,
    double initialQuantity = 1.0,
    int? initialCost,
  })  : searchController = TextEditingController(text: product?.name ?? ''),
        searchFocusNode = FocusNode(),
        quantityController = TextEditingController(text: initialQuantity.toString()),
        unitCostController =
            TextEditingController(text: (initialCost ?? product?.purchasePrice ?? 0).toString());

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0.0;
  int get unitCost => int.tryParse(unitCostController.text.trim()) ?? 0;
  int get total => (quantity * unitCost).round();

  void setProduct(Product? newProduct) {
    product = newProduct;
    searchController.text = newProduct?.name ?? '';
    if (newProduct != null) {
      unitCostController.text = newProduct.purchasePrice.toString();
    }
  }

  void clearProduct() {
    product = null;
    searchController.clear();
    unitCostController.text = '0';
  }

  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    quantityController.dispose();
    unitCostController.dispose();
  }
}

/// شاشة إنشاء فاتورة شراء جديدة
class NewPurchaseInvoiceScreen extends StatefulWidget {
  final PurchasesRepository purchasesRepository;
  final SuppliersRepository suppliersRepository;
  final ProductsRepository productsRepository;
  final CategoriesRepository categoriesRepository;
  final UnitsRepository unitsRepository;

  NewPurchaseInvoiceScreen({
    super.key,
    required this.purchasesRepository,
    SuppliersRepository? suppliersRepository,
    ProductsRepository? productsRepository,
    CategoriesRepository? categoriesRepository,
    UnitsRepository? unitsRepository,
  })  : suppliersRepository = suppliersRepository ?? SuppliersRepositoryImpl(),
        productsRepository = productsRepository ?? ProductsRepositoryImpl(),
        categoriesRepository = categoriesRepository ?? CategoriesRepositoryImpl(),
        unitsRepository = unitsRepository ?? UnitsRepositoryImpl();

  @override
  State<NewPurchaseInvoiceScreen> createState() => _NewPurchaseInvoiceScreenState();
}

class _NewPurchaseInvoiceScreenState extends State<NewPurchaseInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  String _invoiceNumber = '';
  DateTime _invoiceDate = DateTime.now();
  Supplier? _selectedSupplier;
  PurchasePaymentType _paymentType = PurchasePaymentType.cash;

  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  final List<_InvoiceItemDraft> _itemDrafts = [];
  List<Supplier> _availableSuppliers = [];
  List<Product> _availableProducts = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    for (final item in _itemDrafts) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final invoiceNum = await widget.purchasesRepository.generateNextInvoiceNumber();
      final suppliers = await widget.suppliersRepository.getSuppliers(onlyActive: true);
      final products = await widget.productsRepository.getProducts(onlyActive: true);

      if (mounted) {
        setState(() {
          _invoiceNumber = invoiceNum;
          _availableSuppliers = suppliers;
          _availableProducts = products;
          if (_itemDrafts.isEmpty) {
            _addNewItemRow();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل بيانات التهيئة لفاتورة الشراء';
          _isLoading = false;
        });
      }
    }
  }

  void _addNewItemRow([Product? initialProduct]) {
    final draft = _InvoiceItemDraft(
      product: initialProduct,
      initialQuantity: 1.0,
      initialCost: initialProduct?.purchasePrice,
    );
    setState(() {
      _itemDrafts.add(draft);
      _recalculatePaidIfCash();
    });
  }

  void _removeItemRow(int index) {
    if (_itemDrafts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن تحتوي الفاتورة على صنف واحد على الأقل')),
      );
      return;
    }
    setState(() {
      final removed = _itemDrafts.removeAt(index);
      removed.dispose();
      _recalculatePaidIfCash();
    });
  }

  int get _subtotal {
    return _itemDrafts.fold<int>(0, (sum, item) => sum + item.total);
  }

  int get _discount {
    return int.tryParse(_discountController.text.trim()) ?? 0;
  }

  int get _total {
    final sub = _subtotal;
    final disc = _discount;
    return disc > sub ? 0 : sub - disc;
  }

  int get _paidAmount {
    return int.tryParse(_paidAmountController.text.trim()) ?? 0;
  }

  int get _remainingAmount {
    final tot = _total;
    final paid = _paidAmount;
    return paid > tot ? 0 : tot - paid;
  }

  void _recalculatePaidIfCash() {
    if (_paymentType == PurchasePaymentType.cash) {
      _paidAmountController.text = _total.toString();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
  }

  Future<void> _quickAddSupplier() async {
    final created = await AddEditSupplierDialog.show(
      context,
      repository: widget.suppliersRepository,
    );
    if (created != null) {
      final suppliers = await widget.suppliersRepository.getSuppliers(onlyActive: true);
      setState(() {
        _availableSuppliers = suppliers;
        _selectedSupplier = created;
      });
    }
  }

  Future<void> _openQuickAddProduct({
    required _InvoiceItemDraft draft,
    String? initialName,
  }) async {
    final createdProduct = await QuickAddProductDialog.show(
      context,
      initialName: initialName?.trim(),
      initialPurchasePrice: draft.unitCost > 0 ? draft.unitCost : null,
      productsRepository: widget.productsRepository,
      categoriesRepository: widget.categoriesRepository,
      unitsRepository: widget.unitsRepository,
    );

    if (createdProduct != null && mounted) {
      setState(() {
        final existingIdx = _availableProducts.indexWhere((p) => p.id == createdProduct.id);
        if (existingIdx >= 0) {
          _availableProducts[existingIdx] = createdProduct;
        } else {
          _availableProducts.insert(0, createdProduct);
        }
        draft.setProduct(createdProduct);
        _recalculatePaidIfCash();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة المنتج "${createdProduct.name}" بنجاح وتحديده في الفاتورة'),
          backgroundColor: Colors.teal.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplier == null) {
      setState(() => _errorMessage = 'يرجى اختيار المورد');
      return;
    }

    if (_itemDrafts.isEmpty) {
      setState(() => _errorMessage = 'يرجى إضافة صنف واحد على الأقل للفاتورة');
      return;
    }

    for (final item in _itemDrafts) {
      // إذا كان المنتج فارغاً ولكن المستخدم كتب اسماً يطابق منتجاً موجوداً تماماً
      if (item.product == null && item.searchController.text.trim().isNotEmpty) {
        final typedLower = item.searchController.text.trim().toLowerCase();
        final exactMatch = _availableProducts.where(
          (p) => p.name.trim().toLowerCase() == typedLower,
        );
        if (exactMatch.isNotEmpty) {
          item.setProduct(exactMatch.first);
        }
      }

      if (item.product == null) {
        final typedName = item.searchController.text.trim();
        if (typedName.isNotEmpty) {
          setState(() => _errorMessage =
              'المنتج "$typedName" غير مسجل في النظام. اضغط على زر ➕ لإضافته كمنتج جديد أولاً.');
        } else {
          setState(() => _errorMessage = 'يرجى اختيار وتحديد المنتج لكافة أسطر الفاتورة');
        }
        return;
      }
      if (item.quantity <= 0) {
        setState(() => _errorMessage = 'كمية الصنف "${item.product!.name}" يجب أن تكون أكبر من الصفر');
        return;
      }
      if (item.unitCost < 0) {
        setState(() => _errorMessage = 'سعر شراء الصنف "${item.product!.name}" لا يمكن أن يكون سالباً');
        return;
      }
    }

    final subtotal = _subtotal;
    final discount = _discount;
    if (discount > subtotal) {
      setState(() => _errorMessage = 'قيمة الخصم لا يمكن أن تتجاوز مجموع الفاتورة');
      return;
    }

    final total = _total;
    final paid = _paidAmount;
    if (paid > total) {
      setState(() => _errorMessage = 'المبلغ المدفوع لا يمكن أن يتجاوز صافي الفاتورة');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final invoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: _invoiceNumber,
        supplierId: _selectedSupplier!.id,
        invoiceDate: _invoiceDate,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paidAmount: paid,
        remainingAmount: total - paid,
        paymentType: _paymentType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = _itemDrafts.map((d) {
        return PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: d.product!.id,
          quantity: d.quantity,
          unitCost: d.unitCost,
          total: d.total,
        );
      }).toList();

      final savedInvoice = await widget.purchasesRepository.createPurchaseInvoice(
        invoice: invoice,
        items: items,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ فاتورة الشراء (${savedInvoice.invoiceNumber}) بنجاح وتحديث المخزون'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(savedInvoice);
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع أثناء حفظ فاتورة الشراء: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة شراء جديدة'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
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
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. رأس الفاتورة (رقم الفاتورة، التاريخ، المورد)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _invoiceNumber,
                              decoration: const InputDecoration(
                                labelText: 'رقم الفاتورة *',
                                prefixIcon: Icon(Icons.tag),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => _invoiceNumber = val.trim(),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'رقم الفاتورة مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'تاريخ الفاتورة',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(AppFormatters.date(_invoiceDate)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('supplier_sel_${_selectedSupplier?.id}'),
                              initialValue: _availableSuppliers.any((s) => s.id == _selectedSupplier?.id)
                                  ? _selectedSupplier?.id
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'المورد *',
                                prefixIcon: Icon(Icons.business),
                                border: OutlineInputBorder(),
                              ),
                              items: _availableSuppliers.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text('${s.name} ${s.phone != null ? "(${s.phone})" : ""}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedSupplier = val == null
                                      ? null
                                      : _availableSuppliers.firstWhere((s) => s.id == val);
                                });
                              },
                              validator: (val) => val == null ? 'يرجى اختيار المورد' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.person_add_alt_1),
                            tooltip: 'إضافة مورد سريع',
                            onPressed: _quickAddSupplier,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. جدول أصناف الفاتورة
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'أصناف ومشتريات الفاتورة',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton.icon(
                            onPressed: _addNewItemRow,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة صنف'),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (_itemDrafts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: Text('لا توجد أصناف في الفاتورة')),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _itemDrafts.length,
                          separatorBuilder: (context, index) => const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final draft = _itemDrafts[index];
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    // اختيار المنتج (البحث والإكمال التلقائي مع خيار الإضافة السريعة)
                                    Expanded(
                                      flex: 3,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return RawAutocomplete<_ProductSearchOption>(
                                            textEditingController: draft.searchController,
                                            focusNode: draft.searchFocusNode,
                                            optionsBuilder: (TextEditingValue textEditingValue) {
                                              final query = textEditingValue.text.trim();
                                              final matches = _availableProducts.where((p) {
                                                if (query.isEmpty) return true;
                                                final q = query.toLowerCase();
                                                return p.name.toLowerCase().contains(q) ||
                                                    (p.categoryName != null &&
                                                        p.categoryName!.toLowerCase().contains(q));
                                              }).toList();

                                              final List<_ProductSearchOption> options = matches
                                                  .map<_ProductSearchOption>((p) => _ExistingProductOption(p))
                                                  .toList();

                                              final hasExactMatch = _availableProducts.any(
                                                (p) => p.name.trim().toLowerCase() == query.toLowerCase(),
                                              );

                                              if (query.isNotEmpty && !hasExactMatch) {
                                                options.insert(0, _AddNewProductOption(query));
                                              } else if (query.isEmpty) {
                                                options.add(const _AddNewProductOption(''));
                                              }

                                              return options;
                                            },
                                            displayStringForOption: (option) {
                                              if (option is _ExistingProductOption) {
                                                return option.product.name;
                                              }
                                              return '';
                                            },
                                            onSelected: (_ProductSearchOption option) {
                                              if (option is _ExistingProductOption) {
                                                setState(() {
                                                  draft.setProduct(option.product);
                                                  _recalculatePaidIfCash();
                                                });
                                              } else if (option is _AddNewProductOption) {
                                                _openQuickAddProduct(
                                                  draft: draft,
                                                  initialName: option.query,
                                                );
                                              }
                                            },
                                            fieldViewBuilder:
                                                (context, controller, focusNode, onFieldSubmitted) {
                                              return TextFormField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  labelText: 'المنتج #${index + 1} *',
                                                  hintText: 'ابحث أو اكتب اسم صنف...',
                                                  border: const OutlineInputBorder(),
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                                  prefixIcon: const Icon(Icons.search, size: 20),
                                                  suffixIcon: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (controller.text.isNotEmpty)
                                                        IconButton(
                                                          icon: const Icon(Icons.clear, size: 18),
                                                          tooltip: 'مسح',
                                                          onPressed: () {
                                                            setState(() {
                                                              draft.clearProduct();
                                                              _recalculatePaidIfCash();
                                                            });
                                                          },
                                                        ),
                                                      IconButton(
                                                        icon: const Icon(Icons.add_circle,
                                                            color: Colors.teal, size: 22),
                                                        tooltip: 'إضافة منتج جديد للتعريف السريع',
                                                        onPressed: () => _openQuickAddProduct(
                                                          draft: draft,
                                                          initialName: controller.text.trim(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                validator: (val) {
                                                  if (draft.product == null) {
                                                    return 'يرجى تحديد أو إضافة المنتج';
                                                  }
                                                  return null;
                                                },
                                              );
                                            },
                                            optionsViewBuilder: (context, onSelected, options) {
                                              return Align(
                                                alignment: AlignmentDirectional.topStart,
                                                child: Material(
                                                  elevation: 4.0,
                                                  color: Theme.of(context).colorScheme.surface,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: 280,
                                                      maxWidth: constraints.maxWidth,
                                                    ),
                                                    child: ListView.separated(
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      shrinkWrap: true,
                                                      itemCount: options.length,
                                                      separatorBuilder: (context, _) =>
                                                          const Divider(height: 1),
                                                      itemBuilder: (context, optIndex) {
                                                        final option = options.elementAt(optIndex);
                                                        if (option is _AddNewProductOption) {
                                                          final label = option.query.isEmpty
                                                              ? 'إضافة منتج جديد'
                                                              : 'إضافة "${option.query}" كمنتج جديد';
                                                          return ListTile(
                                                            dense: true,
                                                            tileColor: Theme.of(context)
                                                                .colorScheme
                                                                .primaryContainer
                                                                .withValues(alpha: 0.35),
                                                            leading: Icon(
                                                              Icons.add_circle,
                                                              color: Theme.of(context).colorScheme.primary,
                                                            ),
                                                            title: Text(
                                                              '➕ $label',
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.primary,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                            subtitle: const Text(
                                                              'تعريف سريع في دليل المنتجات برصيد 0',
                                                              style: TextStyle(fontSize: 11),
                                                            ),
                                                            onTap: () => onSelected(option),
                                                          );
                                                        }

                                                        final productOption =
                                                            option as _ExistingProductOption;
                                                        final p = productOption.product;
                                                        final isSelected = draft.product?.id == p.id;

                                                        return ListTile(
                                                          dense: true,
                                                          selected: isSelected,
                                                          leading: Icon(
                                                            Icons.inventory_2_outlined,
                                                            size: 20,
                                                            color: isSelected
                                                                ? Theme.of(context).colorScheme.primary
                                                                : Colors.grey.shade600,
                                                          ),
                                                          title: Text(
                                                            p.name,
                                                            style: TextStyle(
                                                              fontWeight: isSelected
                                                                  ? FontWeight.bold
                                                                  : FontWeight.normal,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            'التصنيف: ${p.categoryName ?? "عام"} | الرصيد: ${p.currentStock} ${p.unitSymbol ?? ""}',
                                                            style: const TextStyle(fontSize: 11),
                                                          ),
                                                          trailing: Text(
                                                            '${p.purchasePrice} ر.ي',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.blue.shade800,
                                                            ),
                                                          ),
                                                          onTap: () => onSelected(option),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // الكمية
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: draft.quantityController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'الكمية (${draft.product?.unitSymbol ?? "وحدة"})',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onChanged: (_) => setState(_recalculatePaidIfCash),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // سعر الشراء
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: draft.unitCostController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'تكلفة الوحدة',
                                          border: OutlineInputBorder(),
                                          contentPadding:
                                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onChanged: (_) => setState(_recalculatePaidIfCash),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // زر الحذف
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _removeItemRow(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'إجمالي السطر: ${AppFormatters.currency(draft.total)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. بطاقة الحسابات والدفع
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'الملخص المالي وطريقة الدفع',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الفرعي (Subtotal):', style: TextStyle(fontSize: 15)),
                          Text(
                            AppFormatters.currency(_subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('خصم الفاتورة (Discount):', style: TextStyle(fontSize: 15)),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: _discountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                suffixText: 'ر.ي',
                              ),
                              onChanged: (_) => setState(_recalculatePaidIfCash),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'صافي الفاتورة (Total):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            AppFormatters.currency(_total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // نوع الدفع (نقدي / آجل)
                      Row(
                        children: [
                          const Text('نوع الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          SegmentedButton<PurchasePaymentType>(
                            segments: [
                              ButtonSegment(
                                value: PurchasePaymentType.cash,
                                label: Text(PurchasePaymentType.cash.arabicLabel),
                                icon: const Icon(Icons.money),
                              ),
                              ButtonSegment(
                                value: PurchasePaymentType.credit,
                                label: Text(PurchasePaymentType.credit.arabicLabel),
                                icon: const Icon(Icons.credit_card),
                              ),
                            ],
                            selected: {_paymentType},
                            onSelectionChanged: (set) {
                              setState(() {
                                _paymentType = set.first;
                                if (_paymentType == PurchasePaymentType.cash) {
                                  _paidAmountController.text = _total.toString();
                                } else {
                                  _paidAmountController.text = '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // المبلغ المدفوع
                      Row(
                        children: [
                          const Expanded(
                            child: Text('المبلغ المدفوع حالياً (Paid):',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: _paidAmountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                suffixText: 'ر.ي',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _paidAmountController.text = _total.toString();
                              });
                            },
                            child: const Text('كامل المبلغ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // المتبقي (دين على المحل للمورد)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _remainingAmount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _remainingAmount > 0
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _remainingAmount > 0
                                  ? 'المتبقي (دين مستحق للمورد):'
                                  : 'حالة السداد:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _remainingAmount > 0
                                    ? Colors.orange.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                            Text(
                              _remainingAmount > 0
                                  ? AppFormatters.currency(_remainingAmount)
                                  : 'مدفوعة بالكامل ✓',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _remainingAmount > 0
                                    ? Colors.orange.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الفاتورة (اختياري)',
                          hintText: 'رقم الفاتورة الورقية للمورد أو شروط الشحن والتسليم...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. زر الحفظ النهائي
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle, size: 24),
                  label: Text(
                    _isSaving ? 'جارٍ حفظ الفاتورة وتحديث المخزون...' : 'حفظ الفاتورة واعتماد المخزون',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
