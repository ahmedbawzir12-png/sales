import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/data/database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة FFI لدعم منصات سطح المكتب (Windows / Linux / macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // التأكد من جاهزية وفتح قاعدة البيانات وتطبيق الهجرات الأولية
  try {
    await DatabaseService.instance.database;
  } catch (e) {
    debugPrint('تحذير: حدث خطأ أثناء التهيئة الأولية لقاعدة البيانات: $e');
  }

  // معالجة استثناءات إطارات العرض (UI Errors) لمنع ظهور الشاشة الحمراء تماماً
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 48),
              const SizedBox(height: 16),
              const Text(
                'تنبيه في تحديث الواجهة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exceptionAsString() : 'تم احتواء التنبيه بنجاح، يمكنك تحديث الشاشة لمتابعة العمل.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // تسجيل أي خطأ في وحدة التحكم بدون تعطيل مسار التطبيق
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    return true;
  };

  runApp(const FurnitureStoreApp());
}
