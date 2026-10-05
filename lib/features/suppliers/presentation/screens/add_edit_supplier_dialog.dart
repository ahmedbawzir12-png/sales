import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/suppliers_repository.dart';

/// نافذة إضافة أو تعديل بيانات مورد
class AddEditSupplierDialog extends StatefulWidget {
  final SuppliersRepository repository;
  final Supplier? supplierToEdit;

  const AddEditSupplierDialog({
    super.key,
    required this.repository,
    this.supplierToEdit,
  });

  static Future<Supplier?> show(
    BuildContext context, {
    required SuppliersRepository repository,
    Supplier? supplierToEdit,
  }) {
    return showDialog<Supplier>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditSupplierDialog(
        repository: repository,
        supplierToEdit: supplierToEdit,
      ),
    );
  }

  @override
  State<AddEditSupplierDialog> createState() => _AddEditSupplierDialogState();
}

class _AddEditSupplierDialogState extends State<AddEditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.supplierToEdit != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplierToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _whatsappController = TextEditingController(text: s?.whatsapp ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final updated = widget.supplierToEdit!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          whatsapp: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await widget.repository.updateSupplier(updated);
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final newSupplier = Supplier(
          id: 0,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          whatsapp: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await widget.repository.createSupplier(newSupplier);
        if (mounted) Navigator.of(context).pop(created);
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع أثناء حفظ بيانات المورد';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_note : Icons.person_add_alt_1,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(_isEditing ? 'تعديل بيانات المورد' : 'إضافة مورد جديد'),
        ],
      ),
      content: SizedBox(
        width: 460,
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المورد أو الشركة *',
                    hintText: 'مثال: شركة الأندلس للأقمشة',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال اسم المورد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: 'مثال: 771234567',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الواتساب (اختياري)',
                    hintText: 'مثال: 771234567',
                    prefixIcon: Icon(Icons.chat),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان أو الموقع',
                    hintText: 'مثال: صنعاء - شارع تعز',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات إضافية',
                    hintText: 'شروط التوريد، التخصص، أو شروط السداد...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
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
          onPressed: _isLoading ? null : _saveSupplier,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المورد'),
        ),
      ],
    );
  }
}
