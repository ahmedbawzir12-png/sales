import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/features/settings/data/repositories/store_settings_repository_impl.dart';
import 'package:sales/features/settings/domain/entities/store_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('StoreSettingsRepositoryImpl Tests (Clean Architecture Verification)', () {
    test('يسترجع بيانات المتجر الأولية ككيان نقي (Domain Entity)', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repository = StoreSettingsRepositoryImpl();

      final profile = await repository.getStoreProfile();

      expect(profile.id, equals(1));
      expect(profile.name, equals('معرض المفروشات العصري'));
      expect(profile.currency, equals('ر.ي'));
      expect(profile, isA<StoreProfile>());
    });

    test('يقوم بتحديث بيانات المتجر وحفظها في SQLite بنجاح', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repository = StoreSettingsRepositoryImpl();

      final existingProfile = await repository.getStoreProfile();
      final updatedProfile = existingProfile.copyWith(
        name: 'مفروشات الأناقة الحديثة',
        phone: '0501234567',
        address: 'الرياض - طريق الملك عبد العزيز',
      );

      await repository.updateStoreProfile(updatedProfile);

      final result = await repository.getStoreProfile();
      expect(result.name, equals('مفروشات الأناقة الحديثة'));
      expect(result.phone, equals('0501234567'));
      expect(result.address, equals('الرياض - طريق الملك عبد العزيز'));
    });
  });
}
