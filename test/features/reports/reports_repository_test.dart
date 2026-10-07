import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/features/cash/data/repositories/cashbox_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/expenses/data/repositories/expenses_repository_impl.dart';
import 'package:sales/features/expenses/domain/entities/expense.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/purchases/data/repositories/purchase_returns_repository_impl.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/purchases/domain/entities/purchase_return.dart';
import 'package:sales/features/purchases/domain/entities/purchase_return_item.dart';
import 'package:sales/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:sales/features/reports/domain/entities/date_range.dart';
import 'package:sales/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:sales/features/sales/data/repositories/sales_returns_repository_impl.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/entities/sales_return.dart';
import 'package:sales/features/sales/domain/entities/sales_return_item.dart';
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

  group('ReportsRepository Tests (نظام التقارير الشامل والأرباح والخسائر والمخزون)', () {
    late DatabaseService dbService;
    late ReportsRepositoryImpl reportsRepo;
    late ProductsRepositoryImpl productsRepo;
    late CustomersRepositoryImpl customersRepo;
    late SuppliersRepositoryImpl suppliersRepo;
    late SalesRepositoryImpl salesRepo;
    late SalesReturnsRepositoryImpl salesReturnsRepo;
    late PurchasesRepositoryImpl purchasesRepo;
    late PurchaseReturnsRepositoryImpl purchaseReturnsRepo;
    late ExpensesRepositoryImpl expensesRepo;
    late CashboxRepositoryImpl cashboxRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      reportsRepo = ReportsRepositoryImpl(dbService: dbService);
      productsRepo = ProductsRepositoryImpl(databaseService: dbService);
      customersRepo = CustomersRepositoryImpl(dbService: dbService);
      suppliersRepo = SuppliersRepositoryImpl(databaseService: dbService);
      salesRepo = SalesRepositoryImpl(dbService: dbService);
      salesReturnsRepo = SalesReturnsRepositoryImpl(dbService: dbService);
      purchasesRepo = PurchasesRepositoryImpl(databaseService: dbService);
      purchaseReturnsRepo = PurchaseReturnsRepositoryImpl(dbService: dbService);
      expensesRepo = ExpensesRepositoryImpl(dbService: dbService);
      cashboxRepo = CashboxRepositoryImpl(dbService: dbService);
    });

    test('فترة بلا عمليات تعيد بيانات فارغة بأصفار دون استثناءات أو أخطاء', () async {
      final todayRange = DateRange.today();
      final sales = await reportsRepo.getSalesReport(todayRange);
      expect(sales.grossSales, 0);
      expect(sales.netSales, 0);
      expect(sales.invoices, isEmpty);

      final purchases = await reportsRepo.getPurchasesReport(todayRange);
      expect(purchases.grossPurchases, 0);
      expect(purchases.netPurchases, 0);

      final pl = await reportsRepo.getProfitLossReport(todayRange);
      expect(pl.netSales, 0);
      expect(pl.grossProfit, 0.0);
      expect(pl.netProfit, 0.0);

      final exp = await reportsRepo.getExpensesReport(todayRange);
      expect(exp.totalExpenses, 0);
      expect(exp.expenses, isEmpty);
    });

    test('تقرير المبيعات ومرتجع المبيعات وحساب صافي المبيعات والآجل بدقة', () async {
      // 1. إنشاء منتج وعميل بمخزون أولي
      final prod = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم كنب تركي فاخر',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 200000,
          salePrice: 300000,
          currentStock: 10.0,
          minimumStock: 2.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      final custId = await customersRepo.createCustomer(Customer(
        id: 0,
        name: 'العميل عبدالله المالي',
        phone: '771122334',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 2. فاتورة مبيعات نقدية بـ 300,000
      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-101',
          customerId: custId,
          invoiceDate: DateTime.now(),
          subtotal: 300000,
          totalAmount: 300000,
          paidAmount: 300000,
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
              unitPrice: 300000,
              unitCostAtSale: 200000.0,
              total: 300000,
              costTotal: 200000.0,
            ),
          ],
        ),
      );

      // 3. فاتورة مبيعات آجلة بـ 600,000 (دفعة 100,000 ومتبقي 500,000)
      final creditInv = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-102',
          customerId: custId,
          invoiceDate: DateTime.now(),
          subtotal: 600000,
          totalAmount: 600000,
          paidAmount: 100000,
          remainingAmount: 500000,
          paymentType: SalesPaymentType.credit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: prod.id,
              quantity: 2.0,
              unitPrice: 300000,
              unitCostAtSale: 200000.0,
              total: 600000,
              costTotal: 400000.0,
            ),
          ],
        ),
      );

      // 4. مرتجع بيع بمبلغ 300,000 خفض دين الفاتورة الآجلة
      await salesReturnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: 'RET-101',
          salesInvoiceId: creditInv.id,
          customerId: custId,
          returnDate: DateTime.now(),
          total: 300000,
          refundAmount: 0,
          debtReductionAmount: 300000,
          createdAt: DateTime.now(),
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: prod.id,
              quantity: 1.0,
              unitPrice: 300000,
              unitCostAtSale: 200000.0,
              total: 300000,
            ),
          ],
        ),
      );

      final report = await reportsRepo.getSalesReport(DateRange.today());

      expect(report.invoiceCount, 2);
      expect(report.grossSales, 900000);
      expect(report.returnsTotal, 300000);
      expect(report.netSales, 600000);
      expect(report.cashPaidTotal, 400000);
      expect(report.creditSalesTotal, 600000);
      expect(report.remainingDebtTotal, 200000);
      expect(report.invoices.length, 2);
    });

    test('تقرير الأرباح والخسائر (Profit & Loss) بالتكلفة التاريخية والمصروفات', () async {
      // 1. تأسيس رصيد الصندوق
      await cashboxRepo.setOpeningBalance(1000000);

      // 2. منتج بتكلفة 150,000 وسعر بيع 250,000 ومخزون أولي
      final prod = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم طاولة سفرة 8 كراسي',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 150000,
          salePrice: 250000,
          currentStock: 5.0,
          minimumStock: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 5.0,
      );

      // 3. بيع قطعتين (إجمالي 500,000، التكلفة التاريخية 300,000، الربح الإجمالي 200,000)
      final inv = await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-201',
          invoiceDate: DateTime.now(),
          subtotal: 500000,
          totalAmount: 500000,
          paidAmount: 500000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: prod.id,
              quantity: 2.0,
              unitPrice: 250000,
              unitCostAtSale: 150000.0,
              total: 500000,
              costTotal: 300000.0,
            ),
          ],
        ),
      );

      // 4. إرجاع قطعة واحدة (مردود 250,000، استعادة تكلفة تاريخية 150,000)
      await salesReturnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: 'RET-201',
          salesInvoiceId: inv.id,
          returnDate: DateTime.now(),
          total: 250000,
          refundAmount: 250000,
          debtReductionAmount: 0,
          createdAt: DateTime.now(),
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: prod.id,
              quantity: 1.0,
              unitPrice: 250000,
              unitCostAtSale: 150000.0,
              total: 250000,
            ),
          ],
        ),
      );

      // 5. تسجيل مصروف تشغيلي (إيجار 30,000)
      await expensesRepo.createExpense(Expense(
        id: 0,
        categoryName: 'إيجار',
        amount: 30000,
        expenseDate: DateTime.now(),
        description: 'إيجار معرض شهر أكتوبر',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final pl = await reportsRepo.getProfitLossReport(DateRange.today());

      expect(pl.grossSales, 500000);
      expect(pl.salesReturns, 250000);
      expect(pl.netSales, 250000); // 500,000 - 250,000
      expect(pl.grossCogs, 300000.0);
      expect(pl.returnedCogs, 150000.0);
      expect(pl.netCogs, 150000.0); // 300,000 - 150,000
      expect(pl.grossProfit, 100000.0); // 250,000 - 150,000
      expect(pl.operatingExpenses, 30000);
      expect(pl.netProfit, 70000.0); // 100,000 - 30,000
      expect(pl.profitMargin, closeTo(28.0, 0.1));
    });

    test('ثبات التكلفة التاريخية: تعديل متوسط تكلفة المنتج لاحقاً لا يغير أرباح المبيعات السابقة', () async {
      final prod = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مرتبة طبية مقاس كينج',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 100000,
          salePrice: 160000,
          currentStock: 10.0,
          minimumStock: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      // مبيعات تمت بتكلفة 100,000
      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-HIST',
          invoiceDate: DateTime.now(),
          subtotal: 160000,
          totalAmount: 160000,
          paidAmount: 160000,
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
              unitPrice: 160000,
              unitCostAtSale: 100000.0,
              total: 160000,
              costTotal: 100000.0,
            ),
          ],
        ),
      );

      final initialPL = await reportsRepo.getProfitLossReport(DateRange.today());
      expect(initialPL.netCogs, 100000.0);
      expect(initialPL.grossProfit, 60000.0);

      // تعديل تكلفة المنتج في قاعدة البيانات (ارتفعت إلى 140,000)
      final existingProd = await productsRepo.getProductById(prod.id);
      await productsRepo.updateProduct(existingProd.copyWith(
        purchasePrice: 140000,
        averageCost: 140000.0,
      ));

      // تقرير الأرباح للمبيعات القديمة يجب ألا يتغير إطلاقاً
      final subsequentPL = await reportsRepo.getProfitLossReport(DateRange.today());
      expect(subsequentPL.netCogs, 100000.0);
      expect(subsequentPL.grossProfit, 60000.0);
    });

    test('تقرير المشتريات ومرتجع المشتريات وصافي المشتريات', () async {
      await cashboxRepo.setOpeningBalance(500000);

      final supp = await suppliersRepo.createSupplier(Supplier(
        id: 0,
        name: 'مورد مفروشات الشرق',
        phone: '773344556',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final prod = await productsRepo.createProduct(Product(
        id: 0,
        name: 'مفرش سرير مطرز',
        categoryId: 1,
        unitId: 1,
        purchasePrice: 50000,
        salePrice: 80000,
        currentStock: 0.0,
        minimumStock: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // فاتورة مشتريات بـ 250,000
      final pInv = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PINV-01',
          supplierId: supp.id,
          invoiceDate: DateTime.now(),
          subtotal: 250000,
          total: 250000,
          paidAmount: 100000,
          remainingAmount: 150000,
          paymentType: PurchasePaymentType.credit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: prod.id,
            quantity: 5.0,
            unitCost: 50000,
            total: 250000,
          ),
        ],
      );

      // مردود مشتريات بـ 50,000
      await purchaseReturnsRepo.createReturn(
        PurchaseReturn(
          id: 0,
          returnNumber: 'PRET-01',
          purchaseInvoiceId: pInv.id,
          supplierId: supp.id,
          returnDate: DateTime.now(),
          total: 50000,
          debtReductionAmount: 50000,
          createdAt: DateTime.now(),
          items: [
            PurchaseReturnItem(
              id: 0,
              purchaseReturnId: 0,
              productId: prod.id,
              quantity: 1.0,
              unitCost: 50000,
              total: 50000,
            ),
          ],
        ),
      );

      final pReport = await reportsRepo.getPurchasesReport(DateRange.today());
      expect(pReport.grossPurchases, 250000);
      expect(pReport.returnsTotal, 50000);
      expect(pReport.netPurchases, 200000);
      expect(pReport.creditPurchasesTotal, 250000);
    });

    test('تقرير المخزون وحساب القيمة بالتكلفة والأصناف منخفضة المخزون', () async {
      await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'لحاف مخمل شتوي',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 20000,
          salePrice: 35000,
          currentStock: 2.0,
          minimumStock: 5.0, // منخفض المخزون
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 2.0,
      );

      await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مخدة نوم قطنية',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 10000,
          salePrice: 18000,
          currentStock: 10.0,
          minimumStock: 4.0, // متوفر
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      final invReport = await reportsRepo.getInventoryReport();
      // 2 * 20,000 + 10 * 10,000 = 140,000
      expect(invReport.totalInventoryCostValue, 140000.0);
      expect(invReport.totalProductsCount, 2);
      expect(invReport.lowStockCount, 1);
      expect(invReport.inStockCount, 1);
    });

    test('التقرير السنوي وتجميع الشهور الـ 12', () async {
      final now = DateTime.now();
      final yearly = await reportsRepo.getYearlyReport(now.year);
      expect(yearly.year, now.year);
      expect(yearly.monthlyBreakdown.length, 12);
      expect(yearly.monthlyBreakdown.first.monthName, 'يناير');
      expect(yearly.monthlyBreakdown.last.monthName, 'ديسمبر');
    });
  });
}
