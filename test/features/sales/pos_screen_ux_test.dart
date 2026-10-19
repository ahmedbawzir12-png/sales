import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/presentation/widgets/app_button.dart';
import 'package:sales/core/presentation/widgets/confirm_dialog.dart';
import 'package:sales/core/presentation/widgets/empty_state.dart';
import 'package:sales/core/presentation/widgets/error_state.dart';
import 'package:sales/core/presentation/widgets/loading_state.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_status.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/presentation/widgets/printable_invoice_dialog.dart';
import 'package:sales/features/sales/presentation/widgets/sale_success_dialog.dart';
import 'package:sales/features/sales/domain/repositories/sales_repository.dart';

import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/repositories/products_repository.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/customers/domain/repositories/customers_repository.dart';
import 'package:sales/features/sales/presentation/screens/pos_screen.dart';

class MockSalesRepository implements SalesRepository {
  @override
  Future<SalesInvoice> createInvoice(SalesInvoice invoice) async => invoice;
  @override
  Future<SalesInvoice> getInvoiceById(int id) async => throw UnimplementedError();
  @override
  Future<SalesInvoice> getInvoiceByNumber(String invoiceNumber) async => throw UnimplementedError();
  @override
  Future<List<SalesInvoice>> getInvoices({
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    String? searchQuery,
    int? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async => [];
  @override
  Future<void> cancelInvoice(int invoiceId, {String? reason}) async {}
  @override
  Future<String> generateNextInvoiceNumber() async => 'INV-001';
  @override
  Future<Map<String, dynamic>> getSalesSummaryMetrics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async => {};
  @override
  Future<void> deleteInvoice(int id) async {}
}

class MockProductsRepository implements ProductsRepository {
  final List<Product> products;
  MockProductsRepository(this.products);

  @override
  Future<List<Product>> getProducts({String? searchQuery, int? categoryId, bool? onlyActive, bool? onlyLowStock}) async => products;
  @override
  Future<Product> getProductById(int id) async => products.firstWhere((p) => p.id == id);
  @override
  Future<Product> createProduct(Product product, {double initialStock = 0.0, String? initialStockNotes}) async => product;
  @override
  Future<void> updateProduct(Product product) async {}
  @override
  Future<void> setProductActive(int id, bool isActive) async {}
  @override
  Future<int> getLowStockCount() async => 0;
  @override
  Future<void> deleteProduct(int id) async {}
}

class MockCustomersRepository implements CustomersRepository {
  final List<Customer> customers;
  MockCustomersRepository([this.customers = const []]);

  @override
  Future<List<Customer>> getCustomers({bool? onlyActive, String? searchQuery}) async => customers;
  @override
  Future<Customer> getCustomerById(int id) async => customers.firstWhere((c) => c.id == id);
  @override
  Future<int> createCustomer(Customer customer) async => 1;
  @override
  Future<void> updateCustomer(Customer customer) async {}
  @override
  Future<void> toggleCustomerActive(int id, bool isActive) async {}
  @override
  Future<int> getCustomerDebt(int customerId) async => 0;
  @override
  Future<Map<String, dynamic>> getCustomerStatistics(int customerId) async => {};
  @override
  Future<void> deleteCustomer(int id) async {}
}

void main() {
  group('Phase 9 UI Components & States Tests (مكونات الواجهة الموحدة وتجربة المستخدم)', () {
    testWidgets('EmptyState يعرض العنوان والوصف وزر الإجراء بنجاح', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'لا توجد بيانات متاحة',
              description: 'يرجى إضافة عناصر جديدة',
              actionLabel: 'إضافة عنصر',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('لا توجد بيانات متاحة'), findsOneWidget);
      expect(find.text('يرجى إضافة عناصر جديدة'), findsOneWidget);
      expect(find.text('إضافة عنصر'), findsOneWidget);

      await tester.tap(find.text('إضافة عنصر'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('LoadingState يعرض النص ومؤشر التحميل', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingState(message: 'جارٍ تجهيز الأصناف...'),
          ),
        ),
      );

      expect(find.text('جارٍ تجهيز الأصناف...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ErrorState يعرض رسالة الخطأ وزر إعادة المحاولة', (tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'فشل الاتصال بقاعدة البيانات',
              onRetry: () => retryTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('حدث خطأ أثناء تحميل البيانات'), findsOneWidget);
      expect(find.text('فشل الاتصال بقاعدة البيانات'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      expect(retryTriggered, isTrue);
    });

    testWidgets('ConfirmDialog يوضح أثر العملية الحساسة والأزرار باللغة العربية', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await ConfirmDialog.show(
                  context,
                  title: 'تأكيد إلغاء الفاتورة',
                  message: 'هل تريد إلغاء الفاتورة؟',
                  impactExplanation: 'سيتم إعادة البضاعة للمخزون وعكس القيد المالي',
                  confirmLabel: 'تأكيد الإلغاء',
                  cancelLabel: 'تراجع',
                  isDestructive: true,
                );
              },
              child: const Text('فتح التأكيد'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح التأكيد'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد إلغاء الفاتورة'), findsOneWidget);
      expect(find.text('سيتم إعادة البضاعة للمخزون وعكس القيد المالي'), findsOneWidget);
      expect(find.text('تأكيد الإلغاء'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);

      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('AppButton يمنع النقر المزدوج أثناء التحميل ويعرض مؤشر الدوران', (tester) async {
      int clickCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'حفظ الفاتورة',
              isLoading: true,
              onPressed: () => clickCount++,
            ),
          ),
        ),
      );

      // زر الحفظ في وضع التحميل
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(clickCount, 0); // لم يتم تنفيذ أي استدعاء لمنع التكرار
    });

    testWidgets('PrintableInvoiceDialog يعرض الفاتورة التجارية دون كشف أي تكلفة شراء داخلية', (tester) async {
      final invoice = SalesInvoice(
        id: 1,
        invoiceNumber: 'INV-1001',
        invoiceDate: DateTime(2026, 10, 7, 10, 30),
        subtotal: 500000,
        discount: 50000,
        totalAmount: 450000,
        paidAmount: 450000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        customerName: 'سعيد بامحرز',
        items: const [
          SalesInvoiceItem(
            id: 1,
            salesInvoiceId: 1,
            productId: 10,
            productName: 'طقم كنب كلاسيك 7 مقاعد',
            quantity: 1.0,
            unitPrice: 500000,
            unitCostAtSale: 320000.0, // تكلفة شراء داخلية سرية
            total: 500000,
            costTotal: 320000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableInvoiceDialog(invoice: invoice),
          ),
        ),
      );

      // التحقق من ظهور البيانات التجارية
      expect(find.text('فاتورة مبيعات'), findsOneWidget);
      expect(find.text('INV-1001'), findsOneWidget);
      expect(find.text('سعيد بامحرز'), findsOneWidget);
      expect(find.text('طقم كنب كلاسيك 7 مقاعد'), findsOneWidget);

      // التأكد القاطع من عدم ظهور تكلفة الشراء الداخلية للعميل (320,000)
      expect(find.textContaining('320,000'), findsNothing);
      expect(find.text('unitCostAtSale'), findsNothing);
      expect(find.text('costTotal'), findsNothing);
    });

    testWidgets('SaleSuccessDialog يعرض شاشة النجاح والإجراءات الثلاثة السريعة', (tester) async {
      bool newSaleClicked = false;
      final invoice = SalesInvoice(
        id: 1,
        invoiceNumber: 'INV-777',
        invoiceDate: DateTime.now(),
        subtotal: 300000,
        totalAmount: 300000,
        paidAmount: 300000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaleSuccessDialog(
              invoice: invoice,
              repository: MockSalesRepository(),
              onNewSale: () => newSaleClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('تمت عملية البيع بنجاح'), findsOneWidget);
      expect(find.text('INV-777'), findsOneWidget);
      expect(find.text('عرض الفاتورة'), findsOneWidget);
      expect(find.text('طباعة الفاتورة'), findsOneWidget);
      expect(find.text('عملية بيع جديدة'), findsOneWidget);

      await tester.tap(find.text('عملية بيع جديدة'));
      expect(newSaleClicked, isTrue);
    });

    testWidgets('PosScreen يمنع زيادة الكمية عن المخزون المتوفر ويعرض تنبيه بالرصيد المتاح', (tester) async {
      final product = Product(
        id: 1,
        name: 'وسادة قطن فاخرة',
        categoryId: 1,
        unitId: 1,
        purchasePrice: 10000,
        salePrice: 18000,
        currentStock: 1.0, // رصيد حبة واحدة فقط
        minimumStock: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final productsRepo = MockProductsRepository([product]);
      final customersRepo = MockCustomersRepository();
      final salesRepo = MockSalesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: PosScreen(
            productsRepository: productsRepo,
            customersRepository: customersRepo,
            salesRepository: salesRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // التحقق من ظهور المنتج والرصيد المتاح
      expect(find.text('وسادة قطن فاخرة'), findsOneWidget);
      expect(find.textContaining('المتاح: 1.0'), findsWidgets);

      // النقر لإضافة المنتج إلى السلة
      await tester.tap(find.text('وسادة قطن فاخرة'));
      await tester.pumpAndSettle();

      // محاولة الضغط على زر الزيادة (+) رغم أن الرصيد 1.0 فقط
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // التأكد من ظهور التنبيه الصارم بعدم وجود كمية كافية
      expect(find.textContaining('لا توجد كمية كافية في المخزون. المتاح حالياً: 1.0'), findsOneWidget);
    });

    testWidgets('PosScreen يرفض البيع الآجل إذا لم يتم اختيار عميل محدد', (tester) async {
      final product = Product(
        id: 1,
        name: 'كرسي مكتب دوار',
        categoryId: 1,
        unitId: 1,
        purchasePrice: 40000,
        salePrice: 70000,
        currentStock: 5.0,
        minimumStock: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final productsRepo = MockProductsRepository([product]);
      final customersRepo = MockCustomersRepository();
      final salesRepo = MockSalesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: PosScreen(
            productsRepository: productsRepo,
            customersRepository: customersRepo,
            salesRepository: salesRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // إضافة المنتج للسلة
      await tester.tap(find.text('كرسي مكتب دوار'));
      await tester.pumpAndSettle();

      // تغيير نوع الدفع إلى آجل
      await tester.tap(find.text('آجل'));
      await tester.pumpAndSettle();

      // الضغط على إتمام البيع دون تحديد عميل
      await tester.tap(find.textContaining('إتمام البيع'));
      await tester.pumpAndSettle();

      // التأكد من ظهور رسالة الرفض والطلب الصريح باختيار العميل
      expect(find.text('❌ يجب اختيار العميل للبيع الآجل.'), findsOneWidget);
    });
  });
}
