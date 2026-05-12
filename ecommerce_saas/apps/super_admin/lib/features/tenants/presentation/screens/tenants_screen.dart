import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:super_admin/core/localization/resources/app_strings.dart';
import 'package:super_admin/features/shared/providers.dart';
import 'package:shared_models/shared_models.dart';
import 'package:super_admin/features/tenants/presentation/widgets/add_tenant_dialog.dart';
import 'package:super_admin/features/tenants/presentation/widgets/subscription_dialog.dart';
import 'package:super_admin/features/tenants/presentation/widgets/edit_tenant_dialog.dart';
import 'package:super_admin/features/shared/widgets/super_admin_drawer.dart';
import 'package:intl/intl.dart';

class TenantsScreen extends HookConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now mocking lang.value as 'ar' or 'en' based on system or simple toggle
    final lang = useState('ar');
    final tenants = ref.watch(filteredTenantsProvider);

    useEffect(() {
      Future.microtask(() => ref.read(superAdminFirestoreServiceProvider).refreshSubscriberCounts());
      return null;
    }, []);

    return Scaffold(
      drawer: const SuperAdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('tenants', lang.value)),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => lang.value = lang.value == 'ar' ? 'en' : 'ar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(superAdminFirestoreServiceProvider).refreshSubscriberCounts(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => ref.read(tenantSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: AppStrings.get('search_tenants', lang.value),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: tenants.isEmpty 
              ? Center(child: Text(AppStrings.get('no_tenants_found', lang.value)))
              : ListView.builder(
                  itemCount: tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = tenants[index];
                    return _TenantCard(tenant: tenant, lang: lang.value);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context, 
          builder: (ctx) => AddTenantDialog(lang: lang.value)
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TenantCard extends ConsumerWidget {
  final TenantModel tenant;
  final String lang;
  
  const _TenantCard({required this.tenant, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isExpired = tenant.expiryDate != null && tenant.expiryDate!.isBefore(DateTime.now());
    final bool isActive = tenant.isActive && !isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isActive ? Icons.check_circle : Icons.warning,
            color: isActive ? Colors.green : Colors.red,
          ),
        ),
        title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Icon(Icons.shop, size: 14, color: tenant.isStoreEnabled ? Colors.green : Colors.grey),
            const SizedBox(width: 4),
            Icon(Icons.point_of_sale, size: 14, color: tenant.isPosEnabled ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text('ID: ${tenant.id}'),
          ],
        ),
        trailing: Text('${AppStrings.get('subscriber_count', lang)}: ${tenant.subscriberCount}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(context, AppStrings.get('expiry', lang), 
                  tenant.expiryDate != null ? DateFormat('yyyy/MM/dd').format(tenant.expiryDate!) : 'N/A'),
                _buildInfoRow(context, AppStrings.get('activation_code', lang), tenant.activationCode ?? '-', isActivationCode: true),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => SubscriptionDialog(tenant: tenant, lang: lang),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: Text(AppStrings.get('manage_subscription', lang)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => EditTenantDialog(tenant: tenant, lang: lang),
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(lang == 'ar' ? 'تعديل' : 'Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _toggleStatus(context, ref),
                      icon: Icon(tenant.isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                      label: Text(tenant.isActive 
                        ? AppStrings.get('deactivate', lang) 
                        : AppStrings.get('activate', lang)
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tenant.isActive ? Colors.red : Colors.green,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(AppStrings.get('delete', lang)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isActivationCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                 Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                 if (isActivationCode && value != '-' && value != 'N/A')
                   IconButton(
                     icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                     onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!')));
                     },
                     constraints: const BoxConstraints(),
                     padding: const EdgeInsets.only(left: 8),
                   )
              ],
            )
          ),
        ],
      ),
    );
  }

  void _toggleStatus(BuildContext context, WidgetRef ref) {
    if (tenant.isActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.get('confirm_deactivate', lang)),
          content: Text(AppStrings.get('confirm_deactivate_msg', lang)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
            TextButton(
              onPressed: () {
                ref.read(superAdminFirestoreServiceProvider).setTenantActiveStatus(tenant.id, false);
                Navigator.pop(ctx);
              },
              child: Text(AppStrings.get('deactivate', lang), style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      ref.read(superAdminFirestoreServiceProvider).setTenantActiveStatus(tenant.id, true);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.get('confirm_delete', lang)),
          content: Text(AppStrings.get('confirm_delete_msg', lang)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(AppStrings.get('cancel', lang))
            ),
            TextButton(
              onPressed: () async {
                await ref.read(superAdminFirestoreServiceProvider).deleteTenant(tenant.id);
                Navigator.pop(ctx);
              },
              child: Text(
                AppStrings.get('delete', lang), 
                style: const TextStyle(color: Colors.red)
              ),
            ),
          ],
        ),
      );
  }
}
