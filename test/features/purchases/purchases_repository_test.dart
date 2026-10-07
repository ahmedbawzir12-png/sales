import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/data/repositories/stock_movements_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/entities/stock_movement.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/cash/data/repositories/cashbox_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('PurchasesRepository Tests (دورة المشتريات والمخزون والتكلفة المرجحة)', () {
    setUp(() async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      await CashboxRepositoryImpl().setOpeningBalance(10000000);
    });

    test('شراء نقدي كامل: يزيد المخزون، يحدث متوسط التكلفة، يسجل حركة الشراء، ولا ينشئ ديناً على المورد', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final stockRepo = StockMovementsRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      // إنشاء منتج برصيد أولي 10 بسعر تكلفة 50,000
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم مخدات طبية فندقية',
          categoryId: 5,
          unitId: 1,
          purchasePrice: 50000,
          salePrice: 75000,
          currentStock: 10.0,
          averageCost: 50000.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // إنشاء فاتورة شراء نقدي: 5 قطع بسعر تكلفة 60,000 (إجمالي 300,000)
      final invoiceNumber = await purchasesRepo.generateNextInvoiceNumber();
      final invoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: invoiceNumber,
        supplierId: supplier.id,
        invoiceDate: DateTime.now(),
        subtotal: 300000,
        discount: 0,
        total: 300000,
        paidAmount: 300000,
        remainingAmount: 0,
        paymentType: PurchasePaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: product.id,
          quantity: 5.0,
          unitCost: 60000,
          total: 300000,
        ),
      ];

      final createdInvoice = await purchasesRepo.createPurchaseInvoice(
        invoice: invoice,
        items: items,
      );

      expect(createdInvoice.id, greaterThan(0));
      expect(createdInvoice.isPaidInFull, isTrue);

      // 1. التحقق من زيادة المخزون: 10 + 5 = 15
      final updatedProduct = await productsRepo.getProductById(product.id);
      expect(updatedProduct.currentStock, equals(15.0));

      // 2. التحقق من حساب المتوسط المرجح: (10 * 50,000 + 5 * 60,000) / 15 = 53,333.33
      expect(updatedProduct.averageCost, equals(53333.33));

      // 3. التحقق من تحديث آخر سعر شراء
      expect(updatedProduct.purchasePrice, equals(60000));

      // 4. التحقق من تسجيل حركة المخزون من نوع purchase وربطها برقم الفاتورة
      final movements = await stockRepo.getMovementsByProductId(product.id);
      final purchaseMovement = movements.firstWhere(
        (m) => m.movementType == StockMovementType.purchase,
      );
      expect(purchaseMovement.quantity, equals(5.0));
      expect(purchaseMovement.stockBefore, equals(10.0));
      expect(purchaseMovement.stockAfter, equals(15.0));
      expect(purchaseMovement.reference, equals(invoiceNumber));

      // 5. المورد لم يزدد رصيد دينه لأن الفاتورة مسددة نقداً
      final updatedSupplier = await suppliersRepo.getSupplierById(supplier.id);
      expect(updatedSupplier.currentBalance, equals(0));
    });

    test('شراء آجل جزئي: يسجل المتبقي كدين على المورد بدقة', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مرتبة طبية ملكية',
          categoryId: 3,
          unitId: 1,
          purchasePrice: 100000,
          salePrice: 150000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // شراء 2 مراتب @ 100,000 = 200,000
      // مدفوع 50,000 ومتبقي 150,000 (آجل)
      final invoiceNumber = await purchasesRepo.generateNextInvoiceNumber();
      final invoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: invoiceNumber,
        supplierId: supplier.id,
        invoiceDate: DateTime.now(),
        subtotal: 200000,
        discount: 0,
        total: 200000,
        paidAmount: 50000,
        remainingAmount: 150000,
        paymentType: PurchasePaymentType.credit,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: product.id,
          quantity: 2.0,
          unitCost: 100000,
          total: 200000,
        ),
      ];

      await purchasesRepo.createPurchaseInvoice(invoice: invoice, items: items);

      final updatedSupplier = await suppliersRepo.getSupplierById(supplier.id);
      expect(updatedSupplier.currentBalance, equals(150000));
    });

    test('الخصم المالي: يقلل من صافي الفاتورة بدقة', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم ستائر تركي فاخر',
          categoryId: 4,
          unitId: 1,
          purchasePrice: 100000,
          salePrice: 160000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // سطر بقيمة 100,000 مع خصم 10,000 -> صافي 90,000
      final invoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: 'PUR-DISC-01',
        supplierId: supplier.id,
        invoiceDate: DateTime.now(),
        subtotal: 100000,
        discount: 10000,
        total: 90000,
        paidAmount: 90000,
        remainingAmount: 0,
        paymentType: PurchasePaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: product.id,
          quantity: 1.0,
          unitCost: 100000,
          total: 100000,
        ),
      ];

      final result = await purchasesRepo.createPurchaseInvoice(
        invoice: invoice,
        items: items,
      );

      expect(result.subtotal, equals(100000));
      expect(result.discount, equals(10000));
      expect(result.total, equals(90000));
    });

    test('الذرية (Atomicity): فشل أي خطوة داخل المعاملة يلغي كامل الفاتورة وتأثير المخزون', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'سجادة أرضية حرير',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 80000,
          salePrice: 120000,
          currentStock: 5.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 5.0,
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // فاتورة تحتوي صنف صحيح وصنف آخر بمعرف وهمي غير موجود لإحداث فشل في المعاملة
      final invoice = PurchaseInvoice(
        id: 0,
        invoiceNumber: 'PUR-FAIL-01',
        supplierId: supplier.id,
        invoiceDate: DateTime.now(),
        subtotal: 160000,
        total: 160000,
        paymentType: PurchasePaymentType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final invalidItems = [
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: product.id,
          quantity: 1.0,
          unitCost: 80000,
          total: 80000,
        ),
        PurchaseInvoiceItem(
          id: 0,
          purchaseInvoiceId: 0,
          productId: 999999, // غير موجود!
          quantity: 1.0,
          unitCost: 80000,
          total: 80000,
        ),
      ];

      expect(
        () => purchasesRepo.createPurchaseInvoice(invoice: invoice, items: invalidItems),
        throwsA(isA<AppException>()),
      );

      // التأكد التام من أن رصيد المنتج لم يتغير وبقي 5.0
      final checkProduct = await productsRepo.getProductById(product.id);
      expect(checkProduct.currentStock, equals(5.0));

      // التأكد من عدم إنشاء أي فاتورة في قاعدة البيانات
      final invoices = await purchasesRepo.getInvoices(searchQuery: 'PUR-FAIL-01');
      expect(invoices, isEmpty);
    });

    test('إلغاء فاتورة شراء: يخصم المخزون بحركة عكسية ويخفض دين المورد ويحمي من المخزون السالب', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final stockRepo = StockMovementsRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'لحاف شتوي تركي',
          categoryId: 5,
          unitId: 1,
          purchasePrice: 30000,
          salePrice: 45000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // شراء 4 قطع آجل بالكامل (120,000)
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-CANCEL-01',
          supplierId: supplier.id,
          invoiceDate: DateTime.now(),
          subtotal: 120000,
          total: 120000,
          paidAmount: 0,
          remainingAmount: 120000,
          paymentType: PurchasePaymentType.credit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 4.0,
            unitCost: 30000,
            total: 120000,
          ),
        ],
      );

      expect((await productsRepo.getProductById(product.id)).currentStock, equals(4.0));
      expect((await suppliersRepo.getSupplierById(supplier.id)).currentBalance, equals(120000));

      // إلغاء الفاتورة
      await purchasesRepo.cancelPurchaseInvoice(
        invoice.id,
        reason: 'خطأ في استلام البضاعة من المورد',
      );

      // 1. المخزون عاد إلى صفر
      final productAfterCancel = await productsRepo.getProductById(product.id);
      expect(productAfterCancel.currentStock, equals(0.0));

      // 2. حركة عكسية purchaseReturn تم تسجيلها
      final movements = await stockRepo.getMovementsByProductId(product.id);
      expect(movements.any((m) => m.movementType == StockMovementType.purchaseReturn), isTrue);

      // 3. دين المورد انخفض وعاد إلى صفر
      final supplierAfterCancel = await suppliersRepo.getSupplierById(supplier.id);
      expect(supplierAfterCancel.currentBalance, equals(0));

      // 4. حالة الفاتورة أصبحت ملغاة
      final cancelledInvoice = await purchasesRepo.getInvoiceById(invoice.id);
      expect(cancelledInvoice.isCancelled, isTrue);

      // 5. محاولة إلغائها مرة أخرى تُرفض
      expect(
        () => purchasesRepo.cancelPurchaseInvoice(invoice.id, reason: 'إلغاء ثان'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يرفض إلغاء الفاتورة إذا كان رصيد المخزون الحالي أقل من الكمية المشتراة لمنع السالب', () async {
      final productsRepo = ProductsRepositoryImpl();
      final purchasesRepo = PurchasesRepositoryImpl();
      final stockRepo = StockMovementsRepositoryImpl();
      final suppliersRepo = SuppliersRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم كنب صالون',
          categoryId: 2,
          unitId: 1,
          purchasePrice: 200000,
          salePrice: 300000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final suppliers = await suppliersRepo.getSuppliers();
      final supplier = suppliers.first;

      // شراء 3 أطقم كنب
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-STOCK-CHECK-01',
          supplierId: supplier.id,
          invoiceDate: DateTime.now(),
          subtotal: 600000,
          total: 600000,
          paymentType: PurchasePaymentType.cash,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 3.0,
            unitCost: 200000,
            total: 600000,
          ),
        ],
      );

      // تم سحب طقمين (مثلاً تسوية عجز أو بيع لاحقاً) بحيث أصبح الرصيد 1 فقط
      await stockRepo.adjustStock(
        productId: product.id,
        actualPhysicalStock: 1.0,
        reason: 'تسوية قبل الإلغاء',
      );

      // الآن رصيد المنتج هو 1، بينما الفاتورة كان فيها 3.
      // محاولة إلغاء الفاتورة بالكامل يجب أن تُرْفَض لأن 1 - 3 = -2 سالب!
      expect(
        () => purchasesRepo.cancelPurchaseInvoice(invoice.id, reason: 'محاولة إلغاء مع رصيد غير كافٍ'),
        throwsA(isA<ValidationException>()),
      );

      // التأكد من أن الرصيد لم ينزل للسالب وبقي 1.0
      final checkProduct = await productsRepo.getProductById(product.id);
      expect(checkProduct.currentStock, equals(1.0));
    });
  });
}
