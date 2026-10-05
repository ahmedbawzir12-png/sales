import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/services/sales_calculation_service.dart';

void main() {
  const service = SalesCalculationService();

  group('SalesCalculationService Tests (حسابات فواتير المبيعات والتحقق)', () {
    test('حساب إجمالي السطر بدقة (الكمية × السعر) مع وبدون خصم', () {
      final totalNoDiscount = service.calculateItemTotal(quantity: 3, unitPrice: 20000);
      expect(totalNoDiscount, equals(60000));

      final totalWithDiscount = service.calculateItemTotal(
        quantity: 2,
        unitPrice: 50000,
        discount: 5000,
      );
      expect(totalWithDiscount, equals(95000));
    });

    test('يرفض الكميات الصفرية أو السالبة أو الأسعار والخصومات السالبة', () {
      expect(
        () => service.calculateItemTotal(quantity: 0, unitPrice: 10000),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateItemTotal(quantity: -2, unitPrice: 10000),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateItemTotal(quantity: 2, unitPrice: -500),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateItemTotal(quantity: 2, unitPrice: 1000, discount: -100),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateItemTotal(quantity: 1, unitPrice: 1000, discount: 1500),
        throwsA(isA<ValidationException>()),
      );
    });

    test('حساب إجمالي التكلفة التاريخية للبند وقت البيع', () {
      final cost = service.calculateItemCostTotal(quantity: 3, unitCostAtSale: 15000);
      expect(cost, equals(45000.0));
    });

    test('حساب المجموع الفرعي لمجموعة أسطر', () {
      final items = [
        const SalesInvoiceItem(
          id: 1,
          salesInvoiceId: 1,
          productId: 1,
          quantity: 2,
          unitPrice: 30000,
          unitCostAtSale: 20000,
          total: 60000,
          costTotal: 40000,
        ),
        const SalesInvoiceItem(
          id: 2,
          salesInvoiceId: 1,
          productId: 2,
          quantity: 1,
          unitPrice: 40000,
          unitCostAtSale: 25000,
          total: 40000,
          costTotal: 25000,
        ),
      ];

      expect(service.calculateSubtotal(items), equals(100000));
      expect(service.calculateTotalCost(items), equals(65000.0));
    });

    test('تطبيق الخصم العام واحتساب الصافي بدقة ومنع الخصم الزائد', () {
      expect(service.calculateTotalAmount(subtotal: 500000, discount: 20000), equals(480000));
      expect(service.calculateTotalAmount(subtotal: 100000, discount: 0), equals(100000));

      expect(
        () => service.calculateTotalAmount(subtotal: 100000, discount: 150000),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateTotalAmount(subtotal: 100000, discount: -5000),
        throwsA(isA<ValidationException>()),
      );
    });

    test('حساب المتبقي بدقة للبيع النقدي والآجل', () {
      // نقدي: المتبقي دائماً 0
      expect(
        service.calculateRemainingAmount(
          totalAmount: 100000,
          paidAmount: 100000,
          paymentType: SalesPaymentType.cash,
        ),
        equals(0),
      );

      // آجل كامل: لم يدفع شيئاً
      expect(
        service.calculateRemainingAmount(
          totalAmount: 100000,
          paidAmount: 0,
          paymentType: SalesPaymentType.credit,
        ),
        equals(100000),
      );

      // آجل جزئي: دفع 30,000 من 100,000 = المتبقي 70,000
      expect(
        service.calculateRemainingAmount(
          totalAmount: 100000,
          paidAmount: 30000,
          paymentType: SalesPaymentType.credit,
        ),
        equals(70000),
      );

      // رفض المدفوع السالب أو الزائد عن الصافي
      expect(
        () => service.calculateRemainingAmount(
          totalAmount: 100000,
          paidAmount: -100,
          paymentType: SalesPaymentType.credit,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.calculateRemainingAmount(
          totalAmount: 100000,
          paidAmount: 120000,
          paymentType: SalesPaymentType.credit,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
