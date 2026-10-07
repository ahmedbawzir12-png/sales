import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/widgets/primary_hero_card.dart';
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

    AppDataNotifier.instance.addListener(_handleDataNotification);
    _loadProducts();
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_handleDataNotification);
    _actualStockController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleDataNotification() {
    final event = AppDataNotifier.instance.lastEvent;
    if (event == null) return;
    if (event.type == AppDataChangeType.inventory ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 5)) {
      if (mounted && !_isSubmitting) {
        _loadProducts(isSilent: true);
      }
    }
  }

  Future<void> _loadProducts({bool isSilent = false}) async {
    if (!isSilent || _products.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final list = await _productsRepo.getProducts(onlyActive: true);
      if (mounted) {
        setState(() {
          _products = list;
          if (_selectedProduct != null && list.any((p) => p.id == _selectedProduct!.id)) {
            final refreshedProduct = list.firstWhere((p) => p.id == _selectedProduct!.id);
            final wasMatchingOldStock = _actualStockController.text.trim() == '${_selectedProduct!.currentStock}';
            _selectedProduct = refreshedProduct;
            if (wasMatchingOldStock || _actualStockController.text.trim().isEmpty) {
              _actualStockController.text = '${refreshedProduct.currentStock}';
            }
          } else if (widget.initialProductId != null) {
            _selectedProduct = list.firstWhere(
              (p) => p.id == widget.initialProductId,
              orElse: () => list.isNotEmpty ? list.first : throw Exception(),
            );
            _actualStockController.text = '${_selectedProduct?.currentStock ?? 0}';
          } else if (list.isNotEmpty) {
            _selectedProduct = list.first;
            _actualStockController.text = '${_selectedProduct?.currentStock ?? 0}';
          } else {
            _selectedProduct = null;
            _actualStockController.clear();
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

      // إعادة تحميل قائمة المنتجات والمنتج المحدث لضمان تطابق البيانات وتحديث القائمة
      final refreshedList = await _productsRepo.getProducts(onlyActive: true);
      final updatedProduct = refreshedList.firstWhere(
        (p) => p.id == _selectedProduct!.id,
        orElse: () => _selectedProduct!,
      );

      if (mounted) {
        setState(() {
          _products = refreshedList;
          _selectedProduct = updatedProduct;
          _actualStockController.text = '${updatedProduct.currentStock}';
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

                    // حاوية الهيرو الموحدة لجرد وتسوية المخزون
                    PrimaryHeroCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      icon: Icons.tune,
                      title: 'جرد وتسوية المخزون المستودعي',
                      badge: 'تسوية المخازن',
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: PrimaryHeroMetricItem(
                                label: 'الأصناف المتاحة للجرد',
                                value: '${_products.length} صنف',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            if (_selectedProduct != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: PrimaryHeroMetricItem(
                                  label: 'الرصيد الدفتري الحالي',
                                  value: '${_selectedProduct!.currentStock} ${_selectedProduct!.unitSymbol ?? ""}',
                                  icon: Icons.bookmark_outline,
                                  valueColor: const Color(0xFF93C5FD),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

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
                            DropdownButtonFormField<int>(
                              key: ValueKey('stock_inv_prod_${_selectedProduct?.id}'),
                              initialValue: _products.any((p) => p.id == _selectedProduct?.id)
                                  ? _selectedProduct?.id
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'المنتج',
                                prefixIcon: Icon(Icons.search),
                              ),
                              isExpanded: true,
                              items: _products.map((p) {
                                return DropdownMenuItem<int>(
                                  value: p.id,
                                  child: Text(
                                    '${p.name} (الرصيد: ${p.currentStock} ${p.unitSymbol ?? ""})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (id) {
                                if (id == null) return;
                                final found = _products.firstWhere((p) => p.id == id);
                                _onProductChanged(found);
                              },
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
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.bookmark_outline, size: 14, color: Colors.white70),
                                            SizedBox(width: 4),
                                            Text(
                                              'الرصيد المسجل بالنظام',
                                              style: TextStyle(fontSize: 11.5, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${_selectedProduct!.currentStock} ${_selectedProduct!.unitSymbol ?? ""}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
