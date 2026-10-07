import 'package:flutter/material.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/cash_transaction.dart';
import '../../domain/repositories/cashbox_repository.dart';

/// نافذة تسجيل الرصيد الافتتاحي الأولي للصندوق
class SetOpeningBalanceDialog extends StatefulWidget {
  final CashboxRepository repository;

  const SetOpeningBalanceDialog({
    super.key,
    required this.repository,
  });

  static Future<CashTransaction?> show(
    BuildContext context, {
    required CashboxRepository repository,
  }) {
    return showDialog<CashTransaction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SetOpeningBalanceDialog(repository: repository),
    );
  }

  @override
  State<SetOpeningBalanceDialog> createState() => _SetOpeningBalanceDialogState();
}

class _SetOpeningBalanceDialogState extends State<SetOpeningBalanceDialog> {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final saved = await widget.repository.setOpeningBalance(
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
        _errorMessage = 'حدث خطأ غير متوقع أثناء تسجيل الرصيد الافتتاحي';
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
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تسجيل الرصيد الافتتاحي للصندوق',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      // تم استخدام ConstrainedBox لتوفير تصميم متجاوب بدون أبعاد ثابتة
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
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'تنبيه: الرصيد الافتتاحي يُسجل مرة واحدة فقط عند بدء العمل على النظام، ويمثل النقدية الفعلية الموجودة في الصندوق حالياً.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الرصيد الافتتاحي (ر.ي) *',
                    hintText: 'مثال: 500000',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال مبلغ الرصيد الافتتاحي';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'يرجى إدخال رقم صحيح موجب أكبر من الصفر';
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
                      labelText: 'تاريخ بدء الرصيد',
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
                    labelText: 'ملاحظات أو بيان توضيحي (اختياري)',
                    hintText: 'مثال: جرد النقدية بالدرج قبل بدء التشغيل...',
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
            backgroundColor: AppColors.secondary,
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
          label: const Text('اعتماد الرصيد الافتتاحي'),
        ),
      ],
    );
  }
}
