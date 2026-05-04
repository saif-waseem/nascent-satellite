import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:shared_ui/shared_ui.dart';

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncProducts = ref.watch(adminProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('inventory_alerts', lang)),
      ),
      body: asyncProducts.when(
        loading: () => const SkeletonList(),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (products) {
          final lowStockProducts = products
              .where((p) => p.stockQuantity <= (p.minStockLevel ?? 5) || !p.inStock)
              .toList()
            ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

          if (lowStockProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.get('no_inventory_alerts', lang),
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockProducts.length,
            itemBuilder: (context, index) {
              final product = lowStockProducts[index];
              final isOutOfStock = !product.inStock || product.stockQuantity <= 0;

              final asyncPredictions = ref.watch(stockPredictionsProvider);
              final prediction = asyncPredictions.maybeWhen(
                data: (map) => map[product.id],
                orElse: () => null,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (product.imageUrl != null && product.imageUrl!.startsWith('http'))
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory))
                        : Icon(IconData(int.tryParse(product.imageUrl ?? '58900') ?? 58900, fontFamily: 'MaterialIcons'), color: Colors.grey),
                  ),
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOutOfStock
                            ? AppStrings.get('out_of_stock', lang)
                            : '${AppStrings.get('stock_quantity_label', lang)}: ${product.stockQuantity}',
                        style: TextStyle(
                          color: isOutOfStock ? Colors.red : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (prediction != null && prediction < 900)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_graph, size: 12, color: prediction < 7 ? Colors.red : Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.get('stock_run_out_msg', lang).replaceFirst('{days}', prediction.toStringAsFixed(1)),
                                style: TextStyle(fontSize: 11, color: prediction < 7 ? Colors.red : Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note),
                    onPressed: () => context.push('/product-form', extra: product),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
