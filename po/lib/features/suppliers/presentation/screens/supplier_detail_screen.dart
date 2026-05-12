import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/purchase_repository.dart';
import '../../../../../core/providers/tenant_provider.dart';
import 'purchase_invoice_detail_screen.dart';
import 'purchase_invoice_screen.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../../../products/presentation/providers/product_providers.dart' as pos_prod;

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
                _buildProductsList(ref, supplier.id, searchQuery, ref.watch(tenantIdProvider)),
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
    final invoicesAsync = ref.watch(supplierInvoicesFutureProvider(supplierId));

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

  Widget _buildProductsList(WidgetRef ref, String supplierId, ValueNotifier<String> searchQuery, String tenantId) {
    final invoicesAsync = ref.watch(supplierInvoicesFutureProvider(supplierId));
    final productsAsync = ref.watch(pos_prod.productsFutureProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => searchQuery.value = val,
                  decoration: InputDecoration(
                    hintText: 'البحث باسم المنتج أو الباركود...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => _openScanner(ref.context, ref, searchQuery),
              ),
            ],
          ),
        ),
        Expanded(
          child: invoicesAsync.when(
            data: (invoices) {
        // Extract unique products bought from this supplier
        final productsMap = <String, Map<String, dynamic>>{};
        for (var inv in invoices) {
          for (var item in inv.items) {
            if (!productsMap.containsKey(item.productId)) {
              productsMap[item.productId] = {
                'id': item.productId,
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

        final productList = productsMap.values.where((p) {
          final search = searchQuery.value;
          if (search.isEmpty) return true;
          final nameMatch = p['name'].toString().toLowerCase().contains(search.toLowerCase());
          
          // Try to match barcode if productsAsync is available
          bool barcodeMatch = false;
          productsAsync.whenData((allProducts) {
             final prod = allProducts.where((ap) => ap.id == p['id']).firstOrNull;
             if (prod != null && prod.barcode == search) {
                barcodeMatch = true;
             }
          });
          
          return nameMatch || barcodeMatch || p['id'] == search; 
        }).toList();

        if (productList.isEmpty) {
          return const Center(child: Text('لا توجد مواد مطابقة للبحث'));
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
    ),
  ),
],
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
  
  void _openScanner(BuildContext context, WidgetRef ref, ValueNotifier<String> searchQuery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerWidget(
          onDetect: (barcode) {
            searchQuery.value = barcode;
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

final supplierInvoicesFutureProvider = FutureProvider.family.autoDispose<List<PurchaseInvoiceModel>, String>((ref, supplierId) async {
  final tenantId = ref.watch(tenantIdProvider);
  final repo = ref.watch(purchaseRepositoryProvider);
  return await repo.getInvoices(tenantId, supplierId: supplierId);
});
