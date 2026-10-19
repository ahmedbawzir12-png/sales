import '../entities/category.dart';

/// واجهة مستودع التصنيفات في طبقة النطاق
abstract class CategoriesRepository {
  /// جلب كافة التصنيفات مع إمكانية التصفية للنشطة فقط
  Future<List<Category>> getCategories({bool? onlyActive});

  /// جلب تصنيف عبر معرفه
  Future<Category> getCategoryById(int id);

  /// إضافة تصنيف جديد
  Future<int> createCategory(Category category);

  /// تعديل تصنيف قائم
  Future<void> updateCategory(Category category);

  /// تفعيل أو تعطيل تصنيف
  Future<void> setCategoryActive(int id, bool isActive);

  /// عدد المنتجات المرتبطة بالتصنيف للتحقق قبل الإجراءات
  Future<int> getProductsCountByCategory(int categoryId);

  /// حذف التصنيف نهائياً إذا لم يكن مرتبطاً بأي منتجات
  Future<void> deleteCategory(int id);
}
