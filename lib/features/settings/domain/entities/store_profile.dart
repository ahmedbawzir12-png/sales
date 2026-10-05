import '../../../../core/domain/entities/entity.dart';

/// كيان بيانات المتجر في طبقة النطاق (Domain)
/// كائن نقي تماماً لا يعتمد على Flutter أو مكتبات التخزين
class StoreProfile extends Entity {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String currency;
  final DateTime updatedAt;

  const StoreProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.currency,
    required this.updatedAt,
  });

  StoreProfile copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? currency,
    DateTime? updatedAt,
  }) {
    return StoreProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          address == other.address &&
          currency == other.currency &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, name, phone, address, currency, updatedAt);

  @override
  String toString() {
    return 'StoreProfile(id: $id, name: $name, phone: $phone, currency: $currency)';
  }
}
