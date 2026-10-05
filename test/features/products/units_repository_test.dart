import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/units_repository_impl.dart';
import 'package:sales/features/products/domain/entities/unit_of_measurement.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('UnitsRepository Tests', () {
    test('يسترجع وحدات القياس الافتراضية بنجاح', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = UnitsRepositoryImpl();

      final list = await repo.getUnits();
      expect(list.isNotEmpty, isTrue);
      expect(list.any((u) => u.name == 'متر'), isTrue);
    });

    test('ينشئ وحدة قياس جديدة ويرفض الحقول الفارغة', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = UnitsRepositoryImpl();

      final newUnit = UnitOfMeasurement(
        id: 0,
        name: 'درزن',
        symbol: 'درزن',
        createdAt: DateTime.now(),
      );

      final id = await repo.createUnit(newUnit);
      expect(id, greaterThan(0));

      final fetched = await repo.getUnitById(id);
      expect(fetched.name, equals('درزن'));

      expect(
        () => repo.createUnit(newUnit.copyWith(name: '')),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repo.createUnit(newUnit.copyWith(symbol: '')),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
