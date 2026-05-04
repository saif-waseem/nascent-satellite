import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:shared_models/shared_models.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncOrders = ref.watch(ordersProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('orders', lang)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: AppStrings.get('all', lang)),
            Tab(text: AppStrings.get('active', lang)),
            Tab(text: AppStrings.get('completed', lang)),
            Tab(text: AppStrings.get('cancelled', lang)),
          ],
        ),
      ),
      body: asyncOrders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (orders) => TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersList(orders, null, lang),
            _buildOrdersList(orders, OrderStatus.active, lang),
            _buildOrdersList(orders, OrderStatus.completed, lang),
            _buildOrdersList(orders, OrderStatus.cancelled, lang),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> allOrders, OrderStatus? filterStatus, String lang) {
    final filteredOrders = filterStatus == null
        ? allOrders
        : allOrders.where((o) => o.status == filterStatus).toList();

    if (filteredOrders.isEmpty) {
      return Center(child: Text(AppStrings.get('no_orders_yet', lang)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildOrderCard(order, lang);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, String lang) {
    final orderId = order.id;
    final status = order.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.push('/order-details/$orderId'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${AppStrings.get('order_id_label', lang)}#$orderId', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  _buildStatusChip(status, order.tracking, lang),
                ],
              ),
              const SizedBox(height: 12),
              Text('${order.items.length} ${AppStrings.get('items', lang)} • ${formatCurrency(order.total)}'),
              const SizedBox(height: 8),
              // Show item previews
              _buildItemPreview(order.items),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (status == OrderStatus.active)
                    TextButton.icon(
                      onPressed: () => _cancelOrder(order),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(AppStrings.get('cancel_order', lang)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  if (status == OrderStatus.active)
                    TextButton.icon(
                      onPressed: () => _modifyOrder(order),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(AppStrings.get('edit', lang)), // Using existing 'edit' string
                    ),
                  if (status == OrderStatus.cancelled || status == OrderStatus.completed)
                    TextButton.icon(
                      onPressed: () => _deleteOrder(order.id),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(AppStrings.get('delete', lang)),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  const Spacer(),
                  Text(
                    AppStrings.get('view_details', lang),
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview(List<Map<String, dynamic>> items) {
    final displayItems = items.take(3).toList();
    final asyncProducts = ref.watch(productsProvider);
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: displayItems.map((item) {
        final productId = item['id'] as String?;
        final imageUrl = item['imageUrl'] as String? ?? 
            (item['images'] != null && (item['images'] as List).isNotEmpty ? (item['images'] as List).first as String : null);
        
        return InkWell(
          onTap: productId == null ? null : () {
            // Try to find the full product in the provider
            ProductModel? fullProduct;
            asyncProducts.whenData((products) {
              try {
                fullProduct = products.firstWhere((p) => p.id == productId);
              } catch (_) {}
            });
            
            if (fullProduct != null) {
              context.push('/product-details', extra: fullProduct);
            } else {
              // Fallback to partial data if not in cache, details screen should handle it
              // We need at least tenantId and description, which might be missing.
              // For now, just pass what we have and we'll fix details screen.
              context.push('/product-details', extra: item);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: imageUrl != null && (imageUrl.startsWith('http') || imageUrl.contains('/'))
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 16))
                    : Icon(IconData(int.tryParse(imageUrl ?? '58900') ?? 58900, fontFamily: 'MaterialIcons'), size: 16, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item['name']} x${item['quantity'] ?? 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip(OrderStatus status, String tracking, String lang) {
    Color color = Colors.grey;
    if (status == OrderStatus.completed) color = Colors.green;
    if (status == OrderStatus.cancelled) color = Colors.red;
    if (status == OrderStatus.active) {
      if (tracking == 'processing' || tracking == 'shipped') {
        color = Colors.orange;
      } else {
        color = Colors.blue; // pending
      }
    }

    String displayText = '';
    if (status == OrderStatus.completed) {
      displayText = AppStrings.get('status_completed', lang).toUpperCase();
    } else if (status == OrderStatus.cancelled) {
      displayText = AppStrings.get('status_cancelled', lang).toUpperCase();
    } else {
      // Active status - display tracking info
      if (tracking == 'processing') {
        displayText = AppStrings.get('tracking_processing', lang).toUpperCase();
      } else if (tracking == 'shipped') {
        displayText = AppStrings.get('tracking_shipped', lang).toUpperCase();
      } else if (tracking == 'delivered') {
        displayText = AppStrings.get('tracking_delivered', lang).toUpperCase();
      } else {
        displayText = AppStrings.get('tracking_pending', lang).toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('cancel_order', lang)),
        content: Text(AppStrings.get('cancel_order_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get('no', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.get('yes', lang)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(orderActionsProvider).cancelOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get('order_cancelled', lang))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('delete_order', lang)),
        content: Text(AppStrings.get('confirm_delete_msg', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('no', lang))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.get('yes', lang), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(orderActionsProvider).deleteOrder(orderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get('order_deleted', lang))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _modifyOrder(OrderModel order) {
    ref.read(cartProvider.notifier).loadFromOrder(order);
    ref.read(editingOrderIdProvider.notifier).set(order.id);
    context.push('/cart');
  }
}
