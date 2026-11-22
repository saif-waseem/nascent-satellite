import '../../../../core/providers/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';
import '../providers/product_providers.dart';
import '../providers/category_provider.dart';
import 'product_form_screen.dart';
import '../../data/product_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/widgets/smart_image.dart';
import '../widgets/pos_excel_import_export_dialog.dart';

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
    final searchQuery = ref.watch(productSearchQueryProvider);
    final pagedState = ref.watch(pagedGeneralProductsProvider);
    final searchResultsAsync = ref.watch(filteredProductsProvider);
    final productCountAsync = ref.watch(productCountProvider);
    final scrollController = useScrollController();

    useEffect(() {
      void listener() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
          if (searchQuery.isEmpty) {
            ref.read(pagedGeneralProductsProvider.notifier).loadMore();
          }
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController, searchQuery]);

    Widget buildList(List<ProductModel> products, {bool hasMore = false}) {
      if (products.isEmpty) {
        return const Center(child: Text('لا يوجد منتجات حالياً'));
      }
      return RefreshIndicator(
        onRefresh: () async {
          if (searchQuery.isEmpty) {
            ref.read(pagedGeneralProductsProvider.notifier).loadInitial();
          } else {
            ref.invalidate(filteredProductsProvider);
          }
        },
        child: ListView.builder(
          controller: scrollController,
          itemCount: products.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == products.length) {
              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
            }
            final product = products[index];
            return _ProductListTile(product: product);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إدارة المنتجات / Products', style: TextStyle(fontSize: 16)),
            productCountAsync.when(
              data: (count) => Text('إجمالي المنتجات: $count', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              loading: () => const Text('جاري التحميل...', style: TextStyle(fontSize: 11)),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        actions: [
          if (ref.hasPermission(PosPermission.manageProducts))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade100,
                  foregroundColor: Colors.brown.shade900,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('تراجع عن آخر تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final repo = ref.read(productRepositoryProvider), tenant = ref.read(tenantIdProvider);
                  repo.undo.show(context, tenant, (entry) => repo.undoEntry(tenant, entry));
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: Colors.green),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const PosExcelImportExportDialog(),
            ),
            tooltip: 'استيراد وتصدير إكسل / Excel Import-Export',
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: () => _showArchiveDialog(context, ref),
            tooltip: 'الأرشيف / Archive',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (searchQuery.isEmpty) {
                ref.read(pagedGeneralProductsProvider.notifier).loadInitial();
              } else {
                ref.invalidate(filteredProductsProvider);
              }
            },
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
      body: searchQuery.isEmpty
          ? (pagedState.error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('خطأ في تحميل البيانات:', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(pagedState.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(pagedGeneralProductsProvider.notifier).loadInitial(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ))
              : (pagedState.products.isEmpty && pagedState.isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : buildList(pagedState.products, hasMore: pagedState.hasMore)))
          : searchResultsAsync.when(
              data: (products) => buildList(products),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('خطأ في البحث: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(filteredProductsProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              )),
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

class _ProductListTile extends ConsumerWidget {
  final ProductModel product;
  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ? SmartImage(
                imageUrl: product.images.first, 
                width: 50, 
                height: 50, 
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 50, 
                  height: 50, 
                  color: Colors.grey[200], 
                  child: const Icon(Icons.broken_image, size: 20)
                ),
              )
            : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.name, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            ref.watch(categoriesListProvider).when(
              data: (categories) {
                final cat = categories.where((c) => c.id == product.category || c.name == product.category).firstOrNull;
                return Text('القسم: ${cat?.name ?? product.category}', 
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
              loading: () => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
              error: (_, __) => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 2),
            Text('الكمية: ${product.stockQuantity} ${product.unit ?? ""}', 
                style: TextStyle(color: isLowStock ? Colors.red : Colors.black, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
            ),
            if (product.variants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  product.variants.map((v) => '${v.color}/${v.size}: ${v.stock}').join(' | '),
                  style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Text('الباركود: ${product.barcode ?? "---"}', 
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (product.expiryDate != null)
              Text('الصلاحية: ${DateFormat('yyyy-MM-dd').format(product.expiryDate!)}',
                  style: TextStyle(color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.black), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
              ),
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
