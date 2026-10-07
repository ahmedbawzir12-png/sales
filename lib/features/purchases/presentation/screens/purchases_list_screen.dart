import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../data/repositories/purchases_repository_impl.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_status.dart';
import '../../domain/entities/purchase_payment_type.dart';
import '../../domain/repositories/purchases_repository.dart';
import 'new_purchase_invoice_screen.dart';
import 'purchase_invoice_details_screen.dart';

/// شاشة قائمة فواتير الشراء مع البحث والتصفية وعرض الملخص
class PurchasesListScreen extends StatefulWidget {
  final PurchasesRepository repository;

  PurchasesListScreen({
    super.key,
    PurchasesRepository? repository,
  }) : repository = repository ?? PurchasesRepositoryImpl();

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseInvoice> _invoices = [];
  PurchasePaymentType? _selectedPaymentType;
  PurchaseInvoiceStatus? _selectedStatus;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppDataNotifier.instance.addListener(_onAppDataChanged);
    _loadInvoices();
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
    if (event.type == AppDataChangeType.purchases ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 2)) {
      if (mounted) {
        _loadInvoices(isSilent: true);
      }
    }
  }

  int _searchSequence = 0;

  Future<void> _loadInvoices({bool isSilent = false}) async {
    final currentSeq = ++_searchSequence;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final invoices = await widget.repository.getInvoices(
        searchQuery: _searchController.text.trim(),
        paymentType: _selectedPaymentType,
        status: _selectedStatus,
      );

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _errorMessage = 'فشل تحميل قائمة فواتير الشراء';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openNewInvoice() async {
    final result = await Navigator.of(context).push<PurchaseInvoice>(
      MaterialPageRoute(
        builder: (_) => NewPurchaseInvoiceScreen(
          purchasesRepository: widget.repository,
        ),
      ),
    );

    if (result != null) {
      _loadInvoices();
    }
  }

  int get _totalCompletedAmount {
    return _invoices
        .where((inv) => !inv.isCancelled)
        .fold<int>(0, (sum, inv) => sum + inv.total);
  }

  int get _totalRemainingDebt {
    return _invoices
        .where((inv) => !inv.isCancelled)
        .fold<int>(0, (sum, inv) => sum + inv.remainingAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فواتير المشتريات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadInvoices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'purchases_fab',
        onPressed: _openNewInvoice,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('فاتورة شراء جديدة'),
      ),
      body: Column(
        children: [
          // 1. شريط ملخص إجمالي المشتريات والديون — تصميم مرن متجاوب بـ IntrinsicHeight
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // تم استخدام Expanded لضمان التجاوب والتمدد حسب حجم الشاشة
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'إجمالي المشتريات (النشطة)',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(_totalCompletedAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'المتبقي غير المسدد (ديون)',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(_totalRemainingDebt),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _totalRemainingDebt > 0 ? AppColors.error : AppColors.success,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. أدوات البحث والتصفية
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الفاتورة أو اسم المورد...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _loadInvoices(isSilent: true);
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _loadInvoices(isSilent: true);
                  },
                  onSubmitted: (_) => _loadInvoices(isSilent: true),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('الكل'),
                        selected: _selectedPaymentType == null && _selectedStatus == null,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedPaymentType = null;
                              _selectedStatus = null;
                            });
                            _loadInvoices();
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('نقداً'),
                        selected: _selectedPaymentType == PurchasePaymentType.cash,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? PurchasePaymentType.cash : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('آجل'),
                        selected: _selectedPaymentType == PurchasePaymentType.credit,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? PurchasePaymentType.credit : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('ملغاة'),
                        selected: _selectedStatus == PurchaseInvoiceStatus.cancelled,
                        onSelected: (val) {
                          setState(() => _selectedStatus = val ? PurchaseInvoiceStatus.cancelled : null);
                          _loadInvoices();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. قائمة الفواتير
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
                              onPressed: _loadInvoices,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _invoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد فواتير شراء مسجلة',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadInvoices,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _invoices.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                // تم استبدال Card بـ AppCard المتجاوب بمسافة 16px وحواف ناعمة 14px وبدون أبعاد ثابتة
                                return AppCard(
                                  padding: const EdgeInsets.all(16), // مسافة داخلية مريحة لا تقل عن 16px
                                  backgroundColor: invoice.isCancelled ? AppColors.surfaceElevated : AppColors.surface,
                                  borderColor: invoice.isCancelled
                                      ? AppColors.borderStrong
                                      : (!invoice.isPaidInFull && invoice.remainingAmount > 0
                                          ? AppColors.warning.withAlpha(90)
                                          : AppColors.border),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PurchaseInvoiceDetailsScreen(
                                          invoiceId: invoice.id,
                                          purchasesRepository: widget.repository,
                                        ),
                                      ),
                                    );
                                    _loadInvoices();
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // أيقونة حالة الفاتورة بتصميم دائري متناسق
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: invoice.isCancelled
                                              ? AppColors.surfaceHighlight
                                              : invoice.isPaidInFull
                                                  ? AppColors.successContainer
                                                  : AppColors.warningContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          invoice.isCancelled
                                              ? Icons.close
                                              : invoice.isPaidInFull
                                                  ? Icons.check
                                                  : Icons.access_time,
                                          color: invoice.isCancelled
                                              ? AppColors.textMuted
                                              : invoice.isPaidInFull
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // تفاصيل الفاتورة والمورد — تم إضافة Expanded لمنع تجاوز النصوص
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    invoice.invoiceNumber,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      decoration: invoice.isCancelled ? TextDecoration.lineThrough : null,
                                                      color: invoice.isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceHighlight,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    invoice.paymentType.arabicLabel,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'المورد: ${invoice.supplierName ?? "غير محدد"}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: invoice.isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'التاريخ: ${AppFormatters.date(invoice.invoiceDate)}',
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // المبالغ المالية
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            AppFormatters.currency(invoice.total),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: invoice.isCancelled ? AppColors.textMuted : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            invoice.isCancelled
                                                ? 'ملغاة'
                                                : invoice.isPaidInFull
                                                    ? 'مسددة بالكامل'
                                                    : 'متبقي: ${AppFormatters.currency(invoice.remainingAmount)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: invoice.isCancelled
                                                  ? AppColors.textMuted
                                                  : invoice.isPaidInFull
                                                      ? AppColors.success
                                                      : AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
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
