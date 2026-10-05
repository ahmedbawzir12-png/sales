import '../entities/sales_invoice.dart';
import '../entities/sales_invoice_status.dart';
import '../entities/sales_payment_type.dart';

/// واجهة مستودع المبيعات وفواتير البيع في طبقة النطاق
abstract class SalesRepository {
  /// استرجاع فواتير المبيعات مع خيارات التصفية والبحث
  Future<List<SalesInvoice>> getInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    String? searchQuery,
  });

  /// استرجاع فاتورة معينة بالمعرف مع كامل بنودها وتفاصيلها
  Future<SalesInvoice> getInvoiceById(int id);

  /// استرجاع فاتورة برقمها المرجعي
  Future<SalesInvoice> getInvoiceByNumber(String invoiceNumber);

  /// إنشاء وحفظ فاتورة مبيعات جديدة بصورة ذرية (Atomic Transaction)
  /// - التحقق من وجود العملاء والمنتجات
  /// - التحقق الصارم من توفر المخزون (عدم البيع بأكثر من المتوفر)
  /// - حفظ متوسط التكلفة وقت البيع لكل بند unitCostAtSale
  /// - خصم المخزون عبر Stock Movement
  /// - تسجيل الذمم النقدية أو الآجلة
  Future<SalesInvoice> createInvoice(SalesInvoice invoice);

  /// إلغاء فاتورة مبيعات مكتملة
  /// - استرجاع الكميات للمخزون بحركة عكسية (saleReturn)
  /// - عكس أثر دين العميل إن كانت آجلة
  /// - تغيير حالة الفاتورة إلى cancelled دون حذفها تاريخياً
  Future<void> cancelInvoice(int invoiceId, {String? reason});

  /// توليد الرقم التسلسلي التالي للفاتورة (مثال: SAL-20261005-0001)
  Future<String> generateNextInvoiceNumber();

  /// استرجاع ملخص مالي تشغيلي للمبيعات (الإجمالي، المقبوض، الآجل، عدد الفواتير)
  Future<Map<String, dynamic>> getSalesSummaryMetrics({
    DateTime? fromDate,
    DateTime? toDate,
  });
}
