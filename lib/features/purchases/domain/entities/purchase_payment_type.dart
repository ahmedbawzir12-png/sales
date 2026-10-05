/// أنواع وطرق الدفع لفواتير الشراء
enum PurchasePaymentType {
  cash,
  credit;

  String get arabicLabel {
    switch (this) {
      case PurchasePaymentType.cash:
        return 'نقداً';
      case PurchasePaymentType.credit:
        return 'آجل';
    }
  }

  static PurchasePaymentType fromString(String value) {
    return PurchasePaymentType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PurchasePaymentType.cash,
    );
  }
}
