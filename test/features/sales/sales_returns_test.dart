import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/customers/data/repositories/customer_ledger_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:sales/features/sales/data/repositories/sales_returns_repository_impl.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/entities/sales_return.dart';
import 'package:sales/features/sales/domain/entities/sales_return_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Sales Returns Tests (دورة مرتجعات المبيعات واستعادة المخزون والتكلفة التاريخية)', () {
    late DatabaseService dbService;
    late ProductsRepositoryImpl productsRepo;
    late CustomersRepositoryImpl customersRepo;
    late CustomerLedgerRepositoryImpl ledgerRepo;
    late SalesRepositoryImpl salesRepo;
    late SalesReturnsRepositoryImpl returnsRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      productsRepo = ProductsRepositoryImpl(databaseService: dbService);
      customersRepo = CustomersRepositoryImpl(dbService: dbService);
      ledgerRepo = CustomerLedgerRepositoryImpl(dbService: dbService);
      salesRepo = SalesRepositoryImpl(dbService: dbService);
      returnsRepo = SalesReturnsRepositoryImpl(dbService: dbService);
    });

    test('مرتجع مبيعات نقدي: يعيد المخزون، يستعيد التكلفة التاريخية، ولا ينشئ حركة دين على العميل', () async {
      final now = DateTime.now();
      // 1. إنشاء منتج بمخزون 10 وتكلفة متوسطة 20,000 وسعر بيع 30,000
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طاولة طعام خشبية',
          salePrice: 30000,
          purchasePrice: 20000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 10.0,
      );

      // 2. بيع 4 قطع نقداً
      final invoice = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: '',
          customerId: null,
          invoiceDate: now,
          subtotal: 120000,
          discount: 0,
          totalAmount: 120000,
          paidAmount: 120000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          createdAt: now,
          updatedAt: now,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              productName: product.name,
              quantity: 4,
              unitPrice: 30000,
              unitCostAtSale: 20000,
              total: 120000,
              costTotal: 80000,
            ),
          ],
        ),
      );

      // المخزون بعد البيع أصبح 6
      var updatedProd = await productsRepo.getProductById(product.id);
      expect(updatedProd.currentStock, equals(6.0));

      // 3. إرجاع قطعتين من الفاتورة
      final salesReturn = await returnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: '',
          salesInvoiceId: invoice.id,
          customerId: null,
          returnDate: now,
          total: 60000,
          refundAmount: 60000,
          debtReductionAmount: 0,
          notes: 'إرجاع قطعتين نقداً',
          createdAt: now,
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: product.id,
              quantity: 2,
              unitPrice: 30000,
              unitCostAtSale: 20000,
              total: 60000,
            ),
          ],
        ),
      );

      expect(salesReturn.id, isPositive);
      expect(salesReturn.returnNumber, startsWith('SRET-'));
      expect(salesReturn.refundAmount, equals(60000));
      expect(salesReturn.debtReductionAmount, equals(0));

      // 4. التحقق من عودة المخزون إلى 8
      updatedProd = await productsRepo.getProductById(product.id);
      expect(updatedProd.currentStock, equals(8.0));
      // التكلفة التاريخية مستعادة
      expect(updatedProd.averageCost, equals(20000.0));
    });

    test('مرتجع مبيعات آجل: يخفض دين العميل في أستاذ العميل تلقائياً ويعيد المخزون', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(id: 0, name: 'سالم الكندي', phone: '777123456', createdAt: now, updatedAt: now),
      );

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم كنب ملكي',
          salePrice: 100000,
          purchasePrice: 70000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 5.0,
      );

      // بيع آجل لطقمين (200,000 دين)
      final invoice = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: '',
          customerId: customerId,
          invoiceDate: now,
          subtotal: 200000,
          totalAmount: 200000,
          paidAmount: 0,
          remainingAmount: 200000,
          paymentType: SalesPaymentType.credit,
          createdAt: now,
          updatedAt: now,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 2,
              unitPrice: 100000,
              unitCostAtSale: 70000,
              total: 200000,
              costTotal: 140000,
            ),
          ],
        ),
      );

      expect(await ledgerRepo.getCustomerBalance(customerId), equals(200000));

      // إرجاع طقم واحد (100,000)
      await returnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: '',
          salesInvoiceId: invoice.id,
          customerId: customerId,
          returnDate: now,
          total: 100000,
          refundAmount: 0,
          debtReductionAmount: 100000,
          createdAt: now,
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 100000,
              unitCostAtSale: 70000,
              total: 100000,
            ),
          ],
        ),
      );

      // التحقق من انخفاض دين العميل في الأستاذ إلى 100,000
      expect(await ledgerRepo.getCustomerBalance(customerId), equals(100000));
      final updatedCust = await customersRepo.getCustomerById(customerId);
      expect(updatedCust.currentBalance, equals(100000));

      // المخزون كان 3 وأصبح 4 بعد الإرجاع
      final prod = await productsRepo.getProductById(product.id);
      expect(prod.currentStock, equals(4.0));
    });

    test('يرفض إرجاع كمية تتجاوز الكمية المباعة المتاحة في الفاتورة', () async {
      final now = DateTime.now();
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مرتبة طبية',
          salePrice: 50000,
          purchasePrice: 35000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 10.0,
      );

      // بيع قطعتين
      final invoice = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: '',
          invoiceDate: now,
          subtotal: 100000,
          totalAmount: 100000,
          paidAmount: 100000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          createdAt: now,
          updatedAt: now,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 2,
              unitPrice: 50000,
              unitCostAtSale: 35000,
              total: 100000,
              costTotal: 70000,
            ),
          ],
        ),
      );

      // محاولة إرجاع 3 قطع (المباع فقط 2)
      expect(
        () => returnsRepo.createReturn(
          SalesReturn(
            id: 0,
            returnNumber: '',
            salesInvoiceId: invoice.id,
            returnDate: now,
            total: 150000,
            refundAmount: 150000,
            createdAt: now,
            items: [
              SalesReturnItem(
                id: 0,
                salesReturnId: 0,
                productId: product.id,
                quantity: 3,
                unitPrice: 50000,
                unitCostAtSale: 35000,
                total: 150000,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يرفض تكرار الإرجاع التراكمي إذا تجاوز مجموع المرتجعات الكمية المباعة', () async {
      final now = DateTime.now();
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'كرسي مريح',
          salePrice: 20000,
          purchasePrice: 12000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 10.0,
      );

      final invoice = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: '',
          invoiceDate: now,
          subtotal: 40000,
          totalAmount: 40000,
          paidAmount: 40000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          createdAt: now,
          updatedAt: now,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 2,
              unitPrice: 20000,
              unitCostAtSale: 12000,
              total: 40000,
              costTotal: 24000,
            ),
          ],
        ),
      );

      // إرجاع أول: قطعة واحدة (مقبول)
      await returnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: '',
          salesInvoiceId: invoice.id,
          returnDate: now,
          total: 20000,
          refundAmount: 20000,
          createdAt: now,
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 20000,
              unitCostAtSale: 12000,
              total: 20000,
            ),
          ],
        ),
      );

      // إرجاع ثانٍ: محاولة إرجاع قطعتين (المتاح المتبقي 1 فقط)
      expect(
        () => returnsRepo.createReturn(
          SalesReturn(
            id: 0,
            returnNumber: '',
            salesInvoiceId: invoice.id,
            returnDate: now,
            total: 40000,
            refundAmount: 40000,
            createdAt: now,
            items: [
              SalesReturnItem(
                id: 0,
                salesReturnId: 0,
                productId: product.id,
                quantity: 2,
                unitPrice: 20000,
                unitCostAtSale: 12000,
                total: 40000,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
