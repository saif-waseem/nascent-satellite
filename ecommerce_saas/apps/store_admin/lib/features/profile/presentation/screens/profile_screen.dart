import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenant = ref.watch(tenantProvider).value;
    
    final managerNameController = useTextEditingController();
    final managerPhoneController = useTextEditingController();
    final storeNameController = useTextEditingController();
    final descriptionController = useTextEditingController();

    useEffect(() {
      if (tenant != null) {
        managerNameController.text = tenant.managerName ?? '';
        managerPhoneController.text = tenant.managerPhone ?? '';
        storeNameController.text = tenant.name;
        descriptionController.text = tenant.description;
      }
      return null;
    }, [tenant]);

    if (tenant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('profile', lang)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Store ID
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('ID: ${tenant.id}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // 2. Personal Info Section
            Text(AppStrings.get('profile', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: managerNameController,
              decoration: InputDecoration(
                labelText: AppStrings.get('manager_name', lang),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: managerPhoneController,
              decoration: InputDecoration(
                labelText: AppStrings.get('manager_phone', lang),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            
            // 3. Store Info Section
            Text(AppStrings.get('store_name', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: storeNameController,
              decoration: InputDecoration(
                labelText: AppStrings.get('store_name', lang),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.store_outlined),
                counterText: '${storeNameController.text.length}/50',
              ),
              maxLength: 50,
              onChanged: (v) => (context as Element).markNeedsBuild(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: AppStrings.get('description', lang),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            
            // 4. Restricted Subscription Info
            Text(AppStrings.get('subscription_info', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            Text(
              AppStrings.get('restricted_fields_msg', lang),
              style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(AppStrings.get('expiry_date', lang), tenant.expiryDate?.toString().split(' ')[0] ?? 'N/A', Icons.calendar_today),
            const SizedBox(height: 12),
            _buildReadOnlyField(AppStrings.get('activation_code', lang), tenant.activationCode ?? '******', Icons.vpn_key_outlined),
            
            const SizedBox(height: 48),
            
            // 5. Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                   final updated = tenant.copyWith(
                     managerName: managerNameController.text.trim(),
                     managerPhone: managerPhoneController.text.trim(),
                     name: storeNameController.text.trim(),
                     description: descriptionController.text.trim(),
                   );
                   await ref.read(adminFirestoreServiceProvider).updateTenant(updated);
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(AppStrings.get('success_msg', lang)))
                     );
                   }
                },
                child: Text(AppStrings.get('save_changes', lang)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
        ],
      ),
    );
  }
}
