import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/purchase_repository.dart';
import '../../../../../core/providers/tenant_provider.dart';
import 'purchase_invoice_detail_screen.dart';
import 'purchase_invoice_screen.dart';

class SupplierDetailScreen extends HookConsumerWidget {
  final SupplierModel supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final tabController = useTabController(initialLength: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'الفواتير / Invoices'),
            Tab(text: 'المواد / Products'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryHeader(supplier),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _buildInvoicesList(ref, supplier.id),
                _buildProductsList(ref, supplier.id, searchQuery.value),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewInvoiceDialog(context, ref, supplier),
        label: const Text('شراء جديد'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  Widget _buildSummaryHeader(SupplierModel supplier) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('رقم الهاتف', supplier.phoneNumber),
          _buildInfoItem(
            'الحساب الحالي', 
            '${supplier.balance.toStringAsFixed(2)} IQD',
            color: supplier.balance >= 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildInvoicesList(WidgetRef ref, String supplierId) {
    final invoicesAsync = ref.watch(supplierInvoicesProvider(supplierId));

    return invoicesAsync.when(
      data: (invoices) => ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final inv = invoices[index];
          return ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseInvoiceDetailScreen(invoice: inv))),
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('فاتورة #${inv.id.substring(0, 5)}'),
            subtitle: Text('${inv.date.day}/${inv.date.month}/${inv.date.year}'),
            trailing: Text(
              '${inv.totalAmount.toStringAsFixed(2)} IQD', 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildProductsList(WidgetRef ref, String supplierId, String search) {
    final invoicesAsync = ref.watch(supplierInvoicesProvider(supplierId));

    return invoicesAsync.when(
      data: (invoices) {
        // Extract unique products bought from this supplier
        final productsMap = <String, Map<String, dynamic>>{};
        for (var inv in invoices) {
          for (var item in inv.items) {
            if (!productsMap.containsKey(item.productId)) {
              productsMap[item.productId] = {
                'name': item.productName,
                'lastPrice': item.unitCost,
                'totalQty': 0.0,
                'lastDate': inv.date,
              };
            }
            productsMap[item.productId]!['totalQty'] += item.quantity;
            if (inv.date.isAfter(productsMap[item.productId]!['lastDate'])) {
              productsMap[item.productId]!['lastPrice'] = item.unitCost;
              productsMap[item.productId]!['lastDate'] = inv.date;
            }
          }
        }

        final productList = productsMap.values.toList();
        if (productList.isEmpty) {
          return const Center(child: Text('لم يتم شراء أي مواد من هذا المورد حتى الآن'));
        }

        return ListView.separated(
          itemCount: productList.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final p = productList[index];
            return ListTile(
              title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('آخر سعر شراء: ${p['lastPrice']} IQD'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('إجمالي الكمية: ${p['totalQty']}', style: const TextStyle(color: Colors.blue)),
                  const Text('مادة مشتراة', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showNewInvoiceDialog(BuildContext context, WidgetRef ref, SupplierModel supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseInvoiceScreen(initialSupplier: supplier),
      ),
    );
  }
}

final supplierInvoicesProvider = StreamProvider.family.autoDispose<List<PurchaseInvoiceModel>, String>((ref, supplierId) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(purchaseRepositoryProvider).watchSupplierInvoices(tenantId, supplierId);
});
