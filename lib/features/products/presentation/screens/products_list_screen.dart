import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../data/repositories/products_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/repositories/products_repository.dart';
import 'add_edit_product_screen.dart';
import 'product_details_screen.dart';
import 'stock_inventory_screen.dart';

/// الشاشة الرئيسية للمنتجات والمخزون
class ProductsListScreen extends StatefulWidget {
  final ProductsRepository? productsRepository;
  final CategoriesRepository? categoriesRepository;

  const ProductsListScreen({
    super.key,
    this.productsRepository,
    this.categoriesRepository,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  late final ProductsRepository _productsRepo;
  late final CategoriesRepository _categoriesRepo;

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _onlyActive = true;
  bool _onlyLowStock = false;

  bool _isLoading = true;
  String? _errorMessage;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _productsRepo = widget.productsRepository ?? ProductsRepositoryImpl();
    _categoriesRepo = widget.categoriesRepository ?? CategoriesRepositoryImpl();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final cats = await _categoriesRepo.getCategories(onlyActive: true);
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (_) {}

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _productsRepo.getProducts(
        searchQuery: _searchController.text.trim(),
        categoryId: _selectedCategoryId,
        onlyActive: _onlyActive,
        onlyLowStock: _onlyLowStock,
      );

      final lowCount = await _productsRepo.getLowStockCount();

      if (mounted) {
        setState(() {
          _products = products;
          _lowStockCount = lowCount;
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

  Future<void> _toggleProductStatus(Product product) async {
    try {
      await _productsRepo.setProductActive(product.id, !product.isActive);
      _loadProducts();
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.userFriendlyMessage), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل المنتجات والمخزون'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
          );
          if (result == true) {
            _loadProducts();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج جديد'),
      ),
      body: Column(
        children: [
          // شريط المؤشرات السريعة والبحث
          _buildTopSummaryBar(),
          _buildSearchAndFilterSection(),

          // قائمة المنتجات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textDisabled),
                                const SizedBox(height: 12),
                                const Text(
                                  'لم يتم العثور على أي منتجات مطابقة للبحث أو التصفية',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                if (_searchController.text.isNotEmpty ||
                                    _selectedCategoryId != null ||
                                    _onlyLowStock)
                                  OutlinedButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _selectedCategoryId = null;
                                        _onlyLowStock = false;
                                        _onlyActive = true;
                                      });
                                      _loadProducts();
                                    },
                                    child: const Text('إلغاء التصفية'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _products.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildProductCard(_products[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryPill(
              label: 'إجمالي الأصناف',
              value: '${_products.length}',
              color: AppColors.primary,
              icon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _onlyLowStock = !_onlyLowStock);
                _loadProducts();
              },
              borderRadius: BorderRadius.circular(8),
              child: _buildSummaryPill(
                label: 'نواقص المخزون',
                value: '$_lowStockCount',
                color: _lowStockCount > 0 ? AppColors.warning : AppColors.success,
                icon: Icons.warning_amber_rounded,
                isSelected: _onlyLowStock,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(40) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المنتج...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadProducts();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _loadProducts(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'تطبيق البحث',
                icon: const Icon(Icons.arrow_forward),
                onPressed: _loadProducts,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('كل التصنيفات'),
                  selected: _selectedCategoryId == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategoryId = null);
                      _loadProducts();
                    }
                  },
                ),
                const SizedBox(width: 6),
                ..._categories.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: _selectedCategoryId == c.id,
                      onSelected: (selected) {
                        setState(() => _selectedCategoryId = selected ? c.id : null);
                        _loadProducts();
                      },
                    ),
                  );
                }),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Text(_onlyActive ? 'النشطة فقط' : 'الكل (مع المعطل)'),
                  selected: !_onlyActive,
                  onSelected: (selected) {
                    setState(() => _onlyActive = !selected);
                    _loadProducts();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLow = product.isLowStock;
    final isOutOfStock = product.currentStock <= 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(productId: product.id),
            ),
          );
          _loadProducts();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: product.isActive ? AppColors.textPrimary : AppColors.textMuted,
                            decoration: product.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.categoryName ?? 'تصنيف',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'سعر البيع: ${AppFormatters.currency(product.salePrice, currency: AppConstants.defaultCurrency)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // مؤشر حالة المخزون
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.errorContainer
                          : isLow
                              ? AppColors.warningContainer
                              : AppColors.successContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.currentStock} ${product.unitSymbol ?? ""}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOutOfStock
                                ? AppColors.error
                                : isLow
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                        if (isOutOfStock)
                          const Text('نفد', style: TextStyle(fontSize: 10, color: AppColors.error))
                        else if (isLow)
                          const Text('منخفض', style: TextStyle(fontSize: 10, color: AppColors.warning))
                        else
                          const Text('متوفر', style: TextStyle(fontSize: 10, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // شريط الإجراءات السريعة
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.tune_outlined, size: 16),
                    label: const Text('تسوية جرد', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StockInventoryScreen(initialProductId: product.id),
                        ),
                      );
                      if (result == true) {
                        _loadProducts();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'تعديل بيانات المنتج',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddEditProductScreen(product: product),
                        ),
                      );
                      if (result == true) {
                        _loadProducts();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: product.isActive ? 'تعطيل المنتج' : 'تفعيل المنتج',
                    icon: Icon(
                      product.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                      size: 18,
                      color: product.isActive ? AppColors.textMuted : AppColors.success,
                    ),
                    onPressed: () => _toggleProductStatus(product),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
