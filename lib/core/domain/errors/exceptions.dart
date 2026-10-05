/// الأساس لجميع استثناءات النظام في طبقة النطاق
abstract class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => 'AppException: $message ${cause != null ? "(سبب: $cause)" : ""}';
}

/// استثناءات قاعدة البيانات SQLite
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
}

/// استثناء عدم العثور على العنصر
class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.cause]);
}

/// استثناء التحقق من صحة المدخلات
class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
}
