import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
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
    AppDataNotifier.instance.addListener(_onAppDataChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_onAppDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAppDataChanged() {
    final event = AppDataNotifier.instance.lastEvent;
    if (event == null) return;
    if (event.type == AppDataChangeType.inventory ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 0)) {
      if (mounted) {
        _loadProducts(isSilent: true);
      }
    }
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

  int _searchSequence = 0;

  Future<void> _loadProducts({bool isSilent = false}) async {
    final currentSeq = ++_searchSequence;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final products = await _productsRepo.getProducts(
        searchQuery: _searchController.text.trim(),
        categoryId: _selectedCategoryId,
        onlyActive: _onlyActive,
        onlyLowStock: _onlyLowStock,
      );

      final lowCount = await _productsRepo.getLowStockCount();

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _products = products;
          _lowStockCount = lowCount;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted && currentSeq == _searchSequence) {
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
        heroTag: 'products_fab',
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
    // تم استخدام IntrinsicHeight لضمان تمدد البطاقات رأسياً بالتساوي دون تحديد أي ارتفاع ثابت
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // تم استخدام Expanded لتقسيم المساحة المتاحة بالتساوي وبشكل متجاوب تماماً
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
                borderRadius: BorderRadius.circular(12),
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
    // بطاقة مؤشرات متكيفة ديناميكياً بدون أي أبعاد ثابتة، مع مسافة داخلية مريحة 14×12 وحواف 12px
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // مساحة داخلية مريحة
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(25) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12), // حواف دائرية ناعمة
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          // تم إضافة Expanded لمنع تجاوز النصوص على الشاشات الصغيرة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
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
                              setState(() {});
                              _loadProducts(isSilent: true);
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _loadProducts(isSilent: true);
                  },
                  onSubmitted: (_) => _loadProducts(isSilent: true),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'تطبيق البحث',
                icon: const Icon(Icons.search),
                onPressed: () => _loadProducts(isSilent: true),
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

    // تم استبدال الـ Card الثابت بـ AppCard المتجاوب والسلس (Fluid)
    // مسافة داخلية مريحة 16px وحواف ناعمة 14px بدون أي أبعاد ثابتة
    return AppCard(
      padding: const EdgeInsets.all(16), // مسافة داخلية متساوية ومريحة تمنع اختناق المحتوى
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(productId: product.id),
          ),
        );
        _loadProducts();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تم إضافة Expanded لمنع تجاوز النصوص على أي قياس شاشة
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.categoryName ?? 'تصنيف',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
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
              const SizedBox(width: 12),

              // مؤشر حالة المخزون — حاوية متكيفة ديناميكياً بحسب النص والأرقام
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? AppColors.errorContainer
                      : isLow
                          ? AppColors.warningContainer
                          : AppColors.successContainer,
                  borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(height: 2),
                    Text(
                      isOutOfStock
                          ? 'نفد'
                          : isLow
                              ? 'منخفض'
                              : 'متوفر',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock
                            ? AppColors.error
                            : isLow
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // شريط الإجراءات السريعة — أزرار بمساحة ضغط مريحة (>=48px)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('تسوية جرد', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48), // مساحة ضغط لا تقل عن 48px
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'تعديل بيانات المنتج',
                icon: const Icon(Icons.edit_outlined, size: 20),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48), // مساحة ضغط لا تقل عن 48px
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: product.isActive ? 'تعطيل المنتج' : 'تفعيل المنتج',
                icon: Icon(
                  product.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                  size: 20,
                  color: product.isActive ? AppColors.textMuted : AppColors.success,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48), // مساحة ضغط لا تقل عن 48px
                onPressed: () => _toggleProductStatus(product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
