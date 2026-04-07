import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../widgets/shop_info_tab.dart';
import '../widgets/staff_roles_tab.dart';
import '../widgets/devices_tab.dart';
import '../widgets/activation_tab.dart';
import '../widgets/customization_tab.dart';
import '../widgets/loyalty_settings_tab.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات والإدارة'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.store), text: 'بيانات المحل'),
              Tab(icon: Icon(Icons.badge), text: 'الموظفين والأدوار'),
              Tab(icon: Icon(Icons.print), text: 'الطابعات والأجهزة'),
              Tab(icon: Icon(Icons.tune), text: 'تخصيص القوالب والمزامنة'),
              Tab(icon: Icon(Icons.stars), text: 'نقاط الولاء'),
              Tab(icon: Icon(Icons.vpn_key), text: 'التفعيل والترخيص'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const ShopInfoTab(),
            const StaffRolesTab(),
            const DevicesTab(),
            const CustomizationTab(),
            const LoyaltySettingsTab(),
            const ActivationTab(),
          ],
        ),
      ),
    );
  }
}
