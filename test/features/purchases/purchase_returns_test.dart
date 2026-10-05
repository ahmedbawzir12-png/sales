import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/purchases/data/repositories/purchase_returns_repository_impl.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/purchases/domain/entities/purchase_return.dart';
import 'package:sales/features/purchases/domain/entities/purchase_return_item.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_ledger_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Purchase Returns Tests (دورة مرتجعات المشتريات وحماية المخزون السالب والديون)', () {
    late DatabaseService dbService;
    late ProductsRepositoryImpl productsRepo;
    late SuppliersRepositoryImpl suppliersRepo;
    late SupplierLedgerRepositoryImpl ledgerRepo;
    late PurchasesRepositoryImpl purchasesRepo;
    late PurchaseReturnsRepositoryImpl returnsRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      productsRepo = ProductsRepositoryImpl(databaseService: dbService);
      suppliersRepo = SuppliersRepositoryImpl(databaseService: dbService);
      ledgerRepo = SupplierLedgerRepositoryImpl(dbService: dbService);
      purchasesRepo = PurchasesRepositoryImpl(databaseService: dbService);
      returnsRepo = PurchaseReturnsRepositoryImpl(dbService: dbService);
    });

    test('مرتجع مشتريات نقدي: يخصم المخزون، يجهز استرداد نقدي، ولا ينشئ حركة دين على المورد', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مصنع الأخشاب الممتازة', phone: '777999111', createdAt: now, updatedAt: now),
      );

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'خزانة ملابس 4 درف',
          salePrice: 80000,
          purchasePrice: 50000,
          currentStock: 0,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // شراء 5 قطع نقداً
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-0001',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 250000,
          discount: 0,
          total: 250000,
          paidAmount: 250000,
          remainingAmount: 0,
          paymentType: PurchasePaymentType.cash,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 5,
            unitCost: 50000,
            total: 250000,
          ),
        ],
      );

      // المخزون أصبح 5
      expect((await productsRepo.getProductById(product.id)).currentStock, equals(5.0));

      // إرجاع قطعتين للمورد
      final purchaseReturn = await returnsRepo.createReturn(
        PurchaseReturn(
          id: 0,
          returnNumber: '',
          purchaseInvoiceId: invoice.id,
          supplierId: supplier.id,
          returnDate: now,
          total: 100000,
          refundAmount: 100000,
          debtReductionAmount: 0,
          notes: 'إرجاع قطعتين لوجود خدوش',
          createdAt: now,
          items: [
            PurchaseReturnItem(
              id: 0,
              purchaseReturnId: 0,
              productId: product.id,
              quantity: 2,
              unitCost: 50000,
              total: 100000,
            ),
          ],
        ),
      );

      expect(purchaseReturn.id, isPositive);
      expect(purchaseReturn.returnNumber, startsWith('PRET-'));
      expect(purchaseReturn.refundAmount, equals(100000));
      expect(purchaseReturn.debtReductionAmount, equals(0));

      // المخزون يجب أن ينقص بمقدار 2 ليصبح 3
      final updatedProd = await productsRepo.getProductById(product.id);
      expect(updatedProd.currentStock, equals(3.0));

      // لا يوجد دين على المورد
      expect(await ledgerRepo.getSupplierBalance(supplier.id), equals(0));
    });

    test('مرتجع مشتريات آجل: يخفض دين المورد في أستاذ المورد تلقائياً وينقص المخزون', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مؤسسة الزجاج والمرايا', phone: '777333222', createdAt: now, updatedAt: now),
      );

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مرآة جدارية كبيرة',
          salePrice: 25000,
          purchasePrice: 15000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 2.0,
      );

      // شراء آجل لـ 4 مرايا (60,000 دين)
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-0002',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 60000,
          discount: 0,
          total: 60000,
          paidAmount: 0,
          remainingAmount: 60000,
          paymentType: PurchasePaymentType.credit,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 4,
            unitCost: 15000,
            total: 60000,
          ),
        ],
      );

      expect(await ledgerRepo.getSupplierBalance(supplier.id), equals(60000));
      expect((await productsRepo.getProductById(product.id)).currentStock, equals(6.0));

      // إرجاع مرآتين (30,000)
      await returnsRepo.createReturn(
        PurchaseReturn(
          id: 0,
          returnNumber: '',
          purchaseInvoiceId: invoice.id,
          supplierId: supplier.id,
          returnDate: now,
          total: 30000,
          refundAmount: 0,
          debtReductionAmount: 30000,
          createdAt: now,
          items: [
            PurchaseReturnItem(
              id: 0,
              purchaseReturnId: 0,
              productId: product.id,
              quantity: 2,
              unitCost: 15000,
              total: 30000,
            ),
          ],
        ),
      );

      // الدين انخفض إلى 30,000
      expect(await ledgerRepo.getSupplierBalance(supplier.id), equals(30000));
      final updatedSupp = await suppliersRepo.getSupplierById(supplier.id);
      expect(updatedSupp.currentBalance, equals(30000));

      // المخزون نقص من 6 إلى 4
      final prod = await productsRepo.getProductById(product.id);
      expect(prod.currentStock, equals(4.0));
    });

    test('حماية المخزون السالب: يرفض إرجاع بضاعة للمورد إذا كان الرصيد الحالي بالمستودع غير كافٍ', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مصنع المكاتب', phone: '777444111', createdAt: now, updatedAt: now),
      );

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'كرسي دوار',
          salePrice: 40000,
          purchasePrice: 25000,
          currentStock: 0,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // شراء 5 كراسي
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-0003',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 125000,
          discount: 0,
          total: 125000,
          paidAmount: 125000,
          remainingAmount: 0,
          paymentType: PurchasePaymentType.cash,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 5,
            unitCost: 25000,
            total: 125000,
          ),
        ],
      );

      // لنفترض أنه تم بيع 4 كراسي لاحقاً وبقي في المخزون 1 فقط
      final db = await dbService.database;
      await db.update('products', {'current_stock': 1.0}, where: 'id = ?', whereArgs: [product.id]);

      // الآن محاولة إرجاع 3 كراسي للمورد (المشترى من الفاتورة كان 5 لكن رصيد المستودع الآن 1 فقط!)
      expect(
        () => returnsRepo.createReturn(
          PurchaseReturn(
            id: 0,
            returnNumber: '',
            purchaseInvoiceId: invoice.id,
            supplierId: supplier.id,
            returnDate: now,
            total: 75000,
            refundAmount: 75000,
            createdAt: now,
            items: [
              PurchaseReturnItem(
                id: 0,
                purchaseReturnId: 0,
                productId: product.id,
                quantity: 3,
                unitCost: 25000,
                total: 75000,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يرفض إرجاع كمية تتجاوز الكمية المشتراة في الفاتورة الأصلية', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مورد الستائر', phone: '777555888', createdAt: now, updatedAt: now),
      );

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'ستارة فاخرة',
          salePrice: 15000,
          purchasePrice: 10000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 10.0,
      );

      // شراء قطعتين
      final invoice = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-0004',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 20000,
          discount: 0,
          total: 20000,
          paidAmount: 20000,
          remainingAmount: 0,
          paymentType: PurchasePaymentType.cash,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 2,
            unitCost: 10000,
            total: 20000,
          ),
        ],
      );

      // محاولة إرجاع 4 قطع
      expect(
        () => returnsRepo.createReturn(
          PurchaseReturn(
            id: 0,
            returnNumber: '',
            purchaseInvoiceId: invoice.id,
            supplierId: supplier.id,
            returnDate: now,
            total: 40000,
            refundAmount: 40000,
            createdAt: now,
            items: [
              PurchaseReturnItem(
                id: 0,
                purchaseReturnId: 0,
                productId: product.id,
                quantity: 4,
                unitCost: 10000,
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
