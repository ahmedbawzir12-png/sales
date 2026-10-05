import '../entities/store_profile.dart';

/// واجهة مستودع إعدادات وبيانات المتجر في طبقة النطاق (Domain Repository Contract)
abstract class StoreSettingsRepository {
  /// جلب الملف التعريفي الحالي للمتجر
  Future<StoreProfile> getStoreProfile();

  /// تحديث الملف التعريفي للمتجر
  Future<void> updateStoreProfile(StoreProfile profile);
}
