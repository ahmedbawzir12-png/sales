import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import 'package:sales/core/presentation/widgets/primary_hero_card.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/repositories/purchases_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/suppliers_repository.dart';
import 'add_edit_supplier_dialog.dart';
import 'supplier_details_screen.dart';

/// شاشة قائمة الموردين مع البحث والتصفية وعرض إجمالي الديون
class SuppliersListScreen extends StatefulWidget {
  final SuppliersRepository repository;
  final PurchasesRepository purchasesRepository;

  SuppliersListScreen({
    super.key,
    SuppliersRepository? repository,
    PurchasesRepository? purchasesRepository,
  })  : repository = repository ?? SuppliersRepositoryImpl(),
        purchasesRepository = purchasesRepository ?? PurchasesRepositoryImpl();

  @override
  State<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Supplier> _suppliers = [];
  bool _onlyActive = true;
  bool _isLoading = true;
  int _totalDebt = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppDataNotifier.instance.addListener(_onAppDataChanged);
    _loadSuppliers();
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_onAppDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAppDataChanged() {
    final event = AppDataNotifier.instance.lastEvent;
    if (event == null) return;
    if (event.type == AppDataChangeType.suppliers ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 4)) {
      if (mounted) {
        _loadSuppliers(isSilent: true);
      }
    }
  }

  int _searchSequence = 0;

  Future<void> _loadSuppliers({bool isSilent = false}) async {
    final currentSeq = ++_searchSequence;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final suppliers = await widget.repository.getSuppliers(
        searchQuery: _searchController.text.trim(),
        onlyActive: _onlyActive,
      );
      final totalDebt = await widget.repository.getTotalSuppliersDebt();

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _suppliers = suppliers;
          _totalDebt = totalDebt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _errorMessage = 'فشل تحميل قائمة الموردين';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddSupplier() async {
    final result = await AddEditSupplierDialog.show(
      context,
      repository: widget.repository,
    );
    if (result != null) {
      _loadSuppliers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموردين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: _loadSuppliers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers_fab',
        onPressed: _openAddSupplier,
        icon: const Icon(Icons.person_add),
        label: const Text('مورد جديد'),
      ),
      body: Column(
        children: [
          // 1. حاوية المؤشرات الإحصائية للموردين — موحدة بالهوية الزرقاء الداكنة لنظام الصندوق
          PrimaryHeroCard(
            icon: Icons.business,
            title: 'دليل الموردين والذمم الدائنة',
            badge: 'سجل الموردين',
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryHeroMetricItem(
                      label: 'إجمالي الموردين',
                      value: '${_suppliers.length} مورد',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryHeroMetricItem(
                      label: 'ديون الموردين المستحقة',
                      value: AppFormatters.currency(_totalDebt),
                      icon: Icons.account_balance_wallet_outlined,
                      valueColor: _totalDebt > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. شريط البحث والتصفية
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث باسم المورد أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                                _loadSuppliers(isSilent: true);
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _loadSuppliers(isSilent: true);
                    },
                    onSubmitted: (_) => _loadSuppliers(isSilent: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('النشطين فقط'),
                  selected: _onlyActive,
                  onSelected: (val) {
                    setState(() => _onlyActive = val);
                    _loadSuppliers();
                  },
                ),
              ],
            ),
          ),

          // 3. قائمة الموردين
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadSuppliers,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _suppliers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'لا يوجد موردون مطابقون للبحث',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSuppliers,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _suppliers.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final s = _suppliers[index];
                                // تم استبدال Card بـ AppCard المتجاوب مع مسافة 16px وحواف ناعمة 14px وبدون أبعاد ثابتة
                                return AppCard(
                                  padding: const EdgeInsets.all(16), // مسافة داخلية مريحة لا تقل عن 16px
                                  backgroundColor: s.isActive ? AppColors.surface : AppColors.surfaceElevated,
                                  borderColor: s.currentBalance > 0 ? AppColors.error.withAlpha(90) : AppColors.border,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SupplierDetailsScreen(
                                          supplierId: s.id,
                                          suppliersRepository: widget.repository,
                                          purchasesRepository: widget.purchasesRepository,
                                        ),
                                      ),
                                    );
                                    _loadSuppliers();
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // أيقونة المورد الدائرية
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: s.isActive
                                              ? AppColors.primaryContainer
                                              : AppColors.surfaceHighlight,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.business,
                                          color: s.isActive ? AppColors.primary : AppColors.textMuted,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // تفاصيل المورد — تم استخدام Expanded لضمان عدم تجاوز النصوص
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: s.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              s.phone ?? s.address ?? (s.isActive ? 'مورد نشط' : 'مورد معطل'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: s.isActive ? AppColors.textSecondary : AppColors.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // بيانات الديون وحالة الحساب
                                      if (s.currentBalance > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorContainer,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.error.withAlpha(50)),
                                          ),
                                          child: Text(
                                            'مستحق: ${AppFormatters.currency(s.currentBalance)}',
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text(
                                          'لا توجد ديون',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
