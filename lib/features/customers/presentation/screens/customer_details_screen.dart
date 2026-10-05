import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import 'add_edit_customer_dialog.dart';

/// شاشة تفاصيل العميل وإحصائيات مبيعاته وديونه المستحقة
class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;
  final CustomersRepository repository;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.repository,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  Customer? _customer;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customer = await widget.repository.getCustomerById(widget.customerId);
      final stats = await widget.repository.getCustomerStatistics(widget.customerId);
      if (mounted) {
        setState(() {
          _customer = customer;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل بيانات العميل';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editCustomer() async {
    if (_customer == null) return;
    final updated = await AddEditCustomerDialog.show(
      context,
      repository: widget.repository,
      customerToEdit: _customer,
    );
    if (updated != null) {
      _loadCustomerDetails();
    }
  }

  Future<void> _toggleStatus() async {
    if (_customer == null) return;
    final newStatus = !_customer!.isActive;
    final actionText = newStatus ? 'تنشيط' : 'تعطيل';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionText العميل'),
        content: Text('هل أنت متأكد من رغبتك في $actionText حساب العميل "${_customer!.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.toggleCustomerActive(_customer!.id, newStatus);
        _loadCustomerDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم $actionText العميل بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل تغيير حالة العميل')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'تفاصيل العميل'),
        actions: [
          if (_customer != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل البيانات',
              onPressed: _editCustomer,
            ),
            IconButton(
              icon: Icon(_customer!.isActive ? Icons.block : Icons.check_circle_outline),
              tooltip: _customer!.isActive ? 'تعطيل العميل' : 'تنشيط العميل',
              onPressed: _toggleStatus,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _customer == null
                  ? const Center(child: Text('العميل غير موجود'))
                  : RefreshIndicator(
                      onRefresh: _loadCustomerDetails,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. بطاقة معلومات العميل
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: AppColors.primaryContainer,
                                        child: const Icon(Icons.person, size: 32, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _customer!.name,
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _customer!.isActive ? AppColors.successContainer : AppColors.errorContainer,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _customer!.isActive ? 'نشط' : 'معطل',
                                                style: TextStyle(
                                                  color: _customer!.isActive ? AppColors.success : AppColors.error,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (_customer!.phone != null && _customer!.phone!.isNotEmpty) ...[
                                    _buildInfoRow(Icons.phone, 'الهاتف', _customer!.phone!),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_customer!.whatsapp != null && _customer!.whatsapp!.isNotEmpty) ...[
                                    _buildInfoRow(Icons.chat, 'واتساب', _customer!.whatsapp!),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_customer!.address != null && _customer!.address!.isNotEmpty) ...[
                                    _buildInfoRow(Icons.location_on_outlined, 'العنوان', _customer!.address!),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_customer!.notes != null && _customer!.notes!.isNotEmpty) ...[
                                    _buildInfoRow(Icons.note_alt_outlined, 'ملاحظات', _customer!.notes!),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildInfoRow(
                                    Icons.calendar_today_outlined,
                                    'تاريخ التسجيل',
                                    AppFormatters.date(_customer!.createdAt),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. المؤشرات المالية والمبيعات
                          Text(
                            'المؤشرات المالية والمبيعات',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'رصيد الدين المستحق',
                                  value: AppFormatters.currency(_customer!.currentBalance),
                                  color: _customer!.currentBalance > 0 ? AppColors.error : AppColors.success,
                                  icon: Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'عدد فواتير البيع',
                                  value: '${_stats?['invoiceCount'] ?? 0} فاتورة',
                                  color: AppColors.primary,
                                  icon: Icons.receipt_long_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'إجمالي المبيعات',
                                  value: AppFormatters.currency(_stats?['totalSales'] ?? 0),
                                  color: AppColors.textPrimary,
                                  icon: Icons.shopping_bag_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'إجمالي المقبوضات',
                                  value: AppFormatters.currency(_stats?['totalPaid'] ?? 0),
                                  color: AppColors.success,
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
