/// كائن الفشل الموجه لواجهة المستخدم في طبقة النطاق
abstract class Failure {
  final String userFriendlyMessage;
  final String? technicalDetails;

  const Failure(this.userFriendlyMessage, [this.technicalDetails]);

  @override
  String toString() => '$runtimeType: $userFriendlyMessage';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          other.runtimeType == runtimeType &&
          other.userFriendlyMessage == userFriendlyMessage;

  @override
  int get hashCode => userFriendlyMessage.hashCode;
}

/// فشل عمليات قاعدة البيانات
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.userFriendlyMessage, [super.technicalDetails]);
}

/// فشل العثور على البيانات
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.userFriendlyMessage, [super.technicalDetails]);
}

/// فشل التحقق من صحة البيانات
class ValidationFailure extends Failure {
  const ValidationFailure(super.userFriendlyMessage, [super.technicalDetails]);
}

/// فشل غير متوقع
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.userFriendlyMessage = 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً',
    super.technicalDetails,
  ]);
}
