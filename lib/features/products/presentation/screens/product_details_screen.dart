import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import '../../data/repositories/products_repository_impl.dart';
import '../../data/repositories/stock_movements_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/repositories/stock_movements_repository.dart';
import 'add_edit_product_screen.dart';
import 'stock_inventory_screen.dart';

/// شاشة تفاصيل المنتج وسجل حركات المخزون التاريخية
class ProductDetailsScreen extends StatefulWidget {
  final int productId;
  final ProductsRepository? productsRepository;
  final StockMovementsRepository? movementsRepository;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.productsRepository,
    this.movementsRepository,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late final ProductsRepository _productsRepo;
  late final StockMovementsRepository _movementsRepo;

  Product? _product;
  List<StockMovement> _movements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _productsRepo = widget.productsRepository ?? ProductsRepositoryImpl();
    _movementsRepo = widget.movementsRepository ?? StockMovementsRepositoryImpl();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await _productsRepo.getProductById(widget.productId);
      final m = await _movementsRepo.getMovementsByProductId(widget.productId);

      if (mounted) {
        setState(() {
          _product = p;
          _movements = m;
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

  Future<void> _toggleProductStatus() async {
    if (_product == null) return;
    try {
      await _productsRepo.setProductActive(_product!.id, !_product!.isActive);
      _loadProductDetails();
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
    final product = _product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? 'تفاصيل المنتج'),
        actions: [
          if (product != null) ...[
            IconButton(
              tooltip: 'تعديل بيانات المنتج',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditProductScreen(product: product),
                  ),
                );
                if (result == true) {
                  _loadProductDetails();
                }
              },
            ),
            IconButton(
              tooltip: product.isActive ? 'تعطيل المنتج' : 'تفعيل المنتج',
              icon: Icon(
                product.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                color: product.isActive ? AppColors.warning : AppColors.success,
              ),
              onPressed: _toggleProductStatus,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadProductDetails,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : product == null
                  ? const Center(child: Text('المنتج غير موجود'))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // بطاقة الرأس والتعريف
                        _buildHeaderCard(product),
                        const SizedBox(height: 16),

                        // بطاقة مؤشرات المخزون
                        _buildStockCard(product),
                        const SizedBox(height: 16),

                        // بطاقة الأسعار
                        _buildPricingCard(product),
                        const SizedBox(height: 24),

                        // سجل حركة المخزون
                        _buildMovementsHeader(),
                        const SizedBox(height: 12),
                        _buildMovementsList(),
                      ],
                    ),
    );
  }

  Widget _buildHeaderCard(Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.isActive ? AppColors.successContainer : AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.isActive ? 'نشط' : 'معطل',
                    style: TextStyle(
                      color: product.isActive ? AppColors.success : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  product.categoryName ?? 'تصنيف غير محدد',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.straighten_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'وحدة القياس: ${product.unitSymbol ?? ""}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            if (product.description != null && product.description!.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                product.description!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(Product product) {
    final isLow = product.isLowStock;
    final isOutOfStock = product.currentStock <= 0;

    final Color statusColor;
    final String statusLabel;

    if (isOutOfStock) {
      statusColor = AppColors.error;
      statusLabel = 'نفد المخزون';
    } else if (isLow) {
      statusColor = AppColors.warning;
      statusLabel = 'مخزون منخفض';
    } else {
      statusColor = AppColors.success;
      statusLabel = 'متوفر بكمية جيدة';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'حالة المخزون',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'الرصيد الفعلي الحالي',
                  '${product.currentStock} ${product.unitSymbol ?? ""}',
                  statusColor,
                ),
                Container(height: 35, width: 1, color: AppColors.divider),
                _buildStatColumn(
                  'حد إعادة الطلب الأدنى',
                  '${product.minimumStock} ${product.unitSymbol ?? ""}',
                  AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune_outlined),
                label: const Text('إجراء تسوية جردية لهذا المنتج'),
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StockInventoryScreen(initialProductId: product.id),
                    ),
                  );
                  if (result == true) {
                    _loadProductDetails();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(Product product) {
    final margin = product.salePrice - product.purchasePrice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات التسعير',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'سعر الشراء',
                  AppFormatters.currency(product.purchasePrice, currency: AppConstants.defaultCurrency),
                  AppColors.textPrimary,
                ),
                Container(height: 35, width: 1, color: AppColors.divider),
                _buildStatColumn(
                  'سعر البيع',
                  AppFormatters.currency(product.salePrice, currency: AppConstants.defaultCurrency),
                  AppColors.primary,
                ),
                Container(height: 35, width: 1, color: AppColors.divider),
                _buildStatColumn(
                  'هامش الربح المتوقع',
                  AppFormatters.currency(margin, currency: AppConstants.defaultCurrency),
                  margin >= 0 ? AppColors.success : AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildMovementsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.history_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'سجل حركات المخزون التاريخية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_movements.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovementsList() {
    if (_movements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لا توجد حركات مسجلة لهذا المنتج حتى الآن',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _movements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _movements[index];
        final isAdd = m.movementType.isAddition;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isAdd ? AppColors.successContainer : AppColors.errorContainer,
                  child: Icon(
                    isAdd ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isAdd ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.movementType.arabicLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${isAdd ? "+" : "-"}${m.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isAdd ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرصيد: من ${m.stockBefore} إلى ${m.stockAfter}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (m.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'السبب: ${m.reason}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                      if (m.notes != null && m.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ملاحظات: ${m.notes!}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.dateTime(m.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
