import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService dbService;
  late CustomersRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.initForTesting(inMemory: true);
    repository = CustomersRepositoryImpl(dbService: dbService);
  });

  tearDown(() async {
    await dbService.close();
  });

  group('CustomersRepository Tests (مستودع العملاء)', () {
    test('يسترجع العملاء الافتراضيين المبذورين مع الهجرة v4', () async {
      final list = await repository.getCustomers();
      expect(list.isNotEmpty, isTrue);
      expect(list.any((c) => c.name.contains('عميل نقدي')), isTrue);
    });

    test('إنشاء عميل جديد بنجاح وتحديث معرفه', () async {
      final customer = Customer(
        id: 0,
        name: 'أحمد صالح العمودي',
        phone: '773344556',
        whatsapp: '773344556',
        address: 'حضرموت - المكلا',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await repository.createCustomer(customer);
      expect(id, greaterThan(0));

      final fetched = await repository.getCustomerById(id);
      expect(fetched.name, equals('أحمد صالح العمودي'));
      expect(fetched.phone, equals('773344556'));
      expect(fetched.currentBalance, equals(0));
    });

    test('يرفض إنشاء عميل باسم فارغ أو مكرر', () async {
      final emptyCustomer = Customer(
        id: 0,
        name: '   ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repository.createCustomer(emptyCustomer),
        throwsA(isA<ValidationException>()),
      );

      final duplicateCustomer = Customer(
        id: 0,
        name: 'عميل نقدي (زبون عام)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repository.createCustomer(duplicateCustomer),
        throwsA(isA<ValidationException>()),
      );
    });

    test('تعديل بيانات العميل وتغيير حالة التنشيط', () async {
      final customer = Customer(
        id: 0,
        name: 'سالم بن محفوظ',
        phone: '778899001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await repository.createCustomer(customer);

      final toUpdate = customer.copyWith(id: id, phone: '779988776', address: 'صنعاء');
      await repository.updateCustomer(toUpdate);

      final updated = await repository.getCustomerById(id);
      expect(updated.phone, equals('779988776'));
      expect(updated.address, equals('صنعاء'));

      await repository.toggleCustomerActive(id, false);
      final disabled = await repository.getCustomerById(id);
      expect(disabled.isActive, isFalse);
    });
  });
}
