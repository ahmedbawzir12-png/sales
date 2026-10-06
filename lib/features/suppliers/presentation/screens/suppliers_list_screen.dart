import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
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
          // 1. شريط إحصائي أعلى الشاشة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.people, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'عدد الموردين: ${_suppliers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _totalDebt > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _totalDebt > 0 ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    'إجمالي الديون: ${AppFormatters.currency(_totalDebt)}',
                    style: TextStyle(
                      color: _totalDebt > 0 ? Colors.red.shade800 : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
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
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: s.isActive
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        Icons.business,
                                        color: s.isActive
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.grey,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: s.isActive ? null : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        if (s.currentBalance > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.red.shade200),
                                            ),
                                            child: Text(
                                              'مستحق: ${AppFormatters.currency(s.currentBalance)}',
                                              style: TextStyle(
                                                color: Colors.red.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      s.phone ?? s.address ?? (s.isActive ? 'مورد نشط' : 'مورد معطل'),
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
