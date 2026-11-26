import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../utils/batch_inventory_helper.dart';

String _formatBatchDate(DateTime? dt) => dt == null
    ? '—'
    : '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class InventoryBalanceList extends StatelessWidget {
  final List<ProductModel> products;
  final bool showCost;
  final void Function(ProductModel) onOpenRecord;
  final Future<void> Function(ProductModel)? onReceiveBatch;
  const InventoryBalanceList({
    super.key,
    required this.products,
    required this.onOpenRecord,
    required this.showCost,
    this.onReceiveBatch,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const Center(child: Text('لا توجد أصناف'));
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        final alerts = BatchInventoryHelper.inspectBatches(p);
        final sellable = BatchInventoryHelper.sellableStock(p);
        final hasExpired = alerts.any((a) => a.isExpired);
        final hasExpiringSoon = alerts.any((a) => !a.isExpired);
        return ExpansionTile(
          key: PageStorageKey(p.id),
          title: Row(
            children: [
              Expanded(child: Text(p.name)),
              if (hasExpired)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'منتهي الصلاحية',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                  ),
                )
              else if (hasExpiringSoon)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ينتهي قريباً',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            sellable != p.stockQuantity
                ? 'الصالح للبيع: $sellable | الإجمالي: ${p.stockQuantity} ${p.unit ?? ''}'
                : 'الرصيد: ${p.stockQuantity} ${p.unit ?? ''}',
          ),
          children: [
            if (onReceiveBatch != null)
              ListTile(
                leading: const Icon(Icons.add_box_outlined, color: Colors.teal),
                title: const Text('استلام دفعة جديدة'),
                subtitle: const Text('تحديد الكمية، المخزن، تاريخ الاستلام والصلاحية'),
                onTap: () => onReceiveBatch!(p),
              ),
            for (final alert in alerts)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alert.isExpired ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.isExpired ? Colors.red.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert.isExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                      size: 18,
                      color: alert.isExpired ? Colors.red.shade700 : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: alert.isExpired ? Colors.red.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('سجل المخزون والجرد'),
              onTap: () => onOpenRecord(p),
            ),
            if (showCost)
              ListTile(
                title: const Text('قيمة الرصيد بسعر الشراء المسجل'),
                subtitle: Text(
                  p.purchasePrice == null
                      ? 'سعر الشراء غير مسجل'
                      : (p.stockQuantity * p.purchasePrice!).toStringAsFixed(2),
                ),
              ),
            for (final variant in p.variants)
              for (final location in BatchInventoryHelper.sortFefo(variant.storageLocations))
                Builder(
                  builder: (context) {
                    final expired = BatchInventoryHelper.isLocationExpired(location);
                    final soon = BatchInventoryHelper.isLocationExpiringSoon(location);
                    final variantLabel = [
                      variant.color,
                      variant.size,
                    ].where((v) => v != 'Default').join(' / ');
                    final details = <String>[
                      if (variantLabel.isNotEmpty) variantLabel,
                      if (location.batchNumber != null && location.batchNumber!.isNotEmpty)
                        'تشغيلة: ${location.batchNumber}',
                      if (location.receivedAt != null)
                        'استلام: ${_formatBatchDate(location.receivedAt)}',
                      if (location.expiryDate != null)
                        'انتهاء: ${_formatBatchDate(location.expiryDate)}',
                      if ((location.shelf ?? '').isNotEmpty || (location.box ?? '').isNotEmpty)
                        'موقع: ${location.shelf ?? '-'}/${location.box ?? '-'}',
                    ];
                    return ListTile(
                      tileColor: expired
                          ? Colors.red.withValues(alpha: 0.06)
                          : soon
                          ? Colors.orange.withValues(alpha: 0.06)
                          : null,
                      title: Text(location.warehouseName),
                      subtitle: Text(details.isEmpty ? 'بدون بيانات دفعة' : details.join(' • ')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${location.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (expired)
                            Text('منتهية', style: TextStyle(fontSize: 11, color: Colors.red.shade700))
                          else if (soon)
                            Text('قريبة الانتهاء', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                        ],
                      ),
                    );
                  },
                ),
            if (p.variants.every((v) => v.storageLocations.isEmpty))
              const ListTile(title: Text('الرصيد غير موزّع على مواقع تخزين')),
          ],
        );
      },
    );
  }
}
