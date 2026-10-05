import '../entities/product.dart';

/// واجهة مستودع المنتجات في طبقة النطاق
abstract class ProductsRepository {
  /// جلب المنتجات مع خيارات البحث والتصفية
  Future<List<Product>> getProducts({
    String? searchQuery,
    int? categoryId,
    bool? onlyActive,
    bool? onlyLowStock,
  });

  /// جلب منتج محدد بواسطة معرّفه
  Future<Product> getProductById(int id);

  /// إضافة منتج جديد مع إمكانية إدخال مخزون أولي يُسجل تلقائياً في حركات المخزون
  Future<Product> createProduct(
    Product product, {
    double initialStock = 0.0,
    String? initialStockNotes,
  });

  /// تعديل بيانات المنتج الأساسية (دون تعديل المخزون مباشرة)
  Future<void> updateProduct(Product product);

  /// تعطيل أو إعادة تفعيل المنتج للحفاظ على السجلات التاريخية
  Future<void> setProductActive(int id, bool isActive);

  /// عدد المنتجات التي بلغت أو نزلت عن حد إعادة الطلب
  Future<int> getLowStockCount();
}
