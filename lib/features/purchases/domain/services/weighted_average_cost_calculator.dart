/// خدمة حساب المتوسط المرجح لتكلفة المخزون (Weighted Average Cost)
/// منطق نطاق نقي 100% بدون أي اعتماديات خارجية
class WeightedAverageCostCalculator {
  WeightedAverageCostCalculator._();

  /// حساب متوسط التكلفة الجديد بناءً على:
  /// - [oldQuantity]: رصيد المخزون السابق قبل الشراء
  /// - [oldAverageCost]: متوسط التكلفة السابق للوحدة
  /// - [newQuantity]: الكمية المشتراة حديثاً
  /// - [newUnitCost]: سعر شراء الوحدة في الفاتورة الحالية
  static double calculate({
    required double oldQuantity,
    required double oldAverageCost,
    required double newQuantity,
    required num newUnitCost,
  }) {
    // إذا كانت الكمية المشتراة غير صالحة أو صفر
    if (newQuantity <= 0) {
      return oldAverageCost;
    }

    // إذا كان الرصيد السابق صفر أو سالباً، فالمتوسط الجديد هو سعر الشراء الحالي مباشرة
    if (oldQuantity <= 0) {
      return newUnitCost.toDouble();
    }

    final double totalOldCost = oldQuantity * oldAverageCost;
    final double totalNewCost = newQuantity * newUnitCost;
    final double totalQuantity = oldQuantity + newQuantity;

    if (totalQuantity <= 0) {
      return newUnitCost.toDouble();
    }

    final double averageCost = (totalOldCost + totalNewCost) / totalQuantity;
    // تقريب الناتج لمنزلتين عشريتين لأعلى دقة محاسبية
    return double.parse(averageCost.toStringAsFixed(2));
  }

  /// حساب متوسط التكلفة عند إضافة كمية جديدة (سواء شراء جديد أو استرجاع بتكلفة تاريخية)
  static double calculateNewAverageCost({
    required double currentStock,
    required double currentAverageCost,
    required double addedQuantity,
    required num addedUnitCost,
  }) {
    return calculate(
      oldQuantity: currentStock,
      oldAverageCost: currentAverageCost,
      newQuantity: addedQuantity,
      newUnitCost: addedUnitCost,
    );
  }
}
