import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';
import '../providers/product_providers.dart';
import 'product_form_screen.dart';
import '../../data/product_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../widgets/pos_excel_dialog.dart';

class ProductListScreen extends HookConsumerWidget {
  const ProductListScreen({super.key});

  void _showArchiveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final archivedAsync = ref.watch(archivedProductsProvider);
          final tenantId = ref.watch(tenantIdProvider);

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('أرشيف المنتجات'),
                if (archivedAsync.value?.isNotEmpty ?? false)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('حذف الكل نهائياً؟'),
                          content: const Text('سيتم مسح جميع المنتجات في الأرشيف من السيرفر. لا يمكن التراجع!'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('تفريغ الأرشيف'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(productRepositoryProvider).emptyArchive(tenantId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    label: const Text('تفريغ الأرشيف', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: archivedAsync.when(
                data: (products) {
                  if (products.isEmpty) return const Center(child: Text('الأرشيف فارغ'));
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('باركود: ${p.barcode ?? "---"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.unarchive, color: Colors.blue),
                          onPressed: () async {
                            await ref.read(productRepositoryProvider).saveProduct(tenantId, p.copyWith(isArchived: false));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة المنتج')));
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات / Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: Colors.green),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const PosExcelDialog(),
            ),
            tooltip: 'استيراد وتصدير إكسل (Excel)',
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: () => _showArchiveDialog(context, ref),
            tooltip: 'الأرشيف / Archive',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(productsStreamProvider),
            tooltip: 'تحديث البيانات / Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => ref.read(productSearchQueryProvider.notifier).set(val),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الباركود أو التصنيف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('لا يوجد منتجات حالياً'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(productsStreamProvider),
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductListTile(product: product);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ),
        label: const Text('إضافة منتج جديد'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final ProductModel product;
  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.minStockLevel != null && product.stockQuantity <= (product.minStockLevel ?? 0);
    final now = DateTime.now();
    final isExpiringSoon = product.expiryDate != null && 
                          product.expiryDate!.isAfter(now) && 
                          product.expiryDate!.difference(now).inDays < 30;
    final isExpired = product.expiryDate != null && product.expiryDate!.isBefore(now);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: product.images.isNotEmpty 
            ? Image.network(
                product.images.first, 
                width: 50, 
                height: 50, 
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 50, 
                  height: 50, 
                  color: Colors.grey[200], 
                  child: const Icon(Icons.broken_image, size: 20)
                ),
              )
            : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${product.stockQuantity} ${product.unit ?? ""}', 
                style: TextStyle(color: isLowStock ? Colors.red : Colors.black)),
            Text('الباركود: ${product.barcode ?? "---"}'),
            if (product.expiryDate != null)
              Text('الصلاحية: ${DateFormat('yyyy-MM-dd').format(product.expiryDate!)}',
                  style: TextStyle(color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.black))),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${product.price} IQD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            if (isLowStock) 
              const Icon(Icons.warning, color: Colors.red, size: 20),
            if (isExpiringSoon || isExpired)
              const Icon(Icons.event_busy, color: Colors.orange, size: 20),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
        ),
      ),
    );
  }
}
