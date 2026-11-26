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
    final newCurrency = useState('د.ع');

    const currencies = [
      ('د.ع', 'د.ع (دينار عراقي)'),
      ('\$', '\$ (دولار أمريكي)'),
      ('ر.س', 'ر.س (ريال سعودي)'),
      ('AED', 'AED (درهم إماراتي)'),
      ('EUR', '€ (يورو)'),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: () => advanced.value = !advanced.value,
          child: Text(advanced.value ? 'العودة إلى المبسّط' : 'المخزون المتقدّم'))],
        title: Text(lang == 'ar' ? 'إدارة المخازن والفروع' : 'Warehouses & Branches'),
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
                      flex: 3,
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: lang == 'ar' ? 'اسم المخزن أو الفرع الجديد' : 'New Branch / Warehouse Name',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: newCurrency.value,
                        decoration: InputDecoration(
                          labelText: lang == 'ar' ? 'العملة' : 'Currency',
                          border: const OutlineInputBorder(),
                        ),
                        items: currencies
                            .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) newCurrency.value = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          await ref.read(adminFirestoreServiceProvider).addWarehouse(
                            tenantId,
                            controller.text.trim(),
                            currency: newCurrency.value,
                          );
                          controller.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(lang == 'ar' ? 'إضافة' : 'Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final currentItemCurrency = item['currency'] as String? ?? 'د.ع';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.storefront, color: Colors.blue),
                        ),
                        title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Row(
                          children: [
                            Text(lang == 'ar' ? 'العملة المعتمدة: ' : 'Currency: ', style: const TextStyle(fontSize: 12)),
                            DropdownButton<String>(
                              value: currencies.any((c) => c.$1 == currentItemCurrency) ? currentItemCurrency : 'د.ع',
                              isDense: true,
                              underline: const SizedBox(),
                              items: currencies
                                  .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                                  .toList(),
                              onChanged: (newVal) async {
                                if (newVal != null) {
                                  await ref.read(adminFirestoreServiceProvider).updateWarehouse(
                                    tenantId,
                                    item['id'],
                                    {'currency': newVal},
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => ref.read(adminFirestoreServiceProvider).deleteWarehouse(tenantId, item['id']),
                        ),
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
