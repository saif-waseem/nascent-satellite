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
      data: (tenant) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('حالة ترخيص النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildStatusCard(tenant),
            const SizedBox(height: 16),
            _buildOfflineCard(),
            const SizedBox(height: 32),
            if (tenant?.isPosEnabled != true)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // This is handled by LicenseCheckWrapper normally
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

  Widget _buildStatusCard(TenantModel? tenant) {
    final isActivated = tenant?.isPosEnabled == true;
    return Card(
      child: ListTile(
        leading: Icon(
          isActivated ? Icons.verified : Icons.warning_amber,
          color: isActivated ? Colors.green : Colors.orange,
          size: 40,
        ),
        title: Text(isActivated ? 'النسخة مفعلة بالكامل' : 'النسخة غير مفعلة'),
        subtitle: Text(isActivated 
            ? 'ترخيص دائمي غير مرتبط بمدة محددة' 
            : 'يجب تفعيل البرنامج للوصول لكافة الميزات'),
        trailing: isActivated ? const Icon(Icons.check_circle, color: Colors.green) : null,
      ),
    );
  }

  Widget _buildOfflineCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text('المزامنة والعمل دون اتصال', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'البرنامج يعمل حالياً بنظام المزامنة التلقائية. يمكنك الاستمرار بالعمل وتسجيل المبيعات حتى عند انقطاع الإنترنت.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
