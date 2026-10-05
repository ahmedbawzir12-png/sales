import '../entities/stock_movement.dart';

/// واجهة مستودع حركات المخزون في طبقة النطاق
abstract class StockMovementsRepository {
  /// جلب حركات المخزون لمنتج محدد مرتبة من الأحدث للأقدم
  Future<List<StockMovement>> getMovementsByProductId(int productId);

  /// جلب كافة الحركات في النظام مع إمكانية التحديد والصفحات
  Future<List<StockMovement>> getAllMovements({int limit = 50, int offset = 0});

  /// تسجيل حركة مخزون مع تحديث رصيد المنتج بشكل ذري آمن (Atomic Transaction)
  /// يمنع وصول المخزون لقيمة سالبة ويرفض الكميات غير الصالحة
  Future<StockMovement> recordMovement({
    required int productId,
    required StockMovementType type,
    required double quantity,
    required String reason,
    String? notes,
    String? reference,
  });

  /// تنفيذ تسوية جردية بناءً على الكمية الفعلية المقاسة على أرض الواقع
  Future<StockMovement?> adjustStock({
    required int productId,
    required double actualPhysicalStock,
    required String reason,
    String? notes,
  });
}
