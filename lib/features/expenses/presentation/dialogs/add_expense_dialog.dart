import 'package:flutter/material.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expenses_repository.dart';

/// نافذة تسجيل مصروف تشغيلي جديد
class AddExpenseDialog extends StatefulWidget {
  final ExpensesRepository expensesRepository;
  final CashboxRepository cashboxRepository;

  const AddExpenseDialog({
    super.key,
    required this.expensesRepository,
    required this.cashboxRepository,
  });

  static Future<Expense?> show(
    BuildContext context, {
    required ExpensesRepository expensesRepository,
    required CashboxRepository cashboxRepository,
  }) {
    return showDialog<Expense>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddExpenseDialog(
        expensesRepository: expensesRepository,
        cashboxRepository: cashboxRepository,
      ),
    );
  }

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _newCategoryController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  int _currentCashBalance = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final cats = await widget.expensesRepository.getCategories();
      final balance = await widget.cashboxRepository.getCashBalance();

      if (mounted) {
        setState(() {
          _categories = cats;
          if (cats.isNotEmpty) {
            _selectedCategory = cats.first.name;
          }
          _currentCashBalance = balance;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addNewCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    try {
      final created = await widget.expensesRepository.createCategory(name);
      setState(() {
        _categories.add(created);
        _selectedCategory = created.name;
        _newCategoryController.clear();
      });
      if (mounted) {
        Navigator.of(context).pop(); // إغلاق حوار التصنيف الفرعي
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddCategorySubDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تصنيف مصروف جديد'),
        content: TextField(
          controller: _newCategoryController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم التصنيف',
            hintText: 'مثال: صيانة سيارات، تسويق وإعلانات...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _addNewCategory,
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      setState(() => _errorMessage = 'يرجى اختيار تصنيف المصروف');
      return;
    }

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    if (amount > _currentCashBalance) {
      setState(() => _errorMessage =
          'المبلغ المطلوب صرفه (${Formatters.formatCurrency(amount)}) يتجاوز رصيد الصندوق المتاح (${Formatters.formatCurrency(_currentCashBalance)}). لا يمكن جعل رصيد الصندوق سالباً.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final expense = Expense(
        id: 0,
        categoryName: _selectedCategory!,
        amount: amount,
        expenseDate: _selectedDate,
        description: _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final saved = await widget.expensesRepository.createExpense(expense);

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع أثناء تسجيل المصروف';
        _isSaving = false;
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
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.error),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تسجيل مصروف تشغيلي جديد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      // تم استخدام ConstrainedBox لضمان التجاوب ومنع تجاوز الشاشة
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 280),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
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

                      // ملخص الرصيد المتاح
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'رصيد الصندوق المتاح للصرف:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              Formatters.formatCurrency(_currentCashBalance),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _currentCashBalance > 0
                                    ? AppColors.primary
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // اختيار التصنيف مع زر إضافة تصنيف جديد
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'تصنيف المصروف *',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.name,
                                  child: Text(c.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCategory = val);
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'يرجى اختيار تصنيف';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'إضافة تصنيف جديد',
                            icon: const Icon(Icons.add),
                            onPressed: _showAddCategorySubDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'مبلغ المصروف (ر.ي) *',
                          hintText: 'أدخل المبلغ',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال مبلغ المصروف';
                          }
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) {
                            return 'يرجى إدخال رقم صحيح موجب';
                          }
                          if (num > _currentCashBalance) {
                            return 'المبلغ يتجاوز رصيد الصندوق المتاح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'البيان / الوصف *',
                          hintText: 'مثال: فاتورة كهرباء شهر مايو، أجور نقل البضاعة...',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى كتابة بيان ووصف المصروف';
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
                            labelText: 'تاريخ المصروف',
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
                          labelText: 'ملاحظات إضافية (اختياري)',
                          hintText: 'رقم السند الورقي، المستلم، أو أي تفاصيل أخرى...',
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('حفظ وصرف المصروف'),
        ),
      ],
    );
  }
}
