import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';

class SharedCartPreviewScreen extends ConsumerStatefulWidget {
  final String shareId;
  const SharedCartPreviewScreen({super.key, required this.shareId});

  @override
  ConsumerState<SharedCartPreviewScreen> createState() => _SharedCartPreviewScreenState();
}

class _SharedCartPreviewScreenState extends ConsumerState<SharedCartPreviewScreen> {
  List<Map<String, dynamic>>? _items;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final minimalItems = await ref.read(firestoreServiceProvider).getSharedCart(widget.shareId);
      if (!mounted) return;
      if (minimalItems == null) {
        setState(() { _error = 'Link expired or invalid'; _isLoading = false; });
        return;
      }

      // We need to fetch full product details for each minimal item
      final tenantId = await ref.read(resolvedTenantIdProvider.future);
      if (!mounted) return;
      final products = await ref.read(firestoreServiceProvider).getProducts(tenantId).first;
      if (!mounted) return;
      final List<Map<String, dynamic>> fullItems = [];
      
      for (var d in minimalItems) {
        try {
          final product = products.firstWhere((p) => p.id == d['id']);
          final quantity = d['q'] ?? 1;
          if (quantity is! int || quantity <= 0 || !product.inStock || product.isArchived) continue;
          final selected = product.variants.where((v) => v.color == (d['c'] ?? 'Default') && v.size == (d['s'] ?? 'Default')).firstOrNull;
          if (product.variants.isNotEmpty && selected == null) continue;
          fullItems.add({
            'imageUrl': product.images.firstOrNull,
            ...product.toJson(),
            'price': selected?.price ?? product.price,
            'quantity': quantity,
            'color': d['c'] ?? 'Default',
            'size': d['s'] ?? 'Default',
          });
        } catch (_) {
          continue;
        }
      }

      if (fullItems.isEmpty) throw StateError('No available products');
      setState(() { _items = fullItems; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load items'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenant = ref.watch(tenantProvider).value;
    final currencyUnit = tenant?.currencyUnit;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('shared_items_title', lang)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppStrings.get('shared_msg_prefix', lang)
                      .replaceFirst('{store}', tenant?.name ?? 'Store'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items!.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _items![index];
                      return ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: Text(item['name']),
                        subtitle: Text('${formatCurrency(item['price'] as double, unitOverride: currencyUnit)} x ${item['quantity']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                          onPressed: () {
                            ref.read(cartProvider.notifier).addToCart(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.get('added_to_cart_msg', lang)))
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              for (var item in _items!) {
                                ref.read(cartProvider.notifier).addToCart(item);
                              }
                              context.go('/cart');
                            },
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text(AppStrings.get('add_all_to_cart', lang)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.go('/home'),
                            child: Text(AppStrings.get('browse_products', lang)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
