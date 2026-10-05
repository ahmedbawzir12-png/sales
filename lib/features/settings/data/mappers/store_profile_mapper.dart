import '../../domain/entities/store_profile.dart';
import '../models/store_profile_model.dart';

/// مهايئ (Mapper) للتحويل الصريح بين الكيان والنموذج
extension StoreProfileMapper on StoreProfile {
  /// تحويل الكيان إلى نموذج طبقة البيانات
  StoreProfileModel toModel() {
    return StoreProfileModel.fromEntity(this);
  }
}
