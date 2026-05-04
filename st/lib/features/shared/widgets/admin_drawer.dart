import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/features/shared/providers.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenantId = ref.watch(currentTenantIdProvider);
    final asyncTenant = ref.watch(tenantProvider);

    return Drawer(
      child: Column(
        children: [
          asyncTenant.when(
            data: (tenant) => UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: tenant?.logoUrl != null
                    ? ClipOval(child: Image.network(tenant!.logoUrl!, fit: BoxFit.cover, width: 72, height: 72))
                    : const Icon(Icons.store, size: 40),
              ),
              accountName: Text(tenant?.name ?? 'Store Admin'),
              accountEmail: Text('ID: $tenantId'),
              onDetailsPressed: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            loading: () => const DrawerHeader(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => DrawerHeader(child: Center(child: Text('Error: $e'))),
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('analytics', lang),
            Icons.analytics_outlined,
            '/dashboard',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('orders', lang),
            Icons.local_shipping_outlined,
            '/orders',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('marketing', lang),
            Icons.campaign_outlined,
            '/marketing',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('categories_label', lang),
            Icons.category_outlined,
            '/categories',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('products_label', lang), 
            Icons.inventory_2_outlined,
            '/products',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('subscribers', lang),
            Icons.people_outline,
            '/customers',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('manage_coupons', lang),
            Icons.confirmation_num_outlined,
            '/coupons',
          ),
          _buildDrawerItem(
            context,
            AppStrings.get('loyalty_logic', lang),
            Icons.stars_outlined,
            '/loyalty-settings',
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            AppStrings.get('settings', lang),
            Icons.settings_outlined,
            '/settings',
          ),
          const Spacer(),
          ListTile(
            title: Text(AppStrings.get('logout_reset', lang), style: const TextStyle(color: Colors.red)),
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            onTap: () async {
              await ref.read(currentTenantAuthProvider.notifier).clearTenant();
              if (context.mounted) context.go('/');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, String route) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (route == '/dashboard') {
          context.go(route);
        } else {
          context.push(route);
        }
      },
    );
  }
}
