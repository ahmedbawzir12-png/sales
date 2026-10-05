import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/app/app.dart';
import 'package:sales/app/presentation/main_navigation_shell.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/features/settings/domain/entities/store_profile.dart';
import 'package:sales/features/settings/domain/repositories/store_settings_repository.dart';
import 'package:sales/features/settings/presentation/screens/foundation_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeStoreSettingsRepository implements StoreSettingsRepository {
  final StoreProfile profile;

  FakeStoreSettingsRepository({StoreProfile? profile})
    : profile =
          profile ??
          StoreProfile(
            id: 1,
            name: 'معرض المفروشات العصري',
            phone: '739473030',
            address: 'صنعاء',
            currency: 'ر.ي',
            updatedAt: DateTime(2026, 1, 1),
          );

  @override
  Future<StoreProfile> getStoreProfile() async => profile;

  @override
  Future<void> updateStoreProfile(StoreProfile profile) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  testWidgets('FurnitureStoreApp يفتح ويعرض واجهة التأسيس بنجاح', (
    WidgetTester tester,
  ) async {
    final fakeRepo = FakeStoreSettingsRepository();

    await tester.pumpWidget(
      FurnitureStoreApp(
        home: FoundationScreen(
          repository: fakeRepo,
          initialProfile: fakeRepo.profile,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsAtLeastNWidgets(1));
    expect(find.text('حالة محرك التخزين المحلي (SQLite)'), findsOneWidget);
    expect(find.text('معرض المفروشات العصري'), findsAtLeastNWidgets(1));
    expect(find.text('العملة الافتراضية:'), findsOneWidget);
  });

  testWidgets(
    'MainNavigationShell يعرض أقسام النظام (المنتجات، المشتريات، الموردون، الجرد، النظام)',
    (WidgetTester tester) async {
      await DatabaseService.instance.initForTesting(inMemory: true);

      await tester.pumpWidget(const MaterialApp(home: MainNavigationShell()));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // التحقق من وجهات شريط التنقل
      expect(find.text('المنتجات'), findsWidgets);
      expect(find.text('المبيعات'), findsWidgets);
      expect(find.text('المشتريات'), findsWidgets);
      expect(find.text('العملاء'), findsWidgets);
      expect(find.text('الموردون'), findsWidgets);
      expect(find.text('الجرد والتسوية'), findsWidgets);
      expect(find.text('النظام'), findsWidgets);

      // التحقق من عنوان شاشة المنتجات
      expect(find.text('دليل المنتجات والمخزون'), findsOneWidget);
      expect(find.text('إجمالي الأصناف'), findsOneWidget);
    },
  );
}
