import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/domain/errors/failures.dart';

void main() {
  group('ErrorHandler Tests', () {
    test('يحول NotFoundException إلى NotFoundFailure مع رسالة واضحة', () {
      const exception = NotFoundException('الصنف غير متوفر');
      final failure = ErrorHandler.handle(exception);

      expect(failure, isA<NotFoundFailure>());
      expect(failure.userFriendlyMessage, equals('الصنف غير متوفر'));
    });

    test('يحول ValidationException إلى ValidationFailure', () {
      const exception = ValidationException('السعر يجب أن يكون أكبر من الصفر');
      final failure = ErrorHandler.handle(exception);

      expect(failure, isA<ValidationFailure>());
      expect(failure.userFriendlyMessage, equals('السعر يجب أن يكون أكبر من الصفر'));
    });

    test('يحول الأخطاء غير المتوقعة إلى UnexpectedFailure دون تسريب تفاصيل تقنية حساسة', () {
      final error = Exception('Fatal socket exception 500');
      final failure = ErrorHandler.handle(error);

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.userFriendlyMessage, contains('حدث خطأ غير متوقع'));
    });
  });
}
