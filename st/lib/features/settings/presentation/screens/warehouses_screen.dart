import 'package:shared_models/src/widgets/stock_record_screen.dart';
import 'package:store_admin/core/services/supabase_config.dart';
import 'package:shared_models/src/widgets/inventory_balance_list.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';

class WarehousesScreen extends HookConsumerWidget {
  final bool showRecords;
  const WarehousesScreen({super.key,this.showRecords=false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenantId = ref.watch(currentTenantIdProvider);
    final advanced = useState(showRecords);
    final controller = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: () => advanced.value = !advanced.value,
          child: Text(advanced.value ? 'العودة إلى المبسّط' : 'المخزون المتقدّم'))],
        title: Text(lang == 'ar' ? 'إدارة المخازن' : 'Warehouses Management'),
      ),
      body: advanced.value ? ref.watch(adminProductsProvider).when(data: (products) => InventoryBalanceList(products: products, showCost: true, onOpenRecord: (p) => Navigator.push(context, MaterialPageRoute(builder: (_) => StockRecordScreen(product:p,url:SupabaseConfig.url,publishableKey:SupabaseConfig.anonKey,allowCount:true)))), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text(e.toString()))) : StreamBuilder<List<Map<String, dynamic>>>(
        stream: ref.read(adminFirestoreServiceProvider).getWarehouses(tenantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: lang == 'ar' ? 'اسم المخزن الجديد' : 'New Warehouse Name',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          await ref.read(adminFirestoreServiceProvider).addWarehouse(tenantId, controller.text);
                          controller.clear();
                        }
                      },
                      child: Text(lang == 'ar' ? 'إضافة' : 'Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return ListTile(
                      title: Text(item['name'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => ref.read(adminFirestoreServiceProvider).deleteWarehouse(tenantId, item['id']),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
