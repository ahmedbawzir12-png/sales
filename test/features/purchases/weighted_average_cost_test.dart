import 'package:flutter_test/flutter_test.dart';
import 'package:sales/features/purchases/domain/services/weighted_average_cost_calculator.dart';

void main() {
  group('WeightedAverageCostCalculator Tests (حساب متوسط التكلفة المرجح)', () {
    test('شراء أولي لمنتج برصيد صفري: التكلفة تصبح نفس سعر الشراء الحالي', () {
      final cost = WeightedAverageCostCalculator.calculate(
        oldQuantity: 0.0,
        oldAverageCost: 0.0,
        newQuantity: 10.0,
        newUnitCost: 50000,
      );

      expect(cost, equals(50000.0));
    });

    test('شراء إضافي: 10 قطع بسعر 50,000 ثم شراء 5 قطع بسعر 60,000 = 53,333.33', () {
      final cost = WeightedAverageCostCalculator.calculate(
        oldQuantity: 10.0,
        oldAverageCost: 50000.0,
        newQuantity: 5.0,
        newUnitCost: 60000,
      );

      expect(cost, equals(53333.33));
    });

    test('شراء إضافي بكميات متساوية: 10 @ 50,000 + 10 @ 60,000 = 55,000', () {
      final cost = WeightedAverageCostCalculator.calculate(
        oldQuantity: 10.0,
        oldAverageCost: 50000.0,
        newQuantity: 10.0,
        newUnitCost: 60000,
      );

      expect(cost, equals(55000.0));
    });

    test('يدعم الكميات العشرية بدقة: 2.5 متر @ 10,000 + 1.5 متر @ 12,000 = 10,750', () {
      final cost = WeightedAverageCostCalculator.calculate(
        oldQuantity: 2.5,
        oldAverageCost: 10000.0,
        newQuantity: 1.5,
        newUnitCost: 12000,
      );

      expect(cost, equals(10750.0));
    });

    test('إذا كانت الكمية المشتراة صفراً أو سالبة لا تتغير التكلفة', () {
      final cost = WeightedAverageCostCalculator.calculate(
        oldQuantity: 10.0,
        oldAverageCost: 50000.0,
        newQuantity: 0.0,
        newUnitCost: 60000,
      );

      expect(cost, equals(50000.0));
    });
  });
}
