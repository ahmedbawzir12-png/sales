import '../entities/sales_return.dart';

/// بند متاح للإرجاع من فاتورة المبيعات الأصلية
class SalesReturnAvailableItem {
  final int productId;
  final String productName;
  final double originalQuantity;
  final double alreadyReturnedQuantity;
  final double availableQuantity;
  final int unitPrice;
  final double unitCostAtSale;

  const SalesReturnAvailableItem({
    required this.productId,
    required this.productName,
    required this.originalQuantity,
    required this.alreadyReturnedQuantity,
    required this.availableQuantity,
    required this.unitPrice,
    required this.unitCostAtSale,
  });
}

abstract class SalesReturnsRepository {
  /// توليد رقم تسلسلي فريد لمرتجع المبيعات (SRET-YYYYMMDD-XXXX)
  Future<String> generateNextReturnNumber();

  /// استرجاع سجل المرتجعات مع إمكانية التصفية
  Future<List<SalesReturn>> getReturns({int? invoiceId, int? customerId});

  /// استرجاع تفاصيل مرتجع مبيعات محدد ببنوده
  Future<SalesReturn> getReturnById(int id);

  /// استرجاع البنود المتاحة للإرجاع من فاتورة المبيعات الأصلية والكميات المتبقية
  Future<List<SalesReturnAvailableItem>> getAvailableReturnItems(
      int salesInvoiceId);

  /// إنشاء مرتجع مبيعات جديد كعملية ذرية (Atomic Transaction):
  /// - التحقق من الكميات المتاحة للإرجاع
  /// - إرجاع المخزون وتسجيل Stock Movement (saleReturn)
  /// - استعادة تكلفة الوحدة التاريخية unitCostAtSale لتحديث المتوسط المرجح
  /// - معالجة الأثر المالي (تخفيض دين العميل أو تجهيز الاسترداد النقدي للصندوق)
  Future<SalesReturn> createReturn(SalesReturn salesReturn);
}
