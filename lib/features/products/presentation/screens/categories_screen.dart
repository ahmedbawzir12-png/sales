import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/categories_repository.dart';

/// شاشة إدارة تصنيفات المنتجات
class CategoriesScreen extends StatefulWidget {
  final CategoriesRepository? repository;

  const CategoriesScreen({super.key, this.repository});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoriesRepository _repository;
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CategoriesRepositoryImpl();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      final failure = ErrorHandler.handle(e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddEditDialog([Category? existingCategory]) async {
    final nameController = TextEditingController(text: existingCategory?.name ?? '');
    final descController = TextEditingController(text: existingCategory?.description ?? '');
    final formKey = GlobalKey<FormState>();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingCategory == null ? 'إضافة تصنيف جديد' : 'تعديل التصنيف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم التصنيف *',
                        hintText: 'مثال: فرش نوم ومفارش',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى كتابة اسم التصنيف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'وصف اختياري',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      if (existingCategory == null) {
                        final newCategory = Category(
                          id: 0,
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await _repository.createCategory(newCategory);
                      } else {
                        final updated = existingCategory.copyWith(
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                          updatedAt: DateTime.now(),
                        );
                        await _repository.updateCategory(updated);
                      }

                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                      }
                      if (mounted) {
                        _loadCategories();
                      }
                    } catch (e, stackTrace) {
                      final failure = ErrorHandler.handle(e, stackTrace);
                      setDialogState(() {
                        dialogError = failure.userFriendlyMessage;
                      });
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleCategory(Category category) async {
    try {
      await _repository.setCategoryActive(category.id, !category.isActive);
      _loadCategories();
    } catch (e, stackTrace) {
      final failure = ErrorHandler.handle(e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.userFriendlyMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصنيفات المنتجات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCategories,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة تصنيف'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadCategories,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? const Center(child: Text('لا توجد تصنيفات مضافة حتى الآن'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cat.isActive
                                  ? AppColors.primaryContainer
                                  : AppColors.surfaceHighlight,
                              child: Icon(
                                Icons.category_outlined,
                                color: cat.isActive ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: cat.isActive ? null : TextDecoration.lineThrough,
                                color: cat.isActive ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                            subtitle: cat.description != null && cat.description!.isNotEmpty
                                ? Text(cat.description!)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showAddEditDialog(cat),
                                ),
                                IconButton(
                                  tooltip: cat.isActive ? 'تعطيل التصنيف' : 'تفعيل التصنيف',
                                  icon: Icon(
                                    cat.isActive ? Icons.toggle_on : Icons.toggle_off,
                                    color: cat.isActive ? AppColors.success : AppColors.textMuted,
                                    size: 28,
                                  ),
                                  onPressed: () => _toggleCategory(cat),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
