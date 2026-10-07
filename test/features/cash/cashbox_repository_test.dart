import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/cash/data/repositories/cashbox_repository_impl.dart';
import 'package:sales/features/cash/domain/entities/cash_flow_direction.dart';
import 'package:sales/features/cash/domain/entities/cash_transaction.dart';
import 'package:sales/features/cash/domain/entities/cash_transaction_type.dart';
import 'package:sales/features/customers/data/repositories/customer_ledger_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customer_payments_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/customers/domain/entities/customer_ledger_entry.dart';
import 'package:sales/features/customers/domain/entities/customer_payment.dart';
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
import 'package:sales/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:sales/features/sales/data/repositories/sales_returns_repository_impl.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_item.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/entities/sales_return.dart';
import 'package:sales/features/sales/domain/entities/sales_return_item.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_ledger_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_payments_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier_ledger_entry.dart';
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

  group('CashboxRepository & Phase 6 Core Integrations (الصندوق والمصروفات وحركة النقدية)', () {
    late DatabaseService dbService;
    late CashboxRepositoryImpl cashboxRepo;
    late ExpensesRepositoryImpl expensesRepo;
    late SalesRepositoryImpl salesRepo;
    late PurchasesRepositoryImpl purchasesRepo;
    late CustomerPaymentsRepositoryImpl customerPaymentsRepo;
    late SupplierPaymentsRepositoryImpl supplierPaymentsRepo;
    late SalesReturnsRepositoryImpl salesReturnsRepo;
    late PurchaseReturnsRepositoryImpl purchaseReturnsRepo;
    late ProductsRepositoryImpl productsRepo;
    late CustomersRepositoryImpl customersRepo;
    late SuppliersRepositoryImpl suppliersRepo;
    late CustomerLedgerRepositoryImpl customerLedgerRepo;
    late SupplierLedgerRepositoryImpl supplierLedgerRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);

      cashboxRepo = CashboxRepositoryImpl(dbService: dbService);
      expensesRepo = ExpensesRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      salesRepo = SalesRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      purchasesRepo = PurchasesRepositoryImpl(databaseService: dbService, cashboxRepo: cashboxRepo);
      customerPaymentsRepo = CustomerPaymentsRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      supplierPaymentsRepo = SupplierPaymentsRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      salesReturnsRepo = SalesReturnsRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      purchaseReturnsRepo = PurchaseReturnsRepositoryImpl(dbService: dbService, cashboxRepo: cashboxRepo);
      productsRepo = ProductsRepositoryImpl(databaseService: dbService);
      customersRepo = CustomersRepositoryImpl(dbService: dbService);
      suppliersRepo = SuppliersRepositoryImpl(databaseService: dbService);
      customerLedgerRepo = CustomerLedgerRepositoryImpl(dbService: dbService);
      supplierLedgerRepo = SupplierLedgerRepositoryImpl(dbService: dbService);
    });

    // 1. تسجيل رصيد افتتاحي بنجاح
    test('1. تسجيل رصيد افتتاحي بنجاح وتحديث الرصيد التراكمي', () async {
      final tx = await cashboxRepo.setOpeningBalance(500000, notes: 'رصيد أول المدة');
      expect(tx.amount, equals(500000));
      expect(tx.direction, equals(CashFlowDirection.cashIn));
      expect(tx.type, equals(CashTransactionType.openingBalance));

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(500000));

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.openingBalance, equals(500000));
      expect(summary.currentBalance, equals(500000));
    });

    // 2. منع تكرار الرصيد الافتتاحي
    test('2. منع تكرار الرصيد الافتتاحي ورمي استثناء عند المحاولة مجدداً', () async {
      await cashboxRepo.setOpeningBalance(500000);
      expect(
        () => cashboxRepo.setOpeningBalance(300000),
        throwsA(isA<ValidationException>()),
      );
      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(500000));
    });

    // 3. بيع نقدي يزيد الصندوق
    test('3. بيع نقدي كامل يزيد رصيد الصندوق تلقائياً بحركة قبض cashIn', () async {
      final now = DateTime.now();
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طاولة طعام مودرن',
          salePrice: 150000,
          purchasePrice: 100000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 5.0,
      );

      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-CASH-001',
          customerId: null,
          invoiceDate: now,
          subtotal: 150000,
          totalAmount: 150000,
          paidAmount: 150000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 150000,
              unitCostAtSale: 100000,
              total: 150000,
              costTotal: 100000,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(150000));

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashIn, equals(150000));
      expect(summary.currentBalance, equals(150000));
    });

    // 4. بيع آجل كامل لا يؤثر على الصندوق
    test('4. بيع آجل كامل لا يؤثر على رصيد الصندوق مطلقاً', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(id: 0, name: 'سالم الكندي', phone: '777111222', createdAt: now, updatedAt: now),
      );
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'كرسي مكتب فاخر',
          salePrice: 80000,
          purchasePrice: 50000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 5.0,
      );

      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-CREDIT-001',
          customerId: customerId,
          invoiceDate: now,
          subtotal: 80000,
          totalAmount: 80000,
          paidAmount: 0,
          remainingAmount: 80000,
          paymentType: SalesPaymentType.credit,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 80000,
              unitCostAtSale: 50000,
              total: 80000,
              costTotal: 50000,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(0));
    });

    // 5. بيع آجل جزئي يزيد الصندوق بمقدار الدفعة فقط
    test('5. بيع آجل جزئي (دفعة نقدية) يزيد الصندوق بمقدار الدفعة المدفوعة فقط', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(id: 0, name: 'فهد العامري', phone: '777333444', createdAt: now, updatedAt: now),
      );
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم جلوس كلاسيك',
          salePrice: 500000,
          purchasePrice: 350000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        initialStock: 2.0,
      );

      await salesRepo.createInvoice(
        SalesInvoice(
          id: 0,
          invoiceNumber: 'INV-PARTIAL-001',
          customerId: customerId,
          invoiceDate: now,
          subtotal: 500000,
          totalAmount: 500000,
          paidAmount: 200000,
          remainingAmount: 300000,
          paymentType: SalesPaymentType.credit,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 500000,
              unitCostAtSale: 350000,
              total: 500000,
              costTotal: 350000,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(200000));
    });

    // 6. سند قبض من عميل يزيد الصندوق
    test('6. سند قبض من عميل يسجل دفعة ويزيد الصندوق بحركة customerPayment', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(id: 0, name: 'عمر باوزير', phone: '777555666', createdAt: now, updatedAt: now),
      );
      await customerLedgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: customerId,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 250000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 10,
          createdAt: now,
        ),
      );

      await customerPaymentsRepo.recordPayment(
        CustomerPayment(
          id: 0,
          paymentNumber: '',
          customerId: customerId,
          amount: 100000,
          paymentDate: now,
          paymentMethod: 'cash',
          notes: 'دفعة سداد حساب',
          createdAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(100000));

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashIn, equals(100000));
    });

    // 7. شراء نقدي يخصم من الصندوق
    test('7. شراء نقدي يخصم من الصندوق بنجاح إذا كان الرصيد كافياً', () async {
      await cashboxRepo.setOpeningBalance(1000000);
      final now = DateTime.now();
      final supplier = (await suppliersRepo.getSuppliers()).first;
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'خزانة كتب',
          salePrice: 150000,
          purchasePrice: 100000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-001',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 300000,
          total: 300000,
          paidAmount: 300000,
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
            quantity: 3,
            unitCost: 100000,
            total: 300000,
          ),
        ],
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(700000)); // 1,000,000 - 300,000
    });

    // 8. شراء آجل كامل لا يؤثر على الصندوق
    test('8. شراء آجل كامل لا يؤثر على رصيد الصندوق', () async {
      await cashboxRepo.setOpeningBalance(500000);
      final now = DateTime.now();
      final supplier = (await suppliersRepo.getSuppliers()).first;
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طاولة قهوة',
          salePrice: 60000,
          purchasePrice: 40000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-CREDIT-001',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 200000,
          total: 200000,
          paidAmount: 0,
          remainingAmount: 200000,
          paymentType: PurchasePaymentType.credit,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          PurchaseInvoiceItem(
            id: 0,
            purchaseInvoiceId: 0,
            productId: product.id,
            quantity: 5,
            unitCost: 40000,
            total: 200000,
          ),
        ],
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(500000));
    });

    // 9. سند صرف لمورد يخصم من الصندوق
    test('9. سند صرف دفعة لمورد يخصم من الصندوق بنجاح ويخفض دين المورد', () async {
      await cashboxRepo.setOpeningBalance(1000000);
      final now = DateTime.now();
      final supplier = (await suppliersRepo.getSuppliers()).first;
      await supplierLedgerRepo.recordEntry(
        SupplierLedgerEntry(
          id: 0,
          supplierId: supplier.id,
          transactionType: SupplierLedgerTransactionType.purchaseCredit,
          amount: 400000,
          transactionDate: now,
          referenceType: 'purchase_invoice',
          referenceId: 5,
          createdAt: now,
        ),
      );

      await supplierPaymentsRepo.recordPayment(
        SupplierPayment(
          id: 0,
          paymentNumber: '',
          supplierId: supplier.id,
          amount: 250000,
          paymentDate: now,
          paymentMethod: 'cash',
          notes: 'دفعة حساب',
          createdAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(750000)); // 1,000,000 - 250,000
    });

    // 10. تسجيل مصروف تشغيلي يخصم من الصندوق
    test('10. تسجيل مصروف تشغيلي يخصم من الصندوق ويسجل في المصروفات والصندوق معاً', () async {
      await cashboxRepo.setOpeningBalance(500000);
      final now = DateTime.now();

      final expense = await expensesRepo.createExpense(
        Expense(
          id: 0,
          categoryName: 'إيجار',
          amount: 150000,
          expenseDate: now,
          description: 'إيجار المعرض لشهر أكتوبر',
          notes: 'دفعة نقدية',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(expense.id, greaterThan(0));
      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(350000));

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashOut, equals(150000));
    });

    // 11. سحب المالك يخصم من الصندوق دون التأثير على المصروفات التشغيلية
    test('11. سحب المالك يخصم من الصندوق ولا يسجل كمصروف تشغيلي في جدول المصروفات', () async {
      await cashboxRepo.setOpeningBalance(800000);
      final tx = await cashboxRepo.recordOwnerWithdrawal(
        200000,
        notes: 'مسحوبات شخصية للمالك',
      );
      expect(tx.type, equals(CashTransactionType.ownerWithdrawal));
      expect(tx.direction, equals(CashFlowDirection.cashOut));

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(600000));

      // التأكد من أن جدول المصروفات التشغيلية فارغ تماماً
      final expenses = await expensesRepo.getExpenses();
      expect(expenses, isEmpty);

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashOut, equals(200000));
    });

    // 12. إيداع آخر يزيد الصندوق دون التأثير على إيرادات المبيعات
    test('12. إيداع آخر يزيد الصندوق ولا يعتبر إيراد مبيعات', () async {
      await cashboxRepo.setOpeningBalance(100000);
      final tx = await cashboxRepo.recordOtherDeposit(
        300000,
        notes: 'تمويل إضافي من الشريك',
      );
      expect(tx.type, equals(CashTransactionType.otherDeposit));
      expect(tx.direction, equals(CashFlowDirection.cashIn));

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(400000));

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashIn, equals(300000));
    });

    // 13. مرتجع مبيعات نقدي يخصم من الصندوق
    test('13. مرتجع مبيعات نقدي يخصم من الصندوق بحركة cashOut مستردة للعميل', () async {
      final now = DateTime.now();
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مرآة حائط مذهبة',
          salePrice: 120000,
          purchasePrice: 80000,
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
          invoiceNumber: 'INV-RET-CASH',
          customerId: null,
          invoiceDate: now,
          subtotal: 120000,
          totalAmount: 120000,
          paidAmount: 120000,
          remainingAmount: 0,
          paymentType: SalesPaymentType.cash,
          items: [
            SalesInvoiceItem(
              id: 0,
              salesInvoiceId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 120000,
              unitCostAtSale: 80000,
              total: 120000,
              costTotal: 80000,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(await cashboxRepo.getCashBalance(), equals(120000));

      // إرجاع نقدي للمنتج
      await salesReturnsRepo.createReturn(
        SalesReturn(
          id: 0,
          returnNumber: '',
          salesInvoiceId: invoice.id,
          customerId: null,
          returnDate: now,
          total: 120000,
          refundAmount: 120000,
          debtReductionAmount: 0,
          notes: 'إرجاع نقدي',
          items: [
            SalesReturnItem(
              id: 0,
              salesReturnId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 120000,
              unitCostAtSale: 80000,
              total: 120000,
            ),
          ],
          createdAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(0)); // 120,000 - 120,000

      final summary = await cashboxRepo.getCashboxSummary();
      expect(summary.todayCashOut, equals(120000));
    });

    // 14. مرتجع مشتريات نقدي يزيد الصندوق
    test('14. مرتجع مشتريات نقدي يسترد نقدية من المورد ويزيد الصندوق بحركة cashIn', () async {
      await cashboxRepo.setOpeningBalance(1000000);
      final now = DateTime.now();
      final supplier = (await suppliersRepo.getSuppliers()).first;
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'سجادة صوف بلجيكي',
          salePrice: 300000,
          purchasePrice: 200000,
          categoryId: 1,
          unitId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final purchase = await purchasesRepo.createPurchaseInvoice(
        invoice: PurchaseInvoice(
          id: 0,
          invoiceNumber: 'PUR-RET-01',
          supplierId: supplier.id,
          invoiceDate: now,
          subtotal: 400000,
          total: 400000,
          paidAmount: 400000,
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
            unitCost: 200000,
            total: 400000,
          ),
        ],
      );

      expect(await cashboxRepo.getCashBalance(), equals(600000)); // 1M - 400k

      // إرجاع قطعة واحدة نقداً للمورد (استرداد 200,000)
      await purchaseReturnsRepo.createReturn(
        PurchaseReturn(
          id: 0,
          returnNumber: '',
          purchaseInvoiceId: purchase.id,
          supplierId: supplier.id,
          returnDate: now,
          total: 200000,
          refundAmount: 200000,
          debtReductionAmount: 0,
          notes: 'استرداد نقدي لقطعة معيبة',
          items: [
            PurchaseReturnItem(
              id: 0,
              purchaseReturnId: 0,
              productId: product.id,
              quantity: 1,
              unitCost: 200000,
              total: 200000,
            ),
          ],
          createdAt: now,
        ),
      );

      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(800000)); // 600k + 200k
    });

    // 15. منع الصرف عند عدم وجود رصيد كافٍ (Negative Cash Prevention)
    test('15. منع الصرف عند عدم وجود رصيد كافٍ ويرمي AppException برصيد غير كافٍ', () async {
      await cashboxRepo.setOpeningBalance(50000);

      // محاولة سحب 100,000
      expect(
        () => cashboxRepo.recordOwnerWithdrawal(100000),
        throwsA(isA<AppException>()),
      );

      // محاولة تسجيل مصروف 70,000
      expect(
        () => expensesRepo.createExpense(
          Expense(
            id: 0,
            categoryName: 'إيجار',
            amount: 70000,
            expenseDate: DateTime.now(),
            description: 'مصروف يفوق الرصيد',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(isA<AppException>()),
      );

      // التأكد أن الرصيد لم يتأثر وبقي 50,000
      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(50000));
    });

    // 16. تراجع المعاملة بالكامل عند حدوث خطأ (Atomicity Rollback)
    test('16. تراجع المعاملة بالكامل ذرّياً (Rollback) عند فشل أي خطوة نقدية', () async {
      await cashboxRepo.setOpeningBalance(100000);
      final db = await dbService.database;

      // محاكاة معاملة تفشل أثناء تسجيل حركة الصندوق
      try {
        await db.transaction((txn) async {
          await txn.insert('expenses', {
            'category_name': 'إيجار',
            'amount': 200000, // أكبر من الرصيد 100,000
            'expense_date': DateTime.now().toIso8601String(),
            'description': 'مصروف اختبار الذرية',
            'notes': 'ملاحظات',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          await cashboxRepo.recordCashTransactionWithExecutor(
            txn,
            CashTransaction(
              id: 0,
              amount: 200000,
              direction: CashFlowDirection.cashOut,
              type: CashTransactionType.expense,
              description: 'مصروف',
              transactionDate: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
        });
      } catch (e) {
        // متوقع حدوث استثناء لعدم كفاية الرصيد
      }

      // التأكد من أن جدول المصروفات تراجع ولم يحفظ أي سجل
      final expenses = await expensesRepo.getExpenses();
      expect(expenses, isEmpty);

      // الرصيد لم يتغير
      final balance = await cashboxRepo.getCashBalance();
      expect(balance, equals(100000));
    });

    // 17. منع تكرار المعاملات المزدوجة لنفس الحركة (Duplicate Prevention)
    test('17. منع تسجيل معاملة نقدية مكررة لنفس المرجع (reference_type, reference_id)', () async {
      await cashboxRepo.setOpeningBalance(500000);
      final db = await dbService.database;

      await db.transaction((txn) async {
        await cashboxRepo.recordCashTransactionWithExecutor(
          txn,
          CashTransaction(
            id: 0,
            amount: 50000,
            direction: CashFlowDirection.cashIn,
            type: CashTransactionType.customerPayment,
            description: 'دفعة عميل',
            transactionDate: DateTime.now(),
            referenceType: 'customer_payment',
            referenceId: 999,
            createdAt: DateTime.now(),
          ),
        );
      });

      // محاولة تسجيل حركة أخرى بنفس المرجع المزدوج
      expect(
        () async {
          await db.transaction((txn) async {
            await cashboxRepo.recordCashTransactionWithExecutor(
              txn,
              CashTransaction(
                id: 0,
                amount: 50000,
                direction: CashFlowDirection.cashIn,
                type: CashTransactionType.customerPayment,
                description: 'دفعة عميل ثانية مكررة',
                transactionDate: DateTime.now(),
                referenceType: 'customer_payment',
                referenceId: 999,
                createdAt: DateTime.now(),
              ),
            );
          });
        },
        throwsA(isA<ValidationException>()),
      );
    });

    // 18. احتساب رصيد الصندوق عند الفلترة بتاريخ معين
    test('18. تصفية الحركات النقدية وحساب الرصيد التراكمي في كل لحظة (Running Balance)', () async {
      final t1 = DateTime(2026, 10, 1, 10, 0);
      final t2 = DateTime(2026, 10, 2, 12, 0);
      final t3 = DateTime(2026, 10, 3, 15, 0);

      await cashboxRepo.setOpeningBalance(100000, date: t1);
      await cashboxRepo.recordOtherDeposit(50000, date: t2);
      await cashboxRepo.recordOwnerWithdrawal(30000, date: t3);

      final transactions = await cashboxRepo.getTransactions();
      expect(transactions.length, equals(3));

      // فحص الرصيد التراكمي (running balance) حيث تُعرض الحركات تنازلياً (الأحدث أولاً)
      // الحركة الأحدث (الثالثة t3): 120,000
      expect(transactions[0].runningBalance, equals(120000));
      // الحركة الوسطى (الثانية t2): 150,000
      expect(transactions[1].runningBalance, equals(150000));
      // الحركة الأقدم (الأولى t1): 100,000
      expect(transactions[2].runningBalance, equals(100000));

      // فحص فلترة التاريخ
      final filtered = await cashboxRepo.getTransactions(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 2, 23, 59),
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.amount, equals(50000));
    });
  });
}
