import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/notification_repository.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final notificationsAsync = ref.watch(notificationsFutureProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).clearAll(tenantId);
              ref.invalidate(notificationsFutureProvider(tenantId));
            },
            child: const Text('تحديد الكل كمقروء'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات حالياً'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: n.isRead ? Colors.white : Colors.blue.shade50,
                child: ListTile(
                  leading: _getIcon(n.category),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.message),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(n.createdAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await ref.read(notificationRepositoryProvider).markAsRead(n.id);
                    try {
                      await ref.read(notificationsFutureProvider(tenantId).future).timeout(const Duration(seconds: 5), onTimeout: () => []);
                    } catch (_) {}
                    ref.invalidate(notificationsFutureProvider(tenantId));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Widget _getIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.stock:
        return const Icon(Icons.inventory, color: Colors.orange);
      case NotificationCategory.sales:
        return const Icon(Icons.shopping_bag, color: Colors.blue);
      case NotificationCategory.system:
        return const Icon(Icons.info, color: Colors.grey);
      case NotificationCategory.expiry:
        return const Icon(Icons.timer_outlined, color: Colors.red);
      default:
        return const Icon(Icons.notifications, color: Colors.blueGrey);
    }
  }
}
