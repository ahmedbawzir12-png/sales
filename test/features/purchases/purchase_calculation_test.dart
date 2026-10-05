import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/purchases/domain/services/purchase_calculation_service.dart';

void main() {
  group('PurchaseCalculationService Tests (حسابات الفاتورة والتحقق المالي)', () {
    test('حساب إجمالي السطر بدقة للأعداد الصحيحة والكسور', () {
      expect(PurchaseCalculationService.calculateItemTotal(10, 5000), equals(50000));
      expect(PurchaseCalculationService.calculateItemTotal(2.5, 20000), equals(50000));
    });

    test('يرفض الكميات أو الأسعار السالبة في السطر', () {
      expect(
        () => PurchaseCalculationService.calculateItemTotal(-1, 5000),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PurchaseCalculationService.calculateItemTotal(5, -500),
        throwsA(isA<ValidationException>()),
      );
    });

    test('حساب المجموع الفرعي لمجموعة أسطر', () {
      final subtotal = PurchaseCalculationService.calculateSubtotal([50000, 100000]);
      expect(subtotal, equals(150000));
    });

    test('حساب الصافي بعد تطبيق الخصم', () {
      final total = PurchaseCalculationService.calculateTotal(1000000, 50000);
      expect(total, equals(950000));
    });

    test('يرفض الخصم السالب أو الخصم الذي يتجاوز المجموع الفرعي', () {
      expect(
        () => PurchaseCalculationService.calculateTotal(100000, -100),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PurchaseCalculationService.calculateTotal(100000, 150000),
        throwsA(isA<ValidationException>()),
      );
    });

    test('حساب المبلغ المتبقي (الدين) بدقة للشراء النقدي والآجل', () {
      // شراء آجل جزئي: إجمالي 500,000 مدفوع 200,000 -> متبقي 300,000
      expect(PurchaseCalculationService.calculateRemaining(500000, 200000), equals(300000));

      // شراء نقدي كامل: إجمالي 500,000 مدفوع 500,000 -> متبقي 0
      expect(PurchaseCalculationService.calculateRemaining(500000, 500000), equals(0));
    });

    test('يرفض المدفوع السالب أو المدفوع الذي يتجاوز الإجمالي', () {
      expect(
        () => PurchaseCalculationService.calculateRemaining(100000, -5000),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PurchaseCalculationService.calculateRemaining(100000, 120000),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
