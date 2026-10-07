import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/cash/data/repositories/cashbox_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/data/repositories/stock_movements_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/entities/stock_movement.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_status.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService dbService;
  late SalesRepositoryImpl salesRepo;
  late ProductsRepositoryImpl productsRepo;
  late CustomersRepositoryImpl customersRepo;
  late StockMovementsRepositoryImpl stockMovementsRepo;
  late PurchasesRepositoryImpl purchasesRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.initForTesting(inMemory: true);

    salesRepo = SalesRepositoryImpl(dbService: dbService);
    productsRepo = ProductsRepositoryImpl(databaseService: dbService);
    customersRepo = CustomersRepositoryImpl(dbService: dbService);
    stockMovementsRepo = StockMovementsRepositoryImpl(databaseService: dbService);
    purchasesRepo = PurchasesRepositoryImpl(databaseService: dbService);
    await CashboxRepositoryImpl(dbService: dbService).setOpeningBalance(10000000);
  });

  tearDown(() async {
    await dbService.close();
  });

  // مساعد لإنشاء منتج برصيد وتكلفة محددة
  Future<Product> createTestProduct({
    required String name,
    required double stock,
    required int purchasePrice,
    required int salePrice,
  }) async {
    final now = DateTime.now();
    final p = Product(
      id: 0,
      name: name,
      categoryId: 1,
      unitId: 1,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      averageCost: purchasePrice.toDouble(),
      currentStock: 0,
      createdAt: now,
      updatedAt: now,
    );
    final created = await productsRepo.createProduct(p);

    if (stock > 0) {
      await stockMovementsRepo.recordMovement(
        productId: created.id,
        type: StockMovementType.initialStock,
        quantity: stock,
        reason: 'رصيد اختباري أولي',
      );
    }
    return productsRepo.getProductById(created.id);
  }

  group('SalesRepository Tests (دورة المبيعات والمخزون وتكلفة البيع)', () {
    test('بيع نقدي كامل: ينقص المخزون، يسجل حركة بيع، يحفظ تكلفة البيع، ولا ينشئ ديناً', () async {
      final product = await createTestProduct(
        name: 'مخدة نوم فاخرة',
        stock: 10,
        purchasePrice: 60000,
        salePrice: 80000,
      );

      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0001',
        invoiceDate: DateTime.now(),
        subtotal: 240000,
        totalAmount: 240000,
        paidAmount: 240000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 3,
            unitPrice: 80000,
            unitCostAtSale: 60000,
            total: 240000,
            costTotal: 180000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await salesRepo.createInvoice(invoice);

      expect(saved.id, greaterThan(0));
      expect(saved.totalAmount, equals(240000));
      expect(saved.remainingAmount, equals(0));

      // 1. التحقق من تناقص رصيد المنتج
      final updatedProduct = await productsRepo.getProductById(product.id);
      expect(updatedProduct.currentStock, equals(7.0));

      // 2. التحقق من تسجيل حركة المخزون نوعها sale
      final movements = await stockMovementsRepo.getMovementsByProductId(product.id);
      final saleMovement = movements.firstWhere((m) => m.movementType == StockMovementType.sale);
      expect(saleMovement.quantity, equals(3.0));
      expect(saleMovement.stockBefore, equals(10.0));
      expect(saleMovement.stockAfter, equals(7.0));

      // 3. التحقق من حفظ تكلفة البضاعة المباعة وقت البيع
      final fetchedInvoice = await salesRepo.getInvoiceById(saved.id);
      expect(fetchedInvoice.items.first.unitCostAtSale, equals(60000.0));
      expect(fetchedInvoice.items.first.costTotal, equals(180000.0));
      expect(fetchedInvoice.grossProfit, equals(60000.0));
    });

    test('بيع آجل جزئي: يسجل المتبقي كدين على العميل بدقة', () async {
      final product = await createTestProduct(
        name: 'طقم كنب تركي',
        stock: 5,
        purchasePrice: 150000,
        salePrice: 200000,
      );

      // استرجاع أحد العملاء
      final customers = await customersRepo.getCustomers();
      final customer = customers.firstWhere((c) => !c.isWalkInGeneralCustomer);

      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0002',
        customerId: customer.id,
        invoiceDate: DateTime.now(),
        subtotal: 200000,
        totalAmount: 200000,
        paidAmount: 80000,
        remainingAmount: 120000,
        paymentType: SalesPaymentType.credit,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 1,
            unitPrice: 200000,
            unitCostAtSale: 150000,
            total: 200000,
            costTotal: 150000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await salesRepo.createInvoice(invoice);

      // التحقق من أن دين العميل أصبح 120,000 ريال
      final debt = await customersRepo.getCustomerDebt(customer.id);
      expect(debt, equals(120000));
    });

    test('يرفض البيع الآجل بدون تحديد عميل (لزبون عام)', () async {
      final product = await createTestProduct(
        name: 'لحاف حرير',
        stock: 5,
        purchasePrice: 20000,
        salePrice: 30000,
      );

      final creditNoCustomerInvoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0003',
        customerId: null, // بدون عميل
        invoiceDate: DateTime.now(),
        subtotal: 30000,
        totalAmount: 30000,
        paidAmount: 0,
        remainingAmount: 30000,
        paymentType: SalesPaymentType.credit,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 1,
            unitPrice: 30000,
            unitCostAtSale: 20000,
            total: 30000,
            costTotal: 20000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => salesRepo.createInvoice(creditNoCustomerInvoice),
        throwsA(isA<ValidationException>()),
      );
    });

    test('التحقق الصارم من المخزون: يرفض بيع كمية أكبر من المتوفر ويلغي العملية بالكامل', () async {
      final product = await createTestProduct(
        name: 'ستارة مطرزة',
        stock: 2,
        purchasePrice: 15000,
        salePrice: 25000,
      );

      final excessiveInvoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0004',
        invoiceDate: DateTime.now(),
        subtotal: 125000,
        totalAmount: 125000,
        paidAmount: 125000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 5, // المطلوب 5 والمتاح 2 فقط
            unitPrice: 25000,
            unitCostAtSale: 15000,
            total: 125000,
            costTotal: 75000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => salesRepo.createInvoice(excessiveInvoice),
        throwsA(isA<ValidationException>()),
      );

      // التأكد أن المخزون لم يتغير إطلاقاً
      final checkProduct = await productsRepo.getProductById(product.id);
      expect(checkProduct.currentStock, equals(2.0));
    });

    test('تعديل سعر البيع في الفاتورة يحفظ السعر المخصص ولا يتأثر بتغيير سعر المنتج لاحقاً', () async {
      final product = await createTestProduct(
        name: 'مرتبة رويال',
        stock: 10,
        purchasePrice: 80000,
        salePrice: 100000,
      );

      // بيع بسعر خاص مخفض 90,000
      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0005',
        invoiceDate: DateTime.now(),
        subtotal: 90000,
        totalAmount: 90000,
        paidAmount: 90000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 1,
            unitPrice: 90000,
            unitCostAtSale: 80000,
            total: 90000,
            costTotal: 80000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await salesRepo.createInvoice(invoice);

      // تغيير سعر المنتج لاحقاً في بطاقة الصنف إلى 120,000
      await productsRepo.updateProduct(product.copyWith(salePrice: 120000));

      // التأكد أن الفاتورة التاريخية ما تزال تحتفظ بسعر البيع الفعلي 90,000
      final reloaded = await salesRepo.getInvoiceById(saved.id);
      expect(reloaded.items.first.unitPrice, equals(90000));
      expect(reloaded.totalAmount, equals(90000));
    });

    test('تثبيت تكلفة الوحدة وقت البيع (unitCostAtSale) لا يتغير بتغير تكلفة المخزون اللاحقة', () async {
      final product = await createTestProduct(
        name: 'مفرش سرير',
        stock: 5,
        purchasePrice: 50000,
        salePrice: 70000,
      );

      // بيع وحدة واحدة بتكلفة 50,000
      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0006',
        invoiceDate: DateTime.now(),
        subtotal: 70000,
        totalAmount: 70000,
        paidAmount: 70000,
        remainingAmount: 0,
        paymentType: SalesPaymentType.cash,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 1,
            unitPrice: 70000,
            unitCostAtSale: 50000,
            total: 70000,
            costTotal: 50000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await salesRepo.createInvoice(invoice);

      // شراء دفعة جديدة بسعر مرتفع يرفع متوسط التكلفة
      final purchaseInvoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: 'PUR-TEST-0001',
        supplierId: 1,
        invoiceDate: DateTime.now(),
        subtotal: 400000,
        total: 400000,
        paidAmount: 400000,
        remainingAmount: 0,
        paymentType: PurchasePaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final purchaseItems = [
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: product.id,
          quantity: 5,
          unitCost: 80000,
          total: 400000,
        ),
      ];

      await purchasesRepo.createPurchaseInvoice(
        invoice: purchaseInvoice,
        items: purchaseItems,
      );

      // التحقق من أن متوسط التكلفة في المنتج تغير
      final updatedProduct = await productsRepo.getProductById(product.id);
      expect(updatedProduct.averageCost, greaterThan(50000.0));

      // لكن الفاتورة السابقة يجب أن تبقى تكلفة الوحدة وقت البيع فيها 50,000 بدقة
      final invoiceAfter = await salesRepo.getInvoiceById(saved.id);
      expect(invoiceAfter.items.first.unitCostAtSale, equals(50000.0));
    });

    test('إلغاء فاتورة مبيعات: يرجع الكميات للمخزون، يسجل حركة عكسية، ويصفر دين العميل', () async {
      final product = await createTestProduct(
        name: 'كرسي مريح',
        stock: 8,
        purchasePrice: 30000,
        salePrice: 45000,
      );

      final customers = await customersRepo.getCustomers();
      final customer = customers.firstWhere((c) => !c.isWalkInGeneralCustomer);

      final invoice = SalesInvoice(
        id: 0,
        invoiceNumber: 'SAL-20261005-0007',
        customerId: customer.id,
        invoiceDate: DateTime.now(),
        subtotal: 90000,
        totalAmount: 90000,
        paidAmount: 0,
        remainingAmount: 90000,
        paymentType: SalesPaymentType.credit,
        items: [
          SalesInvoiceItem(
            id: 0,
            salesInvoiceId: 0,
            productId: product.id,
            quantity: 2,
            unitPrice: 45000,
            unitCostAtSale: 30000,
            total: 90000,
            costTotal: 60000,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await salesRepo.createInvoice(invoice);

      // رصيد المخزون بعد البيع
      var currentP = await productsRepo.getProductById(product.id);
      expect(currentP.currentStock, equals(6.0));
      expect(await customersRepo.getCustomerDebt(customer.id), equals(90000));

      // إلغاء الفاتورة
      await salesRepo.cancelInvoice(saved.id, reason: 'طلب العميل إلغاء الطلب');

      // 1. رصيد المخزون عاد إلى 8
      currentP = await productsRepo.getProductById(product.id);
      expect(currentP.currentStock, equals(8.0));

      // 2. حالة الفاتورة أصبحت cancelled
      final cancelledInvoice = await salesRepo.getInvoiceById(saved.id);
      expect(cancelledInvoice.status, equals(SalesInvoiceStatus.cancelled));

      // 3. دين العميل ألغي وعاد إلى صفر
      final debt = await customersRepo.getCustomerDebt(customer.id);
      expect(debt, equals(0));

      // 4. تسجيل حركة مخزون عكسية saleReturn
      final movements = await stockMovementsRepo.getMovementsByProductId(product.id);
      final returnMovement = movements.firstWhere((m) => m.movementType == StockMovementType.saleReturn);
      expect(returnMovement.quantity, equals(2.0));
      expect(returnMovement.stockBefore, equals(6.0));
      expect(returnMovement.stockAfter, equals(8.0));
    });
  });
}
