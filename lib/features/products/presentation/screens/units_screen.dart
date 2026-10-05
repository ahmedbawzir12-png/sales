import 'package:flutter/material.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import '../../data/repositories/units_repository_impl.dart';
import '../../domain/entities/unit_of_measurement.dart';
import '../../domain/repositories/units_repository.dart';

/// شاشة إدارة وحدات القياس
class UnitsScreen extends StatefulWidget {
  final UnitsRepository? repository;

  const UnitsScreen({super.key, this.repository});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  late final UnitsRepository _repository;
  List<UnitOfMeasurement> _units = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? UnitsRepositoryImpl();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getUnits();
      if (mounted) {
        setState(() {
          _units = list;
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

  Future<void> _showAddEditDialog([UnitOfMeasurement? existingUnit]) async {
    final nameController = TextEditingController(text: existingUnit?.name ?? '');
    final symbolController = TextEditingController(text: existingUnit?.symbol ?? '');
    final formKey = GlobalKey<FormState>();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingUnit == null ? 'إضافة وحدة قياس جديدة' : 'تعديل وحدة القياس',
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
                        labelText: 'اسم الوحدة *',
                        hintText: 'مثال: متر، قطعة، كرتون',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى كتابة اسم الوحدة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: symbolController,
                      decoration: const InputDecoration(
                        labelText: 'رمز الوحدة / الاختصار *',
                        hintText: 'مثال: م، قطعة، كرتون',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى كتابة رمز الوحدة';
                        }
                        return null;
                      },
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
                      if (existingUnit == null) {
                        final newUnit = UnitOfMeasurement(
                          id: 0,
                          name: nameController.text.trim(),
                          symbol: symbolController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        await _repository.createUnit(newUnit);
                      } else {
                        final updated = existingUnit.copyWith(
                          name: nameController.text.trim(),
                          symbol: symbolController.text.trim(),
                        );
                        await _repository.updateUnit(updated);
                      }

                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                      }
                      if (mounted) {
                        _loadUnits();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وحدات القياس'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUnits,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'units_fab',
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة وحدة'),
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
                        onPressed: _loadUnits,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _units.isEmpty
                  ? const Center(child: Text('لا توجد وحدات قياس مضافة'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _units.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final unit = _units[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.secondaryContainer,
                              child: Text(
                                unit.symbol,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSecondaryContainer,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              unit.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('الرمز: ${unit.symbol}'),
                            trailing: IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showAddEditDialog(unit),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
