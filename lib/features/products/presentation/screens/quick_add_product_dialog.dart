import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../data/repositories/products_repository_impl.dart';
import '../../data/repositories/units_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/unit_of_measurement.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/repositories/units_repository.dart';

/// نافذة الإضافة السريعة لمنتج جديد أثناء إنشاء فاتورة الشراء أو العمليات المباشرة
class QuickAddProductDialog extends StatefulWidget {
  final String? initialName;
  final int? initialPurchasePrice;
  final ProductsRepository productsRepository;
  final CategoriesRepository categoriesRepository;
  final UnitsRepository unitsRepository;

  QuickAddProductDialog({
    super.key,
    this.initialName,
    this.initialPurchasePrice,
    ProductsRepository? productsRepository,
    CategoriesRepository? categoriesRepository,
    UnitsRepository? unitsRepository,
  })  : productsRepository = productsRepository ?? ProductsRepositoryImpl(),
        categoriesRepository = categoriesRepository ?? CategoriesRepositoryImpl(),
        unitsRepository = unitsRepository ?? UnitsRepositoryImpl();

  /// عرض النافذة المنبثقة وإرجاع المنتج الجديد بعد حفظه في قاعدة البيانات
  static Future<Product?> show(
    BuildContext context, {
    String? initialName,
    int? initialPurchasePrice,
    ProductsRepository? productsRepository,
    CategoriesRepository? categoriesRepository,
    UnitsRepository? unitsRepository,
  }) {
    return showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuickAddProductDialog(
        initialName: initialName,
        initialPurchasePrice: initialPurchasePrice,
        productsRepository: productsRepository,
        categoriesRepository: categoriesRepository,
        unitsRepository: unitsRepository,
      ),
    );
  }

  @override
  State<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<QuickAddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _minStockController;

  int? _selectedCategoryId;
  int? _selectedUnitId;

  List<Category> _categories = [];
  List<UnitOfMeasurement> _units = [];
  bool _isLoadingLookups = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName?.trim() ?? '');
    _purchasePriceController = TextEditingController(
      text: (widget.initialPurchasePrice != null && widget.initialPurchasePrice! > 0)
          ? widget.initialPurchasePrice.toString()
          : '0',
    );
    _salePriceController = TextEditingController(
      text: (widget.initialPurchasePrice != null && widget.initialPurchasePrice! > 0)
          ? widget.initialPurchasePrice.toString()
          : '0',
    );
    _minStockController = TextEditingController(text: '5');

    _loadLookups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      final cats = await widget.categoriesRepository.getCategories(onlyActive: true);
      final uns = await widget.unitsRepository.getUnits();

      if (mounted) {
        setState(() {
          _categories = cats;
          _units = uns;
          if (cats.isNotEmpty) {
            _selectedCategoryId = cats.first.id;
          }
          if (uns.isNotEmpty) {
            _selectedUnitId = uns.first.id;
          }
          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل قائمة التصنيفات أو وحدات القياس';
          _isLoadingLookups = false;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId! <= 0) {
      setState(() => _errorMessage = 'يرجى اختيار تصنيف صالح للمنتج');
      return;
    }

    if (_selectedUnitId == null || _selectedUnitId! <= 0) {
      setState(() => _errorMessage = 'يرجى اختيار وحدة قياس صالحة للمنتج');
      return;
    }

    final purchasePrice = int.tryParse(_purchasePriceController.text.trim()) ?? 0;
    final salePrice = int.tryParse(_salePriceController.text.trim()) ?? purchasePrice;
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0.0;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final selectedCategory = _categories.any((c) => c.id == _selectedCategoryId)
          ? _categories.firstWhere((c) => c.id == _selectedCategoryId)
          : null;
      final selectedUnit = _units.any((u) => u.id == _selectedUnitId)
          ? _units.firstWhere((u) => u.id == _selectedUnitId)
          : null;

      final product = Product(
        id: 0,
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        categoryName: selectedCategory?.name,
        unitId: _selectedUnitId!,
        unitSymbol: selectedUnit?.symbol,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        currentStock: 0.0,
        minimumStock: minStock,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // حفظ المنتج في جدول المنتجات كـ "سجل جديد" مع رصيد افتتاحي 0
      // الكمية سيتم توريدها عبر بنود فاتورة الشراء كحركة مشتريات رسمية
      final createdProduct = await widget.productsRepository.createProduct(
        product,
        initialStock: 0.0,
      );

      if (mounted) {
        Navigator.of(context).pop(createdProduct);
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع أثناء حفظ المنتج الجديد';
          _isSaving = false;
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
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_shopping_cart,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'تعريف منتج جديد سريعاً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      // تم استبدال العرض الثابت بـ ConstrainedBox لضمان التجاوب والتكيف المرن
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          minWidth: 280,
        ),
        child: _isLoadingLookups
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // رسالة تنبيهية / توضيحية لآلية العمل
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'سيتم إضافة هذا المنتج لدليل المنتجات برصيد 0، وستُسجل كميته المشتراة تلقائياً في المخزون فور حفظ الفاتورة.',
                                style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
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
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. اسم المنتج
                      TextFormField(
                        controller: _nameController,
                        autofocus: widget.initialName == null || widget.initialName!.trim().isEmpty,
                        decoration: const InputDecoration(
                          labelText: 'اسم المنتج *',
                          hintText: 'مثال: طقم كنب مفروشات ملكي 7 مقاعد',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال اسم المنتج';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 2. التصنيف ووحدة القياس في صف واحد
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('cat_sel_$_selectedCategoryId'),
                              initialValue: _selectedCategoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'التصنيف *',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (id) => setState(() => _selectedCategoryId = id),
                              validator: (val) => val == null ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('unit_sel_$_selectedUnitId'),
                              initialValue: _selectedUnitId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'وحدة القياس *',
                                prefixIcon: Icon(Icons.straighten_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _units.map((u) {
                                return DropdownMenuItem<int>(
                                  value: u.id,
                                  child: Text('${u.name} (${u.symbol})', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (id) => setState(() => _selectedUnitId = id),
                              validator: (val) => val == null ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. أسعار الشراء والبيع
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'سعر الشراء (ر.ي)',
                                hintText: '0',
                                prefixIcon: Icon(Icons.shopping_bag_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final num = int.tryParse(val.trim());
                                  if (num == null || num < 0) return 'قيمة غير صالحة';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _salePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'سعر البيع المقترح (ر.ي)',
                                hintText: '0',
                                prefixIcon: Icon(Icons.sell_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final num = int.tryParse(val.trim());
                                  if (num == null || num < 0) return 'قيمة غير صالحة';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4. الحد الأدنى للتنبيه
                      TextFormField(
                        controller: _minStockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'الحد الأدنى للمخزون (تنبيه النواقص)',
                          hintText: '5',
                          prefixIcon: Icon(Icons.notification_important_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final num = double.tryParse(val.trim());
                            if (num == null || num < 0) return 'قيمة غير صالحة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: (_isSaving || _isLoadingLookups) ? null : _saveProduct,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ وإدراج في الفاتورة'),
        ),
      ],
    );
  }
}
