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

  runApp(const FurnitureStoreApp());
}
