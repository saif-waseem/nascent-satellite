import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';
import '../../features/common/data/app_settings_repository.dart';
import '../../features/common/data/notification_repository.dart';
import '../../features/products/presentation/providers/inventory_analysis_provider.dart';
import '../providers/tenant_provider.dart';

class StockAlertListener extends ConsumerWidget {
  final Widget child;
  const StockAlertListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Completely disabled on Windows: The C++ Firestore gRPC engine crashes when
    // orderBy+where compound queries run concurrently on startup.
    if (defaultTargetPlatform == TargetPlatform.windows) return child;

    final tenantId = ref.watch(tenantIdProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    
    ref.listen(inventoryAnalysisProvider, (previous, next) async {
       if (next.isLoading || next.hasError) return;
       
       final settings = settingsAsync.value;
       if (settings == null || !settings.stockAlertsEnabled) return;

       final insights = next.value ?? [];
       final repo = ref.read(notificationRepositoryProvider);
       
       try {
         final currentNotifications = await ref.read(notificationsFutureProvider(tenantId).future)
             .timeout(const Duration(seconds: 5), onTimeout: () => []);
             
         final notifiedProductIds = currentNotifications
             .where((n) => !n.isRead && n.category == NotificationCategory.stock)
             .map((n) => n.relatedId)
             .toSet();
         final notifiedExpiryIds = currentNotifications
             .where((n) => !n.isRead && n.category == NotificationCategory.expiry)
             .map((n) => n.relatedId)
             .toSet();

         for (final insight in insights) {
           final p = insight.product;
           final minLevel = p.minStockLevel ?? 5;
           final sellable = BatchInventoryHelper.sellableStock(p);
           
           if (sellable <= minLevel && !notifiedProductIds.contains(p.id)) {
              final notification = NotificationModel(
                id: const Uuid().v4(),
                tenantId: tenantId,
                title: 'نقص في المخزون: ${p.name}',
                message: 'الكمية الصالحة المتوفرة حالياً هي $sellable فقط. الحد الأدنى: $minLevel',
                type: sellable <= 0 ? NotificationType.error : NotificationType.warning,
                category: NotificationCategory.stock,
                createdAt: DateTime.now(),
                relatedId: p.id,
              );
              await repo.addNotification(notification);
           }

           final batchAlerts = BatchInventoryHelper.inspectBatches(p);
           if (batchAlerts.isNotEmpty && !notifiedExpiryIds.contains(p.id)) {
             final first = batchAlerts.first;
             await repo.addNotification(NotificationModel(
               id: const Uuid().v4(),
               tenantId: tenantId,
               title: first.isExpired ? 'صلاحية منتهية: ${p.name}' : 'تنبيه قرب انتهاء الصلاحية: ${p.name}',
               message: first.message,
               type: first.isExpired ? NotificationType.error : NotificationType.warning,
               category: NotificationCategory.expiry,
               createdAt: DateTime.now(),
               relatedId: p.id,
             ));
           }
         }
       } catch (e) {
         debugPrint('Error in StockAlertListener: $e');
       }
    });

    return child;
  }
}
