import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';

class ProductListScreen extends HookConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncProducts = ref.watch(adminProductsProvider);
    final asyncCategories = ref.watch(adminCategoriesProvider);
    final searchQuery = useState('');
    final selectedCategory = useState('All');

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('products', lang)),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/dashboard'),
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => searchQuery.value = v,
                    decoration: InputDecoration(
                      hintText: AppStrings.get('search_hint', lang),
                      prefixIcon: const Icon(Icons.search),
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
                  final matchesSearch = p.name.toLowerCase().contains(searchQuery.value.toLowerCase());
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
                    
                    final imageUrl = product.images.isNotEmpty ? product.images.first : null;

                    final isLowStock = product.minStockLevel != null && product.stockQuantity <= (product.minStockLevel ?? 0);
                    final now = DateTime.now();
                    final isExpiringSoon = product.expiryDate != null && 
                                          product.expiryDate!.isAfter(now) && 
                                          product.expiryDate!.difference(now).inDays < 30;
                    final isExpired = product.expiryDate != null && product.expiryDate!.isBefore(now);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: Container(
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppStrings.get('stock_label', lang)}: ${product.stockQuantity} ${product.unit ?? ""}', 
                                style: TextStyle(color: isLowStock ? Colors.red : Colors.grey[700])),
                            Text('${AppStrings.get('barcode', lang)}: ${product.barcode ?? "---"}'),
                            if (product.expiryDate != null)
                              Text('${AppStrings.get('expiry_date', lang)}: ${product.expiryDate!.year}-${product.expiryDate!.month.toString().padLeft(2, '0')}-${product.expiryDate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.grey[700]))),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCurrency(product.price, lang: lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                if (isLowStock) 
                                  const Icon(Icons.warning, color: Colors.red, size: 18),
                                if (isExpiringSoon || isExpired)
                                  const Icon(Icons.event_busy, color: Colors.orange, size: 18),
                              ],
                            ),
                            const SizedBox(width: 8),
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final tenantId = ref.read(currentTenantIdProvider);
              ref.read(adminFirestoreServiceProvider).deleteProduct(product.id, tenantId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

