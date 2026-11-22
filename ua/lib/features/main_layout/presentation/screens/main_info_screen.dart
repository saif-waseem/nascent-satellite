import '../../../auth/presentation/widgets/buyer_account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/features/shared/providers.dart';

class MainInfoScreen extends ConsumerWidget {
  const MainInfoScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncTenant = ref.watch(tenantProvider);
    
    return Scaffold(
      drawer: Drawer(
        child: asyncTenant.when(
          data: (tenant) => ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: _buildImageOrIcon(tenant?.logoUrl, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final asyncUser = ref.watch(userProvider);
                      return asyncUser.maybeWhen(
                        data: (user) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'Guest', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(user?.id ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        orElse: () => const Text('Welcome', style: TextStyle(color: Colors.white, fontSize: 18)),
                      );
                    }),
                  ],
                ),
              ),
              if (tenant?.description != null && tenant!.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tenant.description, style: const TextStyle(color: Colors.grey)),
                ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppStrings.get('language', lang)),
                onTap: () {
                   final nextLang = lang == 'ar' ? 'en' : 'ar';
                   ref.read(appSettingsProvider.notifier).setLocale(nextLang);
                },
              ),
               if(ref.watch(userPhoneProvider)!=null) ListTile(
                  leading:const Icon(Icons.person_remove_outlined),title:const Text('حذف حسابي'),
                  onTap:()=>showDialog(context:context,builder:(_)=>BuyerAccountDialog(phone:ref.read(userPhoneProvider)))),
                ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(AppStrings.get('sign_out', lang), style: const TextStyle(color: Colors.red)),
                onTap: () {
                   ref.read(userActionsProvider).logout();
                   context.go('/login');
                },
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: AppStrings.get('store', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: AppStrings.get('profile', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: AppStrings.get('orders', lang),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOrIcon(String? data, {double size = 24}) {
    if (data != null && data.startsWith('http')) {
      return Image.network(
        data, 
        width: size, 
        height: size, 
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: size, color: Colors.grey),
      );
    }
    final iconCode = int.tryParse(data ?? '0x1234') ?? 58900;
    return Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), size: size);
  }
}
