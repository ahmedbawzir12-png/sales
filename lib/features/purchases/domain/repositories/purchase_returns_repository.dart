import '../entities/purchase_return.dart';

/// بند متاح للإرجاع من فاتورة المشتريات الأصلية
class PurchaseReturnAvailableItem {
  final int productId;
  final String productName;
  final double originalQuantity;
  final double alreadyReturnedQuantity;
  final double availableQuantity;
  final double currentWarehouseStock;
  final int unitCost;

  const PurchaseReturnAvailableItem({
    required this.productId,
    required this.productName,
    required this.originalQuantity,
    required this.alreadyReturnedQuantity,
    required this.availableQuantity,
    required this.currentWarehouseStock,
    required this.unitCost,
  });
}

abstract class PurchaseReturnsRepository {
  /// توليد رقم تسلسلي فريد لمرتجع المشتريات (PRET-YYYYMMDD-XXXX)
  Future<String> generateNextReturnNumber();

  /// استرجاع سجل مرتجعات المشتريات مع إمكانية التصفية
  Future<List<PurchaseReturn>> getReturns({int? invoiceId, int? supplierId});

  /// استرجاع تفاصيل مرتجع مشتريات محدد ببنوده
  Future<PurchaseReturn> getReturnById(int id);

  /// استرجاع البنود والكميات المتاحة للإرجاع من فاتورة الشراء مع فحص المخزون الحالي
  Future<List<PurchaseReturnAvailableItem>> getAvailableReturnItems(
      int purchaseInvoiceId);

  /// إنشاء مرتجع مشتريات جديد كعملية ذرية (Atomic Transaction):
  /// - التحقق من الكميات المتاحة للإرجاع
  /// - التحقق الصارم من توفر رصيد مخزون فعلي بالمستودع لمنع المخزون السالب
  /// - خصم المخزون وتسجيل Stock Movement من نوع (purchaseReturn)
  /// - معالجة الأثر المالي (تخفيض دين المورد أو تجهيز الاسترداد النقدي للصندوق)
  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn);
}
