import '../entities/stock_movement.dart';
import '../repositories/products_repository.dart';
import '../repositories/stock_movements_repository.dart';

/// الخدمة المركزية لإدارة كافة حركات المخزون وضمان سلامة الأرصدة
class StockMovementService {
  final StockMovementsRepository movementsRepository;
  final ProductsRepository productsRepository;

  StockMovementService({
    required this.movementsRepository,
    required this.productsRepository,
  });

  /// تسجيل تسوية جردية بين الرصيد المسجل والكمية الفعلية
  Future<StockMovement?> performInventoryAdjustment({
    required int productId,
    required double actualPhysicalStock,
    required String reason,
    String? notes,
  }) async {
    return await movementsRepository.adjustStock(
      productId: productId,
      actualPhysicalStock: actualPhysicalStock,
      reason: reason,
      notes: notes,
    );
  }

  /// تسجيل حركة مخزون مخصصة
  Future<StockMovement> recordStockMovement({
    required int productId,
    required StockMovementType type,
    required double quantity,
    required String reason,
    String? notes,
    String? reference,
  }) async {
    return await movementsRepository.recordMovement(
      productId: productId,
      type: type,
      quantity: quantity,
      reason: reason,
      notes: notes,
      reference: reference,
    );
  }

  /// استرجاع السجل التاريخي لحركات منتج معين
  Future<List<StockMovement>> getProductMovementHistory(int productId) async {
    return await movementsRepository.getMovementsByProductId(productId);
  }

  /// التحقق من كفاية المخزون المتاح
  Future<bool> hasSufficientStock(int productId, double requiredQuantity) async {
    final product = await productsRepository.getProductById(productId);
    return product.currentStock >= requiredQuantity;
  }
}
