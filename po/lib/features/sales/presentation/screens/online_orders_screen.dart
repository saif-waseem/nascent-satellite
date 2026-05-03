import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/services/firestore_rest_service.dart';

final onlineOrdersProvider = FutureProvider.family<List<OrderModel>, String>((ref, tenantId) async {
  final restService = ref.watch(firestoreRestServiceProvider);
  final results = await restService.runQuery('orders', {
    'where': {
      'fieldFilter': {
        'field': {'fieldPath': 'tenantId'},
        'op': 'EQUAL',
        'value': {'stringValue': tenantId}
      }
    }
  });
  
  final list = results.map((d) => OrderModel.fromJson(d)).toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});

class OnlineOrdersScreen extends ConsumerWidget {
  const OnlineOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات المتجر أونلاين'),
      ),
      body: tenantAsync.when(
        data: (tenant) {
          if (tenant == null) return const Center(child: Text('Tenant not found'));
          
          if (!tenant.isStoreEnabled) {
            return _buildLockedState();
          }

          return DefaultTabController(
            length: 7,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'الكل'),
                    Tab(text: 'قيد الانتظار'),
                    Tab(text: 'قيد التجهيز'),
                    Tab(text: 'تم الشحن'),
                    Tab(text: 'تم التسليم'),
                    Tab(text: 'مكتملة'),
                    Tab(text: 'ملغية'),
                  ],
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'All'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Pending'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Processing'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Shipped'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Delivered'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Completed'),
                      _OnlineOrdersList(tenantId: tenant.id, filter: 'Cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                size: 80,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'قسم الطلبات أونلاين مغلق',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'يتم تفعيل هذا القسم تلقائياً في حال الاشتراك في برنامج المتجر الإلكتروني وربطه بنظام المبيعات.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineOrdersList extends ConsumerWidget {
  final String tenantId;
  final String filter;
  const _OnlineOrdersList({required this.tenantId, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(onlineOrdersProvider(tenantId));

    return ordersAsync.when(
      data: (allOrders) {
        final orders = allOrders.where((o) {
            if (filter == 'Pending') {
              return o.status == OrderStatus.active && (o.tracking == 'Pending' || o.tracking == 'Preparing');
            } else if (filter == 'Processing') {
              return o.status == OrderStatus.active && o.tracking == 'Processing';
            } else if (filter == 'Shipped') {
              return o.status == OrderStatus.active && o.tracking == 'Shipped';
            } else if (filter == 'Delivered') {
              return (o.status == OrderStatus.active || o.status == OrderStatus.completed) && o.tracking == 'Delivered';
            } else if (filter == 'Completed') {
              return o.status == OrderStatus.completed;
            } else if (filter == 'Cancelled') {
              return o.status == OrderStatus.cancelled;
            }
            return true;
        }).toList();
        
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('لا يوجد طلبات في هذا القسم'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ExpansionTile(
                title: Text(
                  'طلب #${order.id.substring(0, 5).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('العميل: ${order.userName}'),
                    Text('التاريخ: ${order.date.toString().substring(0, 16)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Text('${order.total} IQD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                leading: _getStatusIcon(order.status),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المنتجات في الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Divider(),
                        ...order.items.map((item) {
                          final name = item['productName'] ?? item['name'] ?? item['title'] ?? 'منتج غير معروف';
                          final imageUrl = item['imageUrl'] ?? item['image'] ?? item['productImage'];
                          final qty = item['quantity'] ?? item['qty'] ?? 1;
                          final price = item['price'] ?? 0;
                          final variant = item['variant'] ?? (item['variantColor'] != null ? '${item['variantColor']} ${item['variantSize'] ?? ""}' : null);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl != null 
                                    ? SmartImage(imageUrl: imageUrl, width: 50, height: 50, fit: BoxFit.cover, placeholder: _placeholderImage())
                                    : _placeholderImage(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (variant != null) Text('النوع: $variant', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                      Text('السعر: $price x $qty', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Text('${(price * qty).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }),
                        if (order.status == OrderStatus.active || order.status == OrderStatus.completed) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildStateButton(context, order, 'Pending', 'قيد الانتظار', Icons.hourglass_empty, Colors.orange),
                              _buildStateButton(context, order, 'Processing', 'قيد التجهيز', Icons.settings_suggest, Colors.blue),
                              _buildStateButton(context, order, 'Shipped', 'تم الشحن', Icons.local_shipping, Colors.teal),
                              _buildStateButton(context, order, 'Delivered', 'تم التسليم', Icons.check_circle, Colors.green),
                            ],
                          ),
                          if (order.status == OrderStatus.active) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _updateStatus(context, ref, order.id, OrderStatus.cancelled, 'Cancelled'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                                label: const Text('إلغاء الطلب'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[200],
      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 24),
    );
  }

  Widget _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.active: return const Icon(Icons.timer_outlined, color: Colors.orange);
      case OrderStatus.completed: return const Icon(Icons.check_circle, color: Colors.green);
      case OrderStatus.cancelled: return const Icon(Icons.cancel, color: Colors.red);
    }
  }

  Widget _buildStateButton(BuildContext context, OrderModel order, String targetTracking, String label, IconData icon, Color color) {
    final isCurrent = order.tracking == targetTracking || (targetTracking == 'Pending' && order.tracking == 'Preparing');
    final targetStatus = targetTracking == 'Delivered' ? OrderStatus.completed : OrderStatus.active;
    
    return isCurrent 
      ? FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: null,
          icon: Icon(icon, size: 18),
          label: Text(label),
        )
      : Consumer(
          builder: (ctx, ref, _) => OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
            onPressed: () => _updateStatus(ctx, ref, order.id, targetStatus, targetTracking),
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String orderId, OrderStatus status, String tracking) async {
    final restService = ref.read(firestoreRestServiceProvider);
    await restService.setDocument('orders/$orderId', {
      'status': status.name,
      'tracking': tracking,
    }, isUpdate: true);
    ref.invalidate(onlineOrdersProvider);
  }
}
