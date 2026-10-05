import '../entities/purchase_invoice.dart';
import '../entities/purchase_invoice_item.dart';
import '../entities/purchase_invoice_status.dart';
import '../entities/purchase_payment_type.dart';

/// واجهة مستودع المشتريات في طبقة النطاق
abstract class PurchasesRepository {
  /// جلب فواتير الشراء مع خيارات البحث والتصفية
  Future<List<PurchaseInvoice>> getInvoices({
    String? searchQuery,
    int? supplierId,
    PurchasePaymentType? paymentType,
    PurchaseInvoiceStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  /// جلب فاتورة شراء محددة مع بنودها وملاحظاتها
  Future<PurchaseInvoice> getInvoiceById(int id);

  /// توليد الرقم التسلسلي التالي للفاتورة (مثال: PUR-000001)
  Future<String> generateNextInvoiceNumber();

  /// إنشاء وحفظ فاتورة شراء جديدة بشكل ذري (Atomic Transaction)
  /// يقوم بـ:
  /// 1. حفظ الفاتورة وبنودها
  /// 2. زيادة مخزون كل منتج
  /// 3. تسجيل حركة مخزون purchase لكل منتج
  /// 4. تحديث متوسط التكلفة المرجح (Weighted Average Cost) وسعر الشراء الأخير
  /// 5. تحديث دين المورد إن كانت الفاتورة آجلة أو جزئية
  Future<PurchaseInvoice> createPurchaseInvoice({
    required PurchaseInvoice invoice,
    required List<PurchaseInvoiceItem> items,
  });

  /// إلغاء فاتورة شراء بشكل ذري آمن (مع الحفاظ على الأثر التاريخي)
  /// يقوم بـ:
  /// 1. التحقق من كفاية المخزون الحالي لإلغاء الشراء ومنع الرصيد السالب
  /// 2. خصم الكميات من المخزون
  /// 3. تسجيل حركات مخزون عكسية لتوثيق الإلغاء
  /// 4. عكس أثر الدين في رصيد المورد
  /// 5. تغيير حالة الفاتورة إلى ملغاة (cancelled)
  Future<void> cancelPurchaseInvoice(int invoiceId, {required String reason});
}
