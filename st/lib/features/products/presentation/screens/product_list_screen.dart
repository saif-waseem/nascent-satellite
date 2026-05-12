import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/products/presentation/widgets/csv_import_export_dialog.dart';

class ProductListScreen extends HookConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncProducts = ref.watch(adminProductsProvider);
    final asyncCategories = ref.watch(adminCategoriesProvider);
    final selectedIds = useState<Set<String>>({});
    final selectionMode = useState(false);
    final searchQuery = useState('');
    final selectedCategory = useState('All');

    void toggleSelection(String id) {
      final current = {...selectedIds.value};
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      selectedIds.value = current;
      if (current.isEmpty) selectionMode.value = false;
    }

    return Scaffold(
      drawer: selectionMode.value ? null : const AdminDrawer(),
      appBar: AppBar(
        leading: selectionMode.value 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () {
              selectionMode.value = false;
              selectedIds.value = {};
            }) 
          : null,
        title: selectionMode.value 
          ? Text('${selectedIds.value.length} ${lang == 'ar' ? 'عنصر مختار' : 'Selected'}')
          : Text(AppStrings.get('products', lang)),
        actions: selectionMode.value 
          ? [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showBulkDeleteDialog(context, ref, selectedIds.value, selectionMode),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showBulkEditPriceDialog(context, ref, selectedIds.value, selectionMode),
              ),
            ]
          : [
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                onPressed: () => showDialog(context: context, builder: (_) => const CsvImportExportDialog()),
                icon: const Icon(Icons.import_export),
                tooltip: lang == 'ar' ? 'استيراد/تصدير' : 'Import/Export CSV',
              ),
              IconButton(
                onPressed: () => context.push('/dashboard'),
                icon: const Icon(Icons.analytics_outlined),
              ),
            ],
      ),
      body: Column(
        children: [
          if (!selectionMode.value)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => searchQuery.value = v,
                      decoration: InputDecoration(
                        hintText: lang == 'ar' ? 'بحث بالاسم أو الباركود...' : 'Search by name or barcode...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                          onPressed: () async {
                            final code = await showDialog<String>(
                              context: context,
                              builder: (context) => const BarcodeScannerDialog(),
                            );
                            if (code != null) {
                              searchQuery.value = code;
                              // We might need a controller to update the text field visually
                            }
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  asyncCategories.when(
                    data: (categories) => DropdownButton<String>(
                      value: selectedCategory.value,
                      onChanged: (v) => selectedCategory.value = v ?? 'All',
                      items: [
                        DropdownMenuItem(value: 'All', child: Text(AppStrings.get('all', lang))),
                        ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: asyncProducts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (products) {
                final filteredProducts = products.where((p) {
                  final query = searchQuery.value.toLowerCase();
                  final matchesSearch = p.name.toLowerCase().contains(query) || 
                                      (p.barcode?.toLowerCase().contains(query) ?? false);
                  final matchesCategory = selectedCategory.value == 'All' || p.category == selectedCategory.value;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(AppStrings.get('no_products', lang), style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => context.push('/product-form'),
                          icon: const Icon(Icons.add),
                          label: Text(AppStrings.get('add_product', lang)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isSelected = selectedIds.value.contains(product.id);
                    final categoryName = asyncCategories.maybeWhen(
                      data: (cats) => cats.any((c) => c.id == product.category) 
                        ? cats.firstWhere((c) => c.id == product.category).name 
                        : product.category,
                      orElse: () => product.category,
                    );
                    
                    final imageUrl = product.images.isNotEmpty ? product.images.first : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? Colors.blue[50] : null,
                      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue[300]!)) : null,
                      child: InkWell(
                        onLongPress: () {
                          if (!selectionMode.value) {
                            selectionMode.value = true;
                            toggleSelection(product.id);
                          }
                        },
                        onTap: selectionMode.value ? () => toggleSelection(product.id) : null,
                        child: ListTile(
                          leading: selectionMode.value 
                            ? Checkbox(value: isSelected, onChanged: (_) => toggleSelection(product.id))
                            : Container(
                                width: 50,
                                height: 50,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: imageUrl == null
                                  ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey)
                                  : (imageUrl.startsWith('http')
                                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey))
                                      : Icon(IconData(int.tryParse(imageUrl) ?? 58900, fontFamily: 'MaterialIcons'))),
                              ),
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${formatCurrency(product.price, lang: lang)} • Stock: ${product.stockQuantity} • $categoryName'),
                          trailing: selectionMode.value ? null : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => context.push('/product-form', extra: product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _showDeleteDialog(context, ref, product),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/product-form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showBulkDeleteDialog(BuildContext context, WidgetRef ref, Set<String> ids, ValueNotifier<bool> mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${ids.length} Products?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final tenantId = ref.read(currentTenantIdProvider);
              final service = ref.read(adminFirestoreServiceProvider);
              for (var id in ids) {
                await service.deleteProduct(id, tenantId);
              }
              mode.value = false;
              Navigator.pop(ctx);
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBulkEditPriceDialog(BuildContext context, WidgetRef ref, Set<String> ids, ValueNotifier<bool> mode) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Price for ${ids.length} items'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New Price', prefixIcon: Icon(Icons.attach_money)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                final tenantId = ref.read(currentTenantIdProvider);
                final service = ref.read(adminFirestoreServiceProvider);
                for (var id in ids) {
                   await service.updateProductPrice(id, newPrice, tenantId);
                }
                mode.value = false;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final tenantId = ref.read(currentTenantIdProvider);
              final service = ref.read(adminFirestoreServiceProvider);
              await service.deleteProduct(product.id, tenantId);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
