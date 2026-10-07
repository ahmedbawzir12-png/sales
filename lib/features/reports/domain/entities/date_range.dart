/// نطاق التاريخ الزمني الموحد لتقارير النظام (Domain Layer)
/// يعتمد نمط startInclusive و endExclusive لضمان الدقة المحاسبية التامة ومنع مشاكل التوقيت
class DateRange {
  final DateTime startInclusive;
  final DateTime endExclusive;
  final String label;

  const DateRange({
    required this.startInclusive,
    required this.endExclusive,
    required this.label,
  });

  /// تقرير اليوم الحالي (يبدأ من 00:00:00 وينتهي غداً 00:00:00)
  factory DateRange.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return DateRange(
      startInclusive: start,
      endExclusive: end,
      label: 'اليوم (${start.year}/${start.month}/${start.day})',
    );
  }

  /// تقرير شهر محدد
  factory DateRange.month(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return DateRange(
      startInclusive: start,
      endExclusive: end,
      label: 'شهر $month / $year',
    );
  }

  /// تقرير الشهر الحالي
  factory DateRange.currentMonth() {
    final now = DateTime.now();
    return DateRange.month(now.year, now.month);
  }

  /// تقرير سنة محددة
  factory DateRange.year(int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    return DateRange(
      startInclusive: start,
      endExclusive: end,
      label: 'سنة $year',
    );
  }

  /// تقرير السنة الحالية
  factory DateRange.currentYear() {
    final now = DateTime.now();
    return DateRange.year(now.year);
  }

  /// تقرير فترة مخصصة يحددها المستخدم (يشمل كامل يوم النهاية حتى نهايته 23:59:59)
  factory DateRange.custom(DateTime startDay, DateTime endDay) {
    final start = DateTime(startDay.year, startDay.month, startDay.day);
    // endDay inclusive means endExclusive is day + 1 at 00:00:00
    final end = DateTime(endDay.year, endDay.month, endDay.day)
        .add(const Duration(days: 1));
    return DateRange(
      startInclusive: start,
      endExclusive: end,
      label:
          '${start.year}/${start.month}/${start.day} إلى ${endDay.year}/${endDay.month}/${endDay.day}',
    );
  }

  /// كامل الفترة الزمنية دون قيود
  factory DateRange.allTime() {
    return DateRange(
      startInclusive: DateTime(2000, 1, 1),
      endExclusive: DateTime(2100, 1, 1),
      label: 'كامل العمليات',
    );
  }

  String get startIso => startInclusive.toIso8601String();
  String get endIso => endExclusive.toIso8601String();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          startInclusive == other.startInclusive &&
          endExclusive == other.endExclusive;

  @override
  int get hashCode => Object.hash(startInclusive, endExclusive);

  @override
  String toString() => 'DateRange($label: $startIso -> $endIso)';
}
