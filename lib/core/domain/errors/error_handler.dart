import 'package:sqflite/sqflite.dart' as sqflite;
import 'exceptions.dart';
import 'failures.dart';

/// معالج مركزي للأخطاء يقوم بتحويل الاستثناءات الفنية إلى كائنات Failure مفهومة للمستخدم
class ErrorHandler {
  ErrorHandler._();

  /// تحويل أي استثناء إلى كائن Failure مناسب
  static Failure handle(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      if (error is NotFoundException) {
        return NotFoundFailure(error.message, error.cause?.toString());
      }
      if (error is ValidationException) {
        return ValidationFailure(error.message, error.cause?.toString());
      }
      if (error is DatabaseException) {
        return DatabaseFailure(error.message, error.cause?.toString());
      }
      return DatabaseFailure(error.message, error.cause?.toString());
    }

    if (error is sqflite.DatabaseException) {
      return _mapSqfliteException(error);
    }

    return UnexpectedFailure(
      'حدث خطأ غير متوقع أثناء معالجة البيانات',
      error.toString(),
    );
  }

  /// ترجمة أخطاء SQLite الشائعة إلى رسائل عربية واضحة
  static DatabaseFailure _mapSqfliteException(sqflite.DatabaseException ex) {
    final message = ex.toString().toLowerCase();

    if (message.contains('unique constraint failed') ||
        message.contains('code 2067')) {
      return DatabaseFailure(
        'هذا السجل موجود بالفعل ومكرر، يرجى التحقق من المدخلات.',
        ex.toString(),
      );
    }

    if (message.contains('foreign key constraint failed') ||
        message.contains('code 787')) {
      return DatabaseFailure(
        'لا يمكن إتمام العملية لوجود ارتباطات بسجلات أخرى في النظام.',
        ex.toString(),
      );
    }

    if (message.contains('database is locked') ||
        message.contains('code 5')) {
      return DatabaseFailure(
        'قاعدة البيانات مشغولة حالياً، يرجى المحاولة بعد لحظات.',
        ex.toString(),
      );
    }

    if (message.contains('no such table')) {
      return DatabaseFailure(
        'خطأ في بنية قاعدة البيانات: جدول مفقود.',
        ex.toString(),
      );
    }

    return DatabaseFailure(
      'تعذر حفظ أو استرجاع البيانات محلياً.',
      ex.toString(),
    );
  }
}
