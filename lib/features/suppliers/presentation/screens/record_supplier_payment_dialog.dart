import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/repositories/supplier_payments_repository.dart';

/// نافذة تسجيل دفعة مالية للمورد لسداد المستحقات
class RecordSupplierPaymentDialog extends StatefulWidget {
  final Supplier supplier;
  final int currentDebt;
  final SupplierPaymentsRepository paymentsRepository;

  const RecordSupplierPaymentDialog({
    super.key,
    required this.supplier,
    required this.currentDebt,
    required this.paymentsRepository,
  });

  static Future<SupplierPayment?> show(
    BuildContext context, {
    required Supplier supplier,
    required int currentDebt,
    required SupplierPaymentsRepository paymentsRepository,
  }) {
    return showDialog<SupplierPayment>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordSupplierPaymentDialog(
        supplier: supplier,
        currentDebt: currentDebt,
        paymentsRepository: paymentsRepository,
      ),
    );
  }

  @override
  State<RecordSupplierPaymentDialog> createState() =>
      _RecordSupplierPaymentDialogState();
}

class _RecordSupplierPaymentDialogState
    extends State<RecordSupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;
  String? _errorMessage;

  int get _enteredAmount => int.tryParse(_amountController.text.trim()) ?? 0;
  int get _remainingAfterPayment =>
      (widget.currentDebt - _enteredAmount).clamp(0, widget.currentDebt);

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final amount = _enteredAmount;
    if (amount <= 0) {
      setState(() => _errorMessage = 'يجب إدخال مبلغ أكبر من الصفر');
      return;
    }

    if (amount > widget.currentDebt) {
      setState(() => _errorMessage =
          'المبلغ المدخل ($amount) يتجاوز إجمالي دين المورد المستحق (${widget.currentDebt})');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payment = SupplierPayment(
        id: 0,
        paymentNumber: '',
        supplierId: widget.supplier.id,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMethod: 'cash',
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      final saved = await widget.paymentsRepository.recordPayment(payment);

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSubmitting = false;
        });
      }
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.outbox_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تسجيل دفعة للمورد: ${widget.supplier.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      // تم استبدال العرض الثابت بـ ConstrainedBox لمرونة التكيف على الشاشات المختلفة
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          minWidth: 280,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),

                // بطاقة ملخص الأرصدة - استخدام IntrinsicHeight مع Expanded لمنع الارتفاع الثابت
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBalanceInfo(
                            title: 'الدين الحالي للمورد',
                            amount: widget.currentDebt,
                            color: AppColors.error,
                          ),
                        ),
                        const VerticalDivider(width: 16, thickness: 1),
                        Expanded(
                          child: _buildBalanceInfo(
                            title: 'المبلغ المدفوع',
                            amount: _enteredAmount,
                            color: AppColors.primary,
                          ),
                        ),
                        const VerticalDivider(width: 16, thickness: 1),
                        Expanded(
                          child: _buildBalanceInfo(
                            title: 'المتبقي بعد الدفع',
                            amount: _remainingAfterPayment,
                            color: _remainingAfterPayment == 0
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // حقل المبلغ
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الدفعة (ر.ي) *',
                    hintText: 'أدخل المبلغ المسدد للمورد',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال مبلغ الدفعة';
                    }
                    final val = int.tryParse(value.trim());
                    if (val == null || val <= 0) {
                      return 'يرجى إدخال رقم صحيح موجب';
                    }
                    if (val > widget.currentDebt) {
                      return 'المبلغ يتجاوز إجمالي دين المورد المستحق (${Formatters.formatCurrency(widget.currentDebt)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // حقل التاريخ
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _paymentDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الدفعة',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(Formatters.formatDate(_paymentDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // حقل السند / المرجع
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'رقم السند / الشيك / الحوالة (اختياري)',
                    hintText: 'سند صرف، حوالة بنكية، شيك...',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // حقل الملاحظات
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'أي تفاصيل إضافية عن السداد...',
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('حفظ وصرف الدفعة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceInfo({
    required String title,
    required int amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
