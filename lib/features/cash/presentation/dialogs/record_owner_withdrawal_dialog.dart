import 'package:flutter/material.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/cash_transaction.dart';
import '../../domain/repositories/cashbox_repository.dart';

/// نافذة سحب نقدية شخصي لصاحب المحل (مسحوبات المالك)
class RecordOwnerWithdrawalDialog extends StatefulWidget {
  final CashboxRepository repository;
  final int currentBalance;

  const RecordOwnerWithdrawalDialog({
    super.key,
    required this.repository,
    required this.currentBalance,
  });

  static Future<CashTransaction?> show(
    BuildContext context, {
    required CashboxRepository repository,
    required int currentBalance,
  }) {
    return showDialog<CashTransaction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordOwnerWithdrawalDialog(
        repository: repository,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  State<RecordOwnerWithdrawalDialog> createState() => _RecordOwnerWithdrawalDialogState();
}

class _RecordOwnerWithdrawalDialogState extends State<RecordOwnerWithdrawalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    if (amount > widget.currentBalance) {
      setState(() => _errorMessage =
          'المبلغ المطلوب سحبه (${Formatters.formatCurrency(amount)}) يتجاوز رصيد الصندوق المتاح (${Formatters.formatCurrency(widget.currentBalance)})');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final saved = await widget.repository.recordOwnerWithdrawal(
        amount,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع أثناء تسجيل مسحوبات المالك';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_pin, color: Colors.purple.shade700),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'سحب نقدية لصاحب المحل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      // تم استخدام ConstrainedBox لضمان التجاوب ومنع تجاوز الشاشة
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 280),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
                // بطاقة توضيحية للرصيد المتاح وطبيعة الحركة
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الرصيد المتاح حالياً بالصندوق:',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          Text(
                            Formatters.formatCurrency(widget.currentBalance),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: widget.currentBalance > 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.info),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'مسحوبات المالك الشخصية تخفض رصيد الصندوق ولكنها لا تعتبر مصروفاً تشغيلياً ولا تؤثر على تكاليف النشاط.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المراد سحبه (ر.ي) *',
                    hintText: 'أدخل المبلغ',
                    prefixIcon: Icon(Icons.money_off),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال المبلغ المسحوب';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'يرجى إدخال رقم صحيح موجب';
                    }
                    if (num > widget.currentBalance) {
                      return 'المبلغ يتجاوز رصيد الصندوق المتاح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'تاريخ عملية السحب',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(Formatters.formatDate(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'السبب أو الملاحظات (اختياري)',
                    hintText: 'مثال: سلفة شخصية للمالك، مصاريف خاصة...',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('تأكيد السحب من الصندوق'),
        ),
      ],
    );
  }
}
