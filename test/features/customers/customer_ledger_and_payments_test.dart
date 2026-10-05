import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/customers/data/repositories/customer_ledger_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customer_payments_repository_impl.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/customers/domain/entities/customer_ledger_entry.dart';
import 'package:sales/features/customers/domain/entities/customer_payment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Customer Ledger & Payments Tests (أستاذ العميل والتحصيلات والديون)', () {
    late DatabaseService dbService;
    late CustomersRepositoryImpl customersRepo;
    late CustomerLedgerRepositoryImpl ledgerRepo;
    late CustomerPaymentsRepositoryImpl paymentsRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      customersRepo = CustomersRepositoryImpl(dbService: dbService);
      ledgerRepo = CustomerLedgerRepositoryImpl(dbService: dbService);
      paymentsRepo = CustomerPaymentsRepositoryImpl(dbService: dbService);
    });

    test('تسجيل حركة بيع آجل في أستاذ العميل يزيد الدين تلقائياً في السجل والملخص', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(
          id: 0,
          name: 'محمد الأحمدي',
          phone: '777111222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final customer = await customersRepo.getCustomerById(customerId);
      expect(customer.currentBalance, equals(0));

      // تسجيل بيع آجل في الأستاذ
      await ledgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: customerId,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 150000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 101,
          notes: 'فاتورة مبيعات رقم INV-101',
          createdAt: now,
        ),
      );

      // التحقق من كشف الحساب
      final ledger = await ledgerRepo.getLedgerEntries(customerId);
      expect(ledger.length, equals(1));
      expect(ledger.first.amount, equals(150000));
      expect(ledger.first.transactionType, equals(CustomerLedgerTransactionType.saleCredit));

      // التحقق من الرصيد التراكمي
      final balance = await ledgerRepo.getCustomerBalance(customerId);
      expect(balance, equals(150000));

      // التحقق من احتساب الدين في مستودع العملاء
      final updatedCustomer = await customersRepo.getCustomerById(customerId);
      expect(updatedCustomer.currentBalance, equals(150000));
    });

    test('تسجيل سند قبض دفعة نقدية يسجل في المدفوعات ويخفض دين العميل في الأستاذ', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(
          id: 0,
          name: 'فهد السالم',
          phone: '777333444',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // إضافة دين 200,000
      await ledgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: customerId,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 200000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 102,
          createdAt: now,
        ),
      );

      // تسجيل سند قبض 80,000
      final payment = await paymentsRepo.recordPayment(
        CustomerPayment(
          id: 0,
          paymentNumber: '',
          customerId: customerId,
          amount: 80000,
          paymentDate: now,
          paymentMethod: 'cash',
          notes: 'دفعة نقدية تحت الحساب',
          createdAt: now,
        ),
      );

      expect(payment.id, isPositive);
      expect(payment.paymentNumber, startsWith('CPAY-'));

      // رصيد الدين المتبقي يجب أن يصبح 120,000
      final remainingBalance = await ledgerRepo.getCustomerBalance(customerId);
      expect(remainingBalance, equals(120000));

      final updatedCustomer = await customersRepo.getCustomerById(customerId);
      expect(updatedCustomer.currentBalance, equals(120000));
    });

    test('يرفض تسجيل دفعة بمبلغ صفر أو سالب', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(
          id: 0,
          name: 'عميل اختبار',
          phone: '777555666',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        () => paymentsRepo.recordPayment(
          CustomerPayment(
            id: 0,
            paymentNumber: '',
            customerId: customerId,
            amount: 0,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => paymentsRepo.recordPayment(
          CustomerPayment(
            id: 0,
            paymentNumber: '',
            customerId: customerId,
            amount: -5000,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يرفض تحصيل دفعة تتجاوز إجمالي الدين المستحق على العميل', () async {
      final now = DateTime.now();
      final customerId = await customersRepo.createCustomer(
        Customer(
          id: 0,
          name: 'خالد باوزير',
          phone: '777888999',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // دين 50,000
      await ledgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: customerId,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 50000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 103,
          createdAt: now,
        ),
      );

      // محاولة سداد 60,000 (أكبر من 50,000)
      expect(
        () => paymentsRepo.recordPayment(
          CustomerPayment(
            id: 0,
            paymentNumber: '',
            customerId: customerId,
            amount: 60000,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('التحقق من إجمالي ديون جميع العملاء النشطين وتصفيتها عند السداد التام', () async {
      final now = DateTime.now();
      final c1Id = await customersRepo.createCustomer(
        Customer(id: 0, name: 'عميل 1', phone: '770000001', createdAt: now, updatedAt: now),
      );
      final c2Id = await customersRepo.createCustomer(
        Customer(id: 0, name: 'عميل 2', phone: '770000002', createdAt: now, updatedAt: now),
      );

      await ledgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: c1Id,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 100000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 1,
          createdAt: now,
        ),
      );

      await ledgerRepo.recordEntry(
        CustomerLedgerEntry(
          id: 0,
          customerId: c2Id,
          transactionType: CustomerLedgerTransactionType.saleCredit,
          amount: 150000,
          transactionDate: now,
          referenceType: 'sales_invoice',
          referenceId: 2,
          createdAt: now,
        ),
      );

      expect(await customersRepo.getCustomerDebt(c1Id), equals(100000));
      expect(await customersRepo.getCustomerDebt(c2Id), equals(150000));

      // سداد c1 بالكامل
      await paymentsRepo.recordPayment(
        CustomerPayment(
          id: 0,
          paymentNumber: '',
          customerId: c1Id,
          amount: 100000,
          paymentDate: now,
          createdAt: now,
        ),
      );

      expect(await ledgerRepo.getCustomerBalance(c1Id), equals(0));
      expect(await customersRepo.getCustomerDebt(c1Id), equals(0));
      expect(await customersRepo.getCustomerDebt(c2Id), equals(150000));
    });
  });
}
