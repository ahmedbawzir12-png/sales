import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/presentation/utils/app_toast.dart';

void main() {
  group('AppToast Tests', () {
    tearDown(() {
      AppToast.dismiss(immediate: true);
    });

    testWidgets('AppToast.showSave يعرض التوست بلون خلفية أخضر وأيقونة النجاح', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppToast.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showSave(context, 'تم حفظ البيانات بنجاح');
                },
                child: const Text('حفظ'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('حفظ'));
      await tester.pump(); // بدء حركة الدخول

      expect(find.text('تم حفظ البيانات بنجاح'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // التأكد من اللون الأخضر
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SlideTransition),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF059669));
    });

    testWidgets('AppToast.showDelete يعرض التوست بلون خلفية أحمر وأيقونة الحذف', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppToast.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showDelete(context, 'تم حذف العنصر بنجاح');
                },
                child: const Text('حذف'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('حذف'));
      await tester.pump();

      expect(find.text('تم حذف العنصر بنجاح'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SlideTransition),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFDC2626));
    });

    testWidgets('AppToast.showWarning يعرض التوست بلون برتقالي عنبري', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppToast.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showWarning(context, 'تنبيه: المخزون منخفض');
                },
                child: const Text('تنبيه'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('تنبيه'));
      await tester.pump();

      expect(find.text('تنبيه: المخزون منخفض'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SlideTransition),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFD97706));
    });

    testWidgets('النقر على زر الإغلاق يقوم بإخفاء التوست', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppToast.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showInfo(context, 'إشعار للمعاينة');
                },
                child: const Text('عرض'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('عرض'));
      await tester.pump();

      expect(find.text('إشعار للمعاينة'), findsOneWidget);

      // النقر على زر الإغلاق
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(); // بدء حركة الخروج
      await tester.pump(const Duration(milliseconds: 300)); // إكمال حركة الخروج

      expect(find.text('إشعار للمعاينة'), findsNothing);
    });

    testWidgets('AppToast يعمل بسلاسة مع tester.pumpAndSettle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppToast.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showWarning(context, 'تحذير تجريبي');
                },
                child: const Text('تحذير'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('تحذير'));
      await tester.pumpAndSettle();

      expect(find.text('تحذير تجريبي'), findsOneWidget);
    });
  });
}
