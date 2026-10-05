import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../data/repositories/products_repository_impl.dart';
import '../../data/repositories/units_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/unit_of_measurement.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/repositories/units_repository.dart';
import 'categories_screen.dart';
import 'units_screen.dart';

/// شاشة إضافة أو تعديل منتج
class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final ProductsRepository? productsRepository;
  final CategoriesRepository? categoriesRepository;
  final UnitsRepository? unitsRepository;

  const AddEditProductScreen({
    super.key,
    this.product,
    this.productsRepository,
    this.categoriesRepository,
    this.unitsRepository,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final ProductsRepository _productsRepo;
  late final CategoriesRepository _categoriesRepo;
  late final UnitsRepository _unitsRepo;

  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _initialStockController;
  late final TextEditingController _initialStockNotesController;
  late final TextEditingController _minStockController;
  late final TextEditingController _descController;

  int? _selectedCategoryId;
  int? _selectedUnitId;
  bool _isActive = true;

  List<Category> _categories = [];
  List<UnitOfMeasurement> _units = [];
  bool _isLoadingLookups = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _productsRepo = widget.productsRepository ?? ProductsRepositoryImpl();
    _categoriesRepo = widget.categoriesRepository ?? CategoriesRepositoryImpl();
    _unitsRepo = widget.unitsRepository ?? UnitsRepositoryImpl();

    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _purchasePriceController = TextEditingController(text: p != null ? '${p.purchasePrice}' : '');
    _salePriceController = TextEditingController(text: p != null ? '${p.salePrice}' : '');
    _initialStockController = TextEditingController(text: '0');
    _initialStockNotesController = TextEditingController(text: '');
    _minStockController = TextEditingController(text: p != null ? '${p.minimumStock}' : '5');
    _descController = TextEditingController(text: p?.description ?? '');

    _selectedCategoryId = p?.categoryId;
    _selectedUnitId = p?.unitId;
    _isActive = p?.isActive ?? true;

    _loadLookups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _initialStockController.dispose();
    _initialStockNotesController.dispose();
    _minStockController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      final cats = await _categoriesRepo.getCategories(onlyActive: true);
      final uns = await _unitsRepo.getUnits();

      if (mounted) {
        setState(() {
          _categories = cats;
          _units = uns;
          if (_selectedCategoryId == null && cats.isNotEmpty) {
            _selectedCategoryId = cats.first.id;
          }
          if (_selectedUnitId == null && uns.isNotEmpty) {
            _selectedUnitId = uns.first.id;
          }
          _isLoadingLookups = false;
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isLoadingLookups = false;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      _showSnackbar('يرجى اختيار تصنيف للمنتج');
      return;
    }
    if (_selectedUnitId == null) {
      _showSnackbar('يرجى اختيار وحدة قياس للمنتج');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final purchasePrice = int.tryParse(_purchasePriceController.text.trim()) ?? 0;
    final salePrice = int.tryParse(_salePriceController.text.trim()) ?? 0;
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0.0;

    try {
      final now = DateTime.now();

      if (_isEditing) {
        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          unitId: _selectedUnitId!,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          minimumStock: minStock,
          description: _descController.text.trim(),
          isActive: _isActive,
          updatedAt: now,
        );

        await _productsRepo.updateProduct(updatedProduct);
      } else {
        final initialStock = double.tryParse(_initialStockController.text.trim()) ?? 0.0;
        final newProduct = Product(
          id: 0,
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          unitId: _selectedUnitId!,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          minimumStock: minStock,
          description: _descController.text.trim(),
          isActive: _isActive,
          createdAt: now,
          updatedAt: now,
        );

        await _productsRepo.createProduct(
          newProduct,
          initialStock: initialStock,
          initialStockNotes: _initialStockNotesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد'),
      ),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. الاسم والتصنيف والوحدة
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المعلومات الأساسية',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المنتج *',
                              hintText: 'مثال: طقم كنب مفروشات ملكي 7 مقاعد',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'اسم المنتج حقل إلزامي';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  key: ValueKey('cat_dropdown_$_selectedCategoryId'),
                                  initialValue: _categories.any((c) => c.id == _selectedCategoryId)
                                      ? _selectedCategoryId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'التصنيف *',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: _categories.map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(c.name),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'إضافة تصنيف',
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                                  );
                                  _loadLookups();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  key: ValueKey('unit_dropdown_$_selectedUnitId'),
                                  initialValue: _units.any((u) => u.id == _selectedUnitId)
                                      ? _selectedUnitId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'وحدة القياس *',
                                    prefixIcon: Icon(Icons.straighten_outlined),
                                  ),
                                  items: _units.map((u) {
                                    return DropdownMenuItem<int>(
                                      value: u.id,
                                      child: Text('${u.name} (${u.symbol})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedUnitId = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'إضافة وحدة',
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const UnitsScreen()),
                                  );
                                  _loadLookups();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. الأسعار (بالريال اليمني)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التسعير (الريال اليمني)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _purchasePriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'سعر الشراء *',
                                    suffixText: AppConstants.defaultCurrency,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'سعر الشراء مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _salePriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'سعر البيع *',
                                    suffixText: AppConstants.defaultCurrency,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'سعر البيع مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. المخزون وحد إعادة الطلب
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المخزون وحد الأمان',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          if (_isEditing) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withAlpha(120),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'الرصيد الحالي: ${widget.product!.currentStock} (لا يمكن تعديله مباشرة من هنا، بل عبر شاشة الجرد والتسويات لتوثيق كل حركة مخزنية).',
                                      style: const TextStyle(fontSize: 13, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _initialStockController,
                                    decoration: const InputDecoration(
                                      labelText: 'المخزون الافتتاحي الأولي',
                                      hintText: '0',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return null;
                                      final numVal = double.tryParse(val.trim());
                                      if (numVal == null || numVal < 0) {
                                        return 'قيمة غير صالحة';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _initialStockNotesController,
                                    decoration: const InputDecoration(
                                      labelText: 'ملاحظة المخزون الافتتاحي',
                                      hintText: 'اختياري',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _minStockController,
                            decoration: const InputDecoration(
                              labelText: 'حد إعادة الطلب الأدنى (تنبيه نقص المخزون)',
                              hintText: '5',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'يرجى تحديد الحد الأدنى';
                              final numVal = double.tryParse(val.trim());
                              if (numVal == null || numVal < 0) return 'قيمة غير صالحة';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. الوصف والحالة
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بيانات إضافية',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _descController,
                            decoration: const InputDecoration(
                              labelText: 'وصف المنتج وملاحظاته (اختياري)',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('المنتج نشط ومتاح للعمليات'),
                            subtitle: const Text('عند التعطيل لن يظهر في فواتير البيع ويبقى في السجلات التاريخية'),
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // زر الحفظ
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'تحديث بيانات المنتج' : 'حفظ المنتج'),
                  ),
                ],
              ),
            ),
    );
  }
}
