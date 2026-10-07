import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../domain/entities/date_range.dart';

/// ويدجت موحد لاختيار الفترات الزمنية للتقارير (اليوم، الشهر، السنة، فترة مخصصة)
class DateRangeSelectorWidget extends StatelessWidget {
  final DateRange selectedRange;
  final ValueChanged<DateRange> onRangeChanged;

  const DateRangeSelectorWidget({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withAlpha(120)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            // العنوان والفترة المحددة الحالية
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  selectedRange.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            // أزرار الفترات السريعة
            Wrap(
              spacing: 6,
              children: [
                _buildQuickButton(
                  context,
                  label: 'اليوم',
                  isSelected: _isToday(selectedRange),
                  onTap: () => onRangeChanged(DateRange.today()),
                ),
                _buildQuickButton(
                  context,
                  label: 'الشهر الحالي',
                  isSelected: _isCurrentMonth(selectedRange),
                  onTap: () => onRangeChanged(DateRange.currentMonth()),
                ),
                _buildQuickButton(
                  context,
                  label: 'اختيار شهر',
                  isSelected: false,
                  icon: Icons.calendar_month,
                  onTap: () => _pickMonth(context),
                ),
                _buildQuickButton(
                  context,
                  label: 'السنة الحالية',
                  isSelected: _isCurrentYear(selectedRange),
                  onTap: () => onRangeChanged(DateRange.currentYear()),
                ),
                _buildQuickButton(
                  context,
                  label: 'فترة مخصصة',
                  isSelected: _isCustom(selectedRange),
                  icon: Icons.edit_calendar,
                  onTap: () => _pickCustomRange(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateRange range) {
    final today = DateRange.today();
    return range.startInclusive == today.startInclusive &&
        range.endExclusive == today.endExclusive;
  }

  bool _isCurrentMonth(DateRange range) {
    final cur = DateRange.currentMonth();
    return range.startInclusive == cur.startInclusive &&
        range.endExclusive == cur.endExclusive;
  }

  bool _isCurrentYear(DateRange range) {
    final cur = DateRange.currentYear();
    return range.startInclusive == cur.startInclusive &&
        range.endExclusive == cur.endExclusive;
  }

  bool _isCustom(DateRange range) =>
      !_isToday(range) && !_isCurrentMonth(range) && !_isCurrentYear(range);

  Widget _buildQuickButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;

    final result = await showDialog<DateRange>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار شهر التقرير'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: selectedYear,
                    items: [
                      for (int y = now.year - 3; y <= now.year + 1; y++)
                        DropdownMenuItem(value: y, child: Text('سنة $y')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedYear = val);
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: selectedMonth,
                    items: [
                      for (int m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('شهر $m')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMonth = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogCtx,
                      DateRange.month(selectedYear, selectedMonth),
                    );
                  },
                  child: const Text('اختيار'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onRangeChanged(result);
    }
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final initialRange = DateTimeRange(
      start: selectedRange.startInclusive,
      end: selectedRange.endExclusive.subtract(const Duration(days: 1)),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
      helpText: 'اختر الفترة الزمنية للتقرير',
      saveText: 'تطبيق',
    );

    if (picked != null) {
      onRangeChanged(DateRange.custom(picked.start, picked.end));
    }
  }
}
