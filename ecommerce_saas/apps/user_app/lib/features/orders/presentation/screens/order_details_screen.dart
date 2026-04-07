import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:shared_models/shared_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncTenant = ref.watch(tenantProvider);

    if (ordersAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final orders = ordersAsync.value ?? [];
    final order = orders.firstWhere((o) => o.id == orderId, orElse: () => OrderModel(id: '', userId: '', tenantId: '', total: 0, items: const [], date: DateTime.now(), address: '', userName: '', userPhone: ''));
    
    if (order.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Not Found')),
        body: const Center(child: Text('Order not found')),
      );
    }
    
    final items = order.items;
    final status = order.status;
    final address = order.address;
    
    // Calculate values
    final subtotal = items.fold(0.0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1));
    final pointsToCurrency = asyncTenant.maybeWhen(data: (t) => t?.pointsToCurrencyRatio ?? 100.0, orElse: () => 100.0);
    final pointsDiscount = order.pointsRedeemed * pointsToCurrency;
    final shipping = (order.total - subtotal + pointsDiscount + order.discountAmount).clamp(0, double.infinity).toDouble();
    
    return Scaffold(
      appBar: AppBar(title: Text('${AppStrings.get('orders', lang)} #$orderId')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderStatusTimeline(context, order, lang),
            const SizedBox(height: 24),
            
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(AppStrings.get('address', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 if (status == OrderStatus.active)
                   IconButton(
                     onPressed: () => _showEditInfoDialog(context, ref, order, lang), 
                     icon: const Icon(Icons.edit, size: 20, color: Colors.blue)
                   ),
               ],
             ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(address.isEmpty ? 'No address provided' : address)),
                      ],
                    ),
                    if (order.landmark != null && order.landmark!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${AppStrings.get('landmark', lang)}: ${order.landmark}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(order.userPhone.isEmpty ? 'No phone provided' : order.userPhone)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(AppStrings.get('items_count', lang).replaceFirst('{count}', items.length.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 if (status == OrderStatus.active)
                    TextButton.icon(
                      onPressed: () => _showAddProductDialog(context, ref, order, lang),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: Text(AppStrings.get('add_product', lang)),
                    ),
               ],
             ),
            const SizedBox(height: 8),
            ...items.map((item) {
              final quantity = item['quantity'] ?? 1;
              final productId = item['id'] as String?;
              final size = item['size'];
              final color = item['color'];
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final imageUrl = item['imageUrl'] as String? ?? 
                  (item['images'] != null && (item['images'] as List).isNotEmpty ? (item['images'] as List).first as String : null);
              
              final asyncProducts = ref.watch(productsProvider);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: productId == null ? null : () {
                    ProductModel? fullProduct;
                    asyncProducts.whenData((products) {
                      try {
                        fullProduct = products.firstWhere((p) => p.id == productId);
                      } catch (_) {}
                    });
                    
                    if (fullProduct != null) {
                      context.push('/product-details', extra: fullProduct);
                    } else {
                      final pId = item['productId'] as String? ?? item['id'] as String? ?? '';
                      final partialProduct = ProductModel.fromJson({...item, 'id': pId, 'tenantId': order.tenantId});
                      context.push('/product-details', extra: partialProduct);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Builder(builder: (context) {
                    final isEditing = status == OrderStatus.active;
                    
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: imageUrl != null && (imageUrl.startsWith('http') || imageUrl.contains('/'))
                          ? CachedNetworkImage(
                              imageUrl: imageUrl, 
                              fit: BoxFit.cover, 
                              placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                            )
                          : Icon(IconData(int.tryParse(imageUrl ?? '58900') ?? 58900, fontFamily: 'MaterialIcons')),
                      ),
                      title: Text(item['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppStrings.get('qty', lang)}: $quantity'),
                          if (size != null && size != 'Default' && size != 'none') Text('${AppStrings.get('size', lang)}: $size', style: const TextStyle(fontSize: 12)),
                          if (color != null && color != 'Default' && color != 'none') Text('${AppStrings.get('color', lang)}: $color', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: isEditing 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                                onPressed: (item['quantity'] ?? 1) > 1 
                                  ? () async {
                                      final newItems = List<Map<String, dynamic>>.from(order.items.map((it) => Map<String, dynamic>.from(it)));
                                      final idx = newItems.indexWhere((it) => it['id'] == item['id'] && it['color'] == item['color'] && it['size'] == item['size']);
                                      if (idx != -1) {
                                        newItems[idx]['quantity'] = (newItems[idx]['quantity'] ?? 1) - 1;
                                        final newTotal = newItems.fold(0.0, (sum, it) => sum + ((it['price'] as num?)?.toDouble() ?? 0.0) * (it['quantity'] ?? 1));
                                        await ref.read(orderActionsProvider).updateOrderItems(order, newItems, newTotal);
                                      }
                                    }
                                  : null,
                              ),
                              Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                                onPressed: () async {
                                  final newItems = List<Map<String, dynamic>>.from(order.items.map((it) => Map<String, dynamic>.from(it)));
                                  final idx = newItems.indexWhere((it) => it['id'] == item['id'] && it['color'] == item['color'] && it['size'] == item['size']);
                                  if (idx != -1) {
                                    newItems[idx]['quantity'] = (newItems[idx]['quantity'] ?? 1) + 1;
                                    final newTotal = newItems.fold(0.0, (sum, it) => sum + ((it['price'] as num?)?.toDouble() ?? 0.0) * (it['quantity'] ?? 1));
                                    await ref.read(orderActionsProvider).updateOrderItems(order, newItems, newTotal);
                                  }
                                },
                              ),
                            ],
                          )
                        : Text(formatCurrency(price * quantity), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }),
                ),
              );
            }),
            
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(AppStrings.get('subtotal', lang)),
                Text(formatCurrency(subtotal)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(AppStrings.get('shipping', lang)),
                Text(formatCurrency(shipping)),
              ],
            ),
            const SizedBox(height: 16),
            if (order.discountAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${AppStrings.get('discount_code_label', lang)} (${order.couponCode ?? ""})'),
                  Text('-${formatCurrency(order.discountAmount)}', style: const TextStyle(color: Colors.green)),
                ],
              ),
            if (order.pointsRedeemed > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.get('points_redeem', lang)),
                  Text('-${formatCurrency(pointsDiscount)}', style: const TextStyle(color: Colors.green)),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.get('total', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(formatCurrency(order.total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)),
              ],
            ),
            
            if (status == OrderStatus.active) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                    onPressed: () async {
                         final cart = ref.read(cartProvider);
                         bool proceed = true;
                         if (cart.isNotEmpty) {
                           proceed = await showDialog<bool>(
                             context: context,
                             builder: (ctx) => AlertDialog(
                               title: const Text('Replace Cart?'),
                               content: const Text('Editing this order will replace your current cart items. Do you want to continue?'),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                 TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                               ],
                             ),
                           ) ?? false;
                         }

                         if (proceed) {
                           ref.read(cartProvider.notifier).loadFromOrder(order);
                           ref.read(editingOrderIdProvider.notifier).set(orderId);
                           if (context.mounted) context.push('/cart');
                         }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppStrings.get('edit', lang)), // Using 'edit' label
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(AppStrings.get('cancel_order', lang)),
                            content: Text(AppStrings.get('cancel_order_confirm', lang)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(AppStrings.get('cancel', lang)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(AppStrings.get('confirm', lang), style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ) ?? false;
                        
                        if (confirmed) {
                          await ref.read(orderActionsProvider).cancelOrder(orderId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('order_cancelled', lang))));
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: Text(AppStrings.get('cancel_order', lang)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusTimeline(BuildContext context, OrderModel order, String lang) {
    if (order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(AppStrings.get('status_cancelled', lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
            const SizedBox(height: 4),
            Text(AppStrings.get('cancel_order_confirm', lang), style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
      );
    }

    final currentTracking = order.tracking;
    final isCompleted = order.status == OrderStatus.completed;

    // Map tracking to index: 0=pending, 1=processing, 2=shipped, 3=delivered
    int currentIndex = 0;
    if (isCompleted) {
      currentIndex = 3;
    } else {
      final tracking = currentTracking.toLowerCase();
      if (tracking == 'processing') {
        currentIndex = 1;
      } else if (tracking == 'shipped') currentIndex = 2;
      else if (tracking == 'delivered') currentIndex = 3;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('track_order', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildTimelineStep(lang, 'tracking_pending', currentIndex >= 0, currentIndex == 0, isLast: false),
            _buildTimelineStep(lang, 'tracking_processing', currentIndex >= 1, currentIndex == 1, isLast: false),
            _buildTimelineStep(lang, 'tracking_shipped', currentIndex >= 2, currentIndex == 2, isLast: false),
            _buildTimelineStep(lang, 'tracking_delivered', currentIndex >= 3, currentIndex == 3, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String lang, String titleKey, bool isFinished, bool isActive, {required bool isLast}) {
    final color = isFinished ? Colors.green : Colors.grey[300]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isFinished ? Colors.green : Colors.transparent,
                border: Border.all(color: color, width: 2),
                shape: BoxShape.circle,
              ),
              child: isFinished 
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : isActive ? Container(margin: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: color,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get(titleKey, lang),
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.black : (isFinished ? Colors.green : Colors.grey),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditInfoDialog(BuildContext context, WidgetRef ref, OrderModel order, String lang) {
    final addressController = TextEditingController(text: order.address);
    final phoneController = TextEditingController(text: order.userPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('edit_info', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: InputDecoration(labelText: AppStrings.get('address', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: AppStrings.get('phone', lang)),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () async {
              await ref.read(orderActionsProvider).updateOrderInfo(
                order.id, 
                addressController.text.trim(), 
                phoneController.text.trim()
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order info updated!')));
              }
            },
            child: Text(AppStrings.get('update_btn', lang)),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref, OrderModel order, String lang) {
    final asyncProducts = ref.read(productsProvider);
    ProductModel? selectedProduct;
    String? selectedColor;
    String? selectedSize;
    int quantity = 1;
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Filter products based on search query
          final filteredProducts = asyncProducts.maybeWhen(
            data: (products) => products.where((p) => 
              p.name.toLowerCase().contains(searchQuery.toLowerCase())
            ).toList(),
            orElse: () => <ProductModel>[],
          );

          return AlertDialog(
            title: Text(AppStrings.get('add_product', lang)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search field
                  TextField(
                    decoration: InputDecoration(
                      labelText: AppStrings.get('search', lang),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        // Reset selection when search changes
                        if (selectedProduct != null && !filteredProducts.contains(selectedProduct)) {
                          selectedProduct = null;
                          selectedColor = null;
                          selectedSize = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Product dropdown with filtered results
                  asyncProducts.when(
                    data: (products) => DropdownButtonFormField<ProductModel>(
                      initialValue: selectedProduct,
                      decoration: InputDecoration(labelText: AppStrings.get('select_product', lang)),
                      items: filteredProducts.map((p) => DropdownMenuItem(
                        value: p, 
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (p) {
                        setState(() {
                          selectedProduct = p;
                          selectedColor = p?.variants.isNotEmpty == true ? p!.variants.first.color : null;
                          selectedSize = p?.variants.isNotEmpty == true ? p!.variants.first.size : null;
                        });
                      },
                    ),
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  if (selectedProduct != null) ...[
                    const SizedBox(height: 16),
                    if (selectedProduct!.colors.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedColor,
                        decoration: InputDecoration(labelText: AppStrings.get('color', lang)),
                        items: selectedProduct!.variants.map((v) => v.color).whereType<String>().toSet().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => selectedColor = v),
                      ),
                    if (selectedProduct!.sizes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedSize,
                        decoration: InputDecoration(labelText: AppStrings.get('size', lang)),
                        items: selectedProduct!.variants.where((v) => v.color == selectedColor || selectedProduct!.colors.isEmpty).map((v) => v.size).whereType<String>().toSet().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => selectedSize = v),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(AppStrings.get('quantity_label', lang)),
                        const Spacer(),
                        IconButton(onPressed: quantity > 1 ? () => setState(() => quantity--) : null, icon: const Icon(Icons.remove_circle_outline)),
                        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
              FilledButton(
                onPressed: selectedProduct == null ? null : () {
                  _addProductToOrder(ref, order, selectedProduct!, quantity, selectedColor, selectedSize);
                  Navigator.pop(ctx);
                },
                child: Text(AppStrings.get('add', lang)),
              ),
            ],
          );
        },

      ),
    );
  }

  void _addProductToOrder(WidgetRef ref, OrderModel order, ProductModel product, int qty, String? color, String? size) {
    final newItem = {
      'id': product.id,
      'productId': product.id,
      'name': product.name,
      'price': product.price,
      'quantity': qty,
      'color': color ?? 'Default',
      'size': size ?? 'Default',
      'imageUrl': product.imageUrl,
    };

    final newItems = [...order.items, newItem];
    
    // Calculate new total
    final oldSubtotal = order.items.fold(0.0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1));
    final newSubtotal = newItems.fold(0.0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1));
    final diff = newSubtotal - oldSubtotal;
    final newTotal = order.total + diff;

    ref.read(orderActionsProvider).updateOrderItems(order, newItems, newTotal);
  }
}
