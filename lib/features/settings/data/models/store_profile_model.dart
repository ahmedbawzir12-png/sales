import '../../../../core/data/models/data_model.dart';
import '../../../../core/presentation/constants/app_constants.dart';
import '../../domain/entities/store_profile.dart';

/// نموذج بيانات المتجر في طبقة البيانات (Data Model)
/// مسؤول عن التحويل بين جداول SQLite والكيان
class StoreProfileModel extends DataModel<StoreProfile> {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String currency;
  final String updatedAt;

  const StoreProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.currency,
    required this.updatedAt,
  });

  /// إنشاء النموذج من سجل قادم من SQLite
  factory StoreProfileModel.fromMap(Map<String, dynamic> map) {
    return StoreProfileModel(
      id: map['id'] as int? ?? 1,
      name: map['name'] as String? ?? 'معرض المفروشات العصري',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      currency: map['currency'] as String? ?? AppConstants.defaultCurrency,
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  /// إنشاء النموذج انطلاقاً من كيان النطاق
  factory StoreProfileModel.fromEntity(StoreProfile entity) {
    return StoreProfileModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      address: entity.address,
      currency: entity.currency,
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'currency': currency,
      'updated_at': updatedAt,
    };
  }

  @override
  StoreProfile toEntity() {
    return StoreProfile(
      id: id,
      name: name,
      phone: phone,
      address: address,
      currency: currency,
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
    );
  }
}
