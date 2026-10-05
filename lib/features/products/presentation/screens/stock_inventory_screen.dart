import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../data/repositories/products_repository_impl.dart';
import '../../data/repositories/stock_movements_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/repositories/stock_movements_repository.dart';

/// شاشة جرد وتسويات المخزون السريعة
class StockInventoryScreen extends StatefulWidget {
  final int? initialProductId;
  final ProductsRepository? productsRepository;
  final StockMovementsRepository? movementsRepository;

  const StockInventoryScreen({
    super.key,
    this.initialProductId,
    this.productsRepository,
    this.movementsRepository,
  });

  @override
  State<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends State<StockInventoryScreen> {
  late final ProductsRepository _productsRepo;
  late final StockMovementsRepository _movementsRepo;

  List<Product> _products = [];
  Product? _selectedProduct;

  late final TextEditingController _actualStockController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _productsRepo = widget.productsRepository ?? ProductsRepositoryImpl();
    _movementsRepo = widget.movementsRepository ?? StockMovementsRepositoryImpl();

    _actualStockController = TextEditingController();
    _reasonController = TextEditingController(text: 'تسوية جرد دوري للمخزون');
    _notesController = TextEditingController();

    _loadProducts();
  }

  @override
  void dispose() {
    _actualStockController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _productsRepo.getProducts(onlyActive: true);
      if (mounted) {
        setState(() {
          _products = list;
          if (widget.initialProductId != null) {
            _selectedProduct = list.firstWhere(
              (p) => p.id == widget.initialProductId,
              orElse: () => list.isNotEmpty ? list.first : throw Exception(),
            );
            _actualStockController.text = '${_selectedProduct?.currentStock ?? 0}';
          } else if (list.isNotEmpty) {
            _selectedProduct = list.first;
            _actualStockController.text = '${_selectedProduct?.currentStock ?? 0}';
          }
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

  void _onProductChanged(Product? newProduct) {
    if (newProduct == null) return;
    setState(() {
      _selectedProduct = newProduct;
      _actualStockController.text = '${newProduct.currentStock}';
      _successMessage = null;
      _errorMessage = null;
    });
  }

  double? get _calculatedDifference {
    if (_selectedProduct == null) return null;
    final actual = double.tryParse(_actualStockController.text.trim());
    if (actual == null) return null;
    return actual - _selectedProduct!.currentStock;
  }

  Future<void> _applyAdjustment() async {
    if (_selectedProduct == null) return;

    final actualVal = double.tryParse(_actualStockController.text.trim());
    if (actualVal == null || actualVal < 0) {
      setState(() => _errorMessage = 'يرجى إدخال كمية فعلية صحيحة وغير سالبة');
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة سبب التسوية الجردية');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final movement = await _movementsRepo.adjustStock(
        productId: _selectedProduct!.id,
        actualPhysicalStock: actualVal,
        reason: reason,
        notes: _notesController.text.trim(),
      );

      // إعادة تحميل بيانات المنتج المحدثة
      final updatedProduct = await _productsRepo.getProductById(_selectedProduct!.id);

      if (mounted) {
        setState(() {
          _selectedProduct = updatedProduct;
          _isSubmitting = false;
          if (movement != null) {
            _successMessage =
                'تم اعتماد التسوية بنجاح: تم تسجيل حركة (${movement.movementType.arabicLabel}) بمقدار (${movement.quantity} ${updatedProduct.unitSymbol ?? ""}).';
          } else {
            _successMessage = 'الرصيد الفعلي متطابق تماماً مع رصيد النظام، لم يتطلب الأمر أي تعديل.';
          }
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد وتسوية المخزون'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد منتجات نشطة لإجراء الجرد عليها'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_errorMessage != null) ...[
                      _buildAlertBanner(_errorMessage!, isError: true),
                      const SizedBox(height: 16),
                    ],
                    if (_successMessage != null) ...[
                      _buildAlertBanner(_successMessage!, isError: false),
                      const SizedBox(height: 16),
                    ],

                    // 1. اختيار المنتج
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اختيار الصنف المراد جرده',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            DropdownButtonFormField<Product>(
                              key: ValueKey(_selectedProduct?.id),
                              initialValue: _selectedProduct,
                              decoration: const InputDecoration(
                                labelText: 'المنتج',
                                prefixIcon: Icon(Icons.search),
                              ),
                              isExpanded: true,
                              items: _products.map((p) {
                                return DropdownMenuItem<Product>(
                                  value: p,
                                  child: Text(
                                    '${p.name} (الرصيد: ${p.currentStock} ${p.unitSymbol ?? ""})',
                                  ),
                                );
                              }).toList(),
                              onChanged: _onProductChanged,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. مقارنة الرصيد والكمية الفعلية
                    if (_selectedProduct != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'مطابقة الرصيد والجرد الفعلي',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'الرصيد المسجل بالنظام',
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${_selectedProduct!.currentStock} ${_selectedProduct!.unitSymbol ?? ""}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _actualStockController,
                                      decoration: InputDecoration(
                                        labelText: 'الكمية الفعلية *',
                                        suffixText: _selectedProduct!.unitSymbol,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // مؤشر الفرق التلقائي
                              _buildDifferenceCard(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. سبب التسوية وملاحظات
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'بيانات التسوية المحاسبية',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20),
                              TextFormField(
                                controller: _reasonController,
                                decoration: const InputDecoration(
                                  labelText: 'سبب التسوية الجردية *',
                                  hintText: 'مثال: جرد نهاية الشهر، تسوية تالف، خطأ إدخال سابق',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'ملاحظات إضافية (اختياري)',
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // زر الاعتماد
                      ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_isSubmitting ? 'جاري تطبيق التسوية...' : 'اعتماد وتحديث المخزون'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _isSubmitting ? null : _applyAdjustment,
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildDifferenceCard() {
    final diff = _calculatedDifference;
    if (diff == null) return const SizedBox.shrink();

    final Color cardColor;
    final Color textColor;
    final IconData icon;
    final String title;
    final String desc;

    if (diff > 0.0001) {
      cardColor = AppColors.successContainer;
      textColor = AppColors.success;
      icon = Icons.add_circle_outline;
      title = 'فائض في المخزون (+${diff.toStringAsFixed(2)})';
      desc = 'سيتم إنشاء حركة تسوية (زيادة) لرفع رصيد المخزون ليطابق الواقع الفعلي.';
    } else if (diff < -0.0001) {
      cardColor = AppColors.errorContainer;
      textColor = AppColors.error;
      icon = Icons.remove_circle_outline;
      title = 'عجز / نقص في المخزون (${diff.toStringAsFixed(2)})';
      desc = 'سيتم إنشاء حركة تسوية (عجز) لخصم الكمية المفقودة وخفض رصيد المخزون ليطابق الواقع الفعلي.';
    } else {
      cardColor = AppColors.surfaceElevated;
      textColor = AppColors.textSecondary;
      icon = Icons.check_circle_outline;
      title = 'الرصيد متطابق تماماً';
      desc = 'الكمية الفعلية تطابق رصيد النظام، لن يطرأ أي تعديل على المخزون.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: textColor.withAlpha(210)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(String message, {required bool isError}) {
    final bg = isError ? AppColors.errorContainer : AppColors.successContainer;
    final fg = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
