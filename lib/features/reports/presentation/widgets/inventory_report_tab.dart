import 'package:flutter/material.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/core/presentation/widgets/app_card.dart';
import '../../domain/entities/inventory_report_data.dart';
import '../../domain/entities/stock_movement_report_row.dart';

/// تبويب تقرير المخزون وحركات المستودع
class InventoryReportTab extends StatefulWidget {
  final InventoryReportData inventoryData;
  final List<StockMovementReportRow> movements;
  final bool isLoading;

  const InventoryReportTab({
    super.key,
    required this.inventoryData,
    required this.movements,
    this.isLoading = false,
  });

  @override
  State<InventoryReportTab> createState() => _InventoryReportTabState();
}

class _InventoryReportTabState extends State<InventoryReportTab> {
  int _subTabIndex = 0; // 0: حالة الأصناف, 1: سجل حركات المخزون
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = widget.inventoryData;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // بطاقات إجماليات المخزون
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'قيمة المخزون بالتكلفة',
              value: Formatters.currency(data.totalInventoryCostValue.round()),
              subtitle: 'محسوبة بمتوسط التكلفة',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              isProminent: true,
            ),
            _buildMetricCard(
              title: 'إجمالي الأصناف',
              value: '${data.totalProductsCount} صنف',
              subtitle: '${data.totalStockQuantity.toStringAsFixed(1)} وحدة متوفرة',
              icon: Icons.inventory_2_outlined,
              color: Colors.blueGrey,
            ),
            _buildMetricCard(
              title: 'أصناف متوفرة',
              value: '${data.inStockCount} صنف',
              subtitle: 'رصيد آمن',
              icon: Icons.check_circle_outline,
              color: Colors.green.shade700,
            ),
            _buildMetricCard(
              title: 'منخفض المخزون',
              value: '${data.lowStockCount} صنف',
              subtitle: 'دون حد إعادة الطلب',
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
            ),
            _buildMetricCard(
              title: 'أصناف نفدت',
              value: '${data.outOfStockCount} صنف',
              subtitle: 'رصيد صفر أو سالب',
              icon: Icons.highlight_off_rounded,
              color: Colors.red.shade700,
            ),
            _buildMetricCard(
              title: 'قيمة المخزون بسعر البيع',
              value: Formatters.currency(data.totalInventorySaleValue),
              subtitle: 'القيمة البيعية المتوقعة',
              icon: Icons.sell_outlined,
              color: Colors.teal.shade700,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // أزرار التبديل بين قائمة الأصناف وحركات المخزون
        Row(
          children: [
            ChoiceChip(
              label: const Text('دليل الأصناف وحالة المخزون'),
              selected: _subTabIndex == 0,
              onSelected: (val) => setState(() => _subTabIndex = 0),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _subTabIndex == 0 ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('سجل حركات المخزون (${widget.movements.length})'),
              selected: _subTabIndex == 1,
              onSelected: (val) => setState(() => _subTabIndex = 1),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _subTabIndex == 1 ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // شريط البحث اللحظي
        TextField(
          decoration: InputDecoration(
            hintText: _subTabIndex == 0
                ? 'بحث سريع في الأصناف والتصنيفات...'
                : 'بحث في سجل الحركات...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),

        // المحتوى التفاعلي
        if (_subTabIndex == 0) _buildProductsList(data) else _buildMovementsList(),
      ],
    );
  }

  Widget _buildProductsList(InventoryReportData data) {
    final filtered = data.items.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.name.toLowerCase().contains(_searchQuery) ||
          it.categoryName.toLowerCase().contains(_searchQuery);
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة الأصناف في المستودع (${filtered.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Divider(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('لا توجد أصناف مطابقة')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final statusColor = item.isOut
                    ? Colors.red
                    : (item.isLow ? Colors.orange : Colors.green);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  title: Row(
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withAlpha(100)),
                        ),
                        child: Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${item.categoryName} • المخزون: ${item.currentStock} ${item.unitSymbol} (حد الطلب: ${item.minimumStock}) • تكلفة: ${Formatters.currency(item.averageCost.round())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(item.totalCostValue.round()),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'بيع: ${Formatters.currency(item.salePrice)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMovementsList() {
    final filtered = widget.movements.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.productName.toLowerCase().contains(_searchQuery) ||
          m.movementType.toLowerCase().contains(_searchQuery) ||
          m.reason.toLowerCase().contains(_searchQuery);
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل حركات المخزون (${filtered.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Divider(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('لا توجد حركات مخزون مطابقة')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final m = filtered[idx];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor:
                        m.isAddition ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      m.isAddition ? Icons.arrow_downward : Icons.arrow_upward,
                      color: m.isAddition ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        m.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.movementType,
                        style: TextStyle(
                          fontSize: 12,
                          color: m.isAddition ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${Formatters.formatDateTime(m.createdAt)} • قبل: ${m.stockBefore} -> بعد: ${m.stockAfter} (${m.reason})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '${m.isAddition ? "+" : "-"}${m.quantity} ${m.unitSymbol}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: m.isAddition ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isProminent = false,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isProminent ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProminent ? AppColors.primary : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isProminent ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: isProminent ? Colors.white70 : color,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isProminent ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isProminent ? Colors.white60 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
