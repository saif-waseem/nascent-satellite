import 'package:flutter/material.dart';
import '../models/product_model.dart';

class InventoryBalanceList extends StatelessWidget {
  final List<ProductModel> products;
  final bool showCost;
  final void Function(ProductModel) onOpenRecord;
  const InventoryBalanceList({
    super.key,
    required this.products,
    required this.onOpenRecord,
    required this.showCost,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const Center(child: Text('لا توجد أصناف'));
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return ExpansionTile(
          key: PageStorageKey(p.id),
          title: Text(p.name),
          subtitle: Text('الرصيد: ${p.stockQuantity} ${p.unit ?? ''}'),
          children: [
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
              for (final location in variant.storageLocations)
                ListTile(
                  title: Text(location.warehouseName),
                  subtitle: Text(
                    [
                      variant.color,
                      variant.size,
                    ].where((v) => v != 'Default').join(' / '),
                  ),
                  trailing: Text('${location.quantity}'),
                ),
            if (p.variants.every((v) => v.storageLocations.isEmpty))
              const ListTile(title: Text('الرصيد غير موزّع على مواقع تخزين')),
          ],
        );
      },
    );
  }
}
