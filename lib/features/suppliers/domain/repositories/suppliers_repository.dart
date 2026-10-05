import '../entities/supplier.dart';

/// واجهة مستودع الموردين في طبقة النطاق
abstract class SuppliersRepository {
  /// جلب كافة الموردين مع إمكانية البحث والتصفية
  Future<List<Supplier>> getSuppliers({String? searchQuery, bool? onlyActive});

  /// جلب مورد محدد بواسطة المعرف
  Future<Supplier> getSupplierById(int id);

  /// إنشاء مورد جديد مع التحقق من عدم تكرار الاسم وعدم فراغه
  Future<Supplier> createSupplier(Supplier supplier);

  /// تحديث بيانات المورد
  Future<void> updateSupplier(Supplier supplier);

  /// تغيير حالة تفعيل المورد (حذف ناعم / تعطيل)
  Future<void> setSupplierActive(int id, bool isActive);

  /// إجمالي الديون المستحقة لجميع الموردين
  Future<int> getTotalSuppliersDebt();

  /// عدد الموردين النشطين
  Future<int> getActiveSuppliersCount();
}
