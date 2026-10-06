import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_status.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/entities/sales_return.dart';
import 'package:sales/features/sales/domain/repositories/sales_repository.dart';
import 'package:sales/features/sales/domain/repositories/sales_returns_repository.dart';
import 'package:sales/features/sales/presentation/screens/sales_invoice_details_screen.dart';

class MockSalesRepository implements SalesRepository {
  final SalesInvoice invoice;
  MockSalesRepository(this.invoice);

  @override
  Future<SalesInvoice> getInvoiceById(int id) async => invoice;

  @override
  Future<SalesInvoice> createInvoice(SalesInvoice invoice) async => invoice;

  @override
  Future<void> cancelInvoice(int invoiceId, {String? reason}) async {}

  @override
  Future<String> generateNextInvoiceNumber() async => 'INV-001';

  @override
  Future<SalesInvoice> getInvoiceByNumber(String invoiceNumber) async => invoice;

  @override
  Future<List<SalesInvoice>> getInvoices({
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    int? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
  }) async => [invoice];

  @override
  Future<Map<String, dynamic>> getSalesSummaryMetrics({DateTime? fromDate, DateTime? toDate}) async => {};
}

class MockSalesReturnsRepository implements SalesReturnsRepository {
  @override
  Future<SalesReturn> createReturn(SalesReturn salesReturn) async => salesReturn;

  @override
  Future<String> generateNextReturnNumber() async => 'SR-001';

  @override
  Future<List<SalesReturnAvailableItem>> getAvailableReturnItems(int salesInvoiceId) async => [];

  @override
  Future<SalesReturn> getReturnById(int id) async => throw UnimplementedError();

  @override
  Future<List<SalesReturn>> getReturns({int? invoiceId, int? customerId}) async => [];
}

void main() {
  testWidgets('SalesInvoiceDetailsScreen يعرض قيمة الخصم الحقيقية للأصناف المباعة بدلاً من صفر', (
    WidgetTester tester,
  ) async {
    final invoice = SalesInvoice(
      id: 1,
      invoiceNumber: 'INV-2026-0001',
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 50000,
      discount: 5000, // خصم إجمالي على الفاتورة
      totalAmount: 45000,
      paidAmount: 45000,
      remainingAmount: 0,
      paymentType: SalesPaymentType.cash,
      status: SalesInvoiceStatus.completed,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      items: [
        const SalesInvoiceItem(
          id: 1,
          salesInvoiceId: 1,
          productId: 10,
          quantity: 1.0,
          unitPrice: 50000,
          unitCostAtSale: 35000,
          discount: 0, // كان مسجلاً كصفر في قاعدة البيانات
          total: 50000,
          costTotal: 35000,
          productName: 'طقم كنب ملكي',
          unitSymbol: 'طقم',
        ),
      ],
    );

    final mockRepo = MockSalesRepository(invoice);
    final mockReturnsRepo = MockSalesReturnsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SalesInvoiceDetailsScreen(
          invoiceId: 1,
          repository: mockRepo,
          returnsRepository: mockReturnsRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // التحقق من أن رقم الفاتورة واسم الصنف ظاهران
    expect(find.text('INV-2026-0001'), findsAtLeastNWidgets(1));
    expect(find.text('طقم كنب ملكي'), findsOneWidget);

    // التحقق الحاسم: عمود الخصم في جدول الأصناف المباعة يجب ألا يظهر كصفر، بل يظهر قيمة الخصم الحقيقية (5,000)
    final expectedDiscountText = AppFormatters.currency(5000);
    expect(find.text(expectedDiscountText), findsAtLeastNWidgets(1));

    // التحقق من أن الصافي للبند يظهر 45,000
    final expectedItemNetText = AppFormatters.currency(45000);
    expect(find.text(expectedItemNetText), findsAtLeastNWidgets(1));
  });

  testWidgets('توزيع الخصم العام بدقة على عدة أصناف في جدول الأصناف المباعة', (
    WidgetTester tester,
  ) async {
    final invoice = SalesInvoice(
      id: 2,
      invoiceNumber: 'INV-2026-0002',
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 50000,
      discount: 5000, // 5000 خصم موزع: 3000 للصنف الأول و 2000 للصنف الثاني
      totalAmount: 45000,
      paidAmount: 45000,
      remainingAmount: 0,
      paymentType: SalesPaymentType.cash,
      status: SalesInvoiceStatus.completed,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      items: [
        const SalesInvoiceItem(
          id: 1,
          salesInvoiceId: 2,
          productId: 1,
          quantity: 3.0,
          unitPrice: 10000, // إجمالي = 30,000 (يمثل 60% من الفاتورة) -> خصم 3000
          unitCostAtSale: 7000,
          discount: 0,
          total: 30000,
          costTotal: 21000,
          productName: 'طاولة طعام',
          unitSymbol: 'قطعة',
        ),
        const SalesInvoiceItem(
          id: 2,
          salesInvoiceId: 2,
          productId: 2,
          quantity: 2.0,
          unitPrice: 10000, // إجمالي = 20,000 (يمثل 40% من الفاتورة) -> خصم 2000
          unitCostAtSale: 7000,
          discount: 0,
          total: 20000,
          costTotal: 14000,
          productName: 'كرسي خشب',
          unitSymbol: 'قطعة',
        ),
      ],
    );

    final mockRepo = MockSalesRepository(invoice);
    final mockReturnsRepo = MockSalesReturnsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SalesInvoiceDetailsScreen(
          invoiceId: 2,
          repository: mockRepo,
          returnsRepository: mockReturnsRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // التحقق من حساب وعرض الخصم الموزع لكل صنف
    expect(find.text(AppFormatters.currency(3000)), findsOneWidget); // خصم الصنف الأول
    expect(find.text(AppFormatters.currency(2000)), findsOneWidget); // خصم الصنف الثاني

    // التحقق من إجمالي كل صنف بعد الخصم
    expect(find.text(AppFormatters.currency(27000)), findsOneWidget); // صافي الصنف الأول
    expect(find.text(AppFormatters.currency(18000)), findsOneWidget); // صافي الصنف الثاني
  });
}
