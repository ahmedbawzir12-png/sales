import '../entities/unit_of_measurement.dart';

/// واجهة مستودع وحدات القياس في طبقة النطاق
abstract class UnitsRepository {
  /// جلب كافة وحدات القياس
  Future<List<UnitOfMeasurement>> getUnits();

  /// جلب وحدة قياس عبر معرفها
  Future<UnitOfMeasurement> getUnitById(int id);

  /// إضافة وحدة قياس جديدة
  Future<int> createUnit(UnitOfMeasurement unit);

  /// تعديل وحدة قياس
  Future<void> updateUnit(UnitOfMeasurement unit);

  /// عدد المنتجات المرتبطة بوحدة القياس
  Future<int> getProductsCountByUnit(int unitId);
}
