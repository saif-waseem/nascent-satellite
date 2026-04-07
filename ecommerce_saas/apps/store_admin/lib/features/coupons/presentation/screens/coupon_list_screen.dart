import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:go_router/go_router.dart';

class CouponListScreen extends ConsumerWidget {
  const CouponListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(currentTenantIdProvider);
    final asyncCoupons = ref.watch(couponListProvider(tenantId));
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('manage_coupons', lang)),
      ),
      body: asyncCoupons.when(
        data: (coupons) {
          if (coupons.isEmpty) {
            return Center(child: Text(AppStrings.get('no_coupons_msg', lang)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: coupons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: coupon.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      coupon.type == DiscountType.percentage ? Icons.percent : Icons.attach_money,
                      color: coupon.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(coupon.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                    '${coupon.value}${coupon.type == DiscountType.percentage ? '%' : ' IQD'} off | Used ${coupon.usageCount}/${coupon.maxUsage}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: coupon.isActive,
                        onChanged: (val) {
                           ref.read(adminFirestoreServiceProvider).updateCoupon(
                             tenantId, 
                             CouponModel(
                               id: coupon.id,
                               code: coupon.code,
                               type: coupon.type,
                               value: coupon.value,
                               isActive: val,
                               maxUsage: coupon.maxUsage,
                               usageCount: coupon.usageCount,
                             )
                           );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.push('/coupons/add', extra: coupon),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, tenantId, coupon.id, lang),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading coupons: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/coupons/add'),
        icon: const Icon(Icons.add),
        label: Text(AppStrings.get('add_coupon', lang)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String tenantId, String id, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('delete_confirm_title', lang)),
        content: Text(AppStrings.get('delete_confirm_msg_short', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(adminFirestoreServiceProvider).deleteCoupon(tenantId, id);
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.get('delete', lang)),
          ),
        ],
      ),
    );
  }
}

final couponListProvider = StreamProvider.family<List<CouponModel>, String>((ref, tenantId) {
  return ref.watch(adminFirestoreServiceProvider).getCoupons(tenantId);
});
