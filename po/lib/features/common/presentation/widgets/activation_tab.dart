import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';

class ActivationTab extends ConsumerWidget {
  const ActivationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) => SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('حالة ترخيص النظام والباقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TierBadgeWidget(tenant: tenant),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusCard(context, tenant),
            const SizedBox(height: 16),
            _buildSyncModeCard(tenant),
            if (tenant != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => TierBadgeWidget.showSubscriptionDetailsDialog(context, tenant),
                icon: const Icon(Icons.layers_outlined),
                label: const Text('عرض تفاصيل الباقة والميزات المسموحة'),
              ),
            ],
            const SizedBox(height: 24),
            if (tenant?.isPosEnabled != true)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء الانتقال للشاشة الرئيسية لإدخال الكود')),
                    );
                  },
                  child: const Text('إدخال كود التفعيل'),
                ),
              ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildStatusCard(BuildContext context, TenantModel? tenant) {
    final isActivated = tenant?.isPosEnabled == true;
    final tier = tenant?.effectivePosTier ?? 'A';
    final devLimit = tenant?.effectivePosDeviceLimit ?? 1;
    final devText = devLimit == -1 ? 'غير محدود' : '$devLimit';
    final isExpiredGrace = tenant?.isPosSubscriptionExpiredBeyondGrace == true;

    return Card(
      child: ListTile(
        leading: Icon(
          isExpiredGrace
              ? Icons.lock_clock
              : (isActivated ? Icons.verified : Icons.warning_amber),
          color: isExpiredGrace
              ? Colors.red
              : (isActivated ? Colors.green : Colors.orange),
          size: 40,
        ),
        title: Text(
          isExpiredGrace
              ? 'انتهت مدة الاشتراك (وضع باقة A المحلي)'
              : (isActivated ? 'النسخة مفعلة • الباقة $tier' : 'النسخة غير مفعلة'),
        ),
        subtitle: Text(
          isActivated
              ? 'الأجهزة المسموحة: $devText • '
                  '${tenant?.posExpiryDate != null ? "ينتهي في ${tenant!.posExpiryDate!.year}-${tenant.posExpiryDate!.month.toString().padLeft(2, '0')}-${tenant.posExpiryDate!.day.toString().padLeft(2, '0')}" : "ترخيص مفتوح المدة"}'
              : 'يجب تفعيل البرنامج للوصول لكافة الميزات',
        ),
        trailing: isActivated && !isExpiredGrace
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }

  Widget _buildSyncModeCard(TenantModel? tenant) {
    final isCloudAllowed = tenant?.isPosCloudAllowed ?? false;
    final isLanAllowed = tenant?.isPosLanAllowed ?? false;
    final tier = tenant?.effectivePosTier ?? 'A';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCloudAllowed
                      ? Icons.cloud_done_outlined
                      : (isLanAllowed ? Icons.lan_outlined : Icons.storage_rounded),
                  color: isCloudAllowed ? Colors.blue : Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  isCloudAllowed
                      ? 'المزامنة السحابية مفعّلة (الباقة $tier)'
                      : (isLanAllowed
                          ? 'مزامنة الشبكة المحلية فقط (الباقة $tier)'
                          : 'التخزين المحلي فقط بدون خزن سحابي (الباقة $tier)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isCloudAllowed
                  ? 'المزامنة السحابية والنسخ الاحتياطي السحابي مفعّلان لباقتك مع استمرار العمل عند انقطاع الإنترنت.'
                  : 'في الباقة $tier يتم حفظ جميع الفواتير والمخزون محلياً على الجهاز فقط ولا يتم تفعيل الخزن أو المزامنة السحابية إلا عند الترقية.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
