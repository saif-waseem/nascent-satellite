import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/features/shared/providers.dart';
import 'dart:ui';

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${AppStrings.get('orders', lang)} #$orderId'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderStatusCard(context, order, lang),
            const SizedBox(height: 24),
            
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(AppStrings.get('address', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 if (status == OrderStatus.active)
                   TextButton.icon(
                     onPressed: () => _showEditInfoDialog(context, ref, order, lang), 
                     icon: const Icon(Icons.edit, size: 16),
                     label: Text(AppStrings.get('edit', lang)),
                   ),
               ],
             ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                          child: Icon(Icons.location_on_rounded, color: Colors.blue[700], size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(address.isEmpty ? 'No address provided' : address, style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (order.landmark != null && order.landmark!.isNotEmpty)
                                Text(
                                  '${AppStrings.get('landmark', lang)}: ${order.landmark}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                          child: Icon(Icons.phone_rounded, color: Colors.green[700], size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(order.userPhone.isEmpty ? 'No phone provided' : order.userPhone, style: const TextStyle(fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(AppStrings.get('items_count', lang).replaceFirst('{count}', items.length.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 if (status == OrderStatus.active)
                    TextButton.icon(
                      onPressed: () => _showAddProductDialog(context, ref, order, lang),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: Text(AppStrings.get('add_product', lang)),
                    ),
               ],
             ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final quantity = item['quantity'] ?? 1;
              final productId = item['id'] as String?;
              final size = item['size'];
              final color = item['color'];
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final imageUrl = item['imageUrl'] as String? ?? 
                  (item['images'] != null && (item['images'] as List).isNotEmpty ? (item['images'] as List).first as String : null);
              
              final asyncProducts = ref.watch(productsProvider);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
                  ],
                ),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                '${AppStrings.get('qty', lang)}: $quantity${(size != null && size != 'Default') ? ' / $size' : ''}${(color != null && color != 'Default') ? ' / $color' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Text(formatCurrency(price * quantity), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _summaryRow(AppStrings.get('subtotal', lang), formatCurrency(subtotal)),
                  const SizedBox(height: 8),
                  _summaryRow(AppStrings.get('shipping', lang), formatCurrency(shipping)),
                  if (order.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow('${AppStrings.get('discount_code_label', lang)} (${order.couponCode ?? ""})', '-${formatCurrency(order.discountAmount)}', isNegative: true),
                  ],
                  if (order.pointsRedeemed > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow(AppStrings.get('points_redeem', lang), '-${formatCurrency(pointsDiscount)}', isNegative: true),
                  ],
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.get('total', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(formatCurrency(order.total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).primaryColor)),
                    ],
                  ),
                ],
              ),
            ),
            
            if (status == OrderStatus.active) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
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
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppStrings.get('edit', lang)),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red, 
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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

  Widget _summaryRow(String label, String value, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isNegative ? Colors.green : Colors.black)),
      ],
    );
  }

  Widget _buildOrderStatusCard(BuildContext context, OrderModel order, String lang) {
    if (order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(AppStrings.get('status_cancelled', lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 20)),
            const SizedBox(height: 8),
            Text(AppStrings.get('cancel_order_confirm', lang), style: TextStyle(fontSize: 13, color: Colors.red.withOpacity(0.7)), textAlign: TextAlign.center),
          ],
        ),
      ).animate().shake();
    }

    final currentTracking = order.tracking;
    final isCompleted = order.status == OrderStatus.completed;

    int currentIndex = 0;
    if (isCompleted) {
      currentIndex = 3;
    } else {
      final tracking = currentTracking.toLowerCase();
      if (tracking == 'processing') currentIndex = 1;
      else if (tracking == 'shipped') currentIndex = 2;
      else if (tracking == 'delivered') currentIndex = 3;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              Text(AppStrings.get('track_order', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 32),
          _buildVisualTimeline(lang, currentIndex),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(String lang, int currentIndex) {
    final statusIcons = [
      Icons.inventory_2_outlined,
      Icons.restaurant_menu_outlined, 
      Icons.moped_outlined,           
      Icons.home_outlined,            
    ];
    
    final labels = [
      'tracking_pending',
      'tracking_processing',
      'tracking_shipped',
      'tracking_delivered',
    ];

    return Column(
      children: [
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Track
                Container(
                  height: 6,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Progress Track
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  height: 6,
                  width: (currentIndex / (statusIcons.length - 1)) * width,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Nodes
                ...List.generate(statusIcons.length, (index) {
                  final isReached = index <= currentIndex;
                  final leftPos = index * (width - 16) / (statusIcons.length - 1);
                  
                  return Positioned(
                    left: leftPos,
                    top: -5,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isReached ? Colors.blue : Colors.white,
                        border: Border.all(color: isReached ? Colors.blue : Colors.grey[300]!, width: 2),
                        shape: BoxShape.circle,
                        boxShadow: isReached ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 4)] : [],
                      ),
                      child: isReached ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                    ),
                  );
                }),
                // Moving Icon
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOutCubic,
                  left: (currentIndex * (width - 48) / (statusIcons.length - 1)),
                  top: -55,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Icon(statusIcons[currentIndex], color: Colors.white, size: 28),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .moveY(begin: -3, end: 3, duration: 1200.ms, curve: Curves.easeInOut),
                      const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(labels.length, (index) {
             final isActive = index == currentIndex;
             final isReached = index <= currentIndex;
             return Expanded(
               child: Text(
                 AppStrings.get(labels[index], lang),
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   fontSize: 11,
                   fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                   color: isActive ? Colors.blue : (isReached ? Colors.black87 : Colors.grey[400]),
                 ),
               ),
             );
          }),
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
