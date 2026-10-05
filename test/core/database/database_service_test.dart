import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('DatabaseService Tests', () {
    test('يتم فتح قاعدة البيانات وتطبيق الهجرة الأولى بنجاح', () async {
      final db = await DatabaseService.instance.initForTesting(inMemory: true);

      expect(db.isOpen, isTrue);
      expect(DatabaseService.instance.isOpen, isTrue);

      final version = await db.getVersion();
      expect(version, equals(DatabaseConstants.databaseVersion));

      // التحقق من جدول الهجرات (الهجرة الأولى والثانية مطبقة)
      final migrations = await db.query(DatabaseConstants.tableMigrations);
      expect(migrations.length, equals(2));
      expect(migrations.first['version'], equals(1));
      expect(migrations[1]['version'], equals(2));

      // التحقق من جدول بيانات المتجر
      final storeRecords = await db.query(DatabaseConstants.tableStoreProfile);
      expect(storeRecords.length, equals(1));
      expect(storeRecords.first['id'], equals(1));
      expect(storeRecords.first['name'], equals('معرض المفروشات العصري'));
    });

    test('إغلاق قاعدة البيانات يعيد تعيين الحالة بأمان', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      expect(DatabaseService.instance.isOpen, isTrue);

      await DatabaseService.instance.close();
      expect(DatabaseService.instance.isOpen, isFalse);
    });

    test('آلية الهجرات تقبل ترقيات المخطط المستقبلية بأمان وتسجلها في جدول التتبع', () async {
      final db = await DatabaseService.instance.initForTesting(inMemory: true);

      // محاكاة ترقية لاحقة في معاملة موحدة
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE ${DatabaseConstants.tableStoreProfile} ADD COLUMN email TEXT;');
        await txn.rawInsert('''
          INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
          VALUES (3, 'إضافة حقل البريد الإلكتروني للمتجر', ?)
        ''', [DateTime.now().toIso8601String()]);
      });

      final migrations = await db.query(DatabaseConstants.tableMigrations);
      expect(migrations.length, equals(3));

      final records = await db.query(DatabaseConstants.tableStoreProfile);
      expect(records.first.containsKey('email'), isTrue);
    });
  });
}
