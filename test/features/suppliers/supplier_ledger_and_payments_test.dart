import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_ledger_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_payments_repository_impl.dart';
import 'package:sales/features/suppliers/data/repositories/suppliers_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
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

  group('Supplier Ledger & Payments Tests (أستاذ المورد وسندات الصرف والديون)', () {
    late DatabaseService dbService;
    late SuppliersRepositoryImpl suppliersRepo;
    late SupplierLedgerRepositoryImpl ledgerRepo;
    late SupplierPaymentsRepositoryImpl paymentsRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initForTesting(inMemory: true);
      suppliersRepo = SuppliersRepositoryImpl(databaseService: dbService);
      ledgerRepo = SupplierLedgerRepositoryImpl(dbService: dbService);
      paymentsRepo = SupplierPaymentsRepositoryImpl(dbService: dbService);
    });

    test('تسجيل شراء آجل في أستاذ المورد يزيد دين المورد تلقائياً في السجل والملخص', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مصنع الأثاث الراقي', phone: '777000111', createdAt: now, updatedAt: now),
      );
      expect(supplier.currentBalance, equals(0));

      // تسجيل شراء آجل
      await ledgerRepo.recordEntry(
        SupplierLedgerEntry(
          id: 0,
          supplierId: supplier.id,
          transactionType: SupplierLedgerTransactionType.purchaseCredit,
          amount: 500000,
          transactionDate: now,
          referenceType: 'purchase_invoice',
          referenceId: 201,
          notes: 'فاتورة شراء رقم PINV-201',
          createdAt: now,
        ),
      );

      final ledger = await ledgerRepo.getLedgerEntries(supplier.id);
      expect(ledger.length, equals(1));
      expect(ledger.first.amount, equals(500000));
      expect(ledger.first.transactionType, equals(SupplierLedgerTransactionType.purchaseCredit));

      final balance = await ledgerRepo.getSupplierBalance(supplier.id);
      expect(balance, equals(500000));

      final updatedSupplier = await suppliersRepo.getSupplierById(supplier.id);
      expect(updatedSupplier.currentBalance, equals(500000));
    });

    test('تسجيل سند صرف دفعة للمورد يسجل في المدفوعات ويخفض الدين المستحق في الأستاذ', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'شركة إسفنج اليمن', phone: '777222333', createdAt: now, updatedAt: now),
      );

      // دين 300,000
      await ledgerRepo.recordEntry(
        SupplierLedgerEntry(
          id: 0,
          supplierId: supplier.id,
          transactionType: SupplierLedgerTransactionType.purchaseCredit,
          amount: 300000,
          transactionDate: now,
          referenceType: 'purchase_invoice',
          referenceId: 202,
          createdAt: now,
        ),
      );

      // سداد دفعة 100,000
      final payment = await paymentsRepo.recordPayment(
        SupplierPayment(
          id: 0,
          paymentNumber: '',
          supplierId: supplier.id,
          amount: 100000,
          paymentDate: now,
          paymentMethod: 'cash',
          notes: 'دفعة سداد حساب نقدي',
          createdAt: now,
        ),
      );

      expect(payment.id, isPositive);
      expect(payment.paymentNumber, startsWith('SPAY-'));

      final balance = await ledgerRepo.getSupplierBalance(supplier.id);
      expect(balance, equals(200000));

      final updatedSupplier = await suppliersRepo.getSupplierById(supplier.id);
      expect(updatedSupplier.currentBalance, equals(200000));
    });

    test('يرفض تسجيل سند صرف لمورد بمبلغ صفر أو سالب', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مورد اختبار', phone: '777444555', createdAt: now, updatedAt: now),
      );

      expect(
        () => paymentsRepo.recordPayment(
          SupplierPayment(
            id: 0,
            paymentNumber: '',
            supplierId: supplier.id,
            amount: 0,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => paymentsRepo.recordPayment(
          SupplierPayment(
            id: 0,
            paymentNumber: '',
            supplierId: supplier.id,
            amount: -10000,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يرفض صرف دفعة تتجاوز إجمالي الدين المستحق للمورد', () async {
      final now = DateTime.now();
      final supplier = await suppliersRepo.createSupplier(
        Supplier(id: 0, name: 'مورد الأقمشة الحديثة', phone: '777666777', createdAt: now, updatedAt: now),
      );

      // دين 80,000
      await ledgerRepo.recordEntry(
        SupplierLedgerEntry(
          id: 0,
          supplierId: supplier.id,
          transactionType: SupplierLedgerTransactionType.purchaseCredit,
          amount: 80000,
          transactionDate: now,
          referenceType: 'purchase_invoice',
          referenceId: 203,
          createdAt: now,
        ),
      );

      // محاولة سداد 90,000
      expect(
        () => paymentsRepo.recordPayment(
          SupplierPayment(
            id: 0,
            paymentNumber: '',
            supplierId: supplier.id,
            amount: 90000,
            paymentDate: now,
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
