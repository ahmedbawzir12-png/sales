import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/features/cash/data/repositories/cashbox_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customer_payments_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/customers/domain/entities/customer_payment.dart';
import 'package:sales/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_payments_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
import 'package:sales/features/suppliers/domain/entities/supplier_payment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('DashboardRepository Tests (لوحة التحكم ومؤشرات الأداء المالي والرقابة الإدارية)', () {
    late DatabaseService dbService;
    late DashboardRepositoryImpl dashboardRepo;
    late CashboxRepositoryImpl cashboxRepo;
    late ProductsRepositoryImpl productsRepo;
    late CustomersRepositoryImpl customersRepo;
    late CustomerPaymentsRepositoryImpl customerPaymentsRepo;
    late SuppliersRepositoryImpl suppliersRepo;
    late SupplierPaymentsRepositoryImpl supplierPaymentsRepo;
    late SalesRepositoryImpl salesRepo;
    late PurchasesRepositoryImpl purchasesRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      dashboardRepo = DashboardRepositoryImpl(dbService: dbService);
      cashboxRepo = CashboxRepositoryImpl(dbService: dbService);
      productsRepo = ProductsRepositoryImpl(databaseService: dbService);
      customersRepo = CustomersRepositoryImpl(dbService: dbService);
      customerPaymentsRepo = CustomerPaymentsRepositoryImpl(dbService: dbService);
      suppliersRepo = SuppliersRepositoryImpl(databaseService: dbService);
      supplierPaymentsRepo = SupplierPaymentsRepositoryImpl(dbService: dbService);
      salesRepo = SalesRepositoryImpl(dbService: dbService);
      purchasesRepo = PurchasesRepositoryImpl(databaseService: dbService);
    });

    test('لوحة التحكم فارغة تعرض مؤشرات صفرية سليمة', () async {
      final summary = await dashboardRepo.getDashboardSummary();

      expect(summary.todayNetSales, 0);
      expect(summary.todayNetProfit, 0.0);
      expect(summary.todayExpenses, 0);
      expect(summary.monthNetSales, 0);
      expect(summary.monthNetProfit, 0.0);
      expect(summary.customerDebtTotal, 0);
      expect(summary.supplierDebtTotal, 0);
      expect(summary.cashBalance, 0);
      expect(summary.inventoryCostValue, 0.0);
      expect(summary.lowStockCount, 0);
      expect(summary.lowStockProducts, isEmpty);
    });

    test('سحب صاحب المحل يخفض الصندوق فقط ولا يغير الأرباح أو المصروفات التشغيلية', () async {
      // 1. إيداع رصيد افتتاحي بـ 500,000
      await cashboxRepo.setOpeningBalance(500000);

      // 2. تسجيل مبيعات بـ 200,000 (تكلفة 120,000، ربح 80,000)
      final prod = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'سرير أطفال مفروش',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 120000,
          salePrice: 200000,
          currentStock: 5.0,
          minimumStock: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 5.0,
      );

      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-OWN-1',
          invoiceDate: DateTime.now(),
          subtotal: 200000,
          totalAmount: 200000,
          paidAmount: 200000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: prod.id,
              quantity: 1.0,
              unitPrice: 200000,
              unitCostAtSale: 120000.0,
              total: 200000,
              costTotal: 120000.0,
            ),
          ],
        ),
      );

      final beforeWithdrawal = await dashboardRepo.getDashboardSummary();
      expect(beforeWithdrawal.cashBalance, 700000); // 500,000 + 200,000
      expect(beforeWithdrawal.todayNetProfit, 80000.0);
      expect(beforeWithdrawal.todayExpenses, 0);

      // 3. سحب صاحب المحل الشخصي بمبلغ 150,000
      await cashboxRepo.recordOwnerWithdrawal(150000, notes: 'سحب شخصي للمنزل');

      final afterWithdrawal = await dashboardRepo.getDashboardSummary();
      // الرصيد انخفض بمقدار 150,000
      expect(afterWithdrawal.cashBalance, 550000);
      // الأرباح والمصروفات لم تتأثر إطلاقاً
      expect(afterWithdrawal.todayNetProfit, 80000.0);
      expect(afterWithdrawal.todayExpenses, 0);
    });

    test('سند قبض العميل يزيد الصندوق ويخفض الدين ولا يؤثر على المبيعات أو الأرباح', () async {
      await cashboxRepo.setOpeningBalance(100000);

      final custId = await customersRepo.createCustomer(Customer(
        id: 0,
        name: 'سالم المحضار',
        phone: '778899001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final prod = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'كنبة مفردة كلاسيك',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 40000,
          salePrice: 70000,
          currentStock: 10.0,
          minimumStock: 2.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      // بيع آجل بـ 70,000 (دين كامل على العميل)
      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-CR-1',
          customerId: custId,
          invoiceDate: DateTime.now(),
          subtotal: 70000,
          totalAmount: 70000,
          paidAmount: 0,
          remainingAmount: 70000,
          paymentType: SalesPaymentType.credit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: prod.id,
              quantity: 1.0,
              unitPrice: 70000,
              unitCostAtSale: 40000.0,
              total: 70000,
              costTotal: 40000.0,
            ),
          ],
        ),
      );

      final beforePayment = await dashboardRepo.getDashboardSummary();
      expect(beforePayment.customerDebtTotal, 70000);
      expect(beforePayment.cashBalance, 100000);
      expect(beforePayment.todayNetSales, 70000);
      expect(beforePayment.todayNetProfit, 30000.0);

      // قبض دفعة 50,000 من العميل
      await customerPaymentsRepo.recordPayment(CustomerPayment(
        id: 0,
        paymentNumber: 'CPAY-01',
        customerId: custId,
        amount: 50000,
        paymentDate: DateTime.now(),
        notes: 'دفعة نقدية تحت الحساب',
        createdAt: DateTime.now(),
      ));

      final afterPayment = await dashboardRepo.getDashboardSummary();
      expect(afterPayment.customerDebtTotal, 20000); // انخفض الدين إلى 20,000
      expect(afterPayment.cashBalance, 150000); // زاد الصندوق بـ 50,000
      expect(afterPayment.todayNetSales, 70000); // المبيعات لم تتغير
      expect(afterPayment.todayNetProfit, 30000.0); // الأرباح لم تتغير
    });

    test('سند صرف المورد يخفض الصندوق ويخفض دين المورد ولا يؤثر على المشتريات أو الأرباح', () async {
      await cashboxRepo.setOpeningBalance(500000);

      final supp = await suppliersRepo.createSupplier(Supplier(
        id: 0,
        name: 'مصنع المراتب الذهبية',
        phone: '776655443',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final prod = await productsRepo.createProduct(Product(
        id: 0,
        name: 'مرتبة أسطورية',
        categoryId: 1,
        unitId: 1,
        purchasePrice: 100000,
        salePrice: 150000,
        currentStock: 0.0,
        minimumStock: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // شراء آجل بـ 200,000
      await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PINV-SP-1',
          supplierId: supp.id,
          invoiceDate: DateTime.now(),
          subtotal: 200000,
          total: 200000,
          paidAmount: 0,
          remainingAmount: 200000,
          paymentType: PurchasePaymentType.credit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: prod.id,
            quantity: 2.0,
            unitCost: 100000,
            total: 200000,
          ),
        ],
      );

      final beforePay = await dashboardRepo.getDashboardSummary();
      expect(beforePay.supplierDebtTotal, 200000);
      expect(beforePay.cashBalance, 500000);

      // صرف دفعة نقدية للمورد بـ 120,000
      await supplierPaymentsRepo.recordPayment(SupplierPayment(
        id: 0,
        paymentNumber: 'SPAY-01',
        supplierId: supp.id,
        amount: 120000,
        paymentDate: DateTime.now(),
        notes: 'دفعة شراء آجل للمورد',
        createdAt: DateTime.now(),
      ));

      final afterPay = await dashboardRepo.getDashboardSummary();
      expect(afterPay.supplierDebtTotal, 80000); // انخفض دين المورد
      expect(afterPay.cashBalance, 380000); // انخفض الصندوق بـ 120,000
      expect(afterPay.todayExpenses, 0); // دفع المورد ليس مصروفاً تشغيلياً!
    });
  });
}
