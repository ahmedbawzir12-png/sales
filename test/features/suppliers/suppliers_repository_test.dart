import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
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

  group('SuppliersRepository Tests (مستودع الموردين)', () {
    test('يسترجع الموردين الافتراضيين المبذورين مع الهجرة v3', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = SuppliersRepositoryImpl();

      final suppliers = await repo.getSuppliers();
      expect(suppliers.length, greaterThanOrEqualTo(3));
      expect(suppliers.any((s) => s.name.contains('الأندلس')), isTrue);
    });

    test('إنشاء مورد جديد بنجاح وتحديث معرفه', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = SuppliersRepositoryImpl();

      final newSupplier = Supplier(
        id: 0,
        name: 'مؤسسة الرياض للأقمشة الفاخرة',
        phone: '772233445',
        whatsapp: '772233445',
        address: 'صنعاء',
        notes: 'مورد متميز للأقمشة التركية',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await repo.createSupplier(newSupplier);
      expect(created.id, greaterThan(0));
      expect(created.name, equals('مؤسسة الرياض للأقمشة الفاخرة'));

      final retrieved = await repo.getSupplierById(created.id);
      expect(retrieved.phone, equals('772233445'));
    });

    test('يرفض إنشاء مورد باسم فارغ أو مكرر', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = SuppliersRepositoryImpl();

      final emptyNameSupplier = Supplier(
        id: 0,
        name: '   ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repo.createSupplier(emptyNameSupplier),
        throwsA(isA<ValidationException>()),
      );

      final duplicateSupplier = Supplier(
        id: 0,
        name: 'شركة الأندلس للأقمشة والمفروشات', // موجود مسبقاً
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repo.createSupplier(duplicateSupplier),
        throwsA(isA<ValidationException>()),
      );
    });

    test('تعديل بيانات المورد وتغيير حالة التفعيل (حذف ناعم)', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = SuppliersRepositoryImpl();

      final suppliers = await repo.getSuppliers();
      final target = suppliers.first;

      await repo.updateSupplier(target.copyWith(phone: '779988776'));
      final updated = await repo.getSupplierById(target.id);
      expect(updated.phone, equals('779988776'));

      // تعطيل المورد
      await repo.setSupplierActive(target.id, false);
      final deactivated = await repo.getSupplierById(target.id);
      expect(deactivated.isActive, isFalse);

      // استعلام النشطين فقط يستثني المورد المعطل
      final activeOnly = await repo.getSuppliers(onlyActive: true);
      expect(activeOnly.any((s) => s.id == target.id), isFalse);
    });
  });
}
