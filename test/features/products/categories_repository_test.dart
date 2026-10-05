import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/categories_repository_impl.dart';
import 'package:sales/features/products/domain/entities/category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('CategoriesRepository Tests', () {
    test('يسترجع التصنيفات الافتراضية المبذورة مع الهجرة v2', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = CategoriesRepositoryImpl();

      final list = await repo.getCategories();
      expect(list.isNotEmpty, isTrue);
      expect(list.any((c) => c.name == 'فرش أرضيات وسجاد'), isTrue);
    });

    test('ينشئ تصنيفاً جديداً بنجاح ويرفض الاسم الفارغ', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = CategoriesRepositoryImpl();

      final newCat = Category(
        id: 0,
        name: 'مفارش طاولات فاخرة',
        description: 'مفارش مطرزة',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await repo.createCategory(newCat);
      expect(id, greaterThan(0));

      final fetched = await repo.getCategoryById(id);
      expect(fetched.name, equals('مفارش طاولات فاخرة'));
      expect(fetched.description, equals('مفارش مطرزة'));

      // التحقق من رفض الاسم الفارغ
      expect(
        () => repo.createCategory(newCat.copyWith(name: '   ')),
        throwsA(isA<ValidationException>()),
      );
    });

    test('يقوم بتعديل التصنيف وتغيير حالته', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = CategoriesRepositoryImpl();

      final list = await repo.getCategories();
      final cat = list.first;

      await repo.updateCategory(cat.copyWith(name: '${cat.name} المعدل'));
      final updated = await repo.getCategoryById(cat.id);
      expect(updated.name, contains('المعدل'));

      // تعطيل التصنيف
      await repo.setCategoryActive(cat.id, false);
      final deactivated = await repo.getCategoryById(cat.id);
      expect(deactivated.isActive, isFalse);
    });
  });
}
